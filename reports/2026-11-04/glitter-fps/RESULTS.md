# Glitter and faster FPGA link

4 November 2026. Firmware **v0.3.0**, wire protocol v1. All materials and patterns
now glitter using Aluminium's existing LFSR visibility gate. The FPGA UART runs
at 312500 baud and the desktop requests 18 FPS, with 7/5 FPS fallbacks.
**The complete package is uploaded and physically checked on Shrike-Fi.**
All 24 material/pattern presets pass colour, motion, paired-glitter and Clear
checks; the 18 FPS target measures **17.235 FPS**. The preceding
[Pistil checkpoint](../pistil/RESULTS.md) is retained as history.

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
The 18 FPS target has limited margin below the serializer ceiling; actual bridge
and USB overhead reduce physical throughput to about 17.2 FPS in the run below.
Lower targets reduce polling load while keeping the same baud.

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
build and simulation evidence. The build commands above do not access the board.

## Upload and physical acceptance

The owner explicitly requested the flash. The existing reviewed ESP32 application
and LittleFS files were uploaded without rebuilding or repackaging; their hashes
are unchanged. All five flash sections passed verification at 115200 upload baud.
The board reset into firmware v0.3.0, transferred the 46,408-byte FPGA image and
verified complete received FPGA frames. No OTP programming was performed.
The previous v0.2.0 five-section restore package and existing backups remain local.

| Physical stream target | Received frames | Measured duration | Received FPS |
|---|---:|---:|---:|
| 18 | 174 | 10.037884 s | 17.234708 |
| 7 | 23 | 3.122304 s | 7.046078 |
| 5 | 16 | 2.998879 s | 5.001869 |

FPS uses frame-arrival intervals, so 174 frames provide 173 intervals. Every
sequence advances. An independent initial 10-second run measured 17.114 FPS.
The faster target is about 2.45 times the preceding image's 7.035 FPS physical run.

Each of the 24 presets has 16 captured frames with its expected palette and
advancing positions. Yellow/white and green/white Pistil contrast is present.
Geometric analysis fits exactly one motion/velocity history to each preset,
including Radial's possible launch velocity variations. Across distinct,
in-bounds head/trail positions that do not overlap other sparks, captures contain
1,791 complete visible pairs and 619 complete hidden pairs. Each preset includes
particles observed both visible and hidden while moving. This is paired-glitter
evidence from physical captures; the exact LFSR gate remains independently tested
in RTL. Overlapping or coincident positions are excluded from that inference.

Clear produces two advancing black frames. The clean acceptance run records zero
rejected USB lines, CRC errors, header errors or timeouts. An earlier exploratory
run was not marked passed because one USB line was discarded without recording
its phase. The recorded repeat counts attachment and acceptance separately and
observes zero discards in both. No firmware change or second flash was needed.

The actual desktop received 75 frames during its short integration check, showed
LIVE FPGA, displayed mixed-colour Pistil and received Clear. Its final rolling
FPS snapshot was 17.33; the table above is the longer arrival-time measurement.

The [physical summary](hardware-physical.json) retains rates, statuses, sequences,
per-preset analysis and GUI results. The [compressed original capture](hardware-capture.json.gz)
retains every original base64 FPGA frame for review; its decompressed SHA256 is
recorded in the summary. [Upload verification](upload-verification.log) lists the
five section hashes without machine-specific paths. Local acceptance helpers ran as:

```sh
.venv/bin/python tools/board_check.py --port YOUR_PORT --fps 18 --duration 10 --output build/hardware/glitter-fps-fast.json
.venv/bin/python build/glitter_fps_board_run.py --port YOUR_PORT
.venv/bin/python build/analyze_glitter_physical.py --input build/hardware/glitter-fps-physical.json --output build/hardware/glitter-fps-glitter-analysis.json
QT_QPA_PLATFORM=offscreen .venv/bin/python build/glitter_fps_gui_check.py
```

The scene is left cleared with streaming enabled at the 18 FPS target, and all
test clients are closed. This is a short functional acceptance run; long-duration
reliability and full external BRAM timing signoff remain open.
