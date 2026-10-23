# Releases

Dated builds of the `sharpx1_turbo_z_font_single` release core. Copy the RBF
to `/media/fat/_Computer/` on the MiSTer. Each build's seed, timing and
hardware results are in `docs/DMA_BOARD_BUILD_STATUS.md`.

| File | SHA-256 | Notes |
|---|---|---|
| `SharpX1_20261023.rbf` | `941fde5261868359de407fc27b10c025188badd9b2de8357fb7bf2d45f6e465a` | Seed 10. Fast tape and tape overlay; OSD Machine/Video/Advanced pages with Apply and reset; X1 Turbo Z default; Z80 R register (Thunder Force) |
| `SharpX1_20261022.rbf` | `3102cf335c859b8b2aeda2fd3da98c8acd6791141bfe71d73eba2f844d158abd` | Seed 11. OSD Monitor (high-res 24 kHz DIP); boot3.rom loads the Kanji font |
| `SharpX1_20261021b.rbf` | `322cc621bb1598852d13750d88fcdfabfa9ad1d69f662e8cb64dbe00697db291` | Seed 10. Starts with PS/2 joystick emulation off (A/Z/X/C and keypad work) |
| `SharpX1_20261021.rbf` | `aa3c2332749372b99832d5ad2dba6f65b6a059b7834cb495fe6d1759242dfba9` | Seed 10. Boots without a Kanji font; Turbo Z palette writes in 640x200/64 and 320x400/64 |

ROMs, fonts and disks are not included; see `Readme.md` for the files the
core needs.
