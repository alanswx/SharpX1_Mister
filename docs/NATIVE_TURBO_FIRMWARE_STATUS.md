# Native Turbo firmware probe

October 5, 2026. Execution evidence, **not Turbo firmware/game acceptance**.

`scripts/stage_turbo_ipl.py` extracts one unchanged 32 KiB IPL from the user's
existing Set 2 archive into ignored `software/turbo-firmware/`. It refuses
ambiguous members, wrong sizes, changed archives or differing existing output.
The archive SHA-256 is
`cab67c8e20c9539114dbb98a2d66810e3a72c0d4342d97463e55679f254ed096`.
Member `IPLROM.x1t` SHA-256:
`212895703175665be8544daa55b65da1aebcf1e9a2db65bcc1622e564b802b71`;
SHA-1 `44620f57a25f0bcac2b57ca2b0f1ebad3bf305d3` matches the existing local
MAME `x1turbo` ROM metadata. This does not establish a verified hardware dump,
model authenticity, redistribution rights or correct core mapping.

Reproduction from the repository root, using private staged media:

```sh
python3 scripts/stage_turbo_ipl.py
make -C verilator turbo-video-fast
cd verilator
python3 tests/probe_special_titles.py ./obj_dir_turbo_video_fast/Vtop arcus \
  --rom ../software/turbo-firmware/212895703175-ipl.x1t \
  --font16 ../software/turbo-fonts/e356dd199270-FNT0816.X1 \
  --arcus-drive-b 2 --seconds 8 \
  --output obj_dir_turbo_video_fast/special-probes/arcus-turbo-ipl-new
```

The current probe uses the shared `rtl/sharpx1.v` machine, experimental Turbo
and X3 flags, 32 MHz system / nominal 42.954540 MHz video. Frozen executable
SHA-256 is `a2f1de9005d748d3f172ecd10de40a9842f4e99a2d7ffbbaee06a6a1ea918158`
(deleted-data checkpoint, v04 runner). Arcus Disk 1 in A / Disk 2 in B remains
explicitly exploratory; no release instructions establish the intended order.
No RAM bootstrap, altered firmware/game, mirrored drive images or invented
device readiness is used. Existing 8-row font/remaining Turbo gaps still apply.

First eight-second cold run produced a 320x200 screen reading
“IPL is looking for a program from FD0”, inspected from the actual PPM.
It issued 888 disk requests, zero writes, 36864 ioctl bytes, six PS/2 bytes,
36928 reset edges and 495 complete frames, hash `ad3165ae6bcf6eff`.
HS is 62.562500 us and VS 16.145062500 ms. This establishes instruction/device
execution and a displayed IPL message, **not game boot or correct firmware
compatibility**. Two independent cold runs repeat report/RAM/CPU/PPM bytes
with unchanged inputs. Private evidence lives in
`verilator/obj_dir_turbo_video_fast/special-probes/arcus-v04-turbo-ipl/`.

Next: inspect native CPU/FDC transactions and release boot requirements;
complete bank/decode, high-speed PCG/Kanji and other documented gaps as needed.
Do not attribute the lack of game boot to a particular missing chip without
trace evidence. Older base-IPL Arcus observations remain separate.
Offline disassembly of the supplied IPL finds SIO initialization at `1053`
and DMA initialization at `1062`, plus later BIOS register accesses. This is
code inspection, not a trace proving those paths executed or caused the
observed screen. The end-of-run PC `0447` is inside a text-VRAM clearing
loop, not evidence of a halted CPU or a uniquely identified loader failure.

## Bastard Special late-start trial

A separate 12-second X3/v04 trial used the base 4 KiB IPL, the same frozen
`a2f1de9...` executable and `tests/special_title_late_space.keys`: F at 1 s,
Space at 8 s. The first cold run completed, but its inspected 640x200 image
still shows the title, hash `22b566650e6207c3`; 1062 disk requests, zero writes,
743 frames, six PS/2 bytes and 4159 reset edges. It is **not gameplay evidence**.
The second cold run exceeded its 1800-second host timeout. The older collector
raised before writing its final evidence JSON, so this trial does not establish
two-run repeatability or final unchanged-input acceptance. Retained first-run
outputs and the partial second run are under ignored
`obj_dir_turbo_video_fast/special-probes/bastard-v04-late-space/`.

The collector now preserves partial logs, commands and explicit failed
acceptance for timeouts. Its asset-free mocked timeout regression verifies
that reporting behavior only; it does not simulate or validate a game.
