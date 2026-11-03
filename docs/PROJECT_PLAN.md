# PyroCore — FPGA Fireworks Engine

**Project handoff · 3 November 2026**

**Current position:** the two-framebuffer design fits and passes compilation,
routing, constrained timing checks and simulation. We can proceed with development.
Physical-board memory verification and BRAM interface timing checks remain open.

## 1. What we are building

A small fireworks engine on the Shrike-Fi board. The FPGA calculates particle
motion and draws every firework pixel. The ESP32 transfers commands and completed
frames. The laptop provides controls and displays the image.

```text
Laptop controls → ESP32 → FPGA physics → FPGA pixel renderer
                                             ↓
                                     Back framebuffer
                                             ↓ safe swap
                                     Front framebuffer
                                             ↓
Laptop display ← ESP32 ← completed FPGA frame
```

The laptop may scale pixels and translate colour indices into RGB values. Particle
positions, explosion shapes and firework pixels are produced by the FPGA.

## 2. Baseline decisions

| Item | Starting design |
|---|---|
| Board | Vicharak Shrike-Fi, ESP32-S3 + SLG47910V Rev BB |
| Image resolution | 64 × 64 pixels |
| Colour format | 3-bit palette index: 8 total entries |
| Background | Palette entry 0 is black; 7 other entries are visible colours |
| Framebuffers | Two, both inside FPGA BRAM |
| FPGA core clock | Keep the tested 3.125 MHz baseline initially |
| Initial particle target | One deterministic particle, then eight |
| Later particle target | Increase only after measuring resource use and frame time |
| Visual frame-rate goal | 20–30 FPS after a suitable frame-transfer link is verified |
| First display milestone | A modest measured rate, initially around 5 FPS on the existing UART |

Eight palette entries include the background. More visible colours would require
a different pixel format or encoding. Keep the palette configurable so we can
change shades without rewriting the physics engine.

## 3. What the completed memory test established

Verified using the installed **Go Configure Software Hub 6.55.002**, bundled
**Yosys 0.59** and **eda-placer v23**, matching the Enigma development flow.

| Check | Recorded result | What it means |
|---|---|---|
| Dedicated BRAM | **6 / 8 slices** | Both framebuffers fit in physical BRAM |
| Framebuffer storage | **24,576 bits = 3,072 bytes** | Two × 4,096 pixels × 3 bits |
| Remaining BRAM | **8,192 bits = 1,024 bytes** | Two unused slices, BRAM3 and BRAM7 |
| CLB LUT5s | **87 / 1,120** | 7.77% used by the test design |
| Logic blocks | **14 / 140 CLBs** | Packing also fits |
| CLB / IOB flip-flops | **43 / 67** | 110 in total across these resource types |
| Synthesis, routing and bitstream generation | **Passed** | Vendor tools completed successfully |
| Constrained setup timing | **Passed at 3.125 MHz core / 50 MHz oscillator** | Overall WNS +15.191 ns; TNS 0, typical corner |
| Reported achievable core frequency | **12.997 MHz estimate** | Not a measured RAM speed or permission to raise the clock |
| Simulation | **Passed** | Eight sweeps, 32,768 pixel reads, alternating front/back buffers |
| Injected read-data corruption | **Detected in simulation** | Failure detection is functional |
| Physical-board memory test | **Pending** | No test image was uploaded |

These resource counts cover the test controller and framebuffer connections.
They do not yet include the fireworks engine or a working frame-transfer protocol.
The remaining BRAM is a shared budget for particle state, queues and other storage.

## 4. The memory layout we must retain

| Buffer | Physical slices | Slice mode | Capacity |
|---|---|---|---|
| A | BRAM0, BRAM1, BRAM2 | Each 4,096 × 1 bit | 4,096 × 3 bits |
| B | BRAM4, BRAM5, BRAM6 | Each 4,096 × 1 bit | 4,096 × 3 bits |
| Reserved | BRAM3, BRAM7 | Decide when needed | 1,024 bytes total |

Each colour bit is stored in a separate bitplane. Pixel address is
`y * 64 + x`, with valid coordinates 0–63.

Each slice supplies one synchronous read port and one write port. It does not
supply two interchangeable read/write ports. Four slices share their bank's
clock paths; the baseline uses the same 3.125 MHz clock throughout.

