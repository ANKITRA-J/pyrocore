# First physical PyroCore run — 3 November 2026

The corrected checkpoint was uploaded to the Shrike-Fi and exercised over its
native USB port. A full8MB copy of the previous flash was saved locally under
`build/backups/2026-11-03/`; that private backup is not committed or uploaded.

## Configuration fix

The first image produced valid CRC-protected frames containing only black pixels.
PyroCore had reused a fixed default peripheral header with both BRAM banks powered
down. Register bits320/321 are active-high power-down controls:0 enables each bank.
See [Renesas SLG47910 datasheet, p66](https://www.renesas.com/en/document/dst/slg47910-datasheet?r=25546631).

The project configuration now clears those bits, and the packager derives its
header from the project's `nvmData`. It no longer uses the upstream helper's fixed
default header. The upstream file and its MIT credit remain intact.

Only byte1300 of the46408-byte MCU image changed, from0x03to0x00. The entire routed
core payload stayed byte-for-byte unchanged. No renderer rewrite was needed.
`bram-header-fix.json` records the old/new hashes and byte offset; regression checks
cover configuration preservation and rejecting powered-down banks.

An address-pattern diagnostic build was started during investigation, then stopped
when the power setting was identified. Its temporary renderer was restored and
the diagnostic image was never uploaded or made the checkpoint.

## Physical result

- Valid complete FPGA frames, with firmware CRC verification.
- Eight moving green particles; frame positions changed across sequence numbers.
- Clear produced a complete all-black frame.
-16frames measured at **4.97FPS** with a5FPS target during the short streaming run.
- No new CRC errors, header errors or timeouts.
- All18material/pattern combinations produced the selected colour; aluminium
  showed6–7visible pixels in the sampled frames because of its glitter gating.
- The sampled preset frames include both framebuffer sequence parities.

Evidence: `hardware-check.json`, `hardware-presets.json`. The initial failed run is
retained separately as `hardware-first-run.json` so the investigation is traceable.

This is first-board functional acceptance, not an all-corner timing guarantee or
a long-duration reliability run. The core remains3.125MHz and the full-frame link
remains115200baud. BRAM interface timing constraints and the tight132/140CLB budget
remain considerations for future changes.

The desktop app was opened in normal mode. Automatic approval review denied native
control of the Python app, so its buttons were left for the user. The measured
results above came from the real board over the command-line serial client.
