# PyroCore handoff

## Current checkpoint — 3 November 2026

The first integrated implementation is complete in source. The actual engine
passes Renesas synthesis/place-and-route and produces a 46,408-byte MCU-format
bitstream. Firmware and desktop components are implemented; final cross-layer
packet validation and firmware packaging are being recorded in the next checkpoint.
No physical-board upload has been made.

Implemented: eight fixed-point particles with gravity/clipping/lifetime;
radial, ring and willow patterns; six material presets and white flicker;
two dedicated BRAM framebuffers; safe front/back ownership; UART commands;
1,536-byte packed image payloads with sequence/CRC; ESP32 JSON/base64 bridge;
desktop connection, launch, clear, random show and labelled software preview.

## Actual engine build

The integrated design fits **132/140 logic blocks (94.3%)**, including nine
memory-capable blocks for particle shift registers. The raw placer reports469
6-LUT resources and333 CLB flip-flops; these raw units are not Workshop LUT5
counts. Six dedicated BRAM slices remain assigned to the two framebuffers.
Core clock stays3.125MHz; post-route overall WNS is+15.599ns, TNS0 at the
typical corner. The reported14.202MHz estimate is not a physical BRAM speed result.

Logic space is tight. Implement later features through scheduling and shared
arithmetic; measure before adding particles or protocol machinery.

## Earlier memory feasibility baseline

Dedicated double64×64×3-bit BRAM test fits:6/8 slices,87/1120LUT5,
14/140CLBs;3.125MHz core. Synthesis/PNR and model simulation passed.
Those counts are for the old memory exerciser, not the forthcoming engine.

## Verification so far

- Renderer simulation: clear all4,096pixels, draw/move eight particles, queue
  launches and clear commands, handle done/write ordering.
- Complete UART RTL simulation: two1,545-byte frames; correct header/length/CRC;
  all4,096pixels match an immutable RAM snapshot; eight green particles;
  malformed launch rejected; no front-buffer modification during transfer.
- Seven desktop protocol checks passed; labelled preview and UI controls were
  exercised offscreen. Firmware native parser checks and Arduino compilation passed.
- MCU packaging was compared byte-for-byte against the vendor-generated baseline.

## Commands

```sh
python3 tools/build_fpga.py all --cpus 4
python3 tools/build_firmware.py --bitstream build/fpga/FPGA_bitstream_MCU.bin
python3 -m unittest discover -s tests -v
python3 tools/run_rtl.py --runtime /path/to/verilator-5.034/include
.venv/bin/python desktop/app.py --demo
```

Install desktop dependencies per README. The minimal vendor Verilator bundle lacks
the C++ runtime; supply matching runtime sources or use a complete Verilator5
installation. Sources, project and wire format are self-contained in this repo.

## Next checkpoint

Record the compiled firmware/image hashes, pass the RTL-produced packet through
the exact firmware and desktop decoders, and push a ready-to-continue snapshot.
Then the next concrete task is first board bring-up using this project's image
and firmware. Do not rerun the old Enigma development process.

## Hardware status

Not uploaded. Physical BRAM behavior, BRAM-facing interface timing and sustained
USB/FPGA streaming remain to be measured. Enigma is not part of this repository.
