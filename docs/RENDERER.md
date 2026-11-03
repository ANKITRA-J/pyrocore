# Particle renderer

`particle_renderer.v` is a sequential eight-particle engine. The caller selects
the back framebuffer and commits its registered `pixel_we/pixel_addr/pixel_data`
outputs. Pulse `start` only when `busy` is false. `done` pulses after all pixel
writes have been delivered; `pixel_we` is low during `done`.

Every render first clears all 4,096 pixels. A launch initializes a new burst at
(32,27), replacing the previous burst. Material and pattern are captured with
the launch. Launch and clear received during rendering are queued until the
next render; the latest queued launch wins, and clear takes priority.

Positions are signed Q6.4 (11 bits), velocities signed Q3.4 (7 bits). Each update
adds velocity to position and 1/16 pixel/update² gravity to vertical velocity,
with a positive velocity cap. Out-of-bounds particles deactivate. A burst lives
for at most 49 rendered updates, including its initial rendered update. State
advances when a render starts, so actual motion cadence follows completed renders
and can slow when double-buffer ownership stalls behind frame transmission.

Ring uses eight approximately equal-speed spokes; radial varies spoke speeds;
willow launches an upward fan. Material changes colour; aluminium also flickers
using the FPGA LFSR. Each visible particle writes its previous sampled position
and then its current position in the same material colour. The two points are
generated on the FPGA using the existing x/y registers, without extra history
storage. These are two sampled points, not a filled line or a fading trail.
Aluminium's head and previous point share a visibility flag and flicker together.
The renderer issues at most 16 nonzero writes per frame; overlapping points can
reduce the number of distinct lit pixels. There is no independent per-pixel
brightness, support for multiple overlapping bursts or multiplication.

Rotating packed particle banks avoid an eight-way read multiplexer. Yosys may
map them into distributed shift registers; this is a small use of LUT-memory
resources separate from the dedicated framebuffer BRAM. The final integrated
vendor resource report is authoritative. The integrated trail build uses 36
SRL16E cells, 134 / 140 CLBs, 315 CLB flip-flops, 128 IOB flip-flops and six
dedicated BRAM slices. Its raw placer LUT count is 474 in 6-LUT accounting, which
must not be presented as a LUT5 count. At the 3.125 MHz core clock, the recorded
typical-corner post-route WNS is +15.995 ns and TNS is zero for constrained paths.

The testbench checks full ordered framebuffer clears, eight-particle launch,
16 paired head/previous-position writes, exact fixed-point positions including
gravity, queued launch during clearing, paired aluminium visibility, particle
clearing and completion/write ordering.

The integrated trail image was flashed and checked on the physical Shrike-Fi.
The recorded run in `reports/2026-11-03/refinement/hardware-seven-fps.json` passed advancing green
ring frames with 16 lit pixels, Clear and 7.027 FPS streaming, with no CRC errors,
header errors or timeouts during the run. All 18 material/pattern combinations
were checked on the preceding image without trails; the final trail-image report
has the narrower scope stated above. See TRAILS.md for the resource comparison
and recorded validation details.
