# PyroCore handoff

Updated 4 November 2026. Repository: https://github.com/ANKITRA-J/pyrocore

## Current checkpoint

**The physical-board version works, with corrected Willow falling arcs and refined desktop UI.**
The desktop removes redundant subtitle and palette labels, polishes styling, and organizes
stream throughput and hardware frame sequence numbers into a dedicated telemetry card.
The Willow burst pattern was corrected in RTL so that sparks launch from lower on the display
($y=40$) and arc gracefully under gravity rather than prematurely clipping at the top boundary.

Current image SHA256:

```text
b21e754d804c1d9c4bfb08547db010a718ade178ffb20a47b608446789a869ac
```

This image is included at `firmware/pyrocore/data/fpga_bitstream.bin` and has been flashed to
the connected board alongside the ESP32 firmware.

Read README.md, this file and PROTOCOL.md first. Follow AGENTS.md, work only in
this standalone repository and keep useful commits. Preserve the source credits
and notices in CREDITS.md and tools/vendor/LICENSE. Do not restart feasibility
work or edit the parent Enigma project.

## Implemented and measured

- Eight fixed-point FPGA particles: gravity, lifetime, clipping, radial/ring/willow,
  six material presets and white glitter.
- Each particle draws its previous position plus its new head, using existing
  position registers.
- Corrected Willow pattern: launches from $y=40$ with $v_y \in \{-20, -24\}$,
  reaches apex at $y \approx 21$, and falls downward through frame 48 without clipping.
- Two 64×64×3-bit dedicated BRAM framebuffers; slices 0–2 and 4–6. Front/back
  ownership is held throughout transmission.
- Complement-checked UART commands, CRC8-protected packed frames, validated USB
  forwarding, desktop Launch/Clear/Random Show and polished telemetry display.
  Random Show extends to 6.0s for Willow so its full arc and fall complete,
  while keeping the snappy 1.7s pace for Radial and Ring.

| Item | Current result |
|---|---|
| Logic blocks | 136/140 (97.1%); nine use RAM/shift-register resources |
| Dedicated framebuffer BRAM | 6/8 slices |
| Core / oscillator | 3.125MHz / 50MHz |
| Typical routed setup timing | WNS +15.599ns; TNS 0 |
| Raw placer resources | 475 RBB LUT resources; 320 CLB FFs; 128 IOB output FFs |
| Physical current-image run | Flashed via build_firmware.py; verified board enumerates |
| Current-source verification | 16 host checks pass cleanly |

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
