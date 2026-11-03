# PyroCore handoff

Updated 3 November 2026. Repository: https://github.com/ANKITRA-J/pyrocore

## Current checkpoint

**The first physical-board version works.** The user confirmed that the desktop
app works and receives live FPGA frames. Launch, moving particles, Clear and all
18 material/pattern combinations passed over the real Shrike-Fi USB connection.
The short streaming run measured 4.97 FPS at the 5 FPS setting, with no new CRC,
header or timeout errors.

A desktop layout/FPS-display refinement and evaluation of the existing 7 FPS setting
are now underway following the user's feedback. A small FPGA-drawn trail is being
considered within the remaining logic budget. Keep the confirmed board baseline
while evaluating those improvements.

Read README.md, this file and PROTOCOL.md first. Follow AGENTS.md; work only in
this standalone repository and preserve useful commits. CREDITS.md records source
attribution. Do not restart earlier feasibility work.

## Important fix from real hardware

The first uploaded image sent valid but all-black frames. Both peripheral BRAM
banks had been left powered down by a fixed default SPI header. Register bits320
and321 must be0, not1. The project now enables both banks; the packager derives
its SPI header from project nvmData and rejects disabled banks.

Only MCU-image byte1300 changed, from0x03to0x00. The routed FPGA core remained
byte-for-byte unchanged; the particle renderer was not the cause. The current
image SHA256 is:

```text
a8f619efe1baf4e632af7d95634aaf334e9388cb767377e731c4cfe08da2e111
```

Do not use the earlier image ending`...cdbce2d` as the working checkpoint.
Details and evidence are in`reports/2026-11-03/BRINGUP.md`,
`hardware-check.json`,`hardware-presets.json`and`bram-header-fix.json`.
The initial failed run is retained separately for traceability.

## Implemented

- Eight fixed-point FPGA particles with gravity, lifetime and clipping.
- Radial/ring/willow patterns, six material colours and white glitter.
- Two 64×64×3-bit dedicated BRAM framebuffers with safe front/back ownership.
- UART selection/launch/clear commands and packed, CRC-checked full frames.
- ESP32 loader and USB bridge; no ESP32 particle calculations.
- Desktop connection, launch, clear, random show, palette and live frames.
- Clearly labelled offline software preview, not presented as hardware performance.

## Measured baseline

| Item | Result |
|---|---|
| Logic blocks |132/140; nine use particle shift-register resources |
| Dedicated BRAM |6/8 slices,0–2 and4–6 |
| Core / oscillator |3.125MHz /50MHz |
| Typical setup timing | WNS+15.599ns, TNS0 |
| Raw placer resources |469 six-input LUT resources;333 CLB FFs;134 IOB FFs |
| Physical launch/motion/clear | Passed |
| Physical material/pattern combinations |18/18 passed |
| Short 5 FPS streaming run |4.97 received FPS, no new communication errors |

Raw placer LUT units are not Workshop LUT5 counts. Keep the existing clock and
six-slice memory mapping. Long-duration reliability and full BRAM interface timing
signoff are separate from this initial functional acceptance.

## Local state

The connected board is running the corrected PyroCore image and firmware.
Native USB port was`/dev/cu.usbmodem1101`; rediscover it if reconnected.
Close serial clients before an upload or command-line board check.

The user closed the first desktop window so layout/FPS improvements can be
applied without competing for the port. Native Python-window automation was not
approved; the user operated Connect/Disconnect and confirmed the app worked.

A complete 8 MB backup of the board's previous flash is saved locally under
`build/backups/2026-11-03/`. It is ignored by Git and was not uploaded. Preserve it.
A temporary address-pattern diagnostic was started then abandoned once the power
setting was identified; its renderer was restored and its image was never uploaded.

## Commands

The project-local`.venv`and pinned desktop dependencies are already installed.
On a fresh clone, create it and install`desktop/requirements.txt`.

```sh
.venv/bin/python desktop/app.py
.venv/bin/python desktop/app.py --demo
python3 tools/build_firmware.py --bitstream firmware/pyrocore/data/fpga_bitstream.bin
python3 tools/build_fpga.py all --cpus 4
.venv/bin/python tools/board_check.py --port YOUR_NATIVE_USB_PORT
```

The first two commands are normal mode and an explicitly labelled software preview.
Build commands do not upload. An explicit`--port`on the firmware helper performs
an upload; preserve the user's running state and close serial clients first.
`board_check.py`does not flash; it changes the scene for checks and restores the
material/pattern/streaming settings. Reports go under`build/hardware/`.

For relevant code changes only:

```sh
python3 -m unittest discover -s tests -v
python3 tools/run_rtl.py --runtime /path/to/verilator-5.034/include
python3 tools/check_host.py --packet build/sim/frame_packet.bin
```

Three configuration-header regression cases were added after the hardware fault.
No unchanged core route or firmware application rebuild was needed for the one-byte
power correction; only the filesystem image was repackaged and uploaded.

## Next work

Finish the desktop clipping/spacing fix, label stream FPS separately from scene
activity, and make stale/paused FPS behavior explicit. Measure7FPS before making
it a default. If a previous-position pixel trail fits, validate its new route and
actual board behavior while retaining the working baseline.

Then improve visual density and eventually the transfer link.115200baud limits
1545-byte packets to7.46FPS before delays;20–30FPS needs a faster measured link.
The132/140CLB budget is tight, so share logic instead of simply adding particles.
