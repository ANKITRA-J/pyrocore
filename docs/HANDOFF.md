# PyroCore handoff

Updated 4 November 2026. The working v1 includes the owner's polished GUI and
corrected falling Willow effect (source checkpoint `d6e255f`). Start with
[SETUP.md](SETUP.md) for deployment and [DEVELOPMENT.md](DEVELOPMENT.md) for changes.
Keep credits and bundled notices intact; follow [AGENTS.md](../AGENTS.md).

## Included image and fit

`firmware/pyrocore/data/fpga_bitstream.bin`, 46,408 bytes, SLG47910V Rev BB MCU SPI:

```text
b21e754d804c1d9c4bfb08547db010a718ade178ffb20a47b608446789a869ac
```

| Resource | Current successful build |
|---|---:|
| Logic blocks | 136/140 (97.1%) |
| Dedicated framebuffer BRAM | 6/8 slices |
| RBB LUT resources | 475; not the advertised LUT5 count |
| CLB / IOB output flip-flops | 320 / 128 |
| Core / oscillator | 3.125 MHz / 50 MHz |
| Typical post-route WNS / TNS | +15.599 ns / 0 |

The [current manifest](../reports/2026-11-04/build-manifest.json) identifies the
image and RTL hashes. Matching resource/timing summaries are beside it. A later
failed exploratory build left a 198-block resource log in local `build/`; that
log does not describe this included image. Do not combine reports from different runs.

## What is verified

- The owner reports the updated GUI and falling Willow working on the board.
- The included image and all RTL source hashes match the successful local manifest.
- Sixteen host checks passed at the current source checkpoint.
- The cleaned setup helper compiled the firmware and packaged LittleFS successfully
  without uploading. Default/custom Arduino configuration and upload-command
  construction passed an isolated preflight.
- The preceding trail image has a physical launch/motion/Clear report and a short
  7.027 FPS measurement. Earlier preset coverage passed all 18 combinations.
- Those older automated board results are labelled by image in the
  [reports index](../reports/README.md); they are not new measurements of Willow.

Current patterns are **0 Radial, 1 Ring, 2 Willow**. ID 3 is unused and rejected;
there is no fourth engine to remove. Glitter currently applies to aluminium only.
Willow starts at (32,40), rises and falls under gravity; its two outer sparks can
leave the sides around update 37. See [Architecture](ARCHITECTURE.md).

## Constraints to preserve

- Six bitplane BRAM slices: 0–2 and 4–6, with the existing peripheral port mapping.
- BRAM power-down bits 320/321 clear. Package the SPI header from project nvmData.
- The 3.125 MHz clock route and validated UART framing/ownership behavior.
- Source credits in CREDITS.md and the bundled MIT notice in tools/vendor/LICENSE.
- Local ignored flash backups under `build/backups/`; do not delete them during cleanup.

The current 115200-baud link allows at most 7.46 complete frames/s before delays.
The desktop selects 7 FPS with a 5 FPS fallback. More speed needs a measured link
change. Four free logic blocks are a tight budget; new effects need a fresh fit.
Full external BRAM timing signoff and long-duration reliability remain limitations.

## Continuing work

The project is usable as v1. Documentation is consolidated into Setup, Architecture,
Development, Protocol, Handoff and Credits. Preserve the owner's GUI/Willow changes.
Effect additions or wider glitter behavior require updating the RTL, tests, generated
project source, included image and matching reports together. Build and simulation
commands are in DEVELOPMENT.md; do not flash a board without the user's instruction.
