# PyroCore handoff

Updated 3 November 2026. Repository: https://github.com/ANKITRA-J/pyrocore

## Start here

The first integrated prototype is implemented, compiled and checked in simulation.
**The next task is physical-board bring-up.** No PyroCore image or firmware has
been uploaded to a board yet. Work inside this standalone repository; its parent
folder is a different project.

Read PROTOCOL.md before changing either endpoint of a link. Read README.md for
setup commands. PROJECT_PLAN.md records scope and future improvements. This file
is the current status and takes precedence over older planning notes.

## Implemented

- Eight FPGA particles with signed fixed-point positions, gravity, lifetime and
  screen clipping, using a sequential renderer and rotating state banks.
- Radial, ring and willow patterns; six material colours; FPGA white flicker.
- Two 64×64×3-bit dedicated BRAM framebuffers, with safe front/back ownership.
- Launch, clear and selection commands; packed full-frame UART streaming with
  sequence, version, length and CRC8 checks.
- ESP32-S3 FPGA loader, bounded USB JSON commands, native frame validation,
  base64 forwarding, streaming control and diagnostic counters.
- PySide6 desktop connection, material/pattern selection, Launch, Clear,
  Random Show, palette, received FPS, staleness indication and software preview.

Normal desktop mode displays FPGA frames. The explicit`--demo`mode is a software
preview and is visibly labelled. Its smoother animation is not FPGA performance.

## Verified actual-engine results

| Check | Result |
|---|---|
| Renesas synthesis and routing | Passed; MCU bitstream generated |
| Logic blocks |132/140 (94.3%); nine use shift-register resources |
| Dedicated BRAM | Six slices:0–2 and 4–6; two unused slices |
| Raw placer LUT/FF report |469 six-input LUT resources;333 CLB FFs;134 IOB FFs |
| Core / oscillator |3.125MHz /50MHz |
| Typical-corner setup | WNS+15.599ns; TNS0 |
| Renderer simulation | Full clears, exact motion/gravity, launch/clear queues and completion ordering passed |
| Complete UART simulation | Two 1545-byte frames; header, CRC and all 4096 pixels match immutable RAM snapshots |
| Buffer safety | No writes or swaps of the frame being transmitted |
| Command checks | Malformed launch rejected; valid material/pattern/launch accepted |
| Firmware parser | CRC vector, valid/corrupt frames, length rejection, resynchronization and actual RTL packet passed |
| Desktop decoder | Seven protocol checks passed; actual RTL packet decoded into eight green pixels |
| Firmware compilation |359234bytes flash;26664bytes globals; LittleFS packaged |
| Desktop UI | Preview, controls, no-port startup and frame fixture exercised offscreen |
| Physical board | Not uploaded; not tested |

The raw placer units are not Workshop LUT5 counts. Do not reuse the earlier
memory-only test's87LUT5/14CLB figures for this engine. Logic space is tight;
future features should share arithmetic or replace logic before increasing scope.

Current memory: framebuffers occupy 3072 bytes of 4096 bytes dedicated BRAM.
Particle banks also use distributed shift-register resources, not the two unused
BRAM slices. Current full-frame link target is 5 FPS, not 20–30 FPS.

## Ready artifacts

- `firmware/pyrocore/data/fpga_bitstream.bin`: actual compiled PyroCore MCU SPI image,
  not the earlier memory exerciser. Its SHA256/source hashes are in the manifest.
- `reports/2026-11-03/build-manifest.json`: image/firmware hashes and validation state.
- `reports/2026-11-03/`: resource/timing summaries, simulation logs and a captured
  RTL-produced UART frame for cross-layer checks.
- `docs/images/desktop-preview.png`: explicitly labelled software preview.

Milestone source commit:`d9fdcae`. Subsequent commits add the verified image,
reports, reproducible cross-layer check and this final handoff; use`git log`for
those exact checkpoint hashes.

## Local setup completed

A project-local `.venv` has been created and its pinned desktop dependencies
installed. Its own offscreen preview rendered successfully. On a fresh clone,
use the setup commands below; on this Mac the environment is already ready.
`Launch PyroCore.command` starts normal desktop mode; pass `--demo` from a terminal
for the labelled software preview.

## Build and run

From the repository root:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r desktop/requirements.txt
.venv/bin/python desktop/app.py --demo
```

Build firmware from the included FPGA checkpoint:

```sh
python3 tools/build_firmware.py --bitstream firmware/pyrocore/data/fpga_bitstream.bin
```

Rebuild the actual FPGA if RTL changes:

```sh
python3 tools/build_fpga.py all --cpus 4
python3 tools/build_firmware.py --bitstream build/fpga/FPGA_bitstream_MCU.bin
```

Renesas Go Configure, ESP32 Arduino core3.3.12 and ArduinoJson6.21.5 are needed for
those builds. Desktop needs Python3.9–3.13; firmware helper Python3.9+.
Tool locations can be overridden in the helpers. See FIRMWARE.md and DESKTOP.md.

Focused checks when relevant changes are made:

```sh
python3 tools/run_rtl.py --runtime /path/to/verilator-5.034/include
python3 tools/check_host.py --packet build/sim/frame_packet.bin
```

A complete Verilator5 installation can run without`--runtime`. The minimal vendor
bundle needs matching runtime sources. These commands compile/run locally only.
Routine checks do not need a separate user discussion.

## Next concrete action

1. Connect Shrike-Fi through its native USB port and identify the port.
2. When the user requests the upload, package/upload the included PyroCore image
   and firmware using the helper's explicit`--port`option. This replaces the MCU
   application and filesystem; choose the actual board port.
3. Launch the desktop without`--demo`, connect, and require valid received frames.
   `fpga_loaded`means SPI image transfer;`fpga_verified`requires a valid UART frame.
4. Exercise Launch, each material/pattern, Clear and Random Show. Record the actual
   sustained FPS and any CRC/timeouts before changing clock or baud settings.
5. If a problem appears, investigate that measured failure and preserve this
   compiled baseline. Do not restart the whole project or repeat unrelated work.

## Remaining engineering limits

- No physical RAM/transport acceptance has been performed.
- BRAM-facing delays use vendor default`-1`constraints. Positive core setup slack
  does not sign off all external-to-fabric BRAM interface paths.
- IOB packing warnings remain on BRAM address/data/enable paths; review during
  real interface timing work. Recorded timing is typical1.1V/25°C only.
- The reported14.202MHz achievable core estimate is not measured memory speed.
  Retain3.125MHz initially.
- Two buffers stall rendering once the back buffer is ready and the front remains
  in transfer. Physics advances per rendered frame and may slow with transport.
- 115200-baud UART limits1545-byte frames to7.46FPS before additional delays.
  Smooth20–30FPS requires a later measured faster link; simply setting921600baud
  at3.125MHz is not a verified solution.
- Initial version has eight particles and point sparks; richer trails/density
  remain improvements subject to the132/140CLB budget.
