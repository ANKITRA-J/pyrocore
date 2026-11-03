#pragma once
#include <Arduino.h>
struct FPGALoadResult {
  bool transferred;
  uint32_t bytes;
  const char* message;
};
FPGALoadResult loadFPGA(const char* filename);