**Use the dedicated BRAM ports and existing I/O Planner mappings.** Ordinary
Verilog arrays did not infer these blocks in the verified vendor flow. The array
probe produced 384 distributed-memory cells, which exceed the chip's distributed
RAM capacity. A successful synthesis message alone is insufficient.

Important implementation details already captured in the working test:

- Configure each used slice with `RATIO = 2'b11` for 4,096 × 1 mode.
- Connect WADDR and RADDR to pixel address bits `[11:3]`.
- Send write address bits `[2:0]` through WDATA `[7:5]`.
- Send read address bits `[2:0]` through WDATA `[4:2]`.
- Use WDATA `[0]` for the colour bit.
- Respect active-low enables and synchronous read latency.
- Initialize RAM with sequential writes; do not reset the entire array at once.
- Keep the oscillator/divider/LaC1 route and both banks' BRAM clock mappings.

The BRAM test README contains the exact source and connection details.

## 5. Frame ownership and swapping

1. The renderer clears and draws into the **back** buffer.
2. The ESP32 reads the **front** buffer while rendering proceeds independently.
3. Finishing rendering marks the back buffer ready; it does not immediately swap.
4. Swap only when rendering is complete, the old front frame has finished transfer,
   and its final pending memory read has been handled.
5. The completed back buffer becomes the front buffer. The old front becomes
   available for clearing and drawing.

If the receiver is slow, hold the buffers and wait. Do not overwrite a frame that
is still being transferred. Two buffers do not guarantee unrestricted rendering
when the consumer falls behind.

## 6. Frame transfer is the next performance constraint

One packed frame contains **1,536 bytes**. Sending one byte per pixel instead
would require 4,096 bytes. Use a compact binary format for frame data.

The existing Enigma UART runs at approximately 115200 baud. With 8N1 framing:

| Transfer format or goal | Payload requirement / theoretical limit |
|---|---|
| 115200 baud, packed 3-bit frames | At most **7.5 FPS** before packet overhead |
| 115200 baud, one byte per pixel | At most **2.81 FPS** before packet overhead |
| 20 FPS, packed frames | **30,720 bytes/s**, or 307200 baud before overhead |
| 30 FPS, packed frames | **46,080 bytes/s**, or 460800 baud before overhead |

These are arithmetic limits, not measured board performance. Headers, CRC,
acknowledgements and software delays reduce usable throughput.

Reuse the working UART for commands and an initial slow frame-display test.
Before committing to smooth 20–30 FPS, measure a faster UART implementation or
design an appropriate SPI link. Simply changing a baud constant is insufficient:
at a 3.125 MHz core clock, higher rates need carefully chosen timing. In particular,
do not assume a simple UART will reliably support 921600 baud at this clock.

Define frame number, payload length, packing order, integrity check and recovery
behavior before implementing transport. A partial or corrupted frame must not
replace the displayed complete frame. Any new clock domain needs explicit
synchronization or a suitable clock-domain crossing interface.

## 7. Physics and appearance

Start with fixed-point position and velocity, gravity, lifetime and clipping at
the screen edges. Update motion on a frame tick rather than every core-clock edge.
Use a sequential particle-update engine before considering parallel arithmetic.

Start with one particle and a single visible pixel. Then add a small burst of
eight particles and an FPGA pseudorandom generator. Clear the back buffer before
drawing the next frame; add controlled trails after basic motion is verified.

Initial material presets are stylized visual settings:

| Preset | Main appearance |
|---|---|
| Strontium | Red |
| Barium | Green |
| Copper | Blue |
| Sodium | Yellow |
| Aluminium | White glitter |
| Titanium | Pale/silver or orange sparks |

Map presets to colour indices, particle speeds, spread, lifetime and flicker.
The final eight-entry palette is still to be selected. Presets may share colours.
These are visual approximations, not a chemical-combustion simulation.

A 3-bit index does not provide independent per-pixel brightness. Use colour
choices, flicker, spark density and later temporal dithering for a stylized effect.
Do not assume smooth glow gradients are available without extra representation.

## 8. Implementation order and acceptance criteria

