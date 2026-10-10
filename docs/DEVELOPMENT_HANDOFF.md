# Sharp X1 development handoff

Updated October 10, 2026, 19:23 UTC. **Paused at the user's request: write
handoff and stop.** The goal remains **unfinished**:
complete work groups 1–6 and documented Turbo Z. Component diagnostics,
historical game screenshots and a fitted RBF do not close that goal.

## Stop/resume boundary

Latest verified pushed checkpoint is `3a6f5b4` on `alanswx/master`: passive
cassette PCG/GRAM observations, generated CPU-written GRAM checks and status
updates. Main interrupted only its own two local jobs on request; both return
130. No remote Quartus job or MiSTer was stopped, loaded, reset or sent input.
Preserve interrupted evidence; do not label it a functional failure or a pass.

- Native plane probe: session `26507`, PID 3960, folder
  `/tmp/x1-native-rallyx-cassette-iFzAfm/run83-plane-control/`. Interrupted before
  terminal report/dumps; partial waveform log remains. It does **not** provide
  the PCG/GRAM comparison yet.
- Hardened suite: session `6320`, driver PID 7884, folder
  `x1-z-kanji-machine-suite-khu9v_gz`, log
  `/tmp/x1-z-kanji-hardened-suite-main.log`. Early collector/audit and seventeen
  auditor controls pass; interrupted during full collector build. Its owned
  child group 8219 was drained/terminated by the wrapper; source/artifact
  preservation reports true. Whole hardened-suite acceptance remains open.
- Earlier complete suite `t859nax6` remains terminal pass and untouched. Three
  supplemental Main negative-provenance audits pass; the reusable regression
  also passes all fifteen exact controls in `x1-z-kanji-negative-audit-regression-bp4dzjk1`,
  log `/tmp/x1-z-kanji-negative-audit-regression-main.log`.

Uncommitted drafts must be reviewed/staged selectively on resume:

- `rtl/x1_z_kanji_frontend.sv`, `verilator/tests/x1_z_kanji_frontend_tb.sv`
  and `test_z_kanji_frontend.py`: standalone external-font CPU/ordered-upload
  frontend, outside machine manifest. Frozen 32-MHz review smoke passes one
  full 262,144-byte upload/readback plus eleven focused cases, zero warnings,
  in `x1-z-kanji-frontend-review-h5qgfl2m`. **Latest fixture additions are
  unexecuted**, and checker still expects the older marker. Update the checker,
  freeze final inputs and run the full 32/100-MHz/reset/ownership/malformed/retry
  matrix with matched mutants. Do not claim current draft qualification from
  the older smoke. Backend remains unchanged `638861b6…`.
- `audit_z_kanji_machine_negative.py`,
  `test_z_kanji_machine_negative_audit.py`, `run_z_kanji_machine_suite.py`:
  qualified negative-provenance audit/regression plus hardened orchestration.
  Hardened wrapper hash `8f55095e…`; complete real rerun was interrupted.
  Reusable mock-driver port remains unfinished.
- `mame_rallyx_reference.lua` and `docs/RTC_CASSETTE_PLAN.md`: completed
  read-only MAME observations and a **proposal**, not a combined device build.
- Separate pending HDMI files: workflow/Makefile hunks, context auditor,
  inactive-data SDC, Tcl mock and `test_held_sdc_context_9cc.py`. Main's latest
  synthetic 9cc test passes 26 provenance, 22 byte/missing-file and 37
  scope/preservation negatives; no native timing acceptance follows.

On resume, first inspect `git status` and verify no previously owned process
remains. Explicitly stopped jobs may be rerun in **new** disposable directories;
never overwrite frozen evidence or restart a merely slow live process.

## Pushed checkpoints

- `35b4dbf`: strengthened independent Z machine auditor and external-font
  implementation plan; seventeen bad-evidence controls reject.
- `8305e17`: opt-in full-size Z Kanji shared-machine CPU/display integration,
  exhaustive physical CPU reads, bounded loader/reset/pixel diagnostics and
  reusable evidence-audit regression. **Not native fonts or FPGA storage.**
