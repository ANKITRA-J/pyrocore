# PyroCore

An FPGA graphics accelerator for firework effects on the **Vicharak Shrike-Fi**.
The FPGA calculates particle motion and draws a 64 × 64 image using an eight-colour
palette, including black. The ESP32 passes commands and frames between the FPGA
and desktop app, which provides the controls and displays the result.

Get the verified board images from the [v0.4.0 release](https://github.com/ANKITRA-J/pyrocore/releases/tag/v0.4.0).

## Board demo

https://github.com/user-attachments/assets/5d95ee55-6c60-4a1f-b832-4f7dfd9f5758

*PyroCore running on Shrike-Fi, with FPGA frames shown in the desktop app.*

[Watch the full 32-second video](https://github.com/user-attachments/assets/5d95ee55-6c60-4a1f-b832-4f7dfd9f5758).

## What it does

- Up to eight particles per burst, with fixed-point motion, gravity, lifetime and short trails.
- Glitter on every material and pattern, with each spark retaining its colour.
- Radial, Ring, Willow and dual-colour Pistil patterns; six material presets.
- Two 64 × 64 × 3-bit framebuffers in dedicated FPGA memory; each frame has 1,536 bytes of pixel data.
- Launch and Clear commands, plus a desktop Random Show that launches successive bursts.
- CRC-8 checks on received FPGA frames.
- About 29.4 FPS on the board at the 30 FPS setting, with 18, 7 and 5 FPS options.

The drawing logic is fixed to these firework effects. Adding other drawing
operations requires changes to the FPGA design.

The included design targets **SLG47910V Rev BB + ESP32-S3 with 8 MB flash** on
Shrike-Fi. Other boards need a port; the included binary is device- and board-specific.

## Setup

You need the matching Shrike-Fi board, a USB data cable, Git and Python **3.9–3.13**.
Connect to the board's **native ESP32 USB** port. No external display or extra
wiring is required, and the included FPGA image needs no FPGA compiler.
Current board and desktop checks used macOS; Windows/Linux host workflows have
not had the same physical-board validation.

Both quick starts install the desktop app, flash the prebuilt v0.4.0 release and
launch the app. The prebuilt release needs no Arduino toolchain.

### Quick start (macOS/Linux)

```sh
git clone https://github.com/ANKITRA-J/pyrocore.git
cd pyrocore
./setup.sh
.venv/bin/python desktop/app.py
```

`setup.sh` creates `.venv`, installs the desktop and flashing dependencies,
detects the board's port (asking if several exist), and flashes the release.
The last command opens the app; continue with
[Connect and launch](#connect-and-launch).

### Quick start (Windows PowerShell)

Run these from the folder where you want the repository:

```powershell
git clone https://github.com/ANKITRA-J/pyrocore.git
cd pyrocore
py -3.13 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r desktop\requirements.txt
.\.venv\Scripts\python.exe -m pip install -r tools\requirements-flash.txt
.\.venv\Scripts\python.exe tools\flash_release.py
.\.venv\Scripts\python.exe desktop\app.py
```

Replace `py -3.13` with the Python you have installed (for example `py -3.12`
or `python`); `py -0p` lists what the launcher can find. Use Python 3.9 to 3.13.
No environment activation is needed; each command calls the virtual
environment's interpreter directly. The flasher detects the `COM` port
automatically. If `git` or `python` is not recognized, install Git for Windows
or reinstall Python with "Add python.exe to PATH" selected.

### Manual setup

`./setup.sh` is a convenience wrapper around these steps. Use them if you prefer
to run each part yourself or if `setup.sh` is unavailable.

#### Install the desktop app

macOS or Linux:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r desktop/requirements.txt
```

Windows PowerShell:

```powershell
py -3.13 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r desktop\requirements.txt
```

No environment activation is required. On Windows, replace `.venv/bin/python`
in the remaining commands with `.\.venv\Scripts\python.exe`.

#### Flash the prebuilt release (recommended)

`release/v0.4.0/` contains the application, bootloader, partition table and
FPGA filesystem, already built and checksummed. This path needs esptool, not the
ESP32 Arduino core.

Connect the board to its **native ESP32 USB** port and close PyroCore and any
other serial clients. Then run from the repository root:

```sh
.venv/bin/python -m pip install -r tools/requirements-flash.txt
.venv/bin/python tools/flash_release.py
```

The flasher finds the board automatically. If several serial ports exist, it
prints a numbered list and asks which one to use; `--port NAME` skips the picker
and `--list-ports` shows what it detected. If Arduino's ESP32 core is already
installed, the helper finds its bundled esptool and the first line is
unnecessary. It verifies `SHA256SUMS`, writes all five sections and checks the
flash hashes; upload time depends on the USB connection. This replaces the existing
application and filesystem. See
[the release notes](release/v0.4.0/FLASHING.md) for the raw esptool equivalent.

#### Build from source with Arduino

Install [Arduino CLI](https://docs.arduino.cc/arduino-cli/installation) and make
`arduino-cli` available in your terminal. Install the pinned dependencies:

```sh
arduino-cli core update-index --additional-urls https://espressif.github.io/arduino-esp32/package_esp32_index.json
arduino-cli core install esp32:esp32@3.3.12 --additional-urls https://espressif.github.io/arduino-esp32/package_esp32_index.json
arduino-cli lib update-index
arduino-cli lib install ArduinoJson@6.21.5
```

Then upload the application and FPGA image together:

```sh
.venv/bin/python tools/build_firmware.py --bitstream firmware/pyrocore/data/fpga_bitstream.bin --port YOUR_PORT
```

This uploads **both the ESP32 application and the FPGA image**, replacing the
existing application/filesystem. Back up any existing board contents you need.
The helper selects the board's USB CDC and 8 MB flash settings automatically.
The FPGA is configured at boot; this workflow does not program OTP.
Without `--port`, the helper only builds. Arduino IDE's ordinary Upload button
does not install the FPGA image into LittleFS, so use the complete helper package.

<details>
<summary>Flash without installing the desktop app</summary>

On a headless machine, create the environment, install the flashing dependencies
and run the flasher:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r tools/requirements-flash.txt
.venv/bin/python tools/flash_release.py
```

With `setup.sh`, `./setup.sh --flash-only` does the same: it flashes the board
without installing the desktop app. To install the app and flashing dependencies
without flashing the board, use `./setup.sh --no-flash`.

</details>

### Connect and launch

Run from the repository root:

```sh
.venv/bin/python desktop/app.py
```

1. Select the native USB port and click **Connect**.
2. Confirm bridge **v0.4.0** and wait for **LIVE FPGA** with received frames.
3. Choose **Sodium · yellow** and **Pistil**, then click **Launch firework** for
   a yellow outer group and smaller white glittering core.
4. Try other selections or **Start random show**. Use **Clear scene** to clear
   the image; **18 FPS**, **7 FPS** and **5 FPS** select slower stream targets.

The app displays received FPGA frames. Idle black frames with a healthy FPS are
normal; stale or disconnected streams retain the last image with an explicit
status. Every spark glitters, including its trail; motion continues while a spark
is hidden. Willow gets a slightly longer Random Show interval for its falling arc.
Choose a non-white material to see Pistil's white-core contrast. Scroll the sidebar
in a short window. On macOS, `Launch PyroCore.command` is also available after
installing the app.

For later updates, run `git pull --ff-only`, close the old app and reopen it.
Version 0.4.0 uses a 625,000-baud link between the ESP32 and FPGA to support the
30 FPS stream target. When upgrading from v0.3.0 or earlier, upload the matching
**v0.4.0 application and FPGA image together** using
[the helper above](#flash-the-prebuilt-release-recommended), then reopen the app.

<details>
<summary>Troubleshooting</summary>

| Symptom | Check |
|---|---|
| No board port | Use a data cable and native USB, then refresh. On Linux, check serial-port permissions. |
| Port busy or upload fails | Close other serial clients and recheck the port/cable. Try `--baud 115200` with the flasher if needed. |
| FPGA image unavailable or no valid frames | Use the matching board and complete helper package, including LittleFS; check the status/error text. |
| Black image with healthy FPS | Press Launch; particles expire and Clear deliberately produces black frames. |
| No Pistil option | Update the repository and restart the app. |
| Pattern 3 rejected or incorrect | Upload the matching v0.4.0 application and FPGA image together. |
| Stream rate unstable | Try 18, 7 or 5 FPS and check the status/error counters. |
| Pistil has no colour contrast | Choose a non-white material; Aluminium makes both groups white. |
| Controls below the window | Scroll the sidebar or enlarge the window. |
| Dependency installation fails | Use Python 3.9–3.13 and install into `.venv`. |

</details>

## Status

The v0.4.0 release was tested on the board at **29.436 FPS** with no CRC errors,
header errors or frame timeouts during the recorded run. The FPGA uses a 40 Hz
render scheduler; the desktop's 30 FPS setting is the requested stream rate.

For source changes, builds and technical references, see [Development](docs/DEVELOPMENT.md).
Source attribution and bundled notices are listed in [Credits](docs/CREDITS.md).
