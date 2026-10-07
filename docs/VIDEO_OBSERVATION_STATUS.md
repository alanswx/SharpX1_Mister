# Read-only graphics observation (October 7)

`--video-dump PREFIX` is an opt-in headless-runner diagnostic. It writes
`PREFIX.gram-b`, `.gram-r` and `.gram-g`: physical bytes in each plane,
16,384 bytes for base X1 or 32,768 bytes for Turbo, page 0 before page 1.
It also writes decimal `PAL_B`, `PAL_R`, `PAL_G` and `PRIORITY` in
`.video-palette`. Turbo builds additionally write CPU/video-domain SCRN and
blackclip latches and video width in `.video-controls`.
All builds now dump the three physical 2048-byte PCG planes as `.pcg-b`,
`.pcg-r`, `.pcg-g`, and decimal CRTC R0–R9/R12/R13 in `.crtc`.
`.video-samples` counts invocation-relative enabled video samples, actual
nonblank RGB populations and separate active-layer graphics/text color bins.
`GRAPHICS_SELECTED_FROM_INPUTS` evaluates the RTL priority/transparency
predicate from observed inputs because base builds inline the selection wire.
It is not a forced bus/signal or a recorded registered-output decision.
Layer inputs and registered RGB are one pipeline edge apart; do not correlate
individual pixels merely because their aggregate populations match.

This accesses storage directly without evaluation, advancing clocks or
issuing emulated bus reads/writes. It does not change machine ports, RTL or
snapshot identity. The files are **not captured images**. They can contain
private game bytes and must remain ignored, just like snapshots/RAM dumps.
Sample counters observe existing pixel edges without scheduling new ones.
The actual `--frame` RGB capture remains the screen evidence.

## Local checks

`make -C verilator test-video-dump` passes on delay-aware base, fast
X3/Turbo/DMA savable and delay-aware X3/Turbo/DMA builds. An original IPL program writes distinct
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

## Active renderer / PCG follow-up

The expanded original fixture programs a small running CRTC and real
high-speed PCG writes into every row of a selected character in all three
planes. It checks every PCG byte, all exposed CRTC registers, histogram
population sums, actual nonblank/nonzero RGB and graphics-selection predicates.
The with/without observation reports and five dumps remain identical in all
three clock/delay profiles. Log: `/tmp/x1-video-samples-full.log`, exit zero.
The protected and both-role writable snapshot regressions also pass on the
updated host (`/tmp/x1-video-samples-snapshot-regression.log`, exit zero).
The first PCG fixture correctly stalls before CRTC initialization; its
failure is retained in `/tmp/x1-video-samples-pcg.log`. Initializing CRTC
before the high-speed window accesses fixes the fixture, not the RTL.

An 80 ms observation from the private native 32-second checkpoint captures
four actual 640×400 frames; the final PPM/PNG is visually black with unchanged
frame hash `03702d99714c4325`. Preserved observing runner `Vtop-video-samples`
SHA-256 `a70131ce9e2702f2ddf330ce63c6a195f2e272aa2afd6067475e94c95b38dae4`;
log `/tmp/x1-arcus-samples32.log`, prefix `samples32` in the ignored native
continuation folder. No ROM/font/RAM reload, host requests/writes or DMA
transfers occur; the native CPU continues executing.

There are 1,718,182 enabled video samples and 1,149,766 actual visible samples,
**zero** nonzero visible RGB values. All 1,149,766 active-layer text colors
are 7, none are transparent, and none satisfy the graphics-selection
predicate. Graphics colors underneath are varied: bins 0–7 contain
446,560 / 51,833 / 5,224 / 7,941 / 117,365 / 123,706 / 45,057 / 352,080.
CRTC R0–R9 are `107,80,89,136,27,0,25,26,0,15`; start address is zero.
This demonstrates that the current mixer selects white text and its existing
`0F` blackclip turns that selected white text black; it does not identify
why native software has left the mask in this state.

A separate two-reference-unit PCG observation uses preserved `Vtop-video-pcg`,
SHA-256 `a78abe06dfc465f1ddf67a0349d0a5100853638708e296b124a496ff07cbe692`;
log `/tmp/x1-arcus-pcg32.log`, prefix `pcg32`. Characters FE/FF have all-FF
rows in each plane. Native text RAM has 2,001 FF bytes and 47 zero bytes;
attributes have 2,000 E7 bytes, 47 zero bytes and one 20 byte. These are actual
saved storage observations, not injected font/mask data. Original asset,
native-runner and checkpoint hashes still match the continuation provenance.

Inspected local X Millennium `vram/palettes.c` maps the matching text color
to black **after** text/graphics priority selection, agreeing with this
behavior rather than making the masked text transparent. Local MAME
`src/mame/sharp/x1_v.cpp` instead compares the full attribute value in its
text blackclip check, a separate reference disagreement. Neither emulator
is hardware evidence. Do not turn blackclip into graphics transparency
solely to make Arcus's screen visible. Continue investigating native PCG
programming, timing/interrupt progression and exploratory start inputs.

The unchanged frozen native runner also resumes the 48-second checkpoint
for two seconds with original `special_title_enter_space.keys`: Enter make/
break at relative 50/250 ms, Space make/break at 500/750 ms. Collector exits
zero, unchanged inputs, six PS/2 bytes sent, still black final frame at
50 seconds. Private output: `output_files/arcus-input-enter-space-50/`,
log `/tmp/x1-arcus-input-enter-space-50.log`. Transmission alone does not
prove delivery to the game or keyboard acceptance; these are exploratory
inputs, not release-specific instructions or gameplay.
