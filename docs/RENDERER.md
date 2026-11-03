# Particle renderer

`particle_renderer.v` is a sequential eight-particle engine. The caller selects
the back framebuffer and commits its registered `pixel_we/pixel_addr/pixel_data`
outputs. Pulse `start` only when `busy` is false. `done` pulses after all pixel
writes have been delivered; `pixel_we` is low during `done`.

Every render first clears all4096 pixels. A launch initializes a new burst at
(32,27), replacing the previous burst. Material and pattern are captured with
the launch. Launch and clear received during rendering are queued until the
next render; the latest queued launch wins, and clear takes priority.

Positions are signed Q6.4 (11bits), velocities signed Q3.4 (7bits). Each update
adds velocity to position and1/16pixel/update² gravity to vertical velocity,
with a positive velocity cap. Out-of-bounds particles deactivate. A burst lives
for at most49 rendered updates, including its initial rendered update. State
advances when a render starts, so actual motion cadence follows completed renders
and can slow when double-buffer ownership stalls behind frame transmission.

Ring uses eight approximately equal-speed spokes; radial varies spoke speeds;
willow launches an upward fan. Material changes colour; aluminium also flickers
using the FPGA LFSR. This is a compact stylized particle model without trails,
per-pixel brightness, multiple overlapping bursts or multiplication.

Rotating packed particle banks avoid an eight-way read multiplexer. Yosys may
map them into distributed shift registers; this is a small use of LUT-memory
resources separate from the dedicated framebuffer BRAM. The final integrated
vendor resource report is authoritative.

The testbench checks full ordered framebuffer clears, eight-particle launch,
two exact fixed-point positions including gravity, queued launch during clearing,
particle clearing and completion/write ordering. Physical hardware is untested.
