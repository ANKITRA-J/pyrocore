# PyroCore

A small FPGA fireworks engine for the **Vicharak Shrike-Fi**. The FPGA calculates
particle motion and renders a 64 × 64 image in eight colours. The ESP32 carries
commands and frames; the desktop app provides controls and displays the result.

![PyroCore desktop waiting for a board connection](docs/images/desktop.png)

*The desktop app waiting for a board connection. Fireworks appear from received
FPGA frames after connecting.*

## What it does

- Eight particles with fixed-point motion, gravity, lifetime and short trails.
- Radial, Ring, Willow and dual-colour Pistil patterns; six material presets.
- Two 64 × 64 × 3-bit framebuffers in dedicated FPGA BRAM.
- Launch, Clear and Random Show controls, with validated frame reception.
- A 7 FPS desktop stream target and a selectable 5 FPS fallback.

The included design targets **SLG47910V Rev BB + ESP32-S3 with 8 MB flash** on
Shrike-Fi. Other boards need a port; the included binary is device- and board-specific.

## Setup

You need the matching Shrike-Fi board, a USB data cable, Git and Python **3.9–3.13**.
Connect to the board's **native ESP32 USB** port. No external display or extra
wiring is required, and the included FPGA image needs no FPGA compiler.
The complete workflow has been checked on macOS; Windows/Linux host workflows
have not had the same physical-board validation.

### Install the desktop app

macOS or Linux:

```sh
git clone https://github.com/ANKITRA-J/pyrocore.git
cd pyrocore
python3 -m venv .venv
.venv/bin/python -m pip install -r desktop/requirements.txt
```

<details>
<summary>Windows PowerShell</summary>

Using an installed Python 3.13, or another supported version:

```powershell
git clone https://github.com/ANKITRA-J/pyrocore.git
cd pyrocore
py -3.13 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r desktop/requirements.txt
```

</details>

No environment activation is required. On Windows, replace `.venv/bin/python`
in the remaining commands with `.\.venv\Scripts\python.exe`.

### Load the board package

For the first installation, install [Arduino CLI](https://docs.arduino.cc/arduino-cli/installation)
and make `arduino-cli` available in your terminal. Install the pinned dependencies:

```sh
arduino-cli core update-index --additional-urls https://espressif.github.io/arduino-esp32/package_esp32_index.json
arduino-cli core install esp32:esp32@3.3.12 --additional-urls https://espressif.github.io/arduino-esp32/package_esp32_index.json
arduino-cli lib update-index
arduino-cli lib install ArduinoJson@6.21.5
```

Connect native USB and find the board's port:

```sh
arduino-cli board list
```

Typical ports are `/dev/cu.usbmodem…` on macOS, `/dev/ttyACM…` on Linux and `COM…`
on Windows. Close PyroCore and other serial clients. Replace `YOUR_PORT` below:

```sh
.venv/bin/python tools/build_firmware.py --bitstream firmware/pyrocore/data/fpga_bitstream.bin --port YOUR_PORT
```

This uploads **both the ESP32 application and the FPGA image**, replacing the
existing application/filesystem. Back up any existing board contents you need.
The helper selects the board's USB CDC and 8 MB flash settings automatically.
The FPGA is configured at boot; this workflow does not program OTP.
Without `--port`, the helper only builds. Arduino IDE's ordinary Upload button
does not install the FPGA image into LittleFS, so use the complete helper package.

### Connect and launch

Run from the repository root:

```sh
.venv/bin/python desktop/app.py
```

1. Select the native USB port and click **Connect**.
2. Confirm bridge **v0.2.0** and wait for **LIVE FPGA** with received frames.
3. Choose **Sodium · yellow** and **Pistil**, then click **Launch firework** for
   a yellow outer group and smaller white glittering core.
4. Try other selections or **Start random show**. Use **Clear scene** to clear
   the image; **5 FPS** selects the slower stream.

The app displays received FPGA frames. Idle black frames with a healthy FPS are
normal; stale or disconnected streams retain the last image with an explicit
status. Willow gets a longer Random Show interval. Pistil's white core flickers;
choose a non-white material to see the contrast. Scroll the sidebar in a short window.
On macOS, `Launch PyroCore.command` is also available after installing the app.

For later updates, run `git pull --ff-only`, close the old app and reopen it.
Upgrading from the three-pattern version also requires uploading the matching
v0.2.0 application and FPGA image together using [the helper above](#load-the-board-package).
The desktop-only removal of `--demo` needs no board upload.

<details>
<summary>Troubleshooting</summary>

| Symptom | Check |
|---|---|
| No board port | Use a data cable and native USB, then refresh. On Linux, check serial-port permissions. |
| Port busy or upload fails | Close other serial clients and recheck the port/cable. Upload baud defaults to 115200. |
| FPGA image unavailable or no valid frames | Use the matching board and complete helper package, including LittleFS; check the status/error text. |
| Black image with healthy FPS | Press Launch; particles expire and Clear deliberately produces black frames. |
| No Pistil option | Update the repository and restart the app. |
| Pattern 3 rejected or incorrect | Upload the matching v0.2.0 application and FPGA image together. |
| Pistil has no colour contrast | Choose a non-white material; Aluminium makes both groups white. |
| Controls below the window | Scroll the sidebar or enlarge the window. |
| Dependency installation fails | Use Python 3.9–3.13 and install into `.venv`. |

</details>

## Handoff

Firmware v0.2.0 / protocol v1: Pistil and Clear were physically checked, with a short
7.035 FPS stream ([results](reports/2026-11-04/pistil/RESULTS.md)). `--demo` is removed;
17 host tests and offscreen UI checks passed, without a new board test.
Next: confirm live frames in the updated desktop. Long-run reliability and full
BRAM timing signoff remain open.

For source changes, builds and technical references, see [Development](docs/DEVELOPMENT.md).
Source attribution and bundled notices are listed in [Credits](docs/CREDITS.md).
