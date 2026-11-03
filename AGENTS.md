# PyroCore working instructions

Read README.md, docs/HANDOFF.md and docs/PROTOCOL.md first. Work only in this
standalone repository. The parent directory belongs to a different project.

Keep changes in useful commits. Update docs/HANDOFF.md with what works, exact
commands, remaining limitations and the next concrete step before handing off.
Record physical-board validation honestly; simulation and compilation are not
hardware tests. Keep routine checks proportionate and keep making useful code.

Target Shrike-Fi / SLG47910V Rev BB. Use the installed Renesas toolchain;
dedicated BRAM has explicit I/O Planner ports. Preserve the six-slice 3bpp layout
and 3.125MHz LaC1 route unless a measured implementation requires a change.

Firmware builds do not upload unless an explicit --port option is supplied.
Do not flash a board unless the user explicitly asks for that step. Do not program OTP.
Keep generated build products and machine-specific paths out of source commits.

Retain the source credits and bundled notices in docs/CREDITS.md and
tools/vendor/LICENSE. Update provenance when importing code; do not invent author
identities, rewrite existing attribution, or assign a project-wide license on your own.
