#include "../frame_parser.h"
#include <cassert>
#include <fstream>
#include <iostream>
#include <iterator>
#include <vector>

static std::vector<uint8_t> packet() {
  std::vector<uint8_t> bytes = {0x50,0x59,1,0x46,0x34,0x12,0,6};
  for (size_t i=0; i<FrameParser::PayloadBytes; ++i) bytes.push_back(uint8_t(i*31+0x50));
  uint8_t crc=0;
  for (size_t i=2; i<bytes.size(); ++i) crc=FrameParser::crc8(crc,bytes[i]);
  bytes.push_back(crc);
  return bytes;
}
static FrameParser::Result feed(FrameParser& parser, const std::vector<uint8_t>& bytes) {
  auto result=FrameParser::More;
  for (uint8_t byte:bytes) result=parser.consume(byte);
  return result;
}
int main(int argc, char** argv) {
  FrameParser parser;
  if (argc==2) {
    std::ifstream file(argv[1], std::ios::binary);
    assert(file.good());
    const std::vector<uint8_t> bytes{std::istreambuf_iterator<char>(file),{}};
    assert(bytes.size()==FrameParser::PacketBytes);
    assert(feed(parser,bytes)==FrameParser::Complete);
    std::cout<<"PASS FPGA packet: seq="<<parser.sequence()<<", payload=1536 bytes\n";
    return 0;
  }
  uint8_t crc=0;
  for (char c:std::string("123456789")) crc=FrameParser::crc8(crc,uint8_t(c));
  assert(crc==0xf4);
  auto valid=packet();
  assert(feed(parser,valid)==FrameParser::Complete);
  assert(parser.sequence()==0x1234);
  for (size_t i=0;i<FrameParser::PayloadBytes;++i) assert(parser.payload()[i]==uint8_t(i*31+0x50));
  auto corrupt=valid;corrupt[800]^=1;
  assert(feed(parser,corrupt)==FrameParser::InvalidCRC);
  assert(feed(parser,valid)==FrameParser::Complete);
  auto wrong=valid;wrong[6]=1;
  bool rejected=false;
  for (uint8_t b:wrong) rejected|=parser.consume(b)==FrameParser::InvalidHeader;
  assert(rejected);
  parser.reset();parser.consume(0x50);parser.consume(0x50);
  assert(feed(parser,std::vector<uint8_t>(valid.begin()+1,valid.end()))==FrameParser::Complete);
  parser.consume(0x50);parser.consume(0x59);assert(parser.partial());parser.reset();
  assert(feed(parser,valid)==FrameParser::Complete);
  std::cout<<"PASS CRC vector, valid payload, corruption rejection, length rejection, resynchronization, reset\n";
}
