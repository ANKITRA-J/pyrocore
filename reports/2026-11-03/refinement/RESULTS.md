# Desktop, stream and short-trail refinement

3 November 2026. This checkpoint follows the physical bring-up documented in
`../BRINGUP.md`. Credits remain in `docs/CREDITS.md` at the repository root.

## Result

The board now runs the FPGA image with a previous-position point plus the current
head for each particle. Two physical moving green/ring frames each contained16
lit pixels; Clear returned a complete black frame. A short7FPS-target stream
received22 frames at7.027FPS with no new CRC, header or timeout errors. See
`hardware-seven-fps.json`. The earlier point-renderer image measured7.036FPS at
this target (`hardware-points-seven-fps.json`) and4.97FPS at5FPS. All18 material/
pattern combinations passed on that preceding image; this refinement did not
repeat all18 on hardware.

The new desktop fixes compressed controls with minimum heights, spacing and a
scrollable sidebar, and offers7FPS by default with5FPS selectable. An offscreen
2×-scaling layout capture is `docs/images/desktop-layout.png`; it is disconnected
UI evidence, not a board image. The user had confirmed the preceding live app.

Stream FPS counts complete frames, including black ones. A separate activity
label describes visible sparks. A3-second time window and periodic refresh make
startup, stopped arrivals and stale/disconnected0 explicit. Six clock-based
checks cover these behaviors. All16 host checks passed (`host-tests.log`).

## FPGA fit and verification

The routed image uses134/140 logic blocks,474 RBB LUT resources,315 CLB flip-flops
and128 IOB output flip-flops. Dedicated framebuffer BRAM remains6/8 slices.
WNS is+15.995ns and TNS0 at the vendor typical setup corner; the core stays at
3.125MHz. Raw RBB LUT units are not the advertised LUT5 count, and this summary
is not full external BRAM interface timing signoff. See the resource and timing
logs here.

The renderer test passed ordered clears,16 paired writes, exact old/new positions,
gravity, queued launch, paired glitter and completion ordering. The integrated
UART test compared all4096 pixels with immutable RAM snapshots for two complete
CRC-valid frames and checked ownership and malformed commands. See
`rtl-simulation.log`.

The included46408-byte MCU image SHA256 is:

```text
55068cb7b76fcd634ec4a98aa4ffae851ec6a113682b22a8f5e7fa8a464a7ad8
```

Only LittleFS at0x670000 was uploaded for the trail change; the ESP32 application
was retained. The earlier full-flash backup remains local and ignored by Git.
The current manifest is `../build-manifest.json`; `baseline-build-manifest.json`
retains the preceding image/source record. BRAM power bits320/321 remain clear.

These are short functional measurements. Longer stream reliability, higher
visual density and a faster transport link remain future work.115200baud limits
the current packet stream to7.46FPS before delays.
