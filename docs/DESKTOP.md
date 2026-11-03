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

The stream-rate selector offers **7 FPS · faster** (default) and **5 FPS · steady**.
The selected target is applied when connecting, after startup confirmation, and
when changed during a connection. A physical-board run measured approximately
7.03 FPS at the seven-frame target and 4.97 FPS at the five-frame target; these
are received complete frames, not a particle count or a software-preview rate.
The handoff and hardware reports retain the physical run evidence.

**Stream FPS includes black frames.** A black image means the FPGA currently has
no visible sparks, while its frame stream can remain healthy. The UI shows
`No sparks` separately from `Active · N lit pixels`. It averages arrivals over a
three-second time window, starts with `calculating…`, and refreshes on a timer
so the value declines and reaches zero when frames stop. A disconnected or stale
stream displays zero and retains the last image with an explicit status.

Controls use minimum heights and normal Qt size hints rather than compressing
the text into stylesheet padding. The sidebar scrolls in shorter windows or at
larger display scaling; labels and buttons keep their spacing. The preview's
software timer is independent and does not demonstrate FPGA throughput.

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

### Layout and frame-rate regression check

```sh
.venv/bin/python -m unittest discover -s tests -p test_frame_stats.py -v
```

Six mock-clock checks cover startup, steady black-frame reception, active scenes,
rate decay without new frames, stale/disconnected zero and a resumed stream.
A separate offscreen geometry/control smoke check verified uncompressed controls,
the7/5FPS selector's commands, a black-frame fixture and explicit stale/offline
status. The screenshot from that smoke check is a UI fixture, not a board capture.
