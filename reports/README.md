# Implementation reports

## Current included image

[v0.4.0 flash verification, 4 November 2026](2026-11-04/v0.4.0-flash-verification/RESULTS.md):
firmware v0.4.0 and the 625000-baud FPGA image (`cfd6c830…`). The complete
package was flashed on Shrike-Fi with all five sections hash-verified. The board
loaded the FPGA, passed Launch/motion/Clear, and streamed at 29.436 FPS on a
30 FPS target with zero CRC, header or timeout errors. The build fits 131/140
logic blocks, 477 RBB LUTs, 319 RBB flip-flops and six BRAM slices, with
post-route WNS +15.344 ns. See the
[raw report](2026-11-04/v0.4.0-flash-verification/hardware-flash-verify.json)
and [manifest](2026-11-04/v0.4.0-flash-verification/build-manifest.json).

## Previous board-validated image

[Glitter and faster link, 4 November 2026](2026-11-04/glitter-fps/RESULTS.md):
firmware v0.3.0, glitter for all materials/patterns, and a 312500-baud FPGA link
with an 18 FPS desktop target. The FPGA build fits 131/140 blocks and six BRAM
slices; typical WNS is +15.059 ns, TNS 0. RTL simulation measures 54.03936 ms per
serialized frame and six advancing frames at 18.182 FPS with ideal polling.
These are simulation results. That package was uploaded with all five flash
sections verified. All 24 presets pass colour/motion/Clear checks; geometric
analysis of their captures confirms paired glitter. Hardware delivers 17.235 FPS
at the 18 FPS target, and 7/5 fallbacks pass with no communication errors. The
real desktop check also passes. See the [physical report](2026-11-04/glitter-fps/hardware-physical.json)
and [manifest](2026-11-04/glitter-fps/build-manifest.json) for
matching source/image hashes and validation scope.

## Earlier board-validated image

[Pistil checkpoint, 4 November 2026](2026-11-04/pistil/RESULTS.md): pattern 3,
selected-colour shell and half-speed white glitter core. The FPGA build fits
132/140 logic blocks and six BRAM slices, with typical WNS +15.344 ns and TNS 0.
Simulation checks a CRC-valid mixed-colour frame through the exact firmware parser
and desktop decoder. Firmware v0.2.0 and LittleFS compile successfully.
The complete package is uploaded and physically checked: moving yellow/white
and green/white Pistil, Clear, 7.035 FPS and no new communication errors. See its
[manifest](2026-11-04/pistil/build-manifest.json) for image/source hashes and scope.

## Historical evidence

- [Willow manifest, 4 November](2026-11-04/build-manifest.json): the preceding
  owner's GUI/Willow checkpoint; 136/140 logic blocks. The owner reported the
  improved effect working; no automated physical-frame report was archived for it.
- [Initial board bring-up](2026-11-03/BRINGUP.md): the BRAM power fix, launch,
  motion, Clear, 18 material/pattern presets and the initial 5 FPS measurement.
- [Short-trail refinement](2026-11-03/refinement/RESULTS.md): the earlier image,
  physical head/trail motion and 7.027 FPS over 22 received frames.

Each dated manifest/log applies to its own image. Current setup instructions and
status are in the [README setup](../README.md#setup) and
[status](../README.md#status). Build and validation commands are in
[Development](../docs/DEVELOPMENT.md).
New build outputs go in ignored `build/`; useful checkpoint evidence belongs here.
Full flash backups and machine-specific upload logs remain local.
