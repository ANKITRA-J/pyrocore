# PyroCore handoff

Updated 3 November 2026. Repository: https://github.com/ANKITRA-J/pyrocore

## Current checkpoint

**The physical-board version works, including short FPGA-drawn trails.** The
current desktop fixes clipped controls, defaults to the measured7FPS stream and
shows stream throughput separately from scene activity. The user confirmed the
preceding live app worked; the refined layout was checked offscreen at2× scaling.

Current image SHA256:

```text
55068cb7b76fcd634ec4a98aa4ffae851ec6a113682b22a8f5e7fa8a464a7ad8
```

This image is included at `firmware/pyrocore/data/fpga_bitstream.bin` and is already
running on the connected board. The ESP32 application is unchanged; only its
LittleFS FPGA image was replaced for this refinement.

Read README.md, this file and PROTOCOL.md first. Follow AGENTS.md, work only in
this standalone repository and keep useful commits. Preserve the source credits
and notices in CREDITS.md and tools/vendor/LICENSE. Do not restart feasibility
work or edit the parent Enigma project.

## Implemented and measured

- Eight fixed-point FPGA particles: gravity, lifetime, clipping, radial/ring/willow,
  six material presets and white glitter.
- Each particle draws its previous position plus its new head, using existing
  position registers. These are two sampled points, not a fading or filled line.
- Two64×64×3-bit dedicated BRAM framebuffers; slices0–2 and4–6. Front/back
  ownership is held throughout transmission. No ESP32/laptop particle physics.
- Complement-checked UART commands, CRC8-protected packed frames, validated USB
  forwarding, desktop Launch/Clear/Random Show and a labelled offline preview.
- Desktop7FPS default with5FPS fallback; scrollable controls keep their size at
  larger display scaling. FPS averages complete arrivals over3seconds. Black
  frames count; `No sparks` and `Active · N lit pixels` describe scene content.
  Startup says calculating; stale/disconnected streams report0 and retain the
  last image explicitly.

| Item | Current result |
|---|---|
| Logic blocks |134/140 (95.7%); nine use RAM/shift-register resources |
| Dedicated framebuffer BRAM |6/8 slices |
| Core / oscillator |3.125MHz /50MHz |
| Typical routed setup timing | WNS+15.995ns; TNS0 |
| Raw placer resources |474 RBB LUT resources;315 CLB FFs;128 IOB output FFs |
| Physical current-image run | Launch, two moving green head/trail frames (16 lit pixels), Clear passed |
| Current-image short stream |7.027FPS over22 frames; no new CRC/header/timeout errors |
| Preceding point-renderer image |18/18 material/pattern combinations;4.97FPS at5 target and7.036FPS at7 target |
| Current-source verification |16 host checks; renderer and two full UART frames passed |

Raw RBB LUT resources are not directly the advertised LUT5 count. Timing is the
vendor typical setup result; full external BRAM interface timing signoff and
long-duration streaming remain separate work. Keep3.125MHz and the existing
six-slice layout. Reports are in `reports/2026-11-03/refinement/`; the current
source/image manifest is `reports/2026-11-03/build-manifest.json`.

## Important hardware fix to preserve

The first upload produced valid but black frames because both peripheral BRAM
banks were powered down. Configuration bits320/321 must be0. `build_fpga.py`
enables them and derives its SPI header from project nvmData, rejecting disabled
banks. Do not restore the upstream blink header. Three regression cases cover
this. `reports/2026-11-03/BRINGUP.md` records the investigation.

The preceding working point-only image was
`a8f619efe1baf4e632af7d95634aaf334e9388cb767377e731c4cfe08da2e111`.
Its one-byte header correction left that old core unchanged; the current trail
image also includes a newly routed core. Do not use the original image ending
`...cdbce2d` as a working checkpoint.

## Local state

The native USB port was `/dev/cu.usbmodem1101`; rediscover it after reconnecting.
The old desktop was closed for the update. The refreshed app opens without
connecting automatically; select the board port and click Connect. Native Python
window clicks were blocked by automatic approval review, so the user operates
Connect/Disconnect manually. Do not work around that restriction.

A complete8MB backup of the board's previous flash and the preceding working
FPGA image are saved locally under `build/backups/2026-11-03/`, ignored by Git.
Preserve them. A temporary address-pattern diagnostic was abandoned and never
uploaded. Do not distribute its partial build.

## Commands

The local `.venv` and desktop dependencies are installed. On a new clone, create
it and install `desktop/requirements.txt`. From the repository root:

```sh
.venv/bin/python desktop/app.py
.venv/bin/python desktop/app.py --demo
python3 tools/build_firmware.py --bitstream firmware/pyrocore/data/fpga_bitstream.bin
python3 tools/build_fpga.py all --cpus 4
.venv/bin/python tools/board_check.py --port YOUR_NATIVE_USB_PORT --fps 7
```

The first two commands open normal mode and a labelled software preview.
Build commands do not upload. An explicit `--port` on the firmware helper uploads
and replaces the application/filesystem; close serial clients first and follow
AGENTS.md's authorization rule. No OTP programming is used. The board check does
not flash; it changes the scene and restores selection/stream settings. Without
`--port`, it only lists ports.

For relevant source changes:

```sh
.venv/bin/python -m unittest discover -s tests -v
python3 tools/run_rtl.py --runtime /path/to/verilator-5.034/include
python3 tools/check_host.py --packet build/sim/frame_packet.bin
```

Renesas Go Configure's bundled Yosys and eda-placer are used. Read FIRMWARE.md,
DESKTOP.md, RENDERER.md and TRAILS.md when changing those components. The generated
`fpga/project/ffpga/src/main.v` must match `fpga/rtl`; the build helper prepares it.

## Next concrete work

Use the updated app for a visual run and inspect the short trails. The user can
choose5FPS if preferred. Longer reliability measurement and BRAM interface timing
constraints can follow when needed; routine unchanged tests need not be repeated.

The next major performance improvement is the transport link:115200baud permits
at most7.46 complete1545-byte packets/s before delays.20–30FPS needs a measured
faster UART/SPI implementation and corresponding firmware/RTL work. Raising the
FPGA clock alone will not remove this bottleneck. With134/140 logic blocks used,
share or replace logic before adding particles or more elaborate effects.
