# Source provenance

The two UART RTL modules and the board configuration sequence reuse the user-owned Shrikenigma implementation, which was already tested with this board. The new engine, framebuffer controller, firmware protocol and desktop application are PyroCore-specific. No cipher logic is included.

`tools/vendor/gen_bitstreams.py` is bundled from
[trholding/shrike-gen](https://github.com/trholding/shrike-gen/blob/master/shrike_gen/gen_bitstreams.py).
Its Copyright © 2026 Vulcan and MIT notice are retained in `tools/vendor/LICENSE`.
See [CREDITS.md](CREDITS.md) for project, source, tool and dependency attribution.
