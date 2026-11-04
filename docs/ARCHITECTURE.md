# PyroCore architecture

PyroCore is an eight-particle fireworks engine on the Shrike-Fi FPGA. The FPGA
updates particle motion, draws pixels into its own memory and sends completed
frames to the ESP32. The desktop supplies controls, decodes the palette indices
and enlarges the 64 × 64 image.

```text
Desktop controls → ESP32 → FPGA command decoder
                              ↓
                       Particle renderer
                              ↓
                       Back framebuffer
                              ↓ safe swap
                       Front framebuffer
                              ↓
Desktop display ← ESP32 ← FPGA frame serializer
```

## Current hardware budget

| Resource | Current design |
|---|---|
| FPGA | Renesas SLG47910V Rev BB |
| Logic blocks | 131 / 140 CLBs |
| Dedicated framebuffer BRAM | 6 / 8 slices, 24,576 / 32,768 bits |
| CLB flip-flops | 319 |
| IOB output flip-flops | 116 |
| Raw placer LUT resources | 477, using the placer's 6-LUT accounting |
| Core / oscillator clocks | 3.125 MHz / 50 MHz |
| Typical post-route setup timing | WNS +15.344 ns; TNS 0 |

The raw placer LUT count cannot be compared directly with the advertised 1,120
LUT5 count. The CLB budget is the tighter immediate constraint: nine CLBs remain.
Adding an effect needs a new integrated fit check. The two unused BRAM slices
contain 1,024 bytes in total; they do not provide additional logic blocks.

The clock divider and dedicated LaC1 route produce the core clock. Both BRAM
banks use that same clock for their read and write paths. Keep these mappings
when changing the design.

## Framebuffers and palette

Each of the two framebuffers stores 4,096 three-bit palette indices. The pixel
address is `y * 64 + x`, for coordinates 0–63. Eight palette entries include the
black background:

| Index | Display colour |
|---|---|
| 0 | Black background |
| 1 | Red |
| 2 | Green |
| 3 | Blue |
| 4 | Yellow |
| 5 | Orange |
| 6 | White |
| 7 | Pale silver |

These indices do not carry an independent brightness or alpha value. Glitter
changes visibility over time. The short trails use the same material colour as
their particle heads.

| Buffer | Dedicated slices | Organisation |
|---|---|---|
| A | BRAM0, BRAM1, BRAM2 | Three 4,096 × 1-bit planes |
| B | BRAM4, BRAM5, BRAM6 | Three 4,096 × 1-bit planes |
| Unused | BRAM3, BRAM7 | Two 4,096-bit slices |

The vendor flow connects these peripheral memories through explicit top-level
ports and I/O Planner mappings. It does not infer these framebuffers from plain
Verilog arrays. Each slice has one synchronous read port and one write port;
the read and write ports share the selected width/depth configuration.

For each used slice, `RATIO = 2'b11` selects 4,096 × 1 mode. The nine dedicated
address pins carry pixel address bits `[11:3]`. Unused WDATA pins carry the
remaining address bits:

| Physical pins | Signal |
|---|---|
| WADDR `[8:0]` | Write pixel address `[11:3]` |
| RADDR `[8:0]` | Read pixel address `[11:3]` |
| WDATA `[7:5]` | Write pixel address `[2:0]` |
| WDATA `[4:2]` | Read pixel address `[2:0]` |
| WDATA `[1]` | Zero |
| WDATA `[0]` | This slice's colour bit |

Write/read enables and their clock enables are active LOW; inversion controls
are zero. Configuration bits 320 and 321 must also be zero to power on both BRAM
banks. The build helper preserves the project's chip configuration when packaging
the MCU image.

## Particle state and motion

The renderer maintains eight records containing position, velocity and an alive
flag. All records rotate through a shared datapath, avoiding an eight-way state
read multiplexer. The position/velocity banks use distributed shift-register
resources, separate from the six dedicated framebuffer slices.

Positions are signed 11-bit values with four fractional bits: one pixel is 16
units, and the representable range is −64 to 63.9375 pixels. Velocities are signed
seven-bit values with four fractional bits. Each rendered update performs:

```text
next_x  = x + vx
next_y  = y + vy
next_vy = min(vy + 1, 60)       # fixed-point units
```

Gravity is therefore 1/16 pixel per rendered update squared; the downward speed
cap is 3.75 pixels per update. A particle leaving the screen becomes inactive.
A burst lasts at most 49 rendered updates, including its first update. Motion
advances on rendering, so transport stalls can slow its wall-clock cadence.
The faster link reduces those stalls: a burst can progress and expire sooner in
real time while its per-update velocity, gravity and lifetime remain unchanged.
Hidden glitter sparks continue advancing their state.

