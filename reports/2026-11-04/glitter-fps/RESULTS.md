# Glitter and faster FPGA link

4 November 2026. Firmware **v0.3.0**, wire protocol v1. All materials and patterns
now glitter using Aluminium's existing LFSR visibility gate. The FPGA UART runs
at 312500 baud and the desktop requests 18 FPS, with 7/5 FPS fallbacks.
**This package is built and simulated; it has not been uploaded or physically tested.**
The board remains on the preceding [Pistil checkpoint](../pistil/RESULTS.md).

## Behavior and implementation

The low two LFSR bits hide each spark when both are zero. Head and trail share
the captured visibility decision, retain their colour, and continue moving and
aging while hidden. Pistil keeps its selected-colour shell and white core.
No particle state, framebuffer storage, motion arithmetic or lifetime was added.

The existing 3.125 MHz core clock divides exactly by 10 for 312500 baud. The
ESP32-S3 UART uses the same rate; the pinned Arduino core's 40 MHz crystal clock
also divides exactly by 128. USB CDC selection and firmware upload baud remain
separate. Both the application and FPGA image must be upgraded together.

## Measured build and simulation

| Item | Result |
|---|---:|
| Logic blocks | 131/140 |
| RBB LUT resources (not advertised LUT5 count) | 467 |
| CLB / IOB output flip-flops | 316 / 116 |
| Dedicated framebuffer BRAM | 6/8 slices |
| Core / oscillator | 3.125 / 50 MHz |
| Typical post-route WNS / TNS | +15.059 ns / 0 |
| New frame serializer duration | 168,873 cycles; 54.03936 ms |
| New serializer ceiling, before bridge/USB work | 18.505 FPS |
| New ideal polling simulation | 18.182 FPS; six advancing frames |
| Baseline serializer duration | 431,523 cycles; 138.08736 ms |
| Baseline ideal polling simulation | 7.042 FPS; six advancing frames |

The baseline uses the same current RTL with the earlier divisor 27 and 7 FPS
target. Integer-millisecond bridge-style scheduling gives 55 ms at target 18 and
142 ms at target 7. Every captured packet passes CRC and all 4,096 pixel comparisons
against its immutable RAM snapshot; frame sequences advance without ownership
violations. The simulation does not model ESP32 execution, USB or physical wiring.
The 18 FPS target has limited margin below the serializer ceiling and needs a
board measurement. Lower targets reduce polling load while keeping the same baud.

Rendering remains scheduled at 25 Hz with safe buffer ownership. Faster transfer
reduces stalls, so bursts can move and expire sooner in real time with unchanged
per-update physics. Full external BRAM timing signoff and long-run reliability
remain open.

## Checks and package

- Renderer: all 24 material/pattern combinations; visible/hidden and changing
  glitter gates, paired head/trail writes, colours, selection latch, geometry and Clear.
- Integrated UART: three full frames including mixed yellow/white Pistil, exact
  RAM/CRC comparison, malformed/unknown commands and front-buffer ownership.
- Receiver: 3,240 back-to-back bytes across nominal and ±1% peer baud at four
  asynchronous start phases, with no framing or ordering errors in simulation.
- Host: 18 tests, native firmware parser and the generated Pistil packet through
  the desktop decoder. GUI: disconnected startup and 18/7/5 FPS commands with
  serial access blocked.
- Renesas synthesis/routing/package and ESP32 application/LittleFS compilation pass.
  BRAM power-down bits 320/321 remain clear; the SPI header matches project nvmData.

Commands run from the repository root (the matching Verilator runtime is local):

```sh
python3 tools/run_rtl.py --top particle_renderer_tb --runtime build/toolchain/verilator-5.034/include
python3 tools/run_rtl.py --top pyrocore_core_tb --runtime build/toolchain/verilator-5.034/include
python3 tools/run_rtl.py --top uart_link_tb --runtime build/toolchain/verilator-5.034/include
python3 tools/run_rtl.py --top pyrocore_stream_rate_tb --runtime build/toolchain/verilator-5.034/include
.venv/bin/python tools/check_host.py --packet build/sim/pistil_frame_packet.bin
python3 tools/build_fpga.py all --cpus 4
.venv/bin/python tools/build_firmware.py --bitstream firmware/pyrocore/data/fpga_bitstream.bin --build build/glitter-fps-firmware
```

The included MCU SPI image is 46,408 bytes. Source/image/firmware hashes and check
scope are in the [manifest](build-manifest.json); accompanying logs retain the
build and simulation evidence. The preceding included image is preserved in a
local ignored backup. No serial port was opened, no board was flashed and no OTP
programming was performed. Next: when requested, upload the complete package and
check glitter, advancing frames, actual FPS, Clear and error counters on the board.
