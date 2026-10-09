# Conservative FM decoder and actual-CPU isolation

October 9, 2026. Original `rtl/x1_fm_decode.sv`, exhaustive oracle and additions
to the original CPU/JT51 diagnostic. This is a standalone integration seam,
not an enabled shared-machine FM device or completed Turbo Z audio.

## Contract and provenance

Exact ports `0700/0701` agree with the previously inspected local MAME and
X Millennium maps. The [primary board-pin audit](TURBO_Z_FM_STATUS.md#october-9-primary-board-pin-follow-up)
establishes YM2151 select/A0/IOWE/IORD/data and the provisional 4 MHz clock,
but not the ASIC's address truth table, aliases, WAIT phases or IRQ routing.
The new decoder therefore accepts only these two ports and genuine, exclusive
CPU I/O reads/writes. Disabled profile, reset, DAM, ACK/M1, active memory cycle,
idle strobes and simultaneous RD/WR are excluded. A future CPU-only machine
caller must disable selection during actual DMA ownership, not substitute
BUSRQ for ownership. No optional `0704..0707` CTC or IRQ connection is invented.

The module is included in `rtl/x1_fm.qip`, not `rtl/machine.qip`. Default
machine/board sources, audio ports, assets and ordinary snapshots stay unchanged.
Existing attributed JT51 sources/licenses are unchanged; their GPL-3.0-or-later
requirements and inherited source-notice conflict still require release review.

## Executed fixture scope

`fm_decode_tb.sv` exhausts all 65,536 addresses and all 256 combinations of
enabled/reset/DAM/M1/MREQ/IORQ/RD/WR: 16,777,216 cases. An independent inclusive
range oracle checks all three outputs, rather than reproducing DUT slicing.

`fm_cpu_tb.sv` now uses that decoder with the actual CPU and genuine JT51.
The generated program reads reset status and writes a completion marker
through real CPU memory stores. It then attempts writes and reads at ten
nearby/other-device ports: `0600`, `06FF`, `0702`, `0703`, `0704`, `0707`,
`07FF`, `0800`, `1F90`, `1FA0`. Every read must return FF and the real chip
dispatch count must remain exactly ten per complete program. This does not
emulate neighboring devices; it proves they cannot access FM in this fixture.

Existing busy polling, CT outputs, real Timer A flag, stopped-enable queued
write/CPU WAIT, retained-program HALT/raw-reset and stopped-enable IRQ-flag
reset/restart checks remain required. No CPU, chip, IRQ, memory-result or PC
state is forced. CPU interrupt input remains inactive: the observed Yamaha
IRQ flag is not evidence of native CPU interrupt routing.

The disabled decoder runs the unchanged program and must fail specifically
`CPU FM programmed decode/read failed` after its actual marker store. The
target rejects an unexpected success or a different failure/timeout. All
three master frequencies are tested at CPU CE periods 1/4/8; DAM/ACK/invalid
control combinations are exhaustive unit checks, not executed shared-machine
PPI/DMA/interrupt acceptance.

Commands:

```sh
make -C verilator test-fm-decode HEADLESS_DIR=obj_dir_v15_fm_decode
make -C verilator test-fm-decode HEADLESS_DIR=obj_dir_v15_fm_decode_28636364 FM_MASTER_HZ=28636364
make -C verilator test-fm-decode HEADLESS_DIR=obj_dir_v15_fm_decode_28571428 FM_MASTER_HZ=28571428
```

All three invocations terminate zero with 14 PASS reports each (42 total),
Verilator 5.044. Final logs are `/tmp/x1-fm-decode-32000000-final.log`,
`/tmp/x1-fm-decode-28636364-final.log` and
`/tmp/x1-fm-decode-28571428-final.log`. This covers all nine CPU-clock/master
combinations, their retained-program reset executions, the exhaustive unit
oracle and disabled negative at every master frequency.

| CPU fixture master Hz | Executable SHA-256 |
|---|---|
| 32,000,000 | `ddd111c2c148875fe603ce31b4efcc7fb4535cd97cb1b0580c0b73afcda5ee0d` |
| 28,636,364 | `f1fbf21a74795233bf676dabef52a897dac6e5cbdbe2441517cc1d16706903e9` |
| 28,571,428 | `01cb5aef8cc7e70422d06f533d8445d4c77570c702404c8f06999c5ae8059ada` |

Source SHA-256: decoder
`5c4c97366b75e43807b3f8337f128c6ef6bfaa8354d4a708f0499d7f27b04b0a`,
unit fixture `c6f15aaf20aca5cb3393d26673593ed3744b9634ef19be2ba7ddf66401cbc36c`,
CPU fixture `41e7e1770b734c2721b1ef1a98174219d9a3e17c3f89751a09a82c91a46c724e`.

An initial missing-timescale warning on the new combinational module was
corrected with an explicit directive, not a suppression. Vendor/CPU warnings
remain visible. Hosted diagnostics selects `test-fm-decode` (which includes
the actual CPU target); a hosted outcome is not assumed.

## Required next integration

Connect conservative decode and retained read response to the shared CPU bus,
include genuine adapter WAIT and drained reset behavior, and qualify actual
DAM/ACK/neighbor/device ownership there. Resolve native IRQ routing rather
than copying incomplete emulator assumptions. Then implement signed PSG/FM
stereo/mono delivery with measured or explicitly experimental digital gain,
qualify native register streams, serialize an enabled profile, and fit/test
that profile on hardware. This increment does not complete Z5 or the full goal.