- `7dfcfeb`: standalone full-font DDR command backend; Main's independent
  32/100-MHz/max-base full-byte rerun and nine matched mutants/overflow checks
  pass without warnings. External loader/cache and board integration remain open.

- `5438892`: separate delay-aware cassette runner passes 25 generated-asset
  checks: exact 40/80-column pixels, actual PS/2 Ctrl+C/plain-C behavior and
  retained tape cursor/partial-slot phase over repeated warm resets.
- `e7c4f6a`: independent cassette evidence/pixel audit and primary-document
  Kanji source/level/half/row controls. Four disposable evidence mutations
  reject at their matched assertions.
- `58ad1de`: full 256-KiB Z simulation-reference store and highest-cell
  selector, independently rerun. All physical bytes and loader/reset/clock
  gates pass with three rejecting mutants. **Not machine or FPGA acceptance.**

Remote: `alanswx/master`. Preserve existing worktree changes; stage selectively.
Private ROMs/media, dumps, snapshots and native screenshots remain ignored.

## Worktree and live qualification

Shared-machine Z Kanji integration is **opt-in and synthetically qualified**:
`rtl/sharpx1.v`, `rtl/x1_pcg_access.v`, `rtl/legacy/x1_vid.v`,
`rtl/machine.qip`, and new machine fixtures. `TURBO_Z_KANJI` is default-off,
requires the Turbo/X3/Kanji/render combination and excludes DMA. Ordinary
boards/runners do not enable it. CPU requests freeze an 18-bit address and
retain the real WAIT/response protocol. Display requests capture character,
Kanji controls, attributes and raw raster together; response validity is checked
at glyph load. The initial supported Kanji raster is high-resolution 25-line,
16-raster normal-size text. Unsupported/invalid Kanji suppresses text ink after
reverse/blink; that does not force underlying graphics to black. Other row,
double-width ANK/PCG, underline and native ASIC policies remain unqualified.

Latest isolated generation audit against `e7c4f6a` passes: **two ordinary
base/Turbo models**, eight core files total; five headers and three serializers
per model compare byte-identical, with unchanged 60 warnings each. This is
not eight different machine profiles or runtime snapshot acceptance. Evidence:
`/tmp/x1-ordinary-state-e7c4f6a-latest.0gLaZm/`, report SHA-256
`5e32e886bb0b9e6d1faf8383ca943f187f2e5a47f1b987a94f2f3b88b7b37b27`.
Current enabled-Z lint, ordinary headless build/smoke and adjacent CG/WAIT/CPU
checks pass. The early frozen `zgfae1jf` probe/render80 collector completes;
Main's independent read-only audit confirms 32 actual CPU reads, three frames,
768,000 exact RGB pixels and frame periods with unchanged evidence. This is
synthetic high-resolution normal-size Kanji, not native font or FPGA acceptance.
The larger `hhofb8uy` collector now finishes zero. Main's strengthened audit
confirms all fifteen cases, 262,688 CPU reads (including every physical font
byte), fifteen frames and 3,072,000 exact pixels with frame-period checks.
Frozen/current sources and evidence remain unchanged. Three separate disabled,
half-major and missing-display-response controls reject at matched assertions.
The reusable auditor regression also passes two baselines and seventeen
evidence-mutation/optimized-execution controls; Main rerun evidence is
`x1-z-kanji-audit-regression-d9pqixzx`, log
`/tmp/x1-z-kanji-audit-regression-main.log`. These are synthetic diagnostics,
not native fonts, FPGA backing storage or hardware acceptance.

Existing jobs must be polled, **not restarted because observation times out**:

