# Matched HuBASIC IPL/font and reference input observations

October 16 implementation follow-up: [the separately gated partial-text path](BASE_TEXT_COMPATIBILITY_STATUS.md)
now fixes the base blank display without an IPL shim or assumed native RAM
values. New source-bound RBF 4c0a95f2 cold-repeats unmodified base/Turbo
arithmetic and passes base Main R/T reset/LIST/RUN with independently audited
pixels. Timing and broader mode/native-font/BASIC acceptance remain open.
The earlier fd9a0850 observations below retain their original source and scope.

October 15 local / October 16 UTC. This follow-up separates the IPL and
ANK16 upload changes in the previous native hardware attempt. All eight
hardware cases finish and the independent observation audit passes. No RTL,
firmware or emulator VM changes.

October 16 follow-up: [CPU/metadata and matched generated controls](BASIC_METADATA_STARTUP_STATUS.md)
now isolate the blank display to missing Kanji-plane initialization under
the strict external-font packet contract. Initialization shims pass arithmetic
twice while matched skips remain black. Unmodified base/profile policy is
still open; the earlier unmodified observations below remain unchanged.

## Hardware collection (complete)

`scripts/mister_basic_ipl_matrix.py` freezes the collector, helpers, font
oracle and assets before eight fresh cold cases. Base 4-KiB versus native
Turbo 32-KiB IPL and ANK16 upload omitted versus present are varied in all
four combinations, twice. Each gets its own RBF/config/MGL/protected disk
copy. All use the same complete synthetic physical font and `fd9a0850` RBF;
the earlier [hardware report](BASIC_HARDWARE_RESET_STATUS.md) records its
identity, clocks, failing physical timing and native-media limitations.

The sequence is identical: 25-second cold wait, fresh mrext PNG, F, 20-second
wait, fresh PNG, Backspace/`PRINT 6*7`, no-Enter PNG, Enter, arithmetic PNG.
The same public ANK8 exact banner/transcript oracle requires `PRINT 6*7`,
separate ` 42`, and `Ok` on complete 80-cell rows. Process or transport errors
fail collection; a missing native result is recorded as an observation.
Missing Enter must reject that unchanged completion oracle.

Output: `output_files/BASIC_IPL_20261016T030331Z/manifest.json`.
Log: `/tmp/x1-basic-ipl-matrix.log`; session `89747` is terminal zero.

| IPL upload | ANK16 upload | Cold / repeat observation |
| --- | --- | --- |
| Base, 4 KiB | Omitted | Black at all four capture phases / same |
| Native Turbo, 32 KiB | Omitted | Exact arithmetic completion / same |
| Base, 4 KiB | Present | Black at all four capture phases / same |
| Native Turbo, 32 KiB | Present | Exact arithmetic completion / same |

The four Turbo positives match **81,920 exact banner/transcript pixels**;
their missing-Enter frames reject the unchanged completion oracle and retain
the exact banner. All sixteen base frames are entirely black. These are
observations, not successful native base tests. Independent audit checks
all **32 fresh raw PNGs**, all input/compiler/frozen source hashes, upload
order, local configs/protected disk copies and twelve key actions per case.
Audit SHA `880a3318e1af6311f1dddcad74734c2534afbcb515a7568448554afdefa4790e`.
The terminal collector also checks remote staged payloads, installed Main,
retained full-font DDR and all 428 compiler inputs. Runtime CFG writes are
excluded from the final immutable-payload check.

The source bounds interpretation: `rtl/sharpx1.v` allocates 32 KiB of IPL
storage when Turbo is enabled and selects it throughout `0000–7FFF`.
Uploading only the base 4 KiB does not specify the upper bytes. ANK16 omitted
also means no upload, not proven zero font RAM. A black screenshot does not
establish CPU state, disk failure or a native base-model compatibility defect.
A separate control explicitly appends FF to the unchanged base IPL
through `7FFF`; session `84113` completes two cold observations in
`ff-tail-followup/`, log `/tmp/x1-basic-ff-tail.log`. The derived observer and
exact transformation/asset hashes are frozen in `tail-inputs/`. Local MAME initializes its base IPL
region to FF; CSP's base model instead mirrors its 4-KiB ROM. These are
different reference policies, not a resolved hardware contract.

