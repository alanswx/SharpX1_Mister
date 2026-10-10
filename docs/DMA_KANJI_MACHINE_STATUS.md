# DMA / Kanji shared-bus qualification

## October 10 local gate

`TURBO_DMA_KANJI_EXPERIMENT=1` is a separate shared-machine **SV diagnostic**
profile requiring Turbo, DMA, first-level Kanji and X3 video. Ordinary C++
runners and boards do not enable it; the separately named non-savable C++
follow-up below opts in. There is no combined snapshot identity,
native game acceptance or new RBF. The existing default prohibition remains
and its rejecting control is executable.

```sh
make -C verilator test-machine-dma-kanji
make -C verilator test-machine-kanji-reset test-machine-kanji-loader
```

The original asset-free fixture uploads its program and synthetic 131,072-byte
physical font through ioctl. The actual Z80 initializes the CRTC, PPI/DAM and
selector metadata, then programs an incrementing `1400..140F` I/O-source DMA
to RAM. It verifies all sixteen bytes with actual CPU instructions after the
real BUSRQ/BUSACK transfer. No forced grant or patched CPU/RAM is used.
SYS is 32 MHz; VID uses an integer-picosecond accumulator at nominal
42,954,540 Hz. This is delay-aware Verilator 5.044, not hardware timing.

Eight cases pass: loaded/absent font crossed with cold completion, owned-read
reset with stopped SYS, owned-read reset with stopped VID, and blocked font
upload during owned reset drain. Stopped VID holds the actual read strobe,
WAIT, shared address and frozen Kanji address for eighty SYS observations,
without starting a destination write. The wrapper counters count **strobe
starts**, not completed responses; the pending read already counts as one.
Reset drains exactly one pair, preserves the font, then restarts the retained
IPL. Actual CPU payload checks and 17 read/write starts qualify the restarted
transfer. Absent ROM terminates with sixteen FF bytes, not invented glyphs.

## Confirmed upload-start defect and repair

Before the repair, writes respected `ioctl_wait`, but Kanji upload START did
not. A DOWNLOAD edge while DMA owned a font response could invalidate readiness
and flag a live-upload error even though no byte was admitted. The fixture
holds the attempt over an actual SYS rising edge and asserts that the reset
drain still owns the bus on that edge; a pulse entirely between edges is not
an adequate negative control.

The pre-repair executable SHA-256 is
`f037c0f38385c10705bb5087e7e54de14371aa9774216879bbae6a7ac5867fde`.
Its loaded/reset-kind-3 case fails at `blocked upload invalidated owned Kanji
font`; evidence is `/tmp/x1-dma-kanji-upload-edge.log`, with the binary retained
in ignored `obj_dir_headless/dma-kanji-machine/pre-upload-gate-runner`.
The machine now gates upload START as well as byte writes with `!ioctl_wait`.
All eight unchanged positive assertions pass after this repair. Existing five
CPU pending-read reset cases and nine malformed-loader cases also pass.
The final fixture additionally checks every loaded physical font byte against
the independent synthetic pattern, not just the sixteen transferred bytes.
Logs: `/tmp/x1-dma-kanji-fixed-adjacent.log` and
`/tmp/x1-dma-kanji-guard.log`. The latter requires the precise default-profile
rejection, not just any nonzero simulator exit.

The final `test-machine-dma-kanji` gate also uploads one deliberately corrupted
font byte through the real loader. The actual CPU rejects it with marker EE;
the negative requires `CPU payload/restart mismatch marker=ee`, not a timeout.
Final eight cases and both rejecting controls complete zero in
`/tmp/x1-dma-kanji-final-controls.log`. Fixture SHA-256:
`b36ad7ec39e213fb1a131b37fa9c682e8e67d9d319ed91191306d61d40dd01d4`;
executable SHA-256:
`bfe2e9868af75997bf0ce974ef5262734ea367104ea8e4ebc1732dc515851b85`.
There are no fixture/shared-wrapper warnings in this build; inherited device
pin/width warnings remain accommodations, not correctness guarantees.
Four RAM, five PCG and five CRTC owned-reset cases also complete zero in
`/tmp/x1-dma-kanji-adjacent-dma.log`. Wrapper DMA lint completes zero using its
PLL stand-in, not Quartus or hardware. The ordinary `test`/headless/lint sequence
now completes zero under session 70443 in
`/tmp/x1-dma-kanji-baseline-regression.log`, including exact ordinary RGB,
keyboard/joystick, audio/PSG, PCG, D88/FDC and dual-drive/reset gates. Machine
RTL is the `8be40e6` checkpoint; this is not a combined-profile/native/board
acceptance matrix. A current ordinary `run CYCLES=200000` also completes zero
in `/tmp/x1-combined-current-headless-smoke.log`; its unprogrammed CRTC can
still report zero HS/VS, not a boot failure or a game frame.
CI now schedules the asset-free combined diagnostic; no hosted result is claimed.

