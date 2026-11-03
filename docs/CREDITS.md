# Credits and third-party sources

## Project

PyroCore is maintained by **Ankit Raj / [ANKITRA-J](https://github.com/ANKITRA-J)**,
as recorded in the repository's Git history. Development and documentation were
assisted by OpenAI Codex. Commit attribution remains under the existing project
identity; source provenance is documented below.

## Reused source

| Source | Use in PyroCore | Attribution / notice |
|---|---|---|
| [Shrikenigma](https://github.com/ANKITRA-J/shrikenigma) | The owner's working UART RTL and board configuration sequence | See `fpga/rtl/uart_rx.v`, `fpga/rtl/uart_tx.v`, and `docs/PROVENANCE.md` |
| [trholding/shrike-gen](https://github.com/trholding/shrike-gen/blob/master/shrike_gen/gen_bitstreams.py) | `tools/vendor/gen_bitstreams.py`: MCU image formatting from the vendor AXI output | Copyright © 2026 Vulcan; MIT notice retained in [`tools/vendor/LICENSE`](../tools/vendor/LICENSE) |

The FPGA particle engine, framebuffer/streaming logic, PyroCore firmware protocol,
desktop interface and project-specific build integration were implemented for
this project. No Enigma cipher logic is included.

## Hardware and tools

- **Vicharak:** Shrike-Fi board, board documentation and configuration reference.
- **Renesas:** SLG47910V ForgeFPGA, datasheet, Go Configure/ForgeFPGA Workshop,
  bundled synthesis/route tools and the BRAM FIFO example used as an interface reference.
- **Espressif:** ESP32-S3 and Arduino-ESP32 toolchain.
- **Yosys, ABC and Verilator contributors:** synthesis and RTL simulation tooling.

## Runtime dependencies

The desktop uses PySide6 / Qt for Python and pyserial. Firmware uses Arduino-ESP32
and ArduinoJson by Benoît Blanchon and contributors. Their source and license
notices remain with their respective distributions; they are dependencies rather
than original PyroCore work.

This document does not assign a new project-wide license. The bundled MIT notice
applies to its identified upstream source; it does not relicense all PyroCore files.
