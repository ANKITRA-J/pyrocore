#pragma once
#include <stddef.h>
#include <stdint.h>

// Portable, bounded parser. The native host test exercises this exact code.
class FrameParser {
public:
  static constexpr size_t PayloadBytes = 1536;
  static constexpr size_t PacketBytes = 1545;
  enum Result { More, Complete, InvalidHeader, InvalidCRC };
  static uint8_t crc8(uint8_t crc, uint8_t value) {
    crc ^= value;
    for (uint8_t i = 0; i < 8; ++i)
      crc = (crc & 0x80) ? uint8_t((crc << 1) ^ 0x07) : uint8_t(crc << 1);
    return crc;
  }
  void reset() { position_ = 0; crc_ = 0; }
  bool partial() const { return position_ != 0; }
  const uint8_t* payload() const { return packet_ + 8; }
  uint16_t sequence() const { return uint16_t(packet_[4]) | (uint16_t(packet_[5]) << 8); }
  Result consume(uint8_t value) {
    if (position_ == 0) {
      if (value == 0x50) packet_[position_++] = value;
      return More;
    }
    if (position_ == 1) {
      if (value == 0x59) { packet_[position_++] = value; crc_ = 0; }
      else position_ = value == 0x50 ? 1 : 0;
      return More;
    }
    const size_t index = position_;
    packet_[position_++] = value;
    if (index < PacketBytes - 1) crc_ = crc8(crc_, value);
    if (position_ == 8 && (packet_[2] != 1 || packet_[3] != 0x46 ||
                          packet_[6] != 0 || packet_[7] != 6)) {
      reset(); return InvalidHeader;
    }
    if (position_ == PacketBytes) {
      const bool valid = value == crc_;
      reset(); return valid ? Complete : InvalidCRC;
    }
    return More;
  }
private:
  uint8_t packet_[PacketBytes] = {};
  size_t position_ = 0;
  uint8_t crc_ = 0;
};
