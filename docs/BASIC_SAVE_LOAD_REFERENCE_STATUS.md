# Native BASIC SAVE/LOAD in the local reference

October 16, 2026. Local macOS CSP base now passes native CZ-8FB01
SAVE/NEW/LOAD/LIST/RUN and independent cold disk reopens. **Hardware SAVE/LOAD
is unexecuted.** The user took MiSTer back; no hardware job was running and
this turn made no core load, reset, input or media-staging change. Do not
use the device again until the user makes it available.

## Explicit writable-copy CLI

The user-authorized sibling `common_source_code/src/mac/x1_cli.mm` exposes
revision 4 with `--disk-output-a NEW_COPY` / `--disk-output-b NEW_COPY`.
Each requires its corresponding disk input and exclusively creates a fresh
private copy. Protection bytes are cleared only in that copy; the VM mounts
that copy writable. Inputs are never mounted directly. Without these flags,
the existing protected-copy behavior remains.

Existing files/directories, symlinks, hardlinks, original paths, duplicate
options, shared drive output paths and missing companion inputs reject.
Relative outputs resolve under fresh `--out`; absolute outputs require an
existing parent. Exclusive creation also guards a race after preflight.
Reopening a saved image as a new disk input still mounts another private copy.
JSON reports per-drive permissions and its explicit copy policy. Historical
revision-3 gates retain their original identity.

Fresh X1/Turbo/Turbo Z/Twin/MZ700 builds complete; Twin/MZ are link checks.
`scripts/qualify_csp_disk_output.py` passes **22 cases**: five old/new default
model/CPU/keyboard/reset comparisons with byte-identical machine artifacts,
four disk-policy/mount cases and eight rejecting path controls. Originals
and existing targets stay unchanged. Only the CLI and its guide differ from
the preserved prior reference inputs; no VM/device behavior is changed.

## Native gate

`scripts/qualify_csp_basic_save.py` freezes source, checker/emitter, executable
and assets before nine cases. It types original BASIC commands through real
VM key events, with no RAM injection, snapshots or filesystem bypass:

```basic
10 PRINT "94217365"
SAVE "X1TST01"
NEW
LIST
LOAD "X1TST01"
LIST
RUN
```

Exact native-font pixels check the empty LIST after NEW and restored LIST/RUN.
Both independently saved images are reopened in fresh processes, mounted as
protected new copies and loaded/run again. All **nine cases**, **34 PNGs**
and **1,802,240 exact pixels** pass. Five controls reject unchanged completion:

- Protected SAVE returns exact native `Device I/O error`/Ok; its disk remains
  the protected original copy.
- Missing SAVE Enter leaves its writable copy byte-identical to the input.
- Omitted LOAD after NEW leaves the program empty.
- Omitted LOAD in a fresh process likewise runs no saved program.
- One saved string-literal byte changes `94217365` to `94217364` in a sector
  payload. Cold LOAD/LIST/RUN completes with that altered result and rejects
  the unchanged result oracle.

`verilator/tests/check_basic_save.py` fixes transcripts and the independent
40×2×16×256 D88 transport layout before execution. It checks unchanged
container/sector metadata, actual payload changes, the unique saved literal
and source preservation. Accepted SAVE changes three sector payloads; their
locations are observations, not a native filesystem specification or an
expected ledger derived from DUT data. The single-byte control changes no
transport metadata. Cold reopen verifies serialization beyond live buffers.

The long same-process transcript scrolls four text rows: banner at row0,
transcript at row9. Earlier SAVE/clear/LOAD frames and cold reopens retain
the ordinary banner at row4. No image scaling or OCR is used.

## Clock and repeat scope

The first frozen matrix passes all individual native/control checks but
rejects its final all-artifact repeat assertion. One saved directory byte
changes `40`→`41`, with its RAM buffer byte changing too. `PSUB::initialize`
samples host time and calendar replies return its running BCD clock. The
bytes are consistent with a directory minute. The failed run remains intact.

The subsequent matrix freezes a narrower repeat claim before new cases:
exact full PNGs and frame/clock logs, retaining raw disk/RAM hashes and
reporting their differences separately. Both independently saved images
must cold-reopen successfully. No raw-file/state normalization, clock override
or VM policy change is used. The accepted run happens to have identical raw
outputs too; this is not generalized across host clock boundaries. Calendar,
year and power-retention acceptance remain separate.

## Evidence

Root: `output_files/BASIC_SAVE_20261016T223258Z/`.

| Evidence | Result |
| --- | --- |
| `before/`, `before.json` | Prior qualified sources preserved |
| `build/` | Five targets build; `/tmp/x1-save-cli-{configure,build}.log` |
| `cli-qualification/` | 22 cases pass, session 95715 terminal zero |
| `explore/`, `controls-explore/` | Preserved observations, not acceptance |
| `native-qualification/` | Rejected all-artifact repeat assumption; no overwrite |
| `native-qualification-v2/` | Nine cases pass, session 80126 terminal zero |
| `independent-audit.json`, `auditor.py` | Independent local pixel/disk/control/source audit passes |

Audit SHA:
`b4abf198d24517bfa8476b1208ba2e31d7d4578cdc682f329336e7aa414000fa`.
Original D88 SHA remains
`ef47f5df772f45d97be43646d8f8010d33eca8846913babfd1106e89a361ee6a`.
The audit recomputes all 1,802,240 pixels, disk deltas, exact frame repeats,
all five controls, both cold source selections and the literal mutation.
All frozen source/executable hashes match.

This uses the existing CSP pseudo-sub-CPU/PSG-only base model and isolated
ROM/font assets. It does not qualify native MCU, FPGA writes, other BASIC
releases, arbitrary filesystems/densities, cassette SAVE, physical timing or
licensing. No RTL/Quartus changes were needed; existing RBF timing still
fails as recorded in [board status](DMA_BOARD_BUILD_STATUS.md).