| Stage | Work | Complete when |
|---|---|---|
| 0 — Memory feasibility | Compile and simulate the isolated six-slice test | **Done:** reports and simulation retained |
| 1 — Board memory check | Prepare a separate test loader/firmware and clear PASS/FAIL output | Actual board completes all sweeps with zero mismatches; Enigma can be restored |
| 2 — Framebuffer interface | Extract clear, pixel-write, read-valid and safe-swap controls | Simulation proves front-buffer stability, correct read latency and safe swaps |
| 3 — End-to-end frame path | FPGA test image → ESP32 → laptop | Exact pixels survive transfer; sequence, length and integrity checks work; FPS measured |
| 4 — Transport performance | Validate a link suitable for the visual frame-rate goal | Sustained throughput has room for protocol overhead and survives repeated transfers |
| 5 — Basic physics | One particle, then eight, moving and falling | Motion matches reference calculations; clipping/lifetime work; design still fits and routes |
| 6 — Fireworks controls | Burst patterns, material presets, Launch and Random Show | Commands change FPGA-generated frames correctly; interruptions recover cleanly |
| 7 — Improve appearance | Trails, glitter and optional additional particles | Each addition stays within measured memory, logic and frame-time budgets |

Use reference calculations to verify the FPGA during development. The laptop's
runtime display must still show frames generated by the FPGA.

## 9. What is still unverified

- Physical operation of this new BRAM test on the Shrike-Fi board.
- Full timing of the paths between FPGA fabric and peripheral BRAM. The current
  build uses the vendor GUI's default `-1` input/output delays for those paths.
- Several BRAM-facing pins have IOB flip-flop packing warnings. Retain and review
  those warnings during interface timing work.
- Operation across voltage/temperature corners beyond the recorded typical
  1.1 V / 25 °C timing run.
- A complete frame-transfer protocol, sustained FPS and the final particle count.
- The combined resource use of the completed physics, renderer and transport.

**A clean resource fit is established. Full hardware acceptance is not yet established.**

## 10. Keep Enigma safe

- Create PyroCore as a separate project and firmware folder.
- Use Enigma as a reference for its working loader, clock route and board wiring.
- Preserve its source, project, known-good bitstream and firmware build outputs.
- Do not combine this test with Enigma's cipher logic just to reuse transport.
- Enigma's firmware runs cipher self-tests. It will not understand the standalone
  BRAM test; a separate diagnostic firmware is required for board verification.
- Use the vendor MCU image format when an appropriate loader is prepared.
  OTP programming is outside this project workflow.

Known Enigma runtime connections: ESP32 GPIO11 → FPGA GPIO5/package pin18;
FPGA GPIO6/package pin19 → ESP32 GPIO13. Configuration shares these lines, so the
loader must release the configuration interface before runtime communication.
Keep GPIO numbering distinct from package-pin numbering.

## 11. Files and reproduction

The supporting files are alongside this plan in the `bram_test` folder:

| File | Purpose |
|---|---|
| `bram_test/README.md` | Full BRAM test instructions and interpretation |
| `bram_test/bram_test.ffpga` | Separate vendor project |
| `bram_test/ffpga/src/main.v` | Working dedicated-BRAM test source |
| `bram_test/dual_fb_probe.v` | Ordinary-array inference diagnostic |
| `bram_test/build.py` | Non-uploading synthesis and routing commands |
| `bram_test/simulate.py` | Simulation runner |
| `bram_test/reports/` | Resource, timing, connection and simulation evidence |
| `bram_test/result.json` | Machine-readable test results |
| `bram_test/original_preservation.json` | Hash checks for the original Enigma files |

Reproduce compilation on the current Mac:

```sh
cd '/Users/aayush/Documents/Codex/2026-11-03/referenced-chatgpt-conversation-this-is-an/outputs/bram_test'
python3 build.py all --cpus 16
```

Reproduce simulation with the existing Verilator runtime:

```sh
python3 simulate.py --runtime '/Users/aayush/Documents/Codex/2026-10-24/new-chat/work/tooling/runtime'
```

These commands do not program the board. For a different machine, use its vendor
tool/runtime paths as described in the test README.

Hardware reference: [Renesas SLG47910 datasheet](https://www.renesas.com/en/document/dst/slg47910-datasheet?r=25546631).
The installed Renesas BRAM FIFO example and the verified test reports are the
implementation references for the peripheral memory connections.

## 12. Next working session

Begin with **Stage 1**: prepare the separate ESP32 diagnostic firmware for the
already compiled BRAM test, including explicit running, pass and fail output.
Retain a concrete Enigma restore path before any upload. Then run the memory test
on the actual board and record its result before building the fireworks engine.

After that, extract the reusable framebuffer interface and move immediately to
the end-to-end test image and measured transport rate. Keep 20–30 FPS as a target
until that measurement supports it.
