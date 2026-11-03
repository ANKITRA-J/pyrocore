# Desktop control panel

The PySide6 app displays completed 64×64 FPGA frames, using the eight-entry palette.
It provides serial connection, material/pattern selection, Launch, Clear, and
Random Show. The display uses nearest-neighbour pixel scaling. Frame counters,
received FPS, CRC validation and stale-frame status remain visible.

## Install and run

From the repository root, with Python3.9–3.13:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r desktop/requirements.txt
.venv/bin/python desktop/app.py
```

On Windows use `.venv\Scripts\python.exe` instead of `.venv/bin/python`.
Connect the board, Refresh the ports, select the board's native USB port, and
Connect. The bridge must be running the PyroCore firmware. A successful image
transfer is shown separately from verified FPGA communication, which requires
receipt of a valid complete frame.

For an offline visual preview:

```sh
.venv/bin/python desktop/app.py --demo
```

The preview is explicitly marked SOFTWARE PREVIEW, does not open a port and does
not claim to show the FPGA. Its particle simulation is only for exercising the UI.

## Verification

```sh
.venv/bin/python -m unittest discover -s tests -p test_desktop_protocol.py -v
QT_QPA_PLATFORM=offscreen .venv/bin/python desktop/app.py --demo --screenshot build/desktop-demo.png
```

The pure decoder checks strict base64, exact1536-byte payloads,64×64 dimensions,
palette packing order, source, sequence range and firmware CRC-validation status.
Serial work is bounded and runs on a background thread. Malformed/partial frames
never replace the last complete image. A CRC8 computed by the ESP32 protects the
FPGA UART packet; USB frames report that firmware validation rather than implying
the desktop recalculates the UART packet CRC.

The current bridge targets five hardware frames/second. The preview's timer is
independent and does not demonstrate hardware throughput. No physical-board
acceptance has been performed by these desktop checks.

### Recorded local check

The seven protocol tests passed using the existing Python3.9.6 environment.
An offscreen interaction smoke check also passed: launch/clear/random preview
controls, normal startup without opening a port, and display of a decoded valid
frame fixture. That fixture is a software test, not board acceptance.
The offscreen window screenshot was also generated successfully using the
universal macOS Python/Qt build under x86_64. The restricted execution environment
blocks Qt6.8.3's arm64 hardware-feature probe (`hw.optional.neon`); this is a local
runtime restriction rather than an application exception. On the current Mac,
the offscreen command used for the screenshot was:

```sh
QT_QPA_PLATFORM=offscreen /usr/bin/arch -x86_64 .venv/bin/python desktop/app.py --demo --screenshot build/desktop-demo.png
```

Normal user Terminal launches should use the standard commands above.