## Still required

- Native simultaneous renderer/RTC/mailbox/IRQ/FDC/DMA behavior beyond the
  separately bounded pixel and active disk/clock follow-up below.
- Fixed, decrementing, sequential/non-byte and mixed interrupt ownership.
- A separately identified non-savable combined native runner before Arcus
  trials; this fixture alone does not justify deleting all profile guards.
- Native physical Kanji identity/order, scanline WAIT and second-level Z ROM.
- Current-source synthesis, CDC placement/timing and physical MiSTer tests.

This advances the full DMA/Kanji coexistence goal; it does not close it.

## Separate non-savable RTC / X3 / renderer / DMA runner

`make -C verilator rtc-x3-dma-kanji` builds into
`obj_dir_v17_rtc_x3_dma_kanji`, not any existing runner directory. It explicitly
enables RTC, X3, physical first-level Kanji, its renderer, DMA and the shared-bus
qualification parameter. IRQ/restart DMA remain disabled. The C++ compile
guard requires that combination and forbids `X1_SAVABLE`; JSON explicitly
reports `dma_kanji_experiment`. No snapshot model or board option is added.

The following separately frozen diagnostics run against this combination:

```sh
make -C verilator test-rtc-x3-dma-kanji-runner
make -C verilator test-rtc-x3-dma-kanji-keyboard
make -C verilator test-rtc-x3-dma-kanji-pixels
cd verilator
python3 tests/test_rtc_dma_fdc.py obj_dir_v17_rtc_x3_dma_kanji/Vtop
```

Six real PS/2 keyboard/clock cases and absent-key rejection complete zero;
136 original/copied inputs, actual CPU programs and RAM results are
independently audited in `keyboard-qualified-bs6by1ca`. Original ten loaded/
absent low/high 40/80-column and retained-asset warm pixel cases also complete
zero. Independent program regeneration and all **1,536,000 RGB pixels** match,
with 137 immutable inputs in `kanji-pixels-je2z45n8`. DMA is enabled but idle
in these original calendar/keyboard/pixel programs: these are not concurrent
DMA-rendering or native ASIC acceptance.

The new original-CPU FDC test executes RTC mailbox commands during an armed,
real 1,024-byte byte-mode disk DMA. CPU RTC reads are followed by an actual
FDC Busy assertion before sector completion; full DMA counter readback and
payload verification subsequently complete. Four cases pass: earlier fifteen-
byte and newer sixteen-byte Arcus register streams, each cold and after a
10-us retained-asset reset at 250 ms. The explicit extra WR3 byte is `80` after
WR2 `10`, not a guessed replacement command. Cold/warm require 1,024/2,048
actual grants/read/write starts, no CPU FDC data transfers, zero media writes
and complete sector/clock RAM values. Font/controller are explicit synthetic/
source-derived uploads. Renderer is enabled but no glyph display initialized
in this disk fixture, so its scope is active FDC/clock/DMA coexistence, not
simultaneous rendered pixels.

All four FDC cases and 138 immutable inputs are independently audited in
`fdc-qualified-1mfmk_a1`. The old default `diagnostic()` still produces exactly
the same program, sector and payload as commit `8be40e6`; only explicit new
arguments select clock traffic/the newer stream. Logs:
`/tmp/x1-rtc-x3-dma-kanji-keyboard.log`,
`/tmp/x1-rtc-x3-dma-kanji-pixels.log`,
`/tmp/x1-rtc-x3-dma-kanji-fdc.log`.

