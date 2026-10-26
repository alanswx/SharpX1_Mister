# Releases

Dated builds of the `sharpx1_turbo_z_font_single` release core. Copy the RBF
to `/media/fat/_Computer/` on the MiSTer. Each build's seed, timing and
hardware results are in `docs/DMA_BOARD_BUILD_STATUS.md`.

| File | SHA-256 | Notes |
|---|---|---|
| `SharpX1_20261026b.rbf` | `5c34cb4e2696af9453117cc0287f709c86dd859d7dc5d0be316176317e0938ec` | Seed 1 (`5d74040`). Tape deck FF, REW and APSS (Super Mario Bros. Special loads its levels); drives start empty at every core load (needs the new `boot1.rom` controller) |
| `SharpX1_20261026.rbf` | `4554a92ac14af6d7bfc2eb839a196a55202ddcb1564533c846e9c0c532e942ea` | Seed 1 (`8ab04cb`). 24 kHz half-width text falls back to the doubled 8x8 font without a 16-row ANK (Koei numbers); a 36-KiB `boot.rom` (IPL + 16-row ANK) loads the font at core start |
| `SharpX1_20261025.rbf` | `07c6d841fa650d351c2d8c3fa9b1493d7395a0ca5312ffda76dce94065d02751` | Seed 1 (`0b1d857`). FM drone on first use after reset fixed (JT51 power-on state); Kanji in 15 kHz 8-raster rows (Aoki Ookami); Original aspect 19:14 at 15 kHz, 4:3 at 24 kHz |
| `SharpX1_20261024b.rbf` | `15fb0c7519ead0cbb9a7faff5c2acbce297794cc2fce147138e0e32331c8e8c6` | Seed 1 (`9253317`). Thunder Force speech (PSG period 0); copy-protection ID-CRC records (Suikoden, Shin Kugyokuden, The Man I Love); tape turbo only while the tape has pulses (Hyper Olympic); quick start excludes programs over the IPL stack; tape not remembered; firmware loads under Advanced |
| `SharpX1_20261024.rbf` | `dcf6ac527f9e9c2716bd25c9bb64ee53906f5f3b6bdbd17fa2fed6ca0f7a8786` | Seed 1 (`bd6f331`). OSD Tape speed: 5x + quick start (default), 5x, Normal; a tape's first machine-code program boots at once through the IPL's ROM-cartridge path |
| `SharpX1_20261023.rbf` | `941fde5261868359de407fc27b10c025188badd9b2de8357fb7bf2d45f6e465a` | Seed 10. Fast tape and tape overlay; OSD Machine/Video/Advanced pages with Apply and reset; X1 Turbo Z default; Z80 R register (Thunder Force) |
| `SharpX1_20261022.rbf` | `3102cf335c859b8b2aeda2fd3da98c8acd6791141bfe71d73eba2f844d158abd` | Seed 11. OSD Monitor (high-res 24 kHz DIP); boot3.rom loads the Kanji font |
| `SharpX1_20261021b.rbf` | `322cc621bb1598852d13750d88fcdfabfa9ad1d69f662e8cb64dbe00697db291` | Seed 10. Starts with PS/2 joystick emulation off (A/Z/X/C and keypad work) |
| `SharpX1_20261021.rbf` | `aa3c2332749372b99832d5ad2dba6f65b6a059b7834cb495fe6d1759242dfba9` | Seed 10. Boots without a Kanji font; Turbo Z palette writes in 640x200/64 and 320x400/64 |

ROMs, fonts and disks are not included; see `Readme.md` for the files the
core needs.
