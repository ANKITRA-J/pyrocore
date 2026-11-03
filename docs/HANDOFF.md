# PyroCore handoff

## Current work

Repository initialized for the real project. Shared wire protocol is in PROTOCOL.md.
Implementation is underway: FPGA physics/rendering and double framebuffer,
ESP32 loader/bridge, and desktop display. No physical-board upload has been made.

## Verified starting point

Dedicated double64×64×3-bit BRAM test fits:6/8 slices,87/1120LUT5,
14/140CLBs;3.125MHz core. Synthesis/PNR and model simulation passed.
Those counts are for the old memory exerciser, not the forthcoming engine.

## Next checkpoint

Integrate the v1 protocol, compile the actual engine and firmware, run an end-to-end
RTL frame check and desktop offline checks, then record exact results here.

## Hardware status

Not uploaded. Physical BRAM behavior, BRAM-facing interface timing and sustained
USB/FPGA streaming remain to be measured. Enigma is not part of this repository.