Elapsed seconds and retained-asset warm calendar now complete zero in
`/tmp/x1-rtc-x3-dma-kanji-runner.log`, with independent 138-input/program/RAM
auditing in `qualified-joxd_7zb`. Four missing/short/controller/snapshot
rejections also pass. The combined executable SHA-256 is
`bbfe27a755994dfd75da58d7f5fb95cb5184ec48ae82b8c0fb7a0101bc555988`.
Exploratory protected native Arcus/Bastard sixteen-second cold/repeat probes
also complete from the FDC-qualified frozen runner, sessions 13287/90962. They use
the earlier explicit controller/IPL/ANK/private model40 candidate and late-key
script; Arcus A=Disk 1/B=Disk 2 remains an unverified release configuration.
Their logs are `/tmp/x1-arcus-dma-rtc-x3-kanji-first-16s.log` and
`/tmp/x1-bastard-dma-rtc-x3-kanji-first-16s.log`. No gameplay,
native-font identity or hardware result is inferred from these bounded jobs.
Independent auditing verifies both exact reports, every original input and
all seven cold/repeat artifacts per title. Arcus now performs 57,344 actual DMA
grants/read/write pairs, with 2,914 disk requests and zero writes, ending at
CPU bus address `0A9F` instead of the earlier disk-error state. Its actual
640x400 frame is black (`03702d99714c4325`); the PNG conversion is visually
inspected and matches all 256,000 original PPM pixels exactly. Bastard remains
at its 640x200 title (`82968a99a28dbd3d`), with 1,062 requests and no DMA pairs.
Neither is gameplay acceptance. The absence of the old Arcus dialog is not
proof of the next failure's cause, correct release disk order or native IRQ.

## Repeating DMA during actual Kanji frames

The subsequent opt-in `--active-dma` collector qualifies **ongoing** DMA rather
than only enabling an idle engine or transferring once before final capture:

```sh
make -C verilator test-rtc-x3-dma-kanji-active-pixels
cd verilator
python3 tests/test_kanji_dma_payload_negative.py RUNNER --rtc-controller CONTROLLER.bin
```

All ten original loaded/absent, low/high, 40/80-column and warm-reset pixel cases
pass with repeated actual CG-source DMA reads and CPU comparison of every
delivered byte. Only selector entry zero at cell 2047 changes, outside all
25-row displayed layouts. The existing display pixel oracle remains unchanged;
the four non-active IPL programs remain byte-identical to `bdddcc1`.
The CPU repeatedly loads/enables a sixteen-byte incrementing `1400..140F` to
`D000..D00F` transfer, verifies it after real BUSACK release, increments a
verification counter, and repeats through the end of the run. HSYNC-window
WAIT remains active. No debug writes, forced grant, native assets or fake clock
are used. The RTC controller runs but this pixel program does not exchange
calendar commands; active FDC/clock and active pixels remain separate gates.

The paired-trace run completes zero in
`/tmp/x1-rtc-x3-dma-kanji-active-pixels-paired.log`, immutable directory
`fdc-qualified-1mfmk_a1/kanji-pixels-exz8_tzp`, using the unchanged
`bbfe27...` combined binary and 137 frozen inputs. Independent program and
pixel regeneration matches all **1,536,000 RGB pixels**. Actual bus auditing
matches **18,549 late-run completed read/destination-start pairs**, including
transfers after 290 ms, and every final RAM payload. Each CPU verifies between
125 and 486 complete payload iterations. Read/write counts may differ by one
at the invocation boundary, not by an abandoned transaction mid-run.

The first io-only trace attempt rejects one loaded-case final row: the runner
flushes a still-active WAIT read at exactly `end_ps - 15625`. Its previous
response is not the not-yet-completed new read's payload. The collector now
captures destination memory writes too. It excludes only that terminal source
read when exact final SYS timestamp, current bus address and one-extra-read
counter evidence agree; every completed response and subsequent destination
data/address remain exact. This is an explicit unfinished transaction, not
an accepted wrong byte or a relaxed pixel/timing assertion. Evidence of the
rejected initial attempt remains in the ignored first collector directory.

The independently audited negative uploads exactly one corrupt synthetic
font byte at physical address 129616. The same unmodified active-video CPU
program reads it through one real sixteen-byte DMA grant, observes the changed
destination byte, emits EE and halts without incrementing the verified-iteration
counter. The other fifteen payload bytes remain correct. Negative evidence:
`/tmp/x1-kanji-dma-active-payload-negative.log`, immutable
`fdc-qualified-1mfmk_a1/kanji-dma-negative-ge_ki_jy`.

CI schedules the positive active-pixel target; no hosted result is claimed.
Native font/model behavior, graphics/FDC/IRQ concurrency, exact ASIC WAIT,
current-source Quartus timing/CDC and physical hardware remain open.
