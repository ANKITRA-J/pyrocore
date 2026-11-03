# ESP32-S3 bridge

`firmware/pyrocore/pyrocore.ino` loads the FPGA MCU-format image from LittleFS,
releases the shared configuration pins, and bridges the v1 FPGA protocol to USB
JSON. The bridge never computes particle positions or manufactures frame data.

Use ESP32 Arduino core **3.3.12**, ArduinoJson **6.21.5**, and this board setting:

```text
esp32:esp32:esp32s3:CDCOnBoot=cdc,FlashSize=8M,PartitionScheme=default_8MB
```

Compile and package a real PyroCore FPGA image without accessing the board:

```sh
python3 tools/build_firmware.py --bitstream PATH_TO_FPGA_bitstream_MCU.bin
```

The helper builds the sketch and a LittleFS image containing `/fpga_bitstream.bin`.
It reads the filesystem offset and size from the actual generated partition table.
Builds go under `build/firmware`, including hashes in `build-manifest.json`.
The helper writes the compiler cache under `build/arduino-cache`.

An upload is a distinct, explicit step. Close serial applications first:

```sh
python3 tools/build_firmware.py --bitstream PATH_TO_FPGA_bitstream_MCU.bin --port YOUR_PORT
```

That command replaces the board's application and filesystem. The normal Arduino
Upload button does not install the filesystem image. The FPGA is configured from
LittleFS on every boot; no OTP programming is used.

Runtime UART: ESP32 GPIO13 is RX, GPIO11 TX,115200baud8N1. Configuration uses
GPIO8 power,9 enable,10 select,12 clock,11 MOSI,13 MISO. Loading ends SPI before
starting runtime UART. No Wi-Fi or Bluetooth stack is started.

USB is native CDC at115200 selection. Send one JSON command per line, as documented
in `PROTOCOL.md`. The bridge defaults to five requests/second while a USB host is
connected. Streaming can be disabled; `frame` requests one frame. Unknown commands,
out-of-range selections, oversized command lines, UART timeouts and bad CRCs are
reported as JSON errors. Frame payloads are exactly1536bytes, base64 encoded.

`fpga_loaded` means the SPI image was transferred; `fpga_verified` becomes true
only after a complete correctly typed, correctly sized frame passes CRC.
`frames`, `crc_errors`, `header_errors` and `timeouts` are exposed in status.
`fpga_verified` records that communication has succeeded during this boot; current
communication health should also consider frame arrival and timeout counters.

The600ms frame timeout is longer than the roughly134ms wire time. The parser
resynchronizes on `50 59` magic after malformed headers; the next request resets
and drains a failed transfer. Incomplete packets never become displayed frames.

The parser is portable C++. Its native check runs without an Arduino board:

```sh
mkdir -p build
c++ -std=c++17 firmware/pyrocore/tests/test_frame_parser.cpp -o build/test_frame_parser
build/test_frame_parser
```

It checks the CRC reference vector, complete payloads, corruption and malformed
length rejection, repeated-magic resynchronization and timeout-style reset. Pass
a raw1545byte FPGA response as an argument to validate an RTL-generated packet.

The initial physical-board run passed Launch, moving particles, Clear and all18
material/pattern combinations at4.97FPS. See`reports/2026-11-03/BRINGUP.md` for
the BRAM power-header correction and the recorded hardware results.

Recorded local compile with the versions above: 359,234 bytes of application flash
(10%) and 26,664 bytes of global RAM (8%). The final firmware/LittleFS package uses
the actual PyroCore MCU image included in `data/fpga_bitstream.bin`; image/source
hashes are in `reports/2026-11-03/build-manifest.json`. The earlier packaging-only
check used a BRAM exerciser, but that is not the included checkpoint image.
The corrected image has now been uploaded and checked on the physical board.

Once the PyroCore firmware is running, close other serial applications and use
the project environment for the short board run:

```sh
.venv/bin/python tools/board_check.py --port YOUR_NATIVE_USB_PORT
```

It checks hello/loader state, complete validated frames, moving green particles,
Clear, measured streaming and error counters. It writes `build/hardware/latest.json`
and restores the selected material/pattern and streaming settings. It changes the
displayed scene but never uploads firmware. Without `--port`, it only lists ports.
