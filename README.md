# PyroCore

A small FPGA fireworks engine for the **Vicharak Shrike-Fi**. The FPGA calculates
particle motion and renders a 64 × 64 image in eight colours. The ESP32 carries
commands and frames; the desktop app provides controls and displays the result.

![PyroCore desktop software preview](docs/images/desktop.png)

*Desktop software preview. The preview animation is separate from FPGA output.*

## Get it running

Use the [step-by-step setup guide](docs/SETUP.md). It covers installing the desktop
app, loading the included FPGA image through the ESP32, and connecting your board.
You do **not** need the FPGA compiler to use the included image on matching hardware.

Already installed? From the repository root:

```sh
.venv/bin/python desktop/app.py
```

On Windows, use `.venv\Scripts\python.exe` instead of `.venv/bin/python`.
For a preview without a board, add `--demo`.

## What it does

- Eight particles with fixed-point motion, gravity, lifetime and short trails.
- Radial, Ring and Willow patterns; six material colour presets.
- Two 64 × 64 × 3-bit framebuffers in dedicated FPGA BRAM.
- Launch, Clear and Random Show controls, with validated frame reception.
- A 7 FPS desktop stream target and a selectable 5 FPS fallback.

The included design targets **SLG47910V Rev BB + ESP32-S3 with 8 MB flash** on
Shrike-Fi. Other boards need a port; the included binary is device- and board-specific.

## Documentation

| Guide | Use it for |
|---|---|
| [Setup](docs/SETUP.md) | Install, upload, connect and troubleshoot |
| [Architecture](docs/ARCHITECTURE.md) | Physics, patterns, glitter and framebuffer design |
| [Development](docs/DEVELOPMENT.md) | Change the design, rebuild and run relevant checks |
| [Protocol](docs/PROTOCOL.md) | USB commands and the FPGA frame format |
| [Handoff](docs/HANDOFF.md) | Current image, measured fit and validation status |
| [Credits](docs/CREDITS.md) | Authorship, reused source and license notices |

Build outputs, local environments and board backups belong in ignored local
folders. Dated [reports](reports/README.md) retain evidence for each checkpoint.
