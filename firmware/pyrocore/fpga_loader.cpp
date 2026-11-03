#include "fpga_loader.h"
#include <LittleFS.h>
#include <SPI.h>

FPGALoadResult loadFPGA(const char* filename) {
  if (!LittleFS.begin(false)) return {false, 0, "LittleFS mount failed; upload the filesystem image"};
  File image = LittleFS.open(filename, "r");
  if (!image) return {false, 0, "Missing /fpga_bitstream.bin"};
  const uint32_t length = image.size();
  if (length < 1024 || length > 128 * 1024) {
    image.close(); return {false, length, "FPGA image size is invalid"};
  }
  // Shrike-Fi loader sequence. GPIO11/13 are shared with runtime UART.
  SPIClass configSPI(HSPI);
  pinMode(8, OUTPUT); pinMode(9, OUTPUT); pinMode(10, OUTPUT);
  digitalWrite(10, LOW); digitalWrite(9, LOW); digitalWrite(8, LOW);
  delay(100); digitalWrite(9, HIGH); digitalWrite(8, HIGH); delay(100);
  configSPI.begin(12, 13, 11, 10);
  delay(500); digitalWrite(10, HIGH); delayMicroseconds(2000); digitalWrite(10, LOW);
  configSPI.beginTransaction(SPISettings(1600000, MSBFIRST, SPI_MODE0));
  uint8_t chunk[512]; uint32_t sent = 0; const uint32_t started = millis();
  while (sent < length && millis() - started < 10000) {
    const size_t count = image.read(chunk, sizeof(chunk));
    if (!count) break;
    configSPI.transfer(chunk, count); sent += count;
  }
  configSPI.endTransaction(); digitalWrite(10, HIGH); image.close(); delay(100);
  configSPI.end();
  pinMode(11, INPUT); pinMode(13, INPUT); pinMode(12, INPUT);
  return {sent == length, length, sent == length ?
    "Image transferred; waiting for a valid FPGA frame" : "Incomplete FPGA transfer"};
}
