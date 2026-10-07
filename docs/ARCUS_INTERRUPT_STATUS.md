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
source/binary/config evidence (now recorded below); seek stronger primary/hardware evidence before
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
an executed Arcus comparison or licensing clearance. Subsequent execution is
recorded separately below.

## Executed X Millennium comparison and counterfactual

Original `verilator/tests/xmil_reference_host.c` dynamically loads that dylib
using its exact staged headers. It enters private `system/xmil/`, supplies
libretro callbacks, rejects non-RGB565 output, discards audio, initializes the
machine, then mounts disposable A/B disks explicitly read-only before the first
executed frame. It checks ROM_TYPE=2, DIP=F1 and compares all 32 KiB of loaded
`biosmem` against the supplied IPL. No CPU/memory or firmware bytes are patched.
The final host compiles cleanly with `-std=gnu99 -Wall -Wextra -Werror`.
Its first probe lacked the configuration/loaded-ROM assertions; run 2 includes
them. Final original host SHA-256:
`1b3f64508e844492d5bd5d566521c3a2cb3535bffc1ac66e3843cb1db1da04c0`.
A private F5-config negative control exits one with the explicit F1-profile
error and produces no frames (`/tmp/x1-xmil-reject-config.log`). It does not
change original assets or bypass the configuration guard.

Private run folders are `output_files/xmil-reference-build-ZFOimE/run1/`
and `run2/`; logs `/tmp/x1-xmil-arcus-run1.log` and `run2.log`, both exit zero.
Configuration: `[Xmillennium]`, IPL_TYPE=2, Resolute=F1, s_NOWAIT=true,
SkpFrame=0. The supplied Set-2 archive provides the same IPL and 4096-byte
ANK candidate as RTL, plus FNT0808/FNT1616; the existing archive-tail warning
is retained. FNT0808 SHA-256 `2ce875255d64002589831e68825fbb36b7827be538dd030ffabb907b3c07610b`;
FNT1616 SHA-256 `40c080b7ad381050fe9f8d8063985a2648785ef470e397fbeb3d606a9774fc48`.
All original and disposable A/B hashes remain unchanged.

Each fresh process runs 3,060 frontend frames, with F at frames 60–71,
Space 480–497 and 2910–2924, Return 2883–2894. Capture frames
120/480/960/1920/3000 are real RGB565 converted to PPM, 640×400. Two cold
runs have exactly identical ten CPU/CTC records and all five PPM files.
Later scene images are visibly garbled; neither a start menu nor controlled
gameplay is established. The inspected PNGs are conversions of those PPMs,
not an invented image. `retro_get_system_av_info` advertises 60 Hz, but the
emulated frame clock varies: frame 3000 has 217,891,409 CPU cycles, not exactly
50 native seconds. Do not equate frontend-frame labels with wall/RTL/MAME time.

The actual clock configuration is baseclock=2 MHz, multiple=2, CPU=4 MHz.
CTC uses base-clock ticks: its /128 for command A7 corresponds to /256 at
4 MHz, **not evidence of a twice-fast timer**. The same TC=16 interval is
nominally 1.024 ms. Its phase-based RETI discard is a separate policy.

Original `verilator/tests/xmil_preserve_pending_control.c` includes the exact
reference `ctc.c` with notices intact, renames its original EOI function, and
replaces only EOI with pending retention/event rescheduling. It is a deliberate
counterfactual, **not** the unmodified reference or FPGA implementation. A
separate `preserve-pending-source/` copy is used; compared bytes confirm all
source and every other object unchanged, only `io/ctc.o` and the linked dylib
differ. Counterfactual dylib SHA-256:
`d8bb21c3be14b7e0abcdcd1b81bd7c1c6270744f61235fc6f5eea246fa206288`.
The CTC adapter is compiled instead of its original object with the original
optimization/ABI flags; a normal Makefile relink exits zero in
`/tmp/x1-xmil-preserve-pending-build.log`.

Two cold counterfactual runs use the unchanged run-2 config/assets/input
sequence; logs `/tmp/x1-xmil-preserve-pending-run1.log` and `run2.log`, both
exit zero, captures in `preserve-run1/frames/` and `preserve-run2/frames/`.
Ten records and five PPM files repeat exactly. The first three frames also
match the original reference byte-for-byte. Both later frames become all black:

| X Millennium policy | Frame 1920 | Frame 3000 |
|---|---|---|
| Original phase coalescing | PC=0E2C, varied scene, channel 1 stopped | PC=116D, varied scene, channel 1 stopped |
| Pending retention control | PC=0E9C, black, TC=16 still running/pending | PC=0E9F, black, TC=16 still running/pending |

Retained-policy SP=08B1, I=F0, IM2 and IFF_RAW=1 (this reference encodes
interrupt-disabled as bit 0 set) reproduce the RTL/MAME handler state.
This isolates the policy's effect **within X Millennium**; it does not prove
the physical chip should drop requests, settle disk/release instructions,
or establish game compatibility. No RTL clock/interrupt policy changed.
Re-read the official [Zilog UM0081](https://www.zilog.com/docs/z80/um0081.pdf),
printed pages 25–30: terminal-count requests, channel priority, ACK and RETI
are specified, but the inspected passages do not explicitly settle repeated
same-channel terminal counts during service. Next acceptance gate is stronger
chip/hardware evidence or an independently justified interrupt contract,
not silently copying a compatibility heuristic.

Host invocation (all paths absolute; directories already privately staged):

```sh
output_files/xmil-reference-build-ZFOimE/xmil_reference_host \
  "$PWD/output_files/xmil-reference-build-ZFOimE/source/libretro/x1_libretro.dylib" \
  "$PWD/output_files/xmil-reference-build-ZFOimE/run2/system" \
  "$PWD/output_files/xmil-reference-build-ZFOimE/run2/frames" \
  "$PWD/output_files/xmil-reference-build-ZFOimE/run2/disks/arcus-a.d88" \
  "$PWD/output_files/xmil-reference-build-ZFOimE/run2/disks/arcus-b.d88"
```
