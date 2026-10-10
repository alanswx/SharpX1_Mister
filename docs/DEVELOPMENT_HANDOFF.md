# Sharp X1 development handoff

Updated October 10, 2026, 18:16 UTC. The active goal remains **unfinished**:
complete work groups 1–6 and documented Turbo Z. Component diagnostics,
historical game screenshots and a fitted RBF do not close that goal.

## Pushed checkpoints

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

Shared-machine Z Kanji integration is **uncommitted, not yet pixel-qualified**:
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
checks pass. Machine CPU/pixel/loader/reset tests are being prepared, not passed.

Existing jobs must be polled, **not restarted because observation times out**:

| Job | Handle / evidence | Last verified state |
|---|---|---|
| Native Rally-X, older frozen cassette runner | session `53472`; `/tmp/x1-native-rallyx-cassette-iFzAfm/run130-autoload/` | Live; actual frame says `IPL is loading RALLY-X`; not completed loading/gameplay |
| Ordinary delay-aware regression | session `53793`; `/tmp/x1-z-kanji-ordinary-regression.log` | Live; no terminal suite result yet |
| Ordinary fast/snapshot regression | session `26203`; `/tmp/x1-z-kanji-ordinary-fast.log` | Live; no terminal suite result yet |

The delay-aware regression began before the final Z-only blanking/eligibility
repair; its executable/source scope must be distinguished from final-current
acceptance. Do not edit a frozen collector's inputs while its job is live.
Regenerate final-current checks after integration stabilizes. The native tape
job uses an older immutable executable/assets and is unaffected by these edits.

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

At 18:16:22 UTC the build host still has foreign `quartus_fit` PID 2352689,
`SunSparcStation -c SunSparcStation20`. Do not interrupt it or launch competing
Quartus work. The isolated 9cc timing-study launcher remains deferred, not
completed. Primary remote checkout and fitted originals must remain preserved.

Latest hardware-tested DMA RBF and scope are in
[the hardware feature matrix](HARDWARE_DMA_FEATURE_MATRIX_STATUS.md) and
[build status](DMA_BOARD_BUILD_STATUS.md); no current cassette/Z Kanji RBF
exists. The tester's black-screen report remains unresolved on their exact
RBF/ROM/Main; use [IPL loading instructions](IPL_LOADING.md), not a claim that
the reported hardware failure has been fixed.

## Next work, preserving the full goal

1. Finish real CPU/WAIT and RGB qualification of both Kanji levels, including
   all physical CPU addresses, malformed uploads, delayed service and pending
   resets. Test unsupported/reverse/blink and width transitions. Then implement
   full external backing memory/cache/arbitration for FPGA—do not truncate the
   image to fit spare BRAM. Resolve native font conversion and broader modes.
2. Complete/audit the live Rally-X load, then native cold repeats and controls.
   Cassette still needs other format/rate policies, recording/APSS, coexistence
   and board loading; diagnostics alone do not close base completeness.
3. Finish current-source ordinary/snapshot regressions. On an idle build host,
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
