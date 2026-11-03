# PyroCore scope and roadmap

Read HANDOFF.md for the latest verified implementation state. This file records
what the project is meant to do and how to extend it.

## Product

A64×64 pixel fireworks engine on Shrike-Fi. FPGA calculates particle motion and
renders every pixel. ESP32 transports commands and frames. Laptop supplies the
controls, RGB palette mapping and nearest-neighbour display scaling.

## Implemented baseline

- Eight fixed-point particles with gravity, clipping, lifetime and a previous-position trail.
- Radial, ring and willow bursts; six material selections; white sparkle flicker.
- Two64×64×3-bit framebuffers, six dedicated4-kbit BRAM slices.
- Eight palette entries including black, with seven visible colours.
- Safe front/back ownership: renderer and reader use opposite buffers; swaps wait
  for rendering and transmission to finish.
- CRC-protected packed frame transport; measured7FPS desktop default,5FPS fallback.
- ESP32 loader, USB commands, validated-frame forwarding and status counters.
- Desktop controls, connection, random show and clearly labelled offline preview.

The current integrated FPGA build fits134/140 logic blocks, so further features
must share arithmetic or replace existing logic. Two BRAM slices remain available;
they are a shared budget rather than guaranteed spare storage for any one feature.

## Memory organization

| Buffer | Slices | Mode |
|---|---|---|
| A | BRAM0,1,2 | Each4096×1 bit, one colour bitplane per slice |
| B | BRAM4,5,6 | Each4096×1 bit |
| Reserved | BRAM3,7 |1024bytes total |

Each slice has a synchronous read port and a write port, with shared bank clock
paths. The source uses explicit peripheral ports, not ordinary array inference.
Pixel address is`y*64+x`. RAM contents are initialized by writes.

A frame needs1536packedbytes; a protocol-v1 packet totals1545bytes. The115200-baud
8N1 link has an absolute7.46FPS packet ceiling before additional delays. Initial
desktop target is7FPS, with5FPS selectable.20–30FPS remains a later transport goal and needs a
measured faster implementation. Do not simply change UART baud at the retained
3.125MHz core clock without checking bit timing.

## Material palette

| Material | Appearance |
|---|---|
| Strontium | Red |
| Barium | Green |
| Copper | Blue |
| Sodium | Yellow |
| Aluminium | White glitter |
| Titanium | Pale silver |

These are stylized presets, not chemical combustion calculations. Three-bit
indices do not store independent brightness. Controlled flicker and palette
choices provide the initial effect. Palette entry0 stays black.

## Next milestones

1. Completed: physical launch/motion/clear, baseline18 material/pattern presets,
   short7FPS stream, and short FPGA-drawn trails. Evidence is in HANDOFF.md.
2. Resolve BRAM-facing interface timing warnings/constraints while retaining the
   measured clock and physical mapping.
3. Measure longer streaming sessions and visual cadence before broad reliability claims.
4. Measure a faster UART/SPI link before promising20–30FPS.
5. Increase visual density only when updated synthesis and routing still fit.

Keep physical-board acceptance separate from model simulation. Routine checks
belong inside development; preserve useful progress in commits and keep HANDOFF.md
short, current and sufficient for a different IDE or coding agent to continue.
