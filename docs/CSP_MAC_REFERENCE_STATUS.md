# Common Source macOS reference qualification

October 16 local graphics extension: [native color/PRESET](BASIC_COLOR_REFERENCE_STATUS.md)
passes 22 CLI v4 base cases, nine cold repeats and four rejecting controls,
with 3,248,128 exact pixels / 192 independently expected CPU GRAM writes.
All eight digital colors and erasing preserve the adjacent shared-byte pixel.
No VM/CLI/RTL or hardware changes; these new cases qualify only the reference.

October 16 CLI v4 follow-up: [explicit writable copies and native SAVE/LOAD](BASIC_SAVE_LOAD_REFERENCE_STATUS.md)
pass 22 default/copy/path-rejection cases and nine native disk cases with
1,802,240 exact pixels. Both saved images cold-reopen; originals remain
unchanged. Earlier v3 outputs below retain their frozen source and identity.
Raw timestamp-dependent disk/RAM byte identity is not generalized. MiSTer
is with the user; no hardware SAVE/LOAD acceptance is claimed.

October 15: the existing sibling `../common_source_code` now has a synchronous
X1-family CLI. The user authorized this sibling work. Its base commit is
`c0b9bccb972af2157da823fe28903c9f6e4af958`; it already contained substantial
macOS/frontend/CPU work. This is a build of that local working tree, not a
pristine upstream revision or the older sparse Common Source reference fork.

The interface is documented in
[MAC_X1_CLI.md](../../common_source_code/MAC_X1_CLI.md). It provides bounded
frames, real VM key/reset actions, RGB PNGs, instruction/I/O CSVs and final
CPU-visible memory. An explicit ROM directory bypasses user ROM aliases and
saved configuration. Headless runs create no window or host audio device.
Disk inputs become protected private copies before mounting; caller media
are never mounted directly. PSG-only configuration is explicit.

The adapter also repairs a demonstrated macOS input defect: key events updated
the state array but never called the VM's key callbacks. Revision 3 forwards
both callbacks after updating the array. This matches the existing VM contract
and lets the X1 pseudo-controller receive keys. The existing Z80 observation
hook is reused unchanged. No X1 machine algorithm, FPGA RTL or board changes
were made in this follow-up. Shared frontend Quick Disk calls are now guarded
by the existing machine capability macro so non-Quick-Disk targets link.

## Build and reproducible synthetic gate

All five targets build: `x1`, `x1turbo`, `x1turboz`, `mz800`, `x1twin`.
MZ and Twin are compilation/link checks only; their native GUI behavior was
not run. Twin does not expose the X1 CLI route. Build output is isolated from
the user's existing emulator build:

```sh
cmake -S ../common_source_code \
  -B output_files/CSPMac_20261015T225930Z/build \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
cmake --build output_files/CSPMac_20261015T225930Z/build \
  --target x1 x1turbo x1turboz mz800 x1twin -j 4
python3 scripts/qualify_csp_x1.py \
  --build output_files/CSPMac_20261015T225930Z/build \
  --rtl verilator/obj_dir_headless/Vtop \
  --output output_files/NEW_CSP_QUALIFICATION
```

Existing compiler warnings remain in cassette initialization, FM arithmetic
and FILEIO constant switches. They were reviewed and preserved; this is not
a warning-free build or qualification of those unrelated device paths.

The accepted `qualification-v3/terminal.json` records **293 frozen source
inputs** and four frozen executables under
`output_files/CSPMac_20261015T225930Z/`. All recorded inputs/executables rehash
unchanged at completion. The generated ROMs contain original diagnostic code;
the gate needs no private ROMs/fonts/disks. Turbo/Z execute the same diagnostic
in their 32-KiB IPL containers; this is not native Turbo/Z compatibility.

| Case | Checks and result |
| --- | --- |
| CSP/RTL cold and repeat | `X1OK`, exact 1,024-byte RAM pattern, 22 ordered I/O records each |
| One-byte bad comparison | Same RAM pattern, `EE000000`, 20 exact I/O records; original success oracle rejects |
| Retained-asset warm reset | Two CPU boots, 44 exact I/O records, no IPL reupload; cold control rejects two-boot oracle |
| CSP cold repeat | CPU/I/O/frame CSVs, memory and PNG byte-identical |
| CSP real keyboard mailbox | CPU consumes F then R, stores `KEYS` and `FR`; no-key control rejects same oracle |
| Turbo and Turbo Z | Same synthetic `X1OK` and 22 ordered I/O records |
| Frontend errors | Six argument controls and zero-length D88 reject before emulation |
| Generated D88 open/close | Source unchanged; mounted private copy differs only at protection byte `1A` |

The keyboard fixture uses real Z80 commands `E4/00/E6` and polls PPI/mailbox
ports. Neither host memory pokes nor manufactured controller responses are
used. With the same generated image and F/R schedule, the preserved revision-2
executable leaves completion `00000000`; this independently demonstrates the
old adapter failure. This CSP gate does not establish equivalence to the FPGA
MR16 controller, native keyboard MCU or all modifier/repeat behavior.

