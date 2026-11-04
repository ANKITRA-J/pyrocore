# Prebuilt release images

Each `release/vX.Y.Z/` folder contains a ready-to-flash PyroCore board package:
the ESP32 application, bootloader, partition table, boot selector and the
LittleFS filesystem holding the FPGA bitstream. Flashing one does **not** need
the Arduino ESP32 core or an FPGA compiler — only Python and esptool.

| File | Flash address |
|---|---|
| `pyrocore.ino.bootloader.bin` | `0x0` |
| `pyrocore.ino.partitions.bin` | `0x8000` |
| `boot_app0.bin` | `0xe000` |
| `pyrocore.ino.bin` | `0x10000` |
| `littlefs.bin` | `0x670000` |

`SHA256SUMS` covers all five files. The flasher verifies it before touching the
board, and esptool verifies each written section afterwards. `RELEASE.json`
records the version, target board, bitstream hash and the verified hardware run.

## Flash

From the repository root, with the board on native USB:

```sh
.venv/bin/python tools/flash_release.py --port YOUR_PORT
```

`YOUR_PORT` is `/dev/cu.usbmodem…` on macOS, `/dev/ttyACM…` on Linux or `COM…`
on Windows. Use `--dry-run` to verify the checksums and print the esptool
command without flashing.

The helper uses esptool from the active Python environment, `PATH`, or the
Arduino ESP32 core if one is installed. If none is present:

```sh
.venv/bin/python -m pip install -r tools/requirements-flash.txt
```

## Supported hardware

Only the **Shrike-Fi** board: SLG47910V Rev BB FPGA + ESP32-S3 with **8 MB**
flash, on native ESP32 USB. The binaries are device- and board-specific. A
different board revision, a 4 MB module or a charge-only cable will not work.

## Regenerate a release

The release folder is a snapshot. Rebuild it whenever the firmware or RTL
changes, and bump the folder name with the version:

```sh
.venv/bin/python tools/build_firmware.py \
  --bitstream firmware/pyrocore/data/fpga_bitstream.bin \
  --build build/release-build
mkdir -p release/vX.Y.Z
cp build/release-build/pyrocore.ino.bootloader.bin \
   build/release-build/pyrocore.ino.partitions.bin \
   build/release-build/boot_app0.bin \
   build/release-build/pyrocore.ino.bin \
   build/release-build/littlefs.bin release/vX.Y.Z/
cd release/vX.Y.Z
shasum -a 256 *.bin > SHA256SUMS
```

`tools/flash_release.py` defaults to `release/v0.4.0`; use `--dir` for a newer
version. `tests/test_release_artifacts.py` fails if the checksums drift.
