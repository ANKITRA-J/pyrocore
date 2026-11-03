# Set up PyroCore

## Hardware and software

- A **Shrike-Fi with SLG47910V Rev BB and ESP32-S3, 8 MB flash**.
- A USB data cable connected to the board's **native ESP32 USB** port.
- Git and Python **3.9–3.13** for the desktop app.
- [Arduino CLI](https://docs.arduino.cc/arduino-cli/installation) for the first firmware upload.

No external display or extra wiring is required on the supported board. The
included FPGA image is enough to start; Renesas FPGA tools are only needed when
changing the RTL. The complete workflow has been exercised on macOS. Windows and
Linux commands below use their normal Python/Arduino installations; those host
workflows have not had the same physical-board validation.

## 1. Download and install the desktop app

macOS or Linux:

```sh
git clone https://github.com/ANKITRA-J/pyrocore.git
cd pyrocore
python3 -m venv .venv
.venv/bin/python -m pip install -r desktop/requirements.txt
```

Windows PowerShell, using an installed Python 3.13:

```powershell
git clone https://github.com/ANKITRA-J/pyrocore.git
cd pyrocore
py -3.13 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r desktop/requirements.txt
```

Another supported Python version can be used in place of `3.13`. No environment
activation is required. To try the interface before uploading anything:

```sh
.venv/bin/python desktop/app.py --demo
```

On Windows, replace `.venv/bin/python` in this guide with
`.\.venv\Scripts\python.exe`. Preview mode is labelled SOFTWARE PREVIEW and does
not open a board port.

## 2. Install the firmware tools

Make `arduino-cli` available in your terminal, then install the pinned dependencies:

```sh
arduino-cli core update-index --additional-urls https://espressif.github.io/arduino-esp32/package_esp32_index.json
arduino-cli core install esp32:esp32@3.3.12 --additional-urls https://espressif.github.io/arduino-esp32/package_esp32_index.json
arduino-cli lib update-index
arduino-cli lib install ArduinoJson@6.21.5
```

These use the [Arduino CLI core workflow](https://docs.arduino.cc/arduino-cli/getting-started)
and [Espressif's stable package index](https://docs.espressif.com/projects/arduino-esp32/en/latest/installing.html).
The firmware build selects ESP32-S3, USB CDC on boot, 8 MB flash and the default
8 MB partition scheme automatically.

## 3. Upload the application and FPGA image

Connect native USB and identify its port:

```sh
arduino-cli board list
```

Typical port names are `/dev/cu.usbmodem…` on macOS, `/dev/ttyACM…` on Linux and
`COM…` on Windows. Close the PyroCore app, Arduino Serial Monitor and other clients
using that port. Replace `YOUR_PORT` with the actual value:

```sh
.venv/bin/python tools/build_firmware.py --bitstream firmware/pyrocore/data/fpga_bitstream.bin --port YOUR_PORT
```

This compiles and uploads **both the ESP32 application and its LittleFS FPGA
image**, replacing the existing application/filesystem. Preserve an existing
project or flash backup before using this on a board whose contents you need.
The FPGA is configured at boot; this workflow does not program OTP.

The ordinary Arduino IDE Upload button installs the sketch but does **not** install
`fpga_bitstream.bin` into LittleFS. Use the helper above for the complete package.
To compile without touching the board, omit `--port`.

For an existing installation, run `git pull --ff-only` in the repository, close
the old app, then run the complete upload command above. Reopen the desktop app
afterward. Updating only the Python files or only the ESP32 sketch leaves part
of the old three-pattern implementation in place.

The helper preserves your normal Arduino CLI configuration and detects its data
directory. Use `--arduino-cli PATH` for a CLI outside PATH, `--arduino-config FILE`
for a separate CLI configuration, or `--esp32-tools PATH` / `--libraries PATH` for
explicit tool/library locations. `--baud` changes upload speed; its default is 115200.

## 4. Connect and launch

```sh
.venv/bin/python desktop/app.py
```

1. Select the native USB port and click **Connect**. The app prefers an Espressif port.
2. Confirm the bridge reports **v0.2.0**, then wait for **LIVE FPGA** and received frames.
   Image transfer alone does not verify communication.
3. Choose **Sodium · yellow** and **Pistil**, then click **Launch firework**. Look for
   a yellow outer group and a smaller white glittering core as the burst expands.
4. Try other materials/patterns or **Start random show**. Use **Clear scene** to
   clear the image. Select **5 FPS** if you prefer the slower stream.

Willow gets a longer Random Show interval so its falling arc can develop.
**Pistil** adds a white glittering core inside the selected-colour shell. Choose
a non-white material, such as Sodium or Strontium, to see both colours clearly.
The eight-particle hardware burst is sparse and its points can overlap early on;
the white core deliberately flickers. Aluminium makes both groups white. An
upgrade from the three-pattern version needs both the new firmware and FPGA
image: use the complete upload command in step 3.
**Idle (no sparks)** with a nonzero stream FPS is normal: complete black frames
are still being received. Stale or disconnected streams show zero FPS and retain
the last image with an explicit status. Scroll the controls in a shorter window.

On macOS, `Launch PyroCore.command` is a convenience launcher after step 1.
It is not needed on other systems.

## Troubleshooting

| Symptom | Check |
|---|---|
| No board port | Use a data cable and native USB; refresh the list. On Linux, check your user's serial-port permissions. |
| Port busy | Close other PyroCore windows and Serial Monitor. |
| Upload connection errors | Recheck the port/cable; the helper defaults to 115200 upload baud. |
| FPGA image unavailable | Upload the complete helper package, including LittleFS. |
| Image transferred but no valid frames | Check the matching board/image and native USB connection; use the status/error text. |
| Black image with healthy FPS | Press Launch; particles expire and Clear deliberately produces black frames. |
| No Pistil option | Update the repository and restart the desktop app. |
| Pattern 3 rejected or Pistil behaves like an older pattern | Upload the matching v0.2.0 application and FPGA image together using step 3. |
| Pistil has no colour contrast | Choose a non-white material; Aluminium makes shell and core white. |
| Controls below the window | Scroll the sidebar or enlarge the window. |
| Dependency installation fails | Check Python is 3.9–3.13 and install into `.venv`. |

An optional command-line functional check is documented in
[Development](DEVELOPMENT.md). It is not required before every use.

## Using a different board

The desktop and protocol can be reused. A different FPGA/board requires adapting
and rebuilding the FPGA top level, clocks, memory primitives and pin mapping.
An ESP32 bridge on another board also needs the configuration/UART pins and flash
partitioning adjusted. Review `fpga/project/pins.csv`, `fpga/rtl/pyrocore_top.v`,
`firmware/pyrocore/fpga_loader.cpp` and `firmware/pyrocore/pyrocore.ino`.
Do not upload the Shrike-Fi binary unchanged to a different device.
