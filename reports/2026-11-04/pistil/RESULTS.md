# Pistil pattern checkpoint

4 November 2026. Pattern 3 / opcode `0x23` is implemented across the FPGA,
firmware v0.2.0 and desktop app. **This checkpoint has not been uploaded or
physically tested on the board.**

## Behavior

Even particles 0, 2, 4 and 6 use full Ring velocity and the selected material
colour. Odd particles 1, 3, 5 and 7 use signed arithmetic half-velocity, palette
index 6 (white) and the existing FPGA LFSR glitter. Gravity applies to both groups.
Each spark's old-position trail and current head share its colour and visibility.
Aluminium retains its existing glitter, including the outer Pistil group.

The engine reuses Radial's half-speed arithmetic, the latched pattern, current
particle index and existing random generator. No RTL state registers, particle
colour memory or dedicated BRAM were added. All four two-bit pattern values are
now valid, allowing the previous invalid-pattern clamp to be removed. The command
decoder accepts exactly `0x20`–`0x23`.

## Measured implementation

| Item | Pistil build | Previous Willow build |
|---|---:|---:|
| Logic blocks | 132/140 | 136/140 |
| RBB LUT resources | 471 | 475 |
| CLB flip-flops | 319 | 320 |
| IOB output flip-flops | 128 | 128 |
| Dedicated framebuffer BRAM slices | 6/8 | 6/8 |
| Core clock | 3.125 MHz | 3.125 MHz |
| Typical WNS / TNS | +15.344 ns / 0 | +15.599 ns / 0 |

These are whole-design routing results, including decoder/capture simplification
and packing changes. They do not assign a standalone LUT cost to the new effect.
RBB LUT resources are not directly the advertised LUT5 count. Timing remains the
vendor typical setup result, with external BRAM interface signoff still limited.

## Verification

- Renderer: exact full/half signed initial velocities and two rendered positions;
  even selected colour, odd white; captured pattern independent of later selector
  changes; forced visible/hidden glitter keeps heads and trails paired.
- Existing renderer checks: ordered clears, Ring geometry/gravity, queued Willow,
  Aluminium glitter and completion/write ordering.
- Complete UART simulation: malformed commands and opcode `0x24` rejected;
  `0x23` accepted. Three complete frames pass CRC and match all 4,096 pixels of
  immutable RAM snapshots while ownership guards remain active.
- The Pistil frame contains **8 yellow shell pixels and 8 white core pixels**.
  `rtl-pistil-frame.bin` passes the exact native firmware parser and desktop decoder.
- Seventeen host checks, the offscreen GUI smoke, FPGA synthesis/routing and the
  Arduino application/LittleFS package build passed.

The image/source hashes and firmware package hashes are in `build-manifest.json`.
The included 46,408-byte MCU image SHA256 is:

```text
2c43d2c38a5dfc523b2b0acf14e82fb8469ae4645b2a72df387c8ca461251dbb
```

Upgrade both firmware and its FPGA image with the complete helper command in
SETUP.md; the preceding v0.1.0 firmware rejects pattern 3. Frame protocol v1 is
unchanged. Physical multicolour output and stream rate remain to be checked after
an explicitly requested board upload.
