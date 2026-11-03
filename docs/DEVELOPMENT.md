# Develop PyroCore

Start with [SETUP.md](SETUP.md) for a normal board installation. This guide is for
changing the source. Follow [AGENTS.md](../AGENTS.md), preserve source credits, and
read [HANDOFF.md](HANDOFF.md) before continuing someone else's work.

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

Use the dependency installation in SETUP.md. To compile and package the newly
built FPGA image without accessing the board:

```sh
.venv/bin/python tools/build_firmware.py --bitstream build/fpga/FPGA_bitstream_MCU.bin
```

The helper builds for
`esp32:esp32:esp32s3:CDCOnBoot=cdc,FlashSize=8M,PartitionScheme=default_8MB`,
reads the generated partition table and packages LittleFS. Add `--port YOUR_PORT`
only when an upload is intended. This replaces the application and filesystem;
close serial clients first. Build output and its manifest are in `build/firmware/`.
A new FPGA image does not necessarily require changing the ESP32 application source.

## Run checks relevant to a change

Host protocol, image header and frame statistics:

```sh
.venv/bin/python -m unittest discover -s tests -v
```

RTL renderer and complete UART/framebuffer simulation, with Verilator 5 and a C++ compiler:

```sh
python3 tools/run_rtl.py
```

The minimal bundled Verilator may need a matching runtime source directory:

```sh
python3 tools/run_rtl.py --runtime PATH_TO_VERILATOR_INCLUDE
```

Pass the resulting packet through the exact native firmware parser and desktop decoder:

```sh
.venv/bin/python tools/check_host.py --packet build/sim/frame_packet.bin
```

For a board running PyroCore, close other serial clients first:

```sh
.venv/bin/python tools/board_check.py
.venv/bin/python tools/board_check.py --port YOUR_PORT --fps 7
```

Without `--port`, the first command lists ports only. The second changes the scene
to check launch, motion, Clear, streaming and error counters, restores selection/
stream settings, and writes `build/hardware/latest.json`. It never uploads.
Simulation, successful compilation, uploading and physical functional acceptance
are separate results. Do not claim one from another.

## Publish a checkpoint

Update the included binary only after its build succeeds. Keep a current manifest
and measured reports together, state which image was physically checked, and update
HANDOFF.md with the current state and remaining limitations. Keep historical reports
labelled as history. Use useful commits; routine unchanged checks need not be repeated.