| Job | Handle / evidence | Last verified state |
|---|---|---|
| Native Rally-X, older frozen cassette runner | session `53472`; `/tmp/x1-native-rallyx-cassette-iFzAfm/run130-autoload/` | Terminal exit zero, 130 physical seconds, 524,717 samples, zero underflow; partial score/map/car display, no gameplay acceptance |
| Native Rally-X exploratory keyboard / no-input control | sessions `21805` / `56833`; `run83-input` / `run83-control` under same native folder | Both terminal exit zero; input reaches PUSH START BUTTON/CREDIT 02, no-input remains partial; not gameplay or release-correct controls |
| Native Rally-X passive plane observation | session `26507`; `run83-plane-control` under same native folder | User-stopped, exit 130; no terminal dumps/report, not a result |
| Ordinary delay-aware regression | session `53793`; `/tmp/x1-z-kanji-ordinary-regression.log` | Terminal exit zero; 164 PASS lines; pre-final Z-only repair source scope below |
| Ordinary fast/snapshot regression | session `26203`; `/tmp/x1-z-kanji-ordinary-fast.log` | Terminal exit zero; 144 PASS lines |
| Final-current ordinary delay-aware repeat | session `67295`; `/tmp/x1-z-kanji-final-current-regression.log` | Terminal exit zero, 164 PASS reports after final Z-only repairs |
| Exhaustive shared-machine Z Kanji | `hhofb8uy`; Main audit log `/tmp/x1-z-kanji-full-main-audit.log` | Terminal collector and independent audit pass, not hardware/native acceptance |
| Reproducible complete Kanji suite | session `64002`; folder `x1-z-kanji-machine-suite-t859nax6`, log `/tmp/x1-z-kanji-complete-suite-main.log` | Terminal exit zero: early/full collectors and independent audits, seventeen auditor controls and three machine negatives; supplemental Main negative-provenance audits also pass |

The delay-aware regression began before the final Z-only blanking/eligibility
repair; its executable/source scope must be distinguished from final-current
acceptance. Do not edit a frozen collector's inputs while its job is live.
Regenerate final-current checks after integration stabilizes. The native tape
job uses an older immutable executable/assets and is unaffected by these edits.

Full-font external backing work is now described in
`TURBO_Z_EXTERNAL_FONT_PLAN.md`. Original standalone DDR backend and tests are
pushed as `7dfcfeb`, outside the machine manifest. Full-font 32/100-MHz/max-base
checks, nine rejecting mutants and overflow checks pass. The ordered-upload/
CPU frontend API and drain contract are reviewed; implementation is now assigned
as a separate standalone component. No display cache, native write-
visibility policy or board integration is yet qualified.

The local MAME Rally-X no-input reference completes zero with protected media
and unchanged inputs. Actual 83/130-second PNGs have a changing left playfield,
unlike RTL's partial frame. It observes repeated PLAY and STOP/REWIND; different
PB0/rewind policies are not a proven cause. Evidence is
`output_files/mame-rallyx-reference-siRvI2/`. Read-only memory follow-up
`output_files/mame-rallyx-memory-mStnwi/` also completes zero. A third reference,
`output_files/mame-rallyx-gram-4US3JD/`, adds direct-pointer mapped-bank-0 GRAM
captures at 83/130 seconds, with no I/O side effects or bank changes.
All previous evidence is preserved. Never compare RTL's bus `cpu_address` to
MAME's instruction PC. Main confirms matching code at 1540h..1576h but differing
random-generator seed words: RTL 0000h versus MAME FC1Ah/70F7h in the memory
follow-up. Native initialization reads minute/second from EF; the cassette-only
inherited clock does not advance. This is a concrete lead, **not** a proven
gameplay fix. The combined RTC/cassette and explicit clock-initialization
proposal is in `RTC_CASSETTE_PLAN.md`; implementation remains unapproved/unmade.

Uncommitted passive cassette-runner PCG/GRAM dump extension now passes all
25 diagnostics in `x1-cassette-runner-2rjkcn2t` (session `94866`). Four video
cases verify eighteen actual CPU-written GRAM sentinels per case and physical
plane sizes; PCG payloads are not programmed/qualified by these fixtures.
Main separately verifies all 72 sentinels, rejects 28 in-memory width/boundary/
plane-swap controls and preserves all 431 original files and bound sources.
The same sixty HDL warnings remain after location normalization; sixty-six
warning-containing log lines include explanation links, with no C++ warnings.
This extension changes no shared machine RTL or private native assets.

