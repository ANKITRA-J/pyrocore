# Implementation reports

## Current included image

[Pistil checkpoint, 4 November 2026](2026-11-04/pistil/RESULTS.md): pattern 3,
selected-colour shell and half-speed white glitter core. The FPGA build fits
132/140 logic blocks and six BRAM slices, with typical WNS +15.344 ns and TNS 0.
Simulation checks a CRC-valid mixed-colour frame through the exact firmware parser
and desktop decoder. Firmware v0.2.0 and LittleFS compile successfully.
**This image has not yet been uploaded or physically tested.** See its
[manifest](2026-11-04/pistil/build-manifest.json) for image/source hashes and scope.

## Historical evidence

- [Willow manifest, 4 November](2026-11-04/build-manifest.json): the preceding
  owner's GUI/Willow checkpoint; 136/140 logic blocks. The owner reported the
  improved effect working; no automated physical-frame report was archived for it.
- [Initial board bring-up](2026-11-03/BRINGUP.md): the BRAM power fix, launch,
  motion, Clear, 18 material/pattern presets and the initial 5 FPS measurement.
- [Short-trail refinement](2026-11-03/refinement/RESULTS.md): the earlier image,
  physical head/trail motion and 7.027 FPS over 22 received frames.

Each dated manifest/log applies to its own image. Current setup instructions are
in [SETUP.md](../docs/SETUP.md), and status is in [HANDOFF.md](../docs/HANDOFF.md).
New build outputs go in ignored `build/`; useful checkpoint evidence belongs here.
Full flash backups and machine-specific upload logs remain local.
