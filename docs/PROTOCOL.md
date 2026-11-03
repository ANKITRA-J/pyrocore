# PyroCore protocol v1

This is the shared implementation contract for FPGA, ESP32 and desktop.

## ESP32 ↔ FPGA

115200 baud, 8N1. The initial FPGA uses 27 clocks/bit at a 3.125MHz core
(115741 baud, about 0.47% above nominal). No flow-control wires.

Every command is two bytes: `[opcode, opcode XOR 0xFF]`.

| Opcode | Action |
|---|---|
| 0x01 | Launch a burst with the selected material and pattern |
| 0x02 | Clear particles / scene |
| 0x10–0x15 | Material 0–5: strontium, barium, copper, sodium, aluminium, titanium |
| 0x20–0x22 | Pattern 0–2: radial, ring, willow |
| 0xF0 | Request a complete front-buffer frame; ignored while transmitting |

Malformed command pairs do not execute. A lone first byte expires after 100ms.
The complement is a lightweight command check, not a CRC or authentication.

A response frame is exactly 1545 bytes:

```text
50 59   01 46   seq_lo seq_hi   00 06   [1536 payload bytes]   crc8
magic   ver/type                 len=1536, little endian
```

CRC-8: polynomial0x07, initial0, no reflection/xorout. Cover bytes from version
through the last payload byte; exclude the two magic bytes and final CRC byte.
Check vector `123456789` →0xF4.

Pixels are row-major (`y*64+x`). Eight 3-bit colour indices pack into a24-bit
little-endian word: `word = sum(pixel[i] << (3*i), i=0..7)`. Emit low byte first.
The payload is512 such groups, with no row padding. Value0 is the black background.
Readout must keep the selected front buffer and sequence number stable until the
last byte is sent. Swaps wait for both rendering and transfer completion.

## Desktop ↔ ESP32 USB

Newline-delimited UTF-8 JSON over native USB CDC. Baud selection is115200, but
native USB is not the FPGA UART throughput limit. One JSON object per line.

Commands:

```json
{"cmd":"hello"}
{"cmd":"launch","material":0,"pattern":0}
{"cmd":"set","material":1,"pattern":2}
{"cmd":"clear"}
{"cmd":"stream","enabled":true,"fps":5}
{"cmd":"frame"}
{"cmd":"status"}
```

Material and pattern are integers in the ranges above; fps is1–7, default5.
Launch applies the supplied selection before sending the launch opcode.

Hello/status include `type`, `version`, `fpga_loaded`, and useful counters.
An image transferred to the FPGA is not itself proof that its UART works.
Frame reception establishes communication separately.

```json
{"type":"frame","seq":1,"width":64,"height":64,"format":"indexed3-lsb","source":"fpga","crc_ok":true,"data":"BASE64_OF_1536_BYTES"}
{"type":"error","message":"FPGA frame timeout"}
```

Forward frames only after complete length/version/type/CRC validation. On timeout,
resynchronize on magic and wait for a new complete frame. Desktop rejects malformed
or incorrectly-sized payloads and displays completed frames only. Never label a
software preview as FPGA output.

Palette indices:0 black,1 red,2 green,3 blue,4 yellow,5 orange,6 white,7 pale silver.
The FPGA produces indices; desktop maps the palette and enlarges pixels.

Current full-frame bandwidth ceiling:115200/10/1545=7.46frames/s before any
additional delays. FiveFPS is the initial transport target;20–30FPS needs a later
measured faster-link implementation.