The new `make -C verilator test-z-kanji-components` entry completes zero:
both clock-rate component scans and three matched mutants remain intact.
CI now schedules this asset-free entry; a hosted result is not inferred.

Uncommitted HDMI work remains separate: exact seventh whole-prefetch SDC bank,
strict 9cc provenance/report auditor, mock and CI time-budget changes. Original
full mock completes seven profiles/140 faults/1,048,569 mixed rejections.
Native same-fit preservation and a fresh accepted full flow remain pending.
The faster disposable pin-cache candidate is not the selected `b80a0946…`
candidate; never silently substitute its hash or reuse the original binding.

## Hardware and build-host ownership

Use **mister126 (10.0.2.126)** through `misterubuntu`; existing SSH keys work.
Latest read-only core identity is `SharpX1` / `X1M_20261009T005633Z_01`.
No load/reset/input was sent during this follow-up. Coordinate operator
availability before changing it. Leave `mister192` untouched; `mister14` last
had another core and has not been used in this follow-up.

At the 19:15 UTC read-only check the build host still has foreign `MacPPC7300`
`quartus_sh` PID 2459977 and STA PID 2477096, plus `SunSparcStation20` STA
PID 2476895. Do not interrupt them or launch competing
Quartus work. The isolated 9cc timing-study launcher remains deferred, not
completed. Primary remote checkout and fitted originals must remain preserved.

The current local TAP parser rerun completes zero with 356 synthetic checks
(`/tmp/x1-z-kanji-continuation-tap-parser.log`); transport/native loading is
not inferred from parser success.

Latest hardware-tested DMA RBF and scope are in
[the hardware feature matrix](HARDWARE_DMA_FEATURE_MATRIX_STATUS.md) and
[build status](DMA_BOARD_BUILD_STATUS.md); no current cassette/Z Kanji RBF
exists. The tester's black-screen report remains unresolved on their exact
RBF/ROM/Main; use [IPL loading instructions](IPL_LOADING.md), not a claim that
the reported hardware failure has been fixed.

## Next work, preserving the full goal

1. Extend the completed synthetic CPU/WAIT/RGB qualification beyond its bounded
   high-resolution normal-size contract. Implement the ordered external loader/
   CPU frontend, then full backing memory/cache/arbitration for FPGA—do not truncate the
   image to fit spare BRAM. Resolve native font conversion and broader modes.
2. Audit the new Rally-X plane observation and MAME memory comparison, then
   native cold repeats and release-correct controls.
   Cassette still needs other format/rate policies, recording/APSS, coexistence
   and board loading; diagnostics alone do not close base completeness.
3. Preserve the completed current ordinary/snapshot regressions. On an idle build host,
   run exact 9cc same-fit preservation, then source-bound full-flow timing/CDC
   qualification. Negative global setup is not timing closure.
4. Complete remaining SIO, DMA, HD/FDC and multi-device/reset/native gates;
   establish Arcus and Bastard Special gameplay rather than handler activity
   on black. Requalify the commercial-game matrix for each exact profile/RBF.
5. Finish Turbo Z native model/BIOS, palette/multi-mode/text ASIC behavior,
   FM/native sound, second-level font/hardware storage, mouse/serial/RTC and
   capture/effects pipeline. Run native software and physical acceptance.

Full requirements and open checkboxes remain in
[SHARP_X1_TODO.md](SHARP_X1_TODO.md), [Turbo Z roadmap](TURBO_Z_PLAN.md),
[Kanji status](TURBO_Z_KANJI_STORAGE_STATUS.md) and
[cassette status](CASSETTE_STATUS.md). Keep historical evidence scoped to its
actual source; do not convert v17 snapshots or relabel incomplete runs as passes.
