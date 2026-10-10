# Turbo Z effect-register CPU experiment

`TURBO_Z_EFFECT_CPU=1` is a separate default-off **CPU storage** prototype.
It requires the CPU-only Z palette profile and refuses a video-renderer
combination. No board or C++ runner enables it. It supplies no Z identity,
ADC/input source, capture GRAM writes, mosaic/key/scroll pixels or video CDC.
Those remain necessary to complete Z8.

## Contract and limits

The primary encodings for `1FC1` position, `1FC2` mosaic/quantization, `1FC3`
chroma key and `1FC4` extra scroll are recorded in
[effect-control research](TURBO_Z_EFFECT_CONTROL_STATUS.md). The existing local
Common Source/eX1 `display.cpp` stores and reads each full byte when AEN is set,
but contains no rendered implementation of these effects. MAME's handlers
are logging-only and its map supplies writes, not readback. These references
do **not** establish native ASIC read/reset/unused-bit policies.

The new original `rtl/x1_z_effect_registers.sv` keeps four independent bytes.
Shared-machine admission requires `1FB0[7]` (AEN), actual ordinary I/O and no
DAM. It admits exactly `1FC1..1FC4`; ambiguous read/write strobes are rejected.
Writes occur once per held transaction. A completed read is retained only for
its captured address until a memory, ACK or other I/O cycle. It cannot override
unmapped ports or another control address. AEN exit retains storage; machine
reset clears it. Full-byte reads, unused-bit retention, inactive AEN behavior
and reset-to-zero are **provisional experiment policies**, not measured ASIC
behavior. `1FB0=8C` in its CPU fixture does not enable a functioning digitizer.

No effect decoder is connected to a renderer or a guessed 64-color format.
The earlier stateless decoder and ADC-pin adapter remain separate prerequisites.
Native ADC/line-buffer timing, position direction/origin, reduced quantization,
key comparison, scroll/superimpose/PPI setup and GRAM ownership remain unresolved.

## Executed checks

`make -C verilator test-z-effect-registers` passes 1,024 full-byte values,
65,536 exact addresses, held-write/read-response behavior, disabled/ambiguous
strobes, response clearing and reset. Wrong-enable and wrong-address controls
fail the unchanged required assertions. The first target failed because its
alias-negative **marker check** named the wrong oracle; the retained log is
`/tmp/x1-z-effect-registers-first.log`. Corrected target terminates zero in
`/tmp/x1-z-effect-registers-controls.log`, without warning suppressions.
The stronger current address sweep writes differing `A5` to every unmapped
address rather than an unobservable repeated `FF`; it and both negatives
repeat zero in `/tmp/x1-z-effect-registers-current.log` without suppressions.

`make -C verilator test-machine-z-effects` executes an original ioctl-loaded
IPL on the actual Z80 with SYS 32 MHz / independent VID 28.571428 MHz. Its
1,024 actual OUT/IN roundtrips store all byte values in RAM. It checks AEN
activation/exit, inactive writes, independent final values, adjacent ports,
real C5/DAM blocking and retained-IPL warm reset without asset reupload.
The bench observes **64 DAM-write SYS events** with no effect-port selection.
The disabled-profile control reaches actual CPU readback and fails at byte 0
with `FF`, not a fabricated device response.

Frozen evidence:
`verilator/obj_dir_headless/z-effect-machine-1/qualified-iaqlrlng/`;
terminal-zero log `/tmp/x1-z-effect-machine-real-dam.log`. Independent auditing
verifies 109 original/frozen inputs, both executable copies, emitted IPL,
identical before/after manifests and positive/required negative logs.

Earlier failures remain in `/tmp/x1-z-effect-machine-first.log`,
`/tmp/x1-z-effect-machine-diagnose.log` and
`/tmp/x1-z-effect-machine-neighbors.log`. The fixture mistakenly used the real
`1ECx` IPL-disable aperture as an alias, then failed to create a C5 falling edge
for DAM. Both diagnostic errors were corrected; storage/payload/reset
assertions were not weakened. No CPU registers, grants or RAM were forced.

CI schedules both new asset-free targets; hosted acceptance is separate.
Adjacent exhaustive control/ADC tests and disabled wrapper lint pass in
`/tmp/x1-z-effects-adjacent-builds.log`. Default pre-RTC generated state restores
unchanged in `obj_dir_rtc_disabled_fast/rtc-disabled-state-_ccxx8ba/`; snapshot
and keyboard logs are `/tmp/x1-z-effects-default-cross-snapshot.log`,
`/tmp/x1-z-effects-default-snapshot.log` and
`/tmp/x1-z-effects-default-keyboard.log`. No native pixels or hardware gate is
completed by CPU storage.
