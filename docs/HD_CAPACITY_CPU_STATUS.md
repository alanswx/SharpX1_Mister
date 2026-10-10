# Turbo capacity-selection CPU storage

October 10, 2026. `TURBO_HD_SELECT=1` is a separate default-off shared-machine
CPU-storage experiment. It requires Turbo foundation and rejects unqualified
DMA ownership combinations, but does not enable a
board or C++ runner. Ordinary profiles remain unchanged. It is **not a native
2HD controller profile**: the selected class is not yet consumed by FDCCLK,
byte scheduling, medium matching, RPM, low-current or format logic. Future
enabled runners must be non-savable or introduce a separately qualified state
identity; ordinary snapshot v17 must not absorb this additional latch.

## Contract and source provenance

Original `rtl/x1_disk_capacity_select.sv` implements **IN** `0FFE` = 1.6M/2HD
class and **IN** `0FFF` = 500K/1M 2D/2DD class. These labels describe capacity,
not bit rates. Full sixteen-bit port decoding is used. OUTs, drive selection
and FM/MFM operations do not select the class. The shared machine gates reads
with its existing DAM eligibility and resets with `core_reset`.

Primary reference: local X1 Techknow Appendix A, PDF page 3/printed 275,
SHA-256 `720c79f24169ad33ea91d5b4e2c32b98fab41c91430f226462eb254ac9e5505c`.
Local X Millennium `io/fdc.c` changes its global media class on these reads;
Common Source X1 `source/src/vm/x1/floppy.cpp` changes all drive types on the
same reads. Its RPM changes are commented out, so they are not native RPM
evidence. Existing local MAME only logs the capacity reads. No new emulator
checkout is downloaded and no reference repository is edited.

Reset to 2D/2DD is a provisional startup policy, consistent with X Millennium's
zeroed state, not measured CZ-880 reset wiring. No deferred BUSY queue or
invented drive-specific latch is added. Any future rate consumer must resolve
the primary FDC requirement to keep density fixed during BUSY separately.

## Executed tests

`test-hd-capacity-select` exhausts all 65,536 addresses from **both** initial
classes, checks inactive-read retention and asynchronous/held reset. It finishes
zero; log `/tmp/x1-hd-capacity-decode.log`. This is digital decode, not native
pin-level timing.

`test-machine-hd-capacity` loads an original 8-KiB IPL through ioctl and runs
the real shared-machine Z80. Fourteen explicit program markers check the
selected class independently of the production address equation. Six selection
transactions, upper-address aliases, OUTs, FM/MFM, drive-B/side/motor controls,
DAM and retained-IPL warm reset pass twice with SYS 32 MHz and video
28,571,428 Hz. The identical program/oracle with selection disabled rejects
the absent connection. Logs: `/tmp/x1-hd-capacity-cpu-held-read.log` and
`/tmp/x1-hd-capacity-negative-Qyfy13`. No CPU bus/state is forced or fabricated;
no disk, private ROM, frame or byte-rate acceptance is inferred.

The initial fixture incorrectly expected a DAM-started IN to leave capacity
unchanged. Its failure is preserved in `/tmp/x1-hd-capacity-cpu-first.log`.
Existing `io_read` is held across SYS edges: the first clears DAM, subsequent
edges make that same IN device-eligible. The corrected CPU marker checks the
existing machine behavior; production DAM is unchanged. This does not establish
native ASIC edge ordering or a transaction-bound density window.

Checked SHA-256:

- selector `652075c6678fca70d0d1c25a8d5e3c633c4a2fefc16fdd8161b1770166ffe09a`;
- machine fixture `8df271b32de1fcf2adaec1773c7fdeb5a5825d0e5c16ddc94fa2c1796ea53e85`;
- exhaustive fixture `c16c28832c7e70331b9da9cb0945ccac16db875c781bbe09b4ac4209b5bb3455`.

## Remaining implementation

Connect class selection to explicit medium matching and rate scheduling;
qualify command-owned density changes, byte/DRQ/watchdog timing and mechanics.
Current inherited DRQ delays are CPU/handshake-paced, not proven native byte
slots, so simply doubling controller CE is not a qualified implementation.
Complete ordinary state/regression checks, independent review, source-bound
Quartus and available hardware tests. See [the full HD plan](TURBO_HD_DISK_PLAN.md)
and [wide-storage qualification](WIDE_D88_STATUS.md); neither replaces these
remaining native controller requirements.

The independent review finds no functional defect in the CPU-only latch after
the fixture correction. It identifies the shared DMA-multiplexed bus as an
unqualified combination; the enabled experiment now rejects DMA rather than
silently broadening its acceptance. Ordinary generated savable state against
`1bd97fd` is unchanged: all headers/serializers and checksums are byte-identical.
Actual HDL command lists are 103 then 104 files; existing relative ordering is
unchanged, with the new module inserted through `machine.qip`. Evidence:
`/tmp/x1-hd-select-review-Pb3FZu/comparison.json`. This proves ordinary state
identity, not a new enabled-profile snapshot or native hardware behavior.
Main independently compares all eight generated files byte-for-byte. Current
ordinary headless build/200,000-cycle smoke/disk-control regression and wrapper
interface lint finish zero; logs `/tmp/x1-hd-select-default-regression.log` and
`/tmp/x1-hd-select-wrapper-lint.log`. The final DMA-excluding CPU fixture rerun
also completes both passes and its disabled-profile negative, log
`/tmp/x1-hd-capacity-cpu-final.log`. Wrapper lint is not Quartus or hardware
acceptance. No private firmware/media or generated states are committed.

Direct schematic inspection of CZ-880 service sheets 47/48 confirms FDC
MB8877A CLK pin 24 is routed from MB4107 CK pin 8, separately from the
FM/MFM route. The capacity-class drive connector has its own 500K–1M/1.6M
control. This is evidence to trace the VFO/ASIC clock controls next, not proof
that changing the CPU-derived controller enable reproduces native FDCCLK.