A launch replaces the previous burst. Material and pattern are captured with
the launch command. Launch and Clear received during a render are queued for
the next render; the latest queued launch wins and Clear takes priority.

## Patterns

| Pattern ID | Name | Initial motion |
|---|---|---|
| 0 | Radial | Eight spokes with alternating speeds and a small FPGA-random variation |
| 1 | Ring | Eight approximately equal-speed directions |
| 2 | Willow | A narrower upward fan that bends down under gravity |
| 3 | Pistil | Even particles use full Ring velocity; odd particles use half velocity and white glitter |

All four values of the two-bit pattern field are used. Opcode `0x23` selects
Pistil. Its even particles (0, 2, 4, 6) keep full Ring velocity and the selected
material colour. Odd particles (1, 3, 5, 7) use signed arithmetic right shifts
(`>>> 1`) on both initial velocity components and draw palette index 6 (white).
Both groups use the common LFSR glitter. Gravity still applies equally to every spark.
The half-speed arithmetic is shared with Radial; no per-particle colour memory
or additional BRAM is required. Selecting Aluminium makes both groups white.
The launch captures its pattern, so changing the input selection alone does not
recolour an active burst.

Radial, Ring and Pistil start at (32, 27). Willow starts at (32, 40), with horizontal
velocities of ±2, ±6, ±10 and ±14 fixed-point units and alternating vertical
velocities of −20 and −24 units. The two vertical trajectories reach apex heights
of approximately 26.875 and 21.25 pixels. The outermost two Willow particles leave
the horizontal bounds on update 37; the remaining six stay within the screen for
the burst's full lifetime.

## Materials and glitter

| Material ID | Preset | Palette index |
|---|---|---|
| 0 | Strontium | 1, red |
| 1 | Barium | 2, green |
| 2 | Copper | 3, blue |
| 3 | Sodium | 4, yellow |
| 4 | Aluminium | 6, white |
| 5 | Titanium | 7, pale silver |

A 16-bit FPGA LFSR supplies the existing Aluminium glitter behavior to every
material and pattern, including both groups in Pistil. Each spark is hidden when
the low two LFSR bits are zero. Head and trail share the captured visibility
decision, so both flicker together and retain their selected colour. Visibility
does not stop particle motion, gravity or lifetime updates.

## Rendering and short trails

Every render clears all 4,096 pixels of the back buffer before drawing particles.
For each visible particle, the renderer writes its previous sampled position,
then its updated head position. It reuses the captured x/y registers, adding no
history memory. These are two sampled points; the renderer does not fill a line
between them or apply a fading brightness value.

The update sequence is:

```text
READ → STEP → TRAIL → DRAW → ADVANCE
```

There are at most 16 nonzero writes per render. Points can overlap, particularly
at a new burst's shared centre, so the final image can contain fewer distinct lit
pixels. `done` follows the final committed write and has `pixel_we` LOW.

## Ownership, swapping and transfer

The renderer writes the back buffer while the serializer reads the front buffer.
A completed render marks the back buffer ready. Swapping waits until any front
frame transmission, including its final byte, has completed. The selected front
buffer and sequence number remain stable throughout the transfer. If transfer
falls behind, the renderer waits rather than overwriting the displayed frame.

The FPGA packs eight three-bit indices into one 24-bit little-endian group. Each
complete frame carries 1,536 payload bytes inside a 1,545-byte packet with header,
sequence number and CRC-8. The ESP32 validates complete packets before forwarding
their payloads to the desktop over native USB CDC.

The FPGA link uses 625000 baud with 8N1 framing, exactly 5 cycles per bit at the
preserved 3.125 MHz core clock. Its wire-only ceiling is about 40.5 complete
packets per second. Memory-fetch and UART-handshake pauses, followed by bridge
and USB work, reduce that rate. The desktop requests 30 FPS with 18/7/5 FPS fallbacks;
firmware starts at 5 FPS. Physical hardware measures 29.436 FPS at the 30 FPS target 
(98.1% efficiency). The 40 Hz render scheduler and safe buffer ownership remain 
unchanged. RTL simulation measures 29.319 ms per serialized frame, including those
memory/handshake pauses, for a 34.107 FPS ceiling before bridge and USB work.

The 30 FPS setting provides headroom for real-world overhead. Higher frame rates
would need a faster FPGA UART (3 or 4 clocks/bit) and potentially a higher render 
scheduler frequency. The released v0.4.0 image uses the validated 5 clocks/bit design 
at 625000 baud.

See [Protocol](PROTOCOL.md) for byte layouts and commands,
[README setup](../README.md#setup) for installation and use, and
[Development](DEVELOPMENT.md) for rebuild commands and validation reports.
The [README status](../README.md#status) records the current state and next step.
The desktop displays the frames produced by this FPGA pipeline. It does not
generate a local fireworks animation.
