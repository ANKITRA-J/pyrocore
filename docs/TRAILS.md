# Previous-position particle trails

The renderer now writes each particle's previous position immediately before its
new position. Both are generated on the FPGA, in the same material colour. A
single visibility flag makes an aluminium particle's head and trail flicker
together. These are two sampled points, not a filled line or a fading trail.

Old state order: `READ → STEP → DRAW → ADVANCE`.
New state order: `READ → STEP → TRAIL → DRAW → ADVANCE`.

The existing x/y registers already contain the old position, so no particle
history storage or extra BRAM is needed. All eight state records, velocities,
gravity, clipping and lifetime are retained. Rendering adds eight core cycles
per eight-particle update. Each frame still clears 4,096 pixels first, then issues
at most 16 nonzero writes. Overlapping pixels are expected; the first burst image
has a shared centre point. The final `done` pulse still follows the last write.

Standalone Yosys comparison (same vendor synthesis options):

| Resource | Original | With trails |
|---|---:|---:|
| LUT2–6 cells |162|163|
| Flip-flops |177|179|
| SRL16E |36|36|
| Estimated logic cells |128|127|

## Integrated build and board results

The trail implementation was integrated, routed, flashed and checked on the
Shrike-Fi board on 3 November 2026.

| Integrated resource or timing check | Recorded result |
|---|---:|
| Logic blocks | 134 / 140 CLBs |
| Raw placer LUT count | 474, using the placer's 6-LUT accounting |
| CLB flip-flops | 315 |
| IOB flip-flops | 128 |
| SRL16E shift-register cells | 36 |
| Dedicated framebuffer BRAM | 6 / 8 slices |
| Core clock | 3.125 MHz |
| Post-route WNS / TNS | +15.995 ns / 0, typical corner |

The raw placer LUT count is not a count of the device's 1,120 LUT5s. Use the
final vendor resource report for comparisons. The design is close to the CLB
limit, so subsequent effects need a fresh integrated fit check.

The testbench passed ordered clears, 16 paired writes, exact previous positions,
unchanged fixed-point/gravity head positions, queued launch, paired glitter,
clear and completion ordering.

The physical run recorded in `reports/2026-11-03/refinement/hardware-seven-fps.json` passed:

- Two advancing green ring frames, each containing 16 lit pixels.
- Clear producing a complete all-black frame.
- 22 streamed frames at a measured 7.027 FPS with a target of 7 FPS.
- No CRC errors, header errors or frame timeouts during the run.

All 18 material/pattern combinations passed on the preceding image without
trails. The trail image's recorded board check covers green ring motion, Clear
and streaming; it does not claim that all 18 combinations were rerun on this image.
The timing result is for constrained paths at the typical corner, not a claim
of timing closure across every operating condition.
