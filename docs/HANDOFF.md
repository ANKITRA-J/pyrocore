# PyroCore handoff

Updated 4 November 2026. **Pattern 3, Pistil, is implemented, flashed and
physically verified.** The owner's GUI and falling Willow changes remain intact.
Firmware is v0.2.0; the wire protocol remains v1.
Start with [SETUP.md](SETUP.md) for deployment and [DEVELOPMENT.md](DEVELOPMENT.md)
for source changes. Preserve credits/notices and follow [AGENTS.md](../AGENTS.md).

## Desktop update: FPGA frames only

Removed `--demo` and the approximate local particle animation at the owner's
request. The app starts disconnected with launch controls disabled and displays
received FPGA frames after connection. Random Show still sends board commands,
including the existing 6-second Willow interval. Clear still waits for the next
received frame. Setup, architecture, protocol and README now describe this behavior;
the README screenshot shows the disconnected app with no local animation.

Validation commands from the repository root:

```sh
.venv/bin/python -m unittest discover -s tests -v
.venv/bin/python desktop/app.py --help
.venv/bin/python desktop/app.py --demo
QT_QPA_PLATFORM=offscreen .venv/bin/python desktop/app.py --screenshot build/desktop.png
```

All 17 host tests pass. Help lists only `--screenshot` and help; the removed
`--demo` command intentionally exits 2 with an unrecognized-arguments error.
Offscreen startup/capture passes. An additional offscreen smoke check with serial
access blocked passed disconnected controls, Launch/Clear/stream commands,
6-second Willow cadence and all 4,096 displayed pixel colours from the saved RTL
Pistil packet. This is software validation, not a physical-board test.

Firmware, FPGA sources and the included image are unchanged; no upload or new
physical-board validation was performed. The earlier physical results below
remain the board evidence. Next concrete step: reopen with
`.venv/bin/python desktop/app.py`, connect the board and confirm a live burst in
the updated desktop. No firmware rebuild or upload is needed for this change.

## Current feature and image

Patterns are 0 Radial, 1 Ring, 2 Willow and 3 Pistil. Pistil's even particles use
full Ring velocity and selected material colour; odd particles use signed half
velocity, white index 6 and existing LFSR glitter. No particle-state storage or
BRAM was added. Aluminium's existing glitter remains; other patterns keep their
previous behavior. Both head and trail share each spark's colour/visibility.

The included SLG47910V Rev BB MCU SPI image is
`firmware/pyrocore/data/fpga_bitstream.bin`, 46,408 bytes:

```text
2c43d2c38a5dfc523b2b0acf14e82fb8469ae4645b2a72df387c8ca461251dbb
```

| Resource | Current successful build |
|---|---:|
| Logic blocks | 132/140 (94.3%) |
| Dedicated framebuffer BRAM | 6/8 slices |
| RBB LUT resources | 471; not the advertised LUT5 count |
| CLB / IOB output flip-flops | 319 / 128 |
| Core / oscillator | 3.125 MHz / 50 MHz |
| Typical post-route WNS / TNS | +15.344 ns / 0 |

Matching hashes, resource/timing summaries and validation logs are in the
[Pistil report](../reports/2026-11-04/pistil/RESULTS.md) and
[manifest](../reports/2026-11-04/pistil/build-manifest.json). The preceding Willow
build used 136/140 blocks; these are whole-design routing results, including
simplified pattern validation and packing, not isolated effect-cost measurements.

## Validation and deployment state

- Renderer checks pass exact full/half velocities and positions, per-index
  colours, latched selection, paired glitter and previous regressions.
- Three complete UART frames pass CRC and all-pixel RAM snapshot comparisons.
  The Pistil packet contains 8 yellow shell and 8 white core pixels and passes
  the exact native firmware parser and desktop decoder.
- At the Pistil checkpoint, seventeen host checks, offscreen GUI
  selection/preview/command checks, FPGA synthesis/routing, and firmware/LittleFS
  compilation passed. That software preview has since been removed as noted above.
- The user authorized the full upload. All five flash sections passed hash
  verification; the board runs firmware v0.2.0 and this Pistil image.
- Physical yellow/white and green/white Pistil frames passed motion and outer/core
  span checks; white core counts varied. Clear passed, the short stream measured
  7.035 FPS over 22 frames, and no new CRC/header/timeout errors occurred. See
  [physical results](../reports/2026-11-04/pistil/hardware-physical.json).

Upgrade **both** firmware and FPGA image: v0.1.0 rejects pattern 3. The full upload
helper packages both, as documented in SETUP.md. Builds are under
`build/pistil-firmware/`; they do not upload by default. The command-line board
checker accepts firmware v0.1.0 and v0.2.0; its existing check uses green Ring.
The additional Pistil check is recorded in the physical report. The board is left
with a cleared scene and the 7 FPS stream target selected. Close serial clients
before future uploads; preserve the existing working image and backups.

## Constraints to preserve

- Six bitplane BRAM slices: 0–2 and 4–6, with their existing peripheral port mapping.
- BRAM power-down bits 320/321 clear; package the SPI header from project nvmData.
- The 3.125 MHz clock route and validated UART/framebuffer ownership behavior.
- Source credits in CREDITS.md and tools/vendor/LICENSE.
- Ignored local board/image backups under `build/backups/`; preserve them.

The 115200-baud link permits at most 7.46 complete frames/s before delays. The
7 FPS target and 5 FPS fallback are unchanged; the short physical run measured
7.035 FPS. Full external BRAM timing signoff and long-duration reliability remain
limitations. No feature implementation or initial board bring-up remains pending
for this checkpoint; future effects or transport changes are separate work.
Do not flash without the user's instruction. Keep implementation changes, generated
project source, included image and matching reports together in useful commits.
