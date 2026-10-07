# Read-only graphics observation (October 7)

`--video-dump PREFIX` is an opt-in headless-runner diagnostic. It writes
`PREFIX.gram-b`, `.gram-r` and `.gram-g`: physical bytes in each plane,
16,384 bytes for base X1 or 32,768 bytes for Turbo, page 0 before page 1.
It also writes decimal `PAL_B`, `PAL_R`, `PAL_G` and `PRIORITY` in
`.video-palette`. Turbo builds additionally write CPU/video-domain SCRN and
blackclip latches and video width in `.video-controls`.

This accesses storage directly without evaluation, advancing clocks or
issuing emulated bus reads/writes. It does not change machine ports, RTL or
snapshot identity. The files are **not captured images**. They can contain
private game bytes and must remain ignored, just like snapshots/RAM dumps.
The actual `--frame` RGB capture remains the screen evidence.

## Local checks

`make -C verilator test-video-dump` passes on both delay-aware base and
fast X3/Turbo/DMA savable builds. An original IPL program writes distinct
CPU values into all three planes, both Turbo pages and aperture boundaries,
and programs palette/priority and Turbo controls. Every physical byte and
control is checked. Reports and all five RAM/CPU dumps are identical with
and without observation. The fixture explicitly clears the PPI-init DAM
spill through actual CPU writes; it does not patch memory or ignore unexpected
bytes. Final log: `/tmp/x1-video-dump-final.log`, exit zero. Both protected
dual-media and committed A-first/B-first writable snapshot regressions also
pass on the observing host (`/tmp/x1-video-dump-snapshot-regression.log`,
exit zero). The initial
fixture failure detecting that spill remains in `/tmp/x1-video-dump.log`.

## Arcus evidence, not a video fix

The native two-drive chain in
`output_files/arcus-dma-dual-continuation-32-48/` finishes successfully to
32 and 48 seconds without ROM/font/RAM reload or original-media writes.
At 48 seconds the CPU remains executing at observed bus address `0E9C`,
DMA totals remain 76,800 pairs, no further disk requests occur during that
16-second chunk, and the actual 640×400 final frame remains black,
hash `03702d99714c4325`. This is not gameplay or complete Turbo acceptance.

A separate read-only observation restores the 32-second state with the
same RTL/profile and original A/B disks using the newly built host runner
SHA-256 `bb720ff0b6c66c283df70cf85fe64b2205d943185699e1332f45a71fad37910c`,
preserved as `Vtop-video-observation` in the ignored continuation folder.
It advances exactly two 32 MHz reference units (62,500 ps), with no CPU enable
or DMA/FDC/host transfer, and does not save over the native state. `--reset-cycles 1`
only satisfies CLI duration validation; the restored reset-edge total remains
36,928. This host observation is separate from the frozen-runner continuation
provenance, not a claim that the original executable emitted these fields.
Log: `/tmp/x1-arcus-final-observe32.log`, exit zero; private output prefix
`final-observe32` in the same ignored folder.

CPU/video SCRN both equal `63`, blackclip both `0F`, video width is 0.
Digital palette masks are B=`B8`, R=`CC`, G=`E2`, priority=`00`.
Nonzero bytes per physical page are:

| Plane | Page 0 | Page 1 |
|---|---:|---:|
| Blue | 11,598 | 942 |
| Red | 8,351 | 151 |
| Green | 13,784 | 13,457 |

Thus graphics storage and palette masks are not simply all zero. This does
not establish correct CRTC addressing, fetch/shift phase, text priority or
blackclip behavior, or identify a proven cause. Continue with sampled active
renderer decisions and native traces before changing video behavior. Disk
1 in A / disk 2 in B and the late-Space script remain exploratory choices.
