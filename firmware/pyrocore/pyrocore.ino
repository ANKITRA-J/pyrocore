#include <Arduino.h>
#include <ArduinoJson.h>
#include "fpga_loader.h"
#include "frame_parser.h"

namespace {
constexpr char Version[] = "0.1.0";
constexpr uint32_t FrameTimeoutMs = 600;
HardwareSerial FPGA(2);
FrameParser parser;
FPGALoadResult loadResult = {false, 0, "Not initialized"};
bool fpgaVerified = false, streaming = true, inFlight = false;
uint8_t targetFPS = 5, selectedMaterial = 0, selectedPattern = 0;
uint32_t frames = 0, crcErrors = 0, headerErrors = 0, timeouts = 0;
uint32_t requestedAt = 0, nextFrameAt = 0;
char commandLine[384], encoded[2049];
size_t commandLength = 0;
bool commandOverflow = false;

void error(const char* message) {
  StaticJsonDocument<256> doc;
  doc["type"] = "error"; doc["message"] = message;
  serializeJson(doc, Serial); Serial.println();
}
void status(const char* type) {
  StaticJsonDocument<768> doc;
  doc["type"] = type; doc["version"] = Version; doc["board"] = "Shrike-Fi";
  doc["fpga_loaded"] = loadResult.transferred; doc["fpga_verified"] = fpgaVerified;
  doc["loader_message"] = loadResult.message; doc["bitstream_bytes"] = loadResult.bytes;
  doc["streaming"] = streaming; doc["fps_target"] = targetFPS;
  doc["material"] = selectedMaterial; doc["pattern"] = selectedPattern;
  doc["frames"] = frames; doc["crc_errors"] = crcErrors;
  doc["header_errors"] = headerErrors; doc["timeouts"] = timeouts;
  serializeJson(doc, Serial); Serial.println();
}
void acknowledge(const char* cmd) {
  StaticJsonDocument<160> doc; doc["type"] = "ack"; doc["cmd"] = cmd;
  serializeJson(doc, Serial); Serial.println();
}
void sendOpcode(uint8_t opcode) {
  const uint8_t pair[2] = {opcode, uint8_t(opcode ^ 0xff)};
  FPGA.write(pair, sizeof(pair));
}
void requestFrame(bool manual = false) {
  if (!loadResult.transferred) { if (manual) error(loadResult.message); return; }
  if (inFlight) { if (manual) error("A frame request is already in progress"); return; }
  parser.reset();
  while (FPGA.available()) FPGA.read();
  sendOpcode(0xf0);
  inFlight = true; requestedAt = millis();
  nextFrameAt = requestedAt + 1000 / targetFPS;
}
void publishFrame() {
  static const char alphabet[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  const uint8_t* source = parser.payload(); size_t out = 0;
  for (size_t i = 0; i < FrameParser::PayloadBytes; i += 3) {
    const uint32_t word = (uint32_t(source[i]) << 16) | (uint32_t(source[i+1]) << 8) | source[i+2];
    encoded[out++] = alphabet[(word >> 18) & 63]; encoded[out++] = alphabet[(word >> 12) & 63];
    encoded[out++] = alphabet[(word >> 6) & 63]; encoded[out++] = alphabet[word & 63];
  }
  encoded[out] = 0;
  // Base64 has no JSON metacharacters; the original binary frame passed CRC.
  Serial.print("{\"type\":\"frame\",\"seq\":"); Serial.print(parser.sequence());
  Serial.print(",\"width\":64,\"height\":64,\"format\":\"indexed3-lsb\",\"source\":\"fpga\",\"crc_ok\":true,\"data\":\"");
  Serial.print(encoded); Serial.println("\"}");
}
bool selection(JsonDocument& doc, uint8_t& material, uint8_t& pattern) {
  material = selectedMaterial; pattern = selectedPattern;
  if (doc.containsKey("material")) {
    if (!doc["material"].is<int>() || doc["material"].as<int>() < 0 || doc["material"].as<int>() > 5) {
      error("material must be an integer from 0 through 5"); return false;
    }
    material = doc["material"].as<uint8_t>();
  }
  if (doc.containsKey("pattern")) {
    if (!doc["pattern"].is<int>() || doc["pattern"].as<int>() < 0 || doc["pattern"].as<int>() > 2) {
      error("pattern must be an integer from 0 through 2"); return false;
    }
    pattern = doc["pattern"].as<uint8_t>();
  }
  return true;
}
void handleCommand() {
  StaticJsonDocument<512> doc;
  if (deserializeJson(doc, commandLine) || !doc.is<JsonObject>() || !doc["cmd"].is<const char*>()) {
    error("Expected a JSON object with a cmd string"); return;
  }
  const char* cmd = doc["cmd"];
  if (!strcmp(cmd, "hello") || !strcmp(cmd, "status")) { status(cmd); return; }
  if (!strcmp(cmd, "stream")) {
    if (!doc["enabled"].is<bool>()) { error("stream requires enabled true or false"); return; }
    if (doc.containsKey("fps") && (!doc["fps"].is<int>() || doc["fps"].as<int>() < 1 || doc["fps"].as<int>() > 7)) {
      error("fps must be an integer from 1 through 7"); return;
    }
    streaming = doc["enabled"].as<bool>();
    if (doc.containsKey("fps")) targetFPS = doc["fps"].as<uint8_t>();
    nextFrameAt = millis(); acknowledge(cmd); return;
  }
  if (!strcmp(cmd, "frame")) { requestFrame(true); return; }
  if (!strcmp(cmd, "set") || !strcmp(cmd, "launch")) {
    uint8_t material, pattern;
    if (!selection(doc, material, pattern)) return;
    if (!loadResult.transferred) { error(loadResult.message); return; }
    selectedMaterial = material; selectedPattern = pattern;
    sendOpcode(0x10 + material); sendOpcode(0x20 + pattern);
    if (!strcmp(cmd, "launch")) sendOpcode(1);
    acknowledge(cmd); return;
  }
  if (!strcmp(cmd, "clear")) {
    if (!loadResult.transferred) { error(loadResult.message); return; }
    sendOpcode(2); acknowledge(cmd); return;
  }
  error("Unknown command");
}
void consumeUSB() {
  for (size_t budget = 0; budget < 512 && Serial.available(); ++budget) {
    const char value = char(Serial.read());
    if (value == '\r') continue;
    if (value == '\n') {
      commandLine[commandLength] = 0;
      if (commandOverflow) error("Command line too long");
      else if (commandLength) handleCommand();
      commandLength = 0; commandOverflow = false;
    } else if (commandLength + 1 < sizeof(commandLine) && !commandOverflow) commandLine[commandLength++] = value;
    else commandOverflow = true;
  }
}
void consumeFPGA() {
  while (FPGA.available()) {
    const uint8_t value = uint8_t(FPGA.read());
    if (!inFlight) continue;
    const FrameParser::Result result = parser.consume(value);
    if (result == FrameParser::InvalidHeader) ++headerErrors;
    else if (result == FrameParser::InvalidCRC) {
      ++crcErrors; inFlight = false; error("FPGA frame CRC mismatch");
    } else if (result == FrameParser::Complete) {
      ++frames; fpgaVerified = true; inFlight = false;
      digitalWrite(21, frames & 1);
      if (Serial) publishFrame();
    }
  }
}
} // namespace

void setup() {
  pinMode(21, OUTPUT); digitalWrite(21, LOW);
  Serial.begin(115200);
  loadResult = loadFPGA("/fpga_bitstream.bin");
  FPGA.setRxBufferSize(4096); FPGA.begin(115200, SERIAL_8N1, 13, 11);
  nextFrameAt = millis() + 100;
  if (Serial) status("hello");
}
void loop() {
  consumeFPGA(); if (Serial) consumeUSB();
  const uint32_t now = millis();
  if (inFlight && now - requestedAt >= FrameTimeoutMs) {
    parser.reset(); inFlight = false; ++timeouts;
    if (Serial) error("FPGA frame timeout");
    nextFrameAt = now + 1000 / targetFPS;
  }
  if (Serial && streaming && !inFlight && int32_t(now - nextFrameAt) >= 0) requestFrame();
  delay(1);
}
