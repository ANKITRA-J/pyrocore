# Develop PyroCore

Start with [README setup](../README.md#setup) for a normal board installation.
This guide is the index for changing the source. Follow [AGENTS.md](../AGENTS.md),
preserve source credits, and read the [README handoff](../README.md#handoff) before
continuing someone else's work.

| Guide | Use it for |
|---|---|
| [Architecture](ARCHITECTURE.md) | Physics, patterns, glitter and framebuffer design |
| [Protocol](PROTOCOL.md) | USB commands, UART framing and pixel format |
| [Implementation reports](../reports/README.md) | Image/source hashes, measured fit and validation evidence |
| [Credits](CREDITS.md) | Authorship, reused source and bundled notices |

## Repository layout

| Path | Purpose |
|---|---|
| `desktop/` | PySide6 controls, serial worker, frame decoder and FPS statistics |
| `fpga/rtl/` | Authoritative Verilog sources |
| `fpga/sim/` | Renderer and full UART/framebuffer simulations |
| `fpga/project/` | Shrike-Fi peripheral configuration, pin map and clock constraints |
| `firmware/pyrocore/` | ESP32 loader, USB bridge and included FPGA image |
| `tools/` | Build and validation helpers; retained vendor formatter/license |
| `tests/` | Host protocol, image-header and frame-statistics checks |
| `reports/` | Dated implementation evidence; see its index |
| `build/`, `.venv/` | Ignored local generated files and dependencies |

`fpga/project/ffpga/src/main.v` is generated from `fpga/rtl`; edit the RTL files,
not that combined copy. Preserve ignored board backups when cleaning local builds.

## Rebuild the FPGA

Install [Renesas Go Configure Software Hub](https://www.renesas.com/software-tool/go-configure-software-hub)
with **SLG47910 Rev BB** support. The helper expects its bundled **Yosys v59** and
**eda-placer v23**. The scripted FPGA build is verified on macOS; other host layouts
may need adapting, so do not assume the same CLI works unchanged on Windows/Linux.

From the repository root:

```sh
python3 tools/build_fpga.py all --cpus 4
```

For a nonstandard installation, pass the directory containing `yosys/` and
`eda-placer/`:

```sh
python3 tools/build_fpga.py all --external PATH_TO_EXTERNAL --cpus 4
```

`GOCONFIGURE_EXTERNAL` can supply the same directory. Available steps are
`prepare`, `synth`, `pnr`, `package` and `all`. Use `all` for a source change so the
packaged image and reports come from the same successful run. Outputs are
`build/fpga/FPGA_bitstream_MCU.bin` and `build/fpga/manifest.json`.

For GUI inspection, run `prepare`, then open `fpga/project/pyrocore.ffpga`.
Keep the 3.125 MHz core clock, six BRAM slices and board pin mapping. Configuration
bits 320/321 must stay clear to power both framebuffer banks; the packager takes
its SPI header from project nvmData and rejects powered-down banks.

Do not mix a failed build's resource logs with a preceding successful image.
Before publishing a checkpoint, compare its image and RTL hashes with its manifest,
and archive resource/timing reports from that same successful run.

## Build the ESP32 package

Use the dependency installation in [README setup](../README.md#setup). To compile
and package the newly built FPGA image without accessing the board:

```sh
.venv/bin/python tools/build_firmware.py --bitstream build/fpga/FPGA_bitstream_MCU.bin
```

The helper builds for
`esp32:esp32:esp32s3:CDCOnBoot=cdc,FlashSize=8M,PartitionScheme=default_8MB`,
reads the generated partition table and packages LittleFS. Add `--port YOUR_PORT`
only when an upload is intended. This replaces the application and filesystem;
close serial clients first. Build output and its manifest are in `build/firmware/`.
A new FPGA image does not necessarily require changing the ESP32 application source.
For the current v0.3.0 release, deploy the matching application and FPGA image
together; its faster board link is incompatible with the previous pair.

The helper preserves your normal Arduino CLI configuration and detects its data
directory. Use `--arduino-cli PATH` for a CLI outside PATH, `--arduino-config FILE`
for a separate CLI configuration, or `--esp32-tools PATH` / `--libraries PATH` for
explicit tool/library locations. `--baud` changes upload speed; its default is 115200.

## Using a different board

The desktop and protocol can be reused. A different FPGA/board requires adapting
and rebuilding the FPGA top level, clocks, memory primitives and pin mapping.
An ESP32 bridge on another board also needs the configuration/UART pins and flash
partitioning adjusted. Review `fpga/project/pins.csv`, `fpga/rtl/pyrocore_top.v`,
`firmware/pyrocore/fpga_loader.cpp` and `firmware/pyrocore/pyrocore.ino`.
Do not upload the Shrike-Fi binary unchanged to a different device.

## Run checks relevant to a change

Host protocol, image header and frame statistics:

```sh
.venv/bin/python -m unittest discover -s tests -v
```

For desktop layout changes, capture the disconnected window for inspection:

```sh
QT_QPA_PLATFORM=offscreen .venv/bin/python desktop/app.py --screenshot build/desktop.png
```

RTL renderer and complete UART/framebuffer simulation, with Verilator 5 and a C++ compiler:

```sh
python3 tools/run_rtl.py
```

This runs all-material glitter/geometry checks, full-frame CRC and RAM comparisons,
back-to-back UART bytes at nominal and ±1% baud with four asynchronous start phases,
and production-clock throughput comparisons at the old and new link rates.
The rate test checks advancing frame sequences as well as received packet cadence;
it does not model ESP32 execution time, USB throughput or physical wiring.

The minimal bundled Verilator may need a matching runtime source directory:

```sh
python3 tools/run_rtl.py --runtime PATH_TO_VERILATOR_INCLUDE
```

Pass the resulting packet through the exact native firmware parser and desktop decoder:

```sh
.venv/bin/python tools/check_host.py --packet build/sim/pistil_frame_packet.bin
```

The full UART testbench writes `pistil_frame_packet.bin` for the mixed-colour
Pistil frame and `frame_packet.bin` for the earlier green Ring frame. Either can
be supplied to `check_host.py`; the Pistil packet checks both shell and core
colours through the firmware parser and desktop decoder.

For a board running PyroCore, close other serial clients first:

```sh
.venv/bin/python tools/board_check.py
.venv/bin/python tools/board_check.py --port YOUR_PORT --fps 18
```

Without `--port`, the first command lists ports only. The second changes the scene
to check launch, motion, Clear, streaming and error counters, restores selection/
stream settings, and writes `build/hardware/latest.json`. It never uploads.
This general board checker launches green Ring; it does not select Pistil. For a
current acceptance run, check glitter with each material/pattern, including
paired head/trail flicker and advancing motion. Launch Sodium/Pistil, confirm
moving yellow and white groups, repeat with Barium for green/white, then Clear.
Measure the 18 FPS target and both 7/5 FPS fallbacks with error counters; lower
targets reduce request load, not the board link speed. The current glitter/faster
link has not been physically checked. The
[earlier Pistil run](../reports/2026-11-04/pistil/RESULTS.md#physical-board-acceptance)
records the preceding image's frame data, spans, streaming and error counters.
Simulation, successful compilation, uploading and physical functional acceptance
are separate results. Do not claim one from another.

## Publish a checkpoint

Update the included binary only after its build succeeds. Keep a current manifest
and measured reports together, state which image was physically checked, and update
the [README handoff](../README.md#handoff) with the current state and remaining
limitations. Keep historical reports labelled as history. Use useful commits;
routine unchanged checks need not be repeated.