Both explicit FF-tail cases remain entirely black at all four capture
phases. Independent audit session `18454` passes all eight raw PNG hashes,
unchanged 4-KiB prefix, exact 28-KiB FF tail, source transformation, frozen
sources, all 428 compiler inputs, remote payloads/Main and full-font DDR.
Its SHA is `4badd386a76b6b3e13ff2997ff620a9c928e84c9bf0e9e763567e42e05e5b332`.
There are **zero accepted native completion pixels** in these two cases.
Explicit FF filling does not resolve this bounded blank observation; the
cause and native base-model acceptance remain open. No RTL change is made
from these screenshots alone.

[Actual raw PNG gallery](../output_files/BASIC_IPL_20261016T030331Z/screenshots.html).
The MiSTer is cold-restored to the already observed Turbo+ANK16 MGL.
Session `78909` completes with a fresh raw PNG matching **10,240 exact
banner/Ok pixels** in `restored-turbo/`. Current ownership, payloads/Main,
all compiler inputs and font DDR recheck unchanged. This is a cold reload,
not an additional warm-reset test. All jobs are terminal.

## CSP Turbo input cadence (complete)

The frozen revision-3 CSP Turbo executable is unchanged:
`bfe5aa34565eca7ea83d1f7cf083425a4fc834bcdefd234272e43e78eaeedf2a`.
It uses native Turbo IPL, the existing user ANK8/ANK16, synthetic zero
306,176-byte virtual Kanji, pseudo-controller and PSG-only sound. Its native
640x400 low-scan output doubles each source line. The same identified
CZ-8FB01 D88 is mounted only as a protected private copy. This is distinct
from the already accepted [base CSP command/reset gate](BASIC_REFERENCE_RESET_STATUS.md).

The original `csp-turbo-reference/` cold/repeat observer completes 1,500
frames, but fails the unchanged arithmetic oracle in both identical runs.
Actual final PNGs show `print 6*`, `Missing operand`, then `Ok`; the scheduled
`7` is missing. This native interpreter error is preserved, not relabeled a
font mismatch or a passing failure control.

`scripts/observe_csp_basic_cadence.py` then freezes a separate four-case
collection in `csp-cadence/`, retaining the failed schedule:

| Host press/release frames | Cases | Native completion |
| --- | --- | --- |
| 4 / 4 | Traced reproduction | Missing `7`; unchanged oracle rejects |
| 8 / 8 | Cold and repeat | `print 6*7`, ` 42`, `Ok`; exact pixels pass |
| 8 / 8 | No Enter | Same completion oracle rejects |

All type sequences start at frame 800; each process completes 1,500 frames.
I/O trace covers frames 790–1000. The fast run's actual `1900` reads include
`2A` (`*`) and `0D` (Enter), but no `37` (`7`). Both slower positives read
`37` at frame 928 and Enter at 944. The missing-Enter case reads `37` and no
Enter. This demonstrates cadence sensitivity in this configuration; it does
not identify a physical keyboard timing limit or justify altering RTL/VM.
Source review finds an eight-entry PSUB key FIFO whose generic write drops
new data when full; presses and releases both enqueue. Guest mailbox reads
are delayed during the command in the fast trace. This is a possible queue
explanation, not an executed internal overflow witness.

The two slower runs match every artifact: I/O/frame CSVs, memory, both actual
PNGs and protected D88 copy. **81,920 exact positive pixels** pass the
unchanged CSP release banner and three-row arithmetic oracle. Each original
disk payload remains unchanged; mounted copies differ only by the expected
protection byte `1A=10`. All original and frozen input hashes recheck,
including the previously qualified 293-source graph. Independent audit SHA:
`1552b7564706e365f303d27ed1fd72b34d3efde9cd6ae71b6e77a3ed79d46229`.

SAVE/LOAD, graphics, other releases/models, native controller/font behavior,
active-device reset and physical timing remain open. No new Quartus build
is needed for this observer-only change; existing timing failures persist.
