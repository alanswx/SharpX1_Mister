# Native B boot and actual-board clock profile — October 8

The earlier B-only hardware MGL fallback was not enough to establish a
controller failure. `bios/ipl_x1_disassembly.txt` identifies F dispatch at
010F–0114 to 017A; 0196–019E accepts drive digits 0–3 and stores FF87;
02EA–02F1 adds motor/side bits and writes 0FFC. These instruction bytes were
also checked directly against `bios/ipl_x1.hex`, not only the disassembly.
The 4,095-byte decoded IPL hash remains
`db612eaee19dd2b46d70f8fb96a64b744f0fc3e8f494cc6d015aa1b03d653ec7`.

## Hardware result

On mister126, source-bound RBF
`a0a03761ef9db2bf2a9a14ec5c281175cb02a33d7eaa07978551fe1f393260d3`,
deployment `X1HW_20261008T204730Z_a0a03761`, MGL mounts CROSS Chase in **B
only**. No debug or substituted IPL/ROM/game data were used.

Short/shifted/late held F trials remained at cassette search. For the
successful cold trial: load `08_CROSS_Chase_driveB.mgl`, wait six host seconds,
then invoke the temporary keyboard with `--hold 5 33` (its two-second device
enumeration wait precedes F). Capture shows **Drive No? (0–3)**, SHA-256
`8a0c05373f9f0582e53a2470fa129da7bad64fb24eb95d971bc6cc4b61b551b9`.
Send `--hold 1 --gap 0.3 2 28` (digit 1, Enter), wait twelve seconds and
capture the native CROSS Chase title, SHA-256
`b9e2d2e38fb1e486fa130401aa3688284098a9625a5cda1b102070f2d2572ec5`.
These are observed host delays, not a measured guest-time specification.

Subsequent Space input advances to the starting score screen. Main's open
file list shows only this test D88, and its hash stays
`2fb70389737a7d54bff5a746b581343385ebde115cefb77ded32c473dcde97ec`.
The RBF hash and active setname also remain unchanged. This is protected
native drive-B boot/input evidence, not B writing, exact movement, reset
during B loading, all keyboard timing or full two-drive mechanics.
All actual PNGs/negative trials remain ignored under
`output_files/hardware126-20261008/` and on misterubuntu in the deployment
directory. No remote-control service was enabled. Reserved mister192 was not used.

## Matching simulation clock

`turbo-board-single` is a new isolated delay-aware profile:
`TURBO=1`, `SINGLE_CLOCK=1`, `MASTER_HZ=28571428`, default F1 DIP, no
DMA/IRQ/Ready/Kanji/X3. The C++ scheduler uses the same compile-time frequency.
`turbo-board-single-fast` is a separate non-timing diagnostic profile. Existing
baseline and nominal 28,636,364 Hz single defaults are unchanged. No board
RTL, PLL, firmware or constraints changed in this increment.

`make -C verilator test-board-single` exits zero on final source. It checks
duration/reset/fractional enables/determinism/FST/wrong-clock rejection,
six CPU F/Space/Enter/Caps/Shift polls, MR16 mailbox/PS2 and the eight generated
A/B data/head/register/protection/write trials. The fast clock/poll/mailbox
set also passes. Baseline scheduler, memory/overlay and key-script parser
regressions pass on an isolated freshly rebuilt default runner. CI now includes
the asset-free board-frequency target; hosted execution remains a separate gate.

## Native IPL probe and acceptance command

An initial six-second fast probe with F released at two seconds never enters
017A/019E, issues zero SD requests, and ends at cassette search. Main RAM's
FF85 is 31 (digit 1), FF87 is zero: the input stream ran, but this does not
prove a hardware keyboard defect or a B-read attempt. Two runs have identical
RAM/CPU/PPM and report bytes; read-only opcode-fetch observation preserves that
result. Evidence: `output_files/native-drive-b-20261008/`, logs
`/tmp/x1-native-drive-b-board-fast.log` and
`/tmp/x1-native-drive-b-board-observed.log`.

The extended held-F fixture enters 017A once, executes the real digit-store
instruction 019E once, leaves FF87=91 (physical B), and performs **763 host
reads, zero writes**. Its ten-second RGB is the CROSS Chase native title;
the protected original is unchanged. That exploratory fast runner is frozen
as SHA-256 `a1856502ff297238a9b0d79cfcc8ea2f294095bda08e03c1ae7c259d613522e8`.

The reusable private-asset check freezes runner/IPL/keys/media before execution,
preserves logs, opcode-fetch/CPU/RAM/RGB observations and input/output hashes,
and asserts native drive-1 selection, B-only host reads and the actual title
text. It never injects RAM, patches firmware or restores a snapshot:

```sh
make -C verilator turbo-board-single turbo-board-single-fast
cd verilator
python3 tests/test_native_drive_b.py ./obj_dir_v12_board_single/Vtop \
  ../references/software/private-downloads/cross-chase/Xchase_x1.d88 \
  --output ../output_files/NEW_NATIVE_B_TIMING
```

Both reusable native acceptance runs exited zero on October 8:

- Fast: `output_files/native-drive-b-qualified-fast-20261008/`, frozen runner
  SHA-256 `a1856502ff297238a9b0d79cfcc8ea2f294095bda08e03c1ae7c259d613522e8`.
- Delay-aware: `output_files/native-drive-b-qualified-timing-20261008/`, frozen
  runner SHA-256 `d8e3fa366249ca8075bad40ca8ef9921b808a59ba1d559c10e8e3c58b9d1ecaf`.

Both select physical B through native instructions and make 763 host reads,
zero writes, with unchanged protected inputs. Their actual RGB PPM files are
byte-identical, SHA-256
`13fc0d5c5703b0fd3592f45d9caece66aa5a1cb3d04ea62a84f75363bb8fe4ad`.
The script asserts native title text and captures RGB; this image equality is
a separately checked comparison, not a firmware-independent pixel oracle.
Each ignored evidence directory contains its frozen inputs, logs and provenance.
This is not commercial gameplay acceptance or a completion claim for storage,
keyboard, Turbo/Z, timing or any TODO work group.
