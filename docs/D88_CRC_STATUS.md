# D88 ID/data CRC increment

October 5, 2026. Active path: `rtl/sharpx1.v` → `rtl/vendor/wd1793.sv`.
This is a bounded command-semantic increment, **not** exact rotational MB8877
behavior or completion of the whole storage milestone.

| Generated record / operation | Implemented result |
|---|---|
| Matching bad ID (`A0`), no valid duplicate | No payload DRQ or payload SD request; bounded search ends with CRC+RNF. Reads and writes require a usable ID. |
| Bad ID followed by valid duplicate | Skip the damaged ID, use only the valid payload, retain command CRC. A good duplicate encountered first does not inherit an unvisited bad ID's CRC. |
| Nonmatching bad ID | Does not attribute its CRC to a different requested sector. |
| Data CRC (`B0`) | Transfer payload and apply CRC at completion. Multi-sector transfers continue; missing subsequent R adds RNF. |
| READ ADDRESS `A0` | Six CHRN/CRC bytes, ID CRC at completion without RNF. Computed good CRC is complemented with `FFFF`. |
| READ ADDRESS `B0` | Normal ID CRC bytes/status; a data-field error does not contaminate this command. |
| READ ADDRESS first DRQ missed | Present C in the sector register regardless of host consumption; remaining bytes continue with lost-data and applicable ID CRC. |
| New command, abort, reset, mount quarantine | Clear pending transfer CRC; retain established SD ACK draining/ownership. |

The index remains 57 bits, with byte-7 deleted metadata separate from byte-8
ID/data errors. One new `pending_read_crc` bit preserves the selected record's
CRC until completion; the runner requires **snapshot v05**. Old states are
rejected before deserialization, not converted. Regenerate native states with
matching executable/profile/media. An explicit index settling state supports
divided and continuous FDC enables; it is not a new clock.

## Tests and current qualification boundary

`verilator/tests/d88_crc_tb.sv` mounts original generated media through the
scanner/SD path and operates FDC registers. No firmware/game bytes or debug
memory writes. `make -C verilator test-d88-crc` passes with CE every system
edge and every eighth edge: singleton/end-of-table bad IDs, duplicate ordering,
multi-sector bad IDs, READ ADDRESS lost-data, pending-CRC abort/reset and
command-status recovery. Pre-fix payload DRQ failure is retained in
`/tmp/x1-d88-crc-before.log`; final fixture passes in
`/tmp/x1-d88-crc-final-address.log`.

Final CRC source also passes force-interrupt, twelve pending-SD abort/reset
and direct scanner bounds/replacement fixtures in
`/tmp/x1-d88-crc-final-connected.log`; the earlier increment's retained log is
`/tmp/x1-d88-crc-connected.log`. The later CPU wrapper ownership seam leaves
machine BUSRQ inactive. Combined base/X3 wrapper lint passes in
`/tmp/x1-crc-cpu-wrapper-lint.log`, with
inherited warnings visible. Final source `76d87a2` builds and passes the full
expanded generated-media machine suite in fast and delay-aware baseline
simulation, plus baseline snapshot and same-rate base/X3 profile-rejection
checks. Logs: `/tmp/x1-crc-cpu-final-{fast,headless}-disk.log`,
`/tmp/x1-crc-cpu-final-{base,cross}-snapshot.log`.
Both machine disk suites retain 8,000,000 cycles per original CPU fixture,
32 MHz sys / 28.571428 MHz video and loader-derived resets; source images are
hashed unchanged, with writes confined to disposable output images.

| Final executable | SHA-256 |
|---|---|
| Fast baseline | `2b48f7818c7fa584b82502c9fc2a99ed536fae2b923093eb387f0035a77ed1c0` |
| Delay-aware baseline | `846be4d27b6c84e1738689db55dcf698a6a76f8e5e673b3b8426018ac0a57cc0` |
| Fast savable X3 | `d8650c4e9f36e2dbfce6ce1c7440d1d638ad93d5b8d15833c3e8df9d1e8c59e4` |

X3 snapshot checks use 32 MHz sys / 42.954540 MHz video and original synthetic
CPU diagnostics, not native game acceptance. Five-game v04 results remain
historical; fresh v05 native/game qualification is pending. The frozen
`c0d1042` Quartus fit does not include these later CRC/CPU changes.
No new hardware acceptance is claimed.

## Primary evidence and limits

Fujitsu MB8876A/MB8877A PDF page 5, printed 4-31, explicitly says READ ADDRESS
loads the ID track into SCR; PDF page 7, printed 4-33, distinguishes CRC/RNF.
Both were inspected locally. [Original datasheet](https://knetonator.de/dashboard/PPG/Manuals/WT-A%20MB8876A_FujitsuMediaDevices.pdf),
[local inventory/hash](../references/manuals/README.md).
Local MAME `wd_fdc.cpp::read_sector_continue` cross-checks bad-ID skipping,
duplicate recovery and sticky multi-sector data CRC. Its first READ ADDRESS
byte presentation copies C into SCR. `flopimg.cpp` complements synthesized
damaged ID CRC with `FFFF`: a deterministic **container convention, not
recovered original flux/CRC**. Revision is recorded in
[Turbo evidence](TURBO_IMPLEMENTATION_PLAN.md); no emulator was executed or
code imported for this increment.

Search visits the index once, not five physical index revolutions. Exact
CRC/INTRQ/DRQ pin timing, successful writes through duplicates, missing marks,
deleted writes/CRC metadata repair, format/write track, density/HD mechanics,
native protection/disk changes and physical HPS file epochs remain open.
Synthetic flag handling does not establish full copy-protection compatibility.
