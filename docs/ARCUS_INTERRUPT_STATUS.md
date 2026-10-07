# Native Arcus interrupt progression (October 6/7)

Arcus is not accepted gameplay. This follows the
[black-screen observation](VIDEO_OBSERVATION_STATUS.md); Disk 1 A / Disk 2 B
and start inputs remain exploratory. No original ROM/font/media/state bytes
are patched or bundled.

## Shared-machine evidence

`--video-dump` now exposes Turbo CTC control/constant/down-count/prescaler
and running/pending/service masks in `.ctc`. CPU dumps add actual IFF1/IFF2,
interrupt-mode state and I. The initial probe used TV80's combinational
IM-command field (3 means no change); it was corrected to stored `IStatus`.
Native state is IM2, I=F0, IFF1=IFF2=0 inside the handler.

`.cpu-fetches` counts completed M1 memory-read windows by address, relative
to this invocation. It excludes refresh, operands, interrupt ACK, DMA ownership
and an unfinished final fetch. Original CPU checks cover DI/LD/ED prefix
fetches, exclude immediates/debug-memory reads and positively program/read
CTC counter state with a fixed trigger. Base delay-aware, X3 fast and X3
delay-aware profiles pass with identical with/without-observation reports
and five RAM/CPU dumps (`/tmp/x1-ctc-fetch-final.log`, exit zero). Protected
and both-role writable snapshot regressions pass too
(`/tmp/x1-ctc-fetch-snapshots.log`, exit zero).

The native 32-second checkpoint continues 100 ms using preserved ignored
`output_files/arcus-dma-dual-continuation-32-48/Vtop-fetch-observation`,
SHA-256 `479f8ce3cec1d3005b6fb4a8dc3a9d78fcc46f2c9c8df9472dc1fe4df4681145`.
Log `/tmp/x1-arcus-fetch32.log`, exit zero; private prefix `fetch32`.
All 66,030 completed opcode fetches are within the native handler: 25 entries,
25 complete ED/4D RETI pairs, no foreground LDIR fetches. A separate earlier
ten-ms ordinary bus trace observes three returns and the same saved foreground
return address, but does not classify opcodes versus stack/operand reads.

Channel 1 has constant 16, control A1 (A7 after reset/constant bits consumed),
running/pending/service masks all 2. Existing 4 MHz enable and /256 imply
nominal 1.024 ms terminal-count intervals. Its handler rotates four groups
of 80 graphics bytes. This supports foreground starvation under repeated
service, **not** proof that slowing CTC or dropping pending counts is correct.
No clock, machine port, serialized RTL layout or interrupt policy is changed.

## Existing local MAME, actually executed

The user's private `x1/ank.fnt` is 8192 bytes, matches expected SHA-1
`0d4e072cd6195a24a1a9b68f1d37500caa60e599`, SHA-256
`017ae6c3d2976e5b6f939cacf886c2d8cd602d7287e5944ca5666cb3338f3cfb`.
The entire `x1/` folder is ignored, preserved, not committed. Its final 4096
bytes differ from the prior simulation ANK candidate; font configurations
are not claimed identical. Supplied IPL matches MAME SHA-1
`44620f57a25f0bcac2b57ca2b0f1ebad3bf305d3`.

Used existing sibling executable `../FM-7_MiSTer_alanswx/refs/mame/mame`,
version `0.283 (mame0283-464-gf4bfc5a423f-dirty)`, SHA-256
`296490cde3a874d0ea0cbdab8ac439e6ab4298fa9b8dd8ed6e066330a2d38d69`.
Binary identity is not proof of reproduction from the dirty source checkout.
No download or sibling/config mutation. Private staging is ignored
`output_files/mame-arcus-reference-pnbrRY/`: copied IPL/ANK, supplied model-40
Kanji/font members and disposable read-only A/B disks. ROM verification exits
zero: one set OK/best available, with the still-undumped 80C48 MCU warning.
Original and disposable media retain their native provenance hashes.

Original `tests/mame_arcus_reference.lua` uses read-only write taps/registers,
actual PNG capture and explicit frame-quantized F/Space/Return inputs, never
replacement bus data or ROM/RAM writes. MAME uses default F1/2D DIP, both
slots, private cfg/snapshot paths, no inherited config, video/sound none and
SDL dummy video. Initial normal SDL display initialization and wrong CPU-tag
Lua attempts fail; retained logs are not acceptance. Corrected run executes
to 51 seconds, exit zero, `/tmp/x1-mame-arcus-reference-run.log`.

Inspected actual PNGs: Glodia at 16 seconds, Wolf Team at 32, black at 50.
CTC writes A7/10 to channel 1 at about 38.3066 seconds; 50-second CPU sample
PC=0EA0, SP=08B1, IFF1=IFF2=0, IM2 is the same handler region/state as RTL.
Boot timing differs: compare software states, not equal checkpoint times.
This weakens a core-specific timer fault claim, not proof of hardware
correctness, a faulty disk or gameplay. MAME replaces the undumped keyboard MCU.
An independent second cold run also exits zero with a fresh private cfg/snapshot
directory: all 44 CTC/state records and all five PNG files match byte-for-byte.
Log `/tmp/x1-mame-arcus-reference-repeat.log`; original/disk-copy hashes remain
unchanged. This is repeatable reference evidence, not game acceptance.

Local X Millennium `io/ctc.c::ieeoi_ctc` discards some overlapping requests
using timer phase at service completion, unlike MAME/RTL pending preservation.
Inspected Zilog manual passages describe priority/RETI but do not settle this
overlap case. Execute that second emulator with unchanged assets and preserve
source/binary/config evidence; seek stronger primary/hardware evidence before
silently adopting its compatibility heuristic or changing timer frequency.

## Second-emulator build checkpoint

Archived local X Millennium revision `b07506c0cae31d260db28cb079148857d6ca2e93`
into ignored `output_files/xmil-reference-build-ZFOimE/source/`; the original
checkout remains clean. Apple Clang 21.0.0 rejects missing C declarations.
The isolated copy adds `string.h`, `stdlib.h`, `unistd.h` and the existing
`long GetTicks(void)` declaration to `libretro/compiler.h`; `libretro.c` adds
`sys/time.h`, its existing `sdlkbd.h`, and matching declarations for existing
`joymng_sync`, `xmil_end` and `sound_play_cb`. No CPU/CTC behavior is patched.
Failed attempts remain in `/tmp/x1-xmil-reference-build*.log`.

`make -f Makefile.libretro -j4 platform=osx` finally exits zero in the staged
`libretro/` folder (`/tmp/x1-xmil-reference-build-retry5.log`). Result
`x1_libretro.dylib` SHA-256:
`f0b1d55a970b9907c04ee36a729dedcd4b7029def1a9d289f8adda9d763e4313`.
Inherited format/unused-comparison/dangling-else and linker alignment warnings
are retained, not suppressed. This is a declaration-accommodated build, not
an executed Arcus comparison or licensing clearance. Next: an isolated libretro
host with private unchanged assets, explicit two-drive mapping and recorded
input/CPU/CTC/frame evidence.