CSP memory dumps are the CPU-visible map: byte zero is `F3` beneath the enabled
IPL overlay. RTL `.ram` is physical RAM: byte zero is `A5`. The comparison
retains and checks that distinction without normalizing either dump.

| Frozen executable | SHA-256 |
| --- | --- |
| CSP X1 revision 3 | `6a87e9bfbd1407b49a2df53237160faaede80357df31bc1b599df14a1815b04d` |
| CSP Turbo revision 3 | `bfe5aa34565eca7ea83d1f7cf083425a4fc834bcdefd234272e43e78eaeedf2a` |
| CSP Turbo Z revision 3 | `0ee0d71273346b6db38769548dfe6b6089ddb83af7f5da7ee6fbe4444e07ef55` |
| Existing ordinary RTL | `afcf97118840dd9373cc84bb4d89a5c6baf55192c4bcfcefc92628cf50412d77` |

## Timing evidence and limits

The reference X1 CPU is 4 MHz; its initial frame constants are 61.94 Hz,
258 lines and a 28,636,363-Hz video base. The display can subsequently change
event timing. These are emulator constants, not measured FPGA frequencies.
The ordinary RTL comparison uses SYS 32 MHz / VID 28.571428 MHz. Frame counts
and launch timestamps are not interchangeable between implementations.

The RAM-resident interval from completed `OUT 1E00` to `OUT 1D00` is exactly
**25.624750 ms** in both implementations. After restoring the IPL, the next
PSG address write takes **16.5 us** in CSP and **14.75 us** in RTL. CSP's
`MEMORY::fetch_op` adds one M1 wait while the IPL is mapped and none when it
is disabled. This is a concrete reference-policy difference, not proof of a
native hardware defect. The local MAME driver still lists wait-state penalties
as TODO. No RTL timing was changed to force agreement with a single emulator.
Exact native WAIT/PCG/scanline timing remains open.

## Native observations

Frozen revision-3 binaries execute CROSS Chase for 3,500 frames and Arcus
for 4,000 frames, with real Space events at recorded frame boundaries.
Native CPU/I/O traces cover frames 0–2 only; `frames.csv` covers the full run.
Actual PNGs show CROSS instructions followed by a populated playfield and a
later `You lost` screen. Arcus shows a logo and an `ARCUS`-labelled interface
with colored panels. This is progress beyond the earlier black-handler
observations, not accepted Arcus gameplay or an interrupt-policy correction.

Private inputs are inventoried in `native-report-v3.json`. Base IPL uses the
existing 4,095-byte local dump plus one explicit trailing `FF`; Turbo IPL is
the existing 32-KiB `212895703175…` image. ANK8/ANK16 are copied from the user's
existing macOS setup. **KANJI.ROM is a generated zero-filled 306,176-byte CSP
virtual store.** It is not a converted physical 256-KiB Z ROM and cannot
qualify native Kanji. No SUBROM/KBDROM is supplied, selecting the existing
pseudo-sub-CPU. Sound is PSG-only. These configurations differ from the
earlier combined RTL/other-emulator Arcus profiles, so their endpoints cannot
be used as a matched interrupt-policy experiment.

All original ROM/font/media and the supplied disposable input copies remain
unchanged. Each mounted disk exactly matches its expected payload with every
volume's protection header set. No private bytes are added to tracked sources.
Both native cold repeats pass: frame/CPU/I/O CSVs, memory, four PNGs per title
and protected mounted copies are byte-identical. A separate matched CROSS
pair has an identical frame 2600 before input. Real I at 2601 and J at 2607
move the release-specific player at `35C0` from idle **(22,14)** to **(21,13)**
by frame 2615, with active=1 and changed actual RGB. This is a bounded native
two-axis input check; it does not establish full game compatibility. Results
and exact commands are in `native-verify-v3.json` and per-process JSON files.
The movement cold repeat also matches both PNGs, memory, all three CSVs and
the protected disk copy byte-for-byte. [Actual screenshot gallery](../output_files/CSPMac_20261015T225930Z/screenshots.html)
includes the input/idle pair; it embeds the original PNGs without rewriting.

## Preserved development evidence

The output root retains initial touched-file bytes and status in `before/`
and `before.json`. `sibling-change-review.patch` shows only this turn's delta
against those bytes; `sibling-change-audit.json` confirms the user's existing
`src/vm/z80.cpp` is unchanged. Source notices and emulator credits remain.

The first rejected compile (hook arity and inherited Quick Disk calls) is
preserved. Revision-1 native evidence showed CSP's disk close persists header
byte `1A` even under the protection flag: only a disposable copy changed,
while the original stayed intact. Revision 2 introduced private protected
mount copies. Its synthetic gate and native images remain historical inputs
to the missing-key-callback diagnosis. They are not relabeled as revision-3
keyboard acceptance. The previous adapter's failed keyboard completion also
remains in `keyboard-old-adapter/` with its frozen binary in
`qualification-v2/bin/x1`.

The exact frame/key schedules, source/executable/input hashes and process logs
are in the ignored output JSON/CSV/log files. No new Quartus or MiSTer run was
needed for this host-reference work. FPGA timing closure, native fonts,
broader reference matrices and release licensing remain open.
