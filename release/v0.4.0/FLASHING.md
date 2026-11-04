# Flash PyroCore v0.4.0 (prebuilt)

This folder is a complete, checksummed board package. You do **not** need the
Arduino ESP32 core or an FPGA compiler.

## One command

On a fresh machine:

```sh
git clone https://github.com/ANKITRA-J/pyrocore.git
cd pyrocore
./setup.sh
```

`setup.sh` creates the environment, installs the desktop and flashing
dependencies, and flashes. If the repo is already set up, run the flasher
directly from the repository root, with the board connected to its **native
ESP32 USB** port:

```sh
.venv/bin/python tools/flash_release.py
```

The helper detects the port automatically. If more than one serial port is
present, it prints a numbered picker. Non-interactive shells can pass
`--port NAME`; `--list-ports` shows what was detected. Typical names are
`/dev/cu.usbmodem…` on macOS, `/dev/ttyACM…` on Linux and `COM…` on Windows.

The helper verifies `SHA256SUMS`, writes the five sections and lets esptool
verify each one. It takes about 15 seconds. Use `--dry-run` first if you want to
see the command without flashing.

## Manual esptool equivalent

If you prefer raw esptool from this folder (works with esptool 4 and 5):

```sh
esptool --chip esp32s3 --port YOUR_PORT --baud 460800 write_flash \
  0x0      pyrocore.ino.bootloader.bin \
  0x8000   pyrocore.ino.partitions.bin \
  0xe000   boot_app0.bin \
  0x10000  pyrocore.ino.bin \
  0x670000 littlefs.bin
```

esptool 5 prints a deprecation warning for the underscore form but accepts it;
`tools/flash_release.py` selects the right spelling automatically.

## Then

```sh
.venv/bin/python desktop/app.py
```

Select the native USB port, click **Connect**, and wait for **LIVE FPGA** with
bridge **v0.4.0**. The FPGA image loads from LittleFS at boot.

## Scope

Only for Shrike-Fi (SLG47910V Rev BB + ESP32-S3, 8 MB flash). This replaces the
existing application and filesystem, so back up anything you need first.

Verified 4 November 2026: this package was flashed on Shrike-Fi, loaded the FPGA,
passed Launch/motion/Clear and streamed at 29.436 FPS with zero CRC, header or
timeout errors. See
[`reports/2026-11-04/v0.4.0-flash-verification/`](../../reports/2026-11-04/v0.4.0-flash-verification/RESULTS.md).
