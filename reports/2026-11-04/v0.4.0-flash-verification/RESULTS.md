# v0.4.0 flash and physical verification

4 November 2026. Firmware **v0.4.0**, wire protocol v1, FPGA image
`cfd6c830befcae17a2a23d51869afc16d6371062ca27aa90469cfd3c6eb47b04`.
The repository's included `firmware/pyrocore/data/fpga_bitstream.bin` was flashed
together with the v0.4.0 application and filesystem. The board booted the FPGA,
produced advancing frames at the 30 FPS target, and reported no CRC, header or
timeout errors.

## Scope

One Shrike-Fi board (ESP32-S3, 8 MB flash, SLG47910V Rev BB) over native USB.
Short functional run: Launch, motion, Clear, and 10 seconds of streaming at
30 FPS. This is not a long-duration reliability test and not a multi-board survey.
The run used the image committed to the repository, not a local-only build.

## Flash

Command:

```sh
.venv/bin/python tools/build_firmware.py \
  --bitstream firmware/pyrocore/data/fpga_bitstream.bin \
  --port /dev/cu.usbmodem1101
```

| Item | Value |
|---|---|
| esptool | 5.3.1 |
| Chip | ESP32-S3 (QFN56) rev v0.2, 8 MB XMC flash |
| USB mode | USB-Serial/JTAG |
| MAC | `ac:a7:04:03:fa:74` |
| Bootloader | 19,968 bytes at `0x0` |
| Partition table | 3,072 bytes at `0x8000` |
| boot_app0 | 8,192 bytes at `0xe000` |
| Application | 359,392 bytes at `0x10000` |
| LittleFS (FPGA image) | 1,572,864 bytes at `0x670000` |

All five sections reported `Hash of data verified` from esptool.

## Physical result

| Check | Result |
|---|---|
| Firmware version | `0.4.0` |
| `fpga_loaded` | `true`, 46,408-byte image |
| `fpga_verified` | `true` after streaming |
| Launch / motion | 16 lit green pixels → 8 lit, positions advanced |
| Clear | all-black complete frame |
| Streaming | 294 frames in 10 s, **29.436 FPS** at the 30 FPS target |
| Frame sequence | `852 → 1186` |
| CRC / header / timeout errors | 0 / 0 / 0 |
| Ignored USB lines | 0 |

29.436 FPS is 98.1% of the 30 FPS target, consistent with the expected bridge
and USB overhead. `tools/board_check.py` restored the board to its pre-check
settings (5 FPS, Radial, Strontium, streaming enabled) after the run.

## Build provenance

The flashed image is `cfd6c830…`. [build-manifest.json](build-manifest.json)
records the same SHA-256 and the exact RTL source hashes:

| Source | SHA-256 |
|---|---|
| `fpga/rtl/pyrocore_top.v` | `78dafd8d…` |
| `fpga/rtl/pyrocore_core.v` | `71aa8420…` |
| `fpga/rtl/particle_renderer.v` | `171eeffa…` |
| `fpga/rtl/frame_streamer.v` | `bde2d559…` |
| `fpga/rtl/uart_rx.v` | `11cba6a2…` |
| `fpga/rtl/uart_tx.v` | `33fb3eec…` |

The same build's [resource](fpga-resources.log) and
[timing](fpga-timing-summary.log) reports show 131/140 logic blocks, 477 RBB
LUTs, 319 RBB flip-flops, 116 IOB output flip-flops, and post-route WNS
+15.344 ns with TNS 0.

## Raw report

[hardware-flash-verify.json](hardware-flash-verify.json) contains the complete
`tools/board_check.py` output: the hello and final status objects, motion frames,
clear frame, streaming sequence numbers and error counters.

## Notes

- This closes the earlier gap where the committed image was still the v0.3.0
  312500-baud build while the firmware expected 625000 baud.
- The board was left with streaming enabled at 5 FPS, Radial, Strontium, and a
  cleared scene.
