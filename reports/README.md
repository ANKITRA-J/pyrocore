# Implementation reports

## Current included image

[4 November 2026 manifest](2026-11-04/build-manifest.json): corrected Willow and
the current GUI checkpoint. Its image and RTL hashes match the successful local
build. [Resources](2026-11-04/fpga-resources.log): 136/140 logic blocks;
[timing](2026-11-04/fpga-timing-summary.log): typical WNS +15.599 ns, TNS 0.
The owner reports the updated effect working. An automated physical frame/rate
measurement was not archived for this specific image.

## Historical evidence

- [Initial board bring-up](2026-11-03/BRINGUP.md): the BRAM power fix, launch,
  motion, Clear, 18 material/pattern presets and the initial 5 FPS measurement.
- [Short-trail refinement](2026-11-03/refinement/RESULTS.md): the preceding image,
  physical head/trail motion and 7.027 FPS over 22 received frames.
- The manifests and logs under `2026-11-03/` describe those older images. Their
  resource counts, screenshots and physical measurements are historical evidence.

Current setup instructions belong in [SETUP.md](../docs/SETUP.md), and current
status belongs in [HANDOFF.md](../docs/HANDOFF.md). New build outputs go in ignored
`build/`; only useful checkpoint evidence is kept here. Full flash backups and
machine-specific upload logs remain local.
