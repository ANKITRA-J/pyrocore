# PyroCore handoff

Updated 4 November 2026. **Pattern 3, Pistil, is implemented and built.** The
owner's GUI and falling Willow changes remain intact. Firmware is now v0.2.0.
Start with [SETUP.md](SETUP.md) for deployment and [DEVELOPMENT.md](DEVELOPMENT.md)
for source changes. Preserve credits/notices and follow [AGENTS.md](../AGENTS.md).

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
- Seventeen host checks, offscreen GUI selection/preview/command checks, FPGA
  synthesis/routing, and firmware/LittleFS compilation passed.
- **No Pistil upload or physical-board test was performed.** The board's prior
  running image was the owner's Willow version. Previous board evidence remains
  labelled by image in the [reports index](../reports/README.md).

Upgrade **both** firmware and FPGA image: v0.1.0 rejects pattern 3. The full upload
helper packages both, as documented in SETUP.md. Builds are under
`build/pistil-firmware/`; they do not upload by default. The command-line board
checker accepts firmware v0.1.0 and v0.2.0; its existing check uses green Ring.
The next physical acceptance should additionally launch a non-white Pistil
material and confirm both colours, glitter, motion, Clear and error counters.

## Constraints to preserve

- Six bitplane BRAM slices: 0–2 and 4–6, with their existing peripheral port mapping.
- BRAM power-down bits 320/321 clear; package the SPI header from project nvmData.
- The 3.125 MHz clock route and validated UART/framebuffer ownership behavior.
- Source credits in CREDITS.md and tools/vendor/LICENSE.
- Ignored local board/image backups under `build/backups/`; preserve them.

The 115200-baud link permits at most 7.46 complete frames/s before delays. The
7 FPS target and 5 FPS fallback are unchanged; no new physical rate claim is made.
Full external BRAM timing signoff and long-duration reliability remain limitations.
Do not flash without the user's instruction. Keep implementation changes, generated
project source, included image and matching reports together in useful commits.
