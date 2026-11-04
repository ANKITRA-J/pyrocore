# PyroCore wire protocol v1

Current firmware: **v0.2.0**. The wire format remains v1; the firmware version
identifies the added Pistil selection. Firmware v0.1.0 accepts only patterns 0–2.

## Selections

| Field | Valid IDs |
|---|---|
| Material | 0 Strontium, 1 Barium, 2 Copper, 3 Sodium, 4 Aluminium, 5 Titanium |
| Pattern | 0 Radial, 1 Ring, 2 Willow, 3 Pistil |
| Stream FPS target | 1–7 |

Pattern 3 is Pistil: selected-colour outer sparks and half-speed white glitter
inside. Firmware v0.2.0 and its matching FPGA image add this pattern; update both
when upgrading from v0.1.0. Existing command/frame formats remain compatible.
Material names are visual presets, not combustion calculations.

## Desktop ↔ ESP32 native USB

Newline-delimited UTF-8 JSON, one object per line. The desktop opens native USB
CDC with a 115200 baud selection; the separate FPGA UART is the throughput limit.

```json
{"cmd":"hello"}
{"cmd":"status"}
{"cmd":"set","material":1,"pattern":2}
{"cmd":"launch","material":3,"pattern":3}
{"cmd":"clear"}
{"cmd":"stream","enabled":true,"fps":7}
{"cmd":"frame"}
```

`set` changes the selection; `launch` applies the selection and starts a burst.
Omitted material/pattern values retain the current selection. `frame` requests one
complete frame. Firmware starts at 5 FPS; the desktop selects 7 FPS by default,
with 5 FPS available. The launch example above selects Sodium Pistil.

`set`, `launch`, `clear` and `stream` return `ack` or `error`. Hello/status return
their named status objects; a manual frame request returns a frame or an error.
A launch/clear acknowledgement confirms command forwarding, not completion of
rendering. A frame already in flight can still show the preceding scene.

For manual capture, send `{"cmd":"stream","enabled":false}`, let any in-flight
frame or timeout finish, then send `{"cmd":"frame"}`. A new request during a
transfer returns `A frame request is already in progress`.

Hello/status report version, `fpga_loaded`, `fpga_verified`, stream/selection state,
frame count, CRC errors, header errors and timeouts. `fpga_loaded` means image
transfer finished. `fpga_verified` means a complete valid FPGA frame has been
received during this boot; recent arrivals/counters determine current stream health.

```json
{"type":"frame","seq":1,"width":64,"height":64,"format":"indexed3-lsb","source":"fpga","crc_ok":true,"data":"BASE64_OF_1536_BYTES"}
{"type":"error","message":"FPGA frame timeout"}
```

The bridge forwards frames only after validating UART length, version, type and
CRC. The desktop checks this envelope, sequence range, strict base64 and payload
size. Malformed/partial frames do not replace the last complete image. `crc_ok`
reports the bridge's UART validation; the USB envelope does not contain that raw CRC.
Black frames are valid frames and count toward received FPS. The desktop displays
received FPGA frames; it does not generate a local fireworks animation.

## ESP32 ↔ FPGA UART

115200 baud, 8N1, no flow-control wires. The FPGA uses 27 clocks/bit at 3.125 MHz,
about 115741 baud (0.47% above nominal).

Commands are two bytes: `[opcode, opcode XOR 0xFF]`.

| Opcode | Action |
|---|---|
| `01` | Launch with the current selection |
| `02` | Clear particles and scene |
| `10`–`15` | Material 0–5 |
| `20`–`23` | Pattern 0–3 |
| `F0` | Request the front-buffer frame; ignored during an active transmission |

Opcode values above are hexadecimal. Malformed pairs do not execute; a lone first
byte expires after 100 ms. The complement is a lightweight command check.

To select Sodium, select Pistil and launch, send these hexadecimal byte pairs
in order: `13 EC`, `23 DC`, `01 FE`. Request a subsequent frame with `F0 0F`.

A frame is exactly **1545 bytes**:

```text
50 59 | 01 46 | seq_lo seq_hi | 00 06 | 1536 payload bytes | crc8
magic   ver/type   sequence     length=1536 (little endian)
```

CRC-8 polynomial `0x07`, initial 0, no reflection or final XOR. Cover version
through the last payload byte, excluding magic and the final CRC byte.
The reference vector `123456789` produces `0xF4`.

Pixels are row-major at `y*64+x`, each a three-bit palette index. Eight pixels
pack into a 24-bit little-endian word:

```text
word = sum(pixel[i] << (3*i), i=0..7)
```

Emit the low byte first. A payload contains 512 such groups with no row padding.
Palette indices are 0 black, 1 red, 2 green, 3 blue, 4 yellow, 5 orange, 6 white
and 7 pale silver. The desktop maps indices to RGB and enlarges the image.

The front buffer and sequence stay fixed until the last transmitted byte.
A swap waits for rendering and transmission to finish. On a failed packet the
bridge resynchronizes on magic; the next request drains/resets the failed transfer.
The 600 ms timeout exceeds the approximately 134 ms wire time.

The current full-frame ceiling is `115200 / 10 / 1545 ≈ 7.46 FPS` before delays.
Higher rates require a measured transport change, not a different USB baud selector.
