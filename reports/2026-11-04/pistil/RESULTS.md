# Pistil pattern checkpoint

4 November 2026. Pattern 3 / opcode `0x23` is implemented across the FPGA,
firmware v0.2.0 and desktop app. **The complete package is uploaded and physically
verified on the Shrike-Fi board.**

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

The image/source hashes and firmware package hashes are in the
[build manifest](build-manifest.json).
The included 46,408-byte MCU image SHA256 is:

```text
2c43d2c38a5dfc523b2b0acf14e82fb8469ae4645b2a72df387c8ca461251dbb
```

Upgrade both firmware and its FPGA image with the complete helper command in
[SETUP.md](../../../docs/SETUP.md#3-upload-the-application-and-fpga-image); the
preceding v0.1.0 firmware rejects pattern 3. Frame protocol v1 is
unchanged. Physical acceptance results are below.

## Physical board acceptance

The owner explicitly requested the upload. The complete application/filesystem
package was flashed at 115200 baud; all five written sections passed esptool hash
verification and the board reset into firmware v0.2.0. No OTP programming was used.
The original local flash backup remains preserved.

[The physical report](hardware-physical.json) records:

- Ring launch/motion and Clear passed on the new image.
- A short 7 FPS target stream received 22 frames at **7.035 FPS**.
- Sodium Pistil: four advancing frames contained yellow shell and white core
  pixels. Shell count stayed 8; white counts were 8, 6, 5, 8.
- Barium Pistil: four advancing frames contained green shell and white core
  pixels. Shell count stayed 8; white counts were 6, 8, 6, 8.
- In all four sampled frames for each material, the shell's horizontal and vertical
  span exceeded the inner core's span.
- Pistil Clear returned a complete black frame. Firmware reported
  `fpga_verified:true` and no new CRC, header or timeout errors.

The white core visibly varied across frames; exact parity, half-speed and paired
glitter behavior also have the deterministic simulation coverage above. This is
a short functional check, not a long-duration reliability claim. The board is
left with a cleared scene and the 7 FPS stream target selected.
