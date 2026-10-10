# DMA single-clock FPGA qualification revision

## October 10 current-source build gate

The latest guarded idle-host check permits a fresh Quartus 17.0.2 full flow
at 08:02:29 UTC, source `3c6242e771446dc11843cc8f4b7d4c58430b8f17`.
This is the separate `sharpx1_turbo_z_handoff` revision, **not** a rebuild or
new qualification of the DMA single-clock revision below. Frozen remote root:
`/home/alans/mister/SharpX1_Mister/output_files/quartus-linux-VlAoOluh/source`;
input-manifest SHA-256:
`5643c4693d104110957118b0b62b93ccb13fcd1b836d7434a61bec9a5a841219`.
Launcher PID 1836585/session 39592 and live synthesis/fitting were observed;
local log `/tmp/x1-quartus-3c6242e-handoff-local.XhSvnjgI`. The full flow now
terminates **exit 3** at 08:15:43 UTC: final STA rejects an unreviewed
whole-prefetch D/ASDATA profile. Fitting precedes this failure; the guard is
not loosened and there is no full-flow timing or hardware acceptance.
The terminal source/artifact audit completes: all 408 checkout inputs match
the frozen manifest; only generated QPF metadata/revision differ in the build
snapshot. Direct fitted-summary readback confirms 20,605 ALMs and 393 RAM
blocks. The unaccepted RBF SHA-256 is
`7f6a2009cbebe2caa34fec785bd39a19da0ba58e4f970f2ca80b9f0384d5a993`.
Partial STA setup/hold is -10.317/-2.636 ns, not a completed constrained audit.
Native fitted-profile discovery remains pending because other actual fitters
occupy the host; no guard is broadened or failed artifact deployed.
The C++ RTC/X3/Kanji profile
does not enable those devices in this board revision. Older outputs and
other cores/media are preserved; no MiSTer is loaded or reset.

## Earlier DMA source-bound qualification

October 8, 2026. `sharpx1_turbo_dma_single` is a separate opt-in FPGA revision,
inheriting `sharpx1_turbo_single` and enabling the existing shared-machine DMA,
completion IRQ and EOB-only restart IRQ. SYS/video use the checked-in actual
28,571,428 Hz PLL output and enables. Existing revisions remain DMA-disabled.
This is not full DMA, native Turbo firmware or Turbo Z support.

The wrapper passes the three capability parameters together under
`X1_TURBO_DMA_RESTART`. Invalid combinations without single-clock Turbo
foundation, or with X3 video, are rejected. No framework, clock constraints,
private assets, device engine, reset drain or interrupt bridge are changed.
The Linux and Apple-container build helpers accept this revision explicitly.

Both baseline and DMA-profile wrapper lint pass (Verilator 5.044); inherited
framework warnings remain, log `/tmp/x1-dma-board-wrapper-lint.log`. Shell
syntax checks pass. The native Quartus 17.0.2 full flow completed from frozen
commit `818b0de28e6a3331e3894fd0313369bad618e534`, in build-host directory
`output_files/quartus-linux-mlCE5xen/`. Input-manifest SHA-256 is
`0ea6cc295cca21472203cb1a08cf8e56ebd66c8d3fc4dfd3ec68700c7ba00d99`.
Build started 00:23:55 UTC October 9 and finished 00:31:08 UTC, exit zero,
123 warnings. Fit uses 20,947 ALMs (50%), 394 RAM blocks (71%), 3,143,582
memory bits. Its hierarchy report retains the DMA engine/service, IRQ bridge
and reset guard. Quartus warns that reset-guard `pending` powers
up high despite the RTL initializer (`18061`/`18010`). Do not suppress this or
claim cold-start equivalence from the RTL initializer; physical startup/reset
must be qualified. Inherited framework mode-array/CDC warnings remain too.

The shared-machine clock-matched simulator previously passed six memory and
twelve A/B FDC restart cases; see [exact scope](DMA_RESTART_MACHINE_STATUS.md).
That is not fitted or hardware evidence. The dedicated wrapper lint target
uses the same PLL interface stand-in as the other wrapper checks.

```sh
make -C verilator lint-wrapper-turbo-dma
ssh misterubuntu 'cd /home/alans/mister/SharpX1_Mister && QUARTUS_REVISION=sharpx1_turbo_dma_single bash scripts/build_quartus_linux.sh --check'
# Only after checking for competing Quartus jobs:
ssh misterubuntu 'cd /home/alans/mister/SharpX1_Mister && QUARTUS_REVISION=sharpx1_turbo_dma_single bash scripts/build_quartus_linux.sh --build'
```

The candidate is locally available at
[sharpx1_turbo_dma_single.rbf](../output_files/quartus-linux-mlCE5xen/sharpx1_turbo_dma_single.rbf),
SHA-256 `c1d83e6bc7218a5736d3c8cf4505cc3eb69d4c75c4ca958a5106f3c698bc8ca3`.
Supplemental all-corner STA and path reports each exit zero, with RBF hash
unchanged. Every local input matches the original 359-file manifest.
Post-build snapshot verification intentionally reports a mismatch for
`sharpx1.qpf`: Quartus added notices/date and the requested revision, preserving
the original revision. All other 358 inputs, including RTL/QSF/SDC/assets,
match. The failed checksum command remains recorded, not rewritten as a pass.
Generated QPF SHA-256 is
`c7c997185f5007e626d8fa70fa8ebac07a56b6f622f43194e262f37a2adac4a5`.

| All eight models, constrained checks | Worst slack (ns) |
|---|---:|
| Setup | 0.649 |
| Hold | 0.052 |
| Recovery | 4.153 |
| Removal | 0.434 |
| Minimum pulse width | 1.122 |

Zero unconstrained clocks, but 3 input ports / 7 input paths and 44 output
ports / 50 output paths remain unconstrained. No global clock cuts or timing
constraint changes were made. Inherited CDC/PLL/external-I/O and physical
qualification are not closed by these positive numbers. Original STA reports
are preserved before supplemental analysis. Local ignored reports/logs are
under `output_files/quartus-linux-mlCE5xen/`.

Actual CPU-driven hardware diagnostics need visible RGB success/failure markers: the existing
RAM-completion-only simulation fixtures do not prove hardware success from a
black screen. Protected disposable A/B media, restart/RETI, native boot/input,
owned/pending-SD reset and broader video/audio must be tested separately.
Do not contact or use reserved mister192. The recommended previously qualified
experimental RBF remains `quartus-linux-ZOMREvtv/sharpx1_turbo_single.rbf`.

## Visible CPU diagnostics

`test_dma_visible_ipl.py` now emits eighteen original, 32 KiB IPLs based on
the existing memory/A/B restart programs. A real CPU prologue programs PPI,
40-column CRTC and palette/VRAM. Pending/failure stays red; green is published
only after the original buffered-address/payload/guard/status and three-handler
assertions. GRAM power-up data cannot affect the uniform palette marker.
No machine debug writes, forced IRQ/grants or private assets are used.
The six default memory and twelve default FDC fixture byte streams are unchanged.

All eighteen pass the board-matched 28,571,428 Hz fast runner
`3058ff48dce8da0527ffc8afe7a21b47c584a0871c473f5b3c121ee673e67004`:
exact CPU completion/counts, unchanged generated disk images and 1,152,000
green pixels. The completion-only control stays red with zero pairs. The
earlier isolated first-destination-buffer bug control produces CPU `EE` after
eight pairs and all 64,000 red pixels; production RTL is untouched.
Outputs: ignored `output_files/dma-visible-818b0de/`; logs
`/tmp/x1-dma-visible-ipl.log`, `/tmp/x1-dma-visible-bug-negative.log`.
The separate SYS32/video28,571,428 Hz delay-aware visible matrix also completes
all eighteen cases, checking another 1,152,000 green pixels and the same CPU
counts/guards/status/unchanged disks. Its frozen executable SHA-256 is
`a8601ef7abbdee9871fd706a426a060e819966420d85f16e5bd48bbbc036d287`;
outputs `output_files/dma-visible-timing-818b0de/`, log
`/tmp/x1-dma-visible-ipl-timing.log`. This is independent-clock simulation,
not board-frequency delay-aware or physical acceptance.

```sh
make -C verilator test-machine-dma-restart-visible
```

`scripts/mister_dma_matrix.py` stages unique MGLs/configs, verifies RBF/IPL/disk
hashes, accepts only mister126/mister14 and defaults to no core loading.
`--execute` loads each test and records actual PNGs, requiring exact 320×200
green pixels and unchanged disposable disks. It refuses incomplete local
fixture qualification. The hardware matrix completed on released
mister126 in `/media/fat/_Computer/X1DMA_20261009T003346Z/`, with local evidence
under ignored `output_files/X1DMA_20261009T003346Z/`. All eighteen cases pass:
six memory and twelve A/B sector-boundary restart programs, all three bus modes
and both programmed transfer directions. Each captured PNG is exactly 320×200
green; all 1,152,000 captured pixels match. Disposable generated A/B image hashes
remain unchanged after every case. Log `/tmp/x1-dma-hardware-matrix.log`.

The actual CPU program verifies payload/buffer isolation/guards, DMA/FDC status,
live-counter readback and three genuine IM2 handlers followed by RETI before
publishing green. Hardware grant/pair counts and exact bus/IRQ pin timing were
not independently instrumented: those quantities remain simulation evidence.
These are cold MGL/core/IPL loads, not power-cycle/physical-keyboard, concurrent
interrupt, OSD-reset/owned-SD drain, writable-media or native Turbo acceptance.
The recommended general native-game test RBF remains the DMA-disabled artifact;
this is a separately qualified bounded DMA diagnostic candidate.

The same first memory IPL also runs on the earlier DMA-disabled RBF
`a0a03761…` as an independent hardware negative. Its captured 320×200 PNG is
exactly red, not success; generated disks stay unchanged. Evidence:
`output_files/X1DMA_20261009T004022Z/`, log
`/tmp/x1-dma-hardware-disabled.log`. This does not measure hardware pair counts
or identify every possible red-screen cause. `--disabled-control` runs only
that case and explicitly expects red; the normal matrix still requires green.

The native matrix helper now accepts explicit RBF path/hash and an optional
single-title selector; its earlier defaults and observation-only verdict stay
unchanged. A protected CROSS Chase trial on the DMA candidate completes:
native title at 30 seconds, then keyboard input reaches "Press key" and a
populated playfield. Actual PNGs were inspected, not inferred from filenames.
Evidence `output_files/X1Matrix_20261009T004105Z/`, log
`/tmp/x1-dma-native-cross-hardware.log`; copied disk/ROM hashes stay unchanged.
This is native boot/input progression, not exact movement, game music, long
compatibility, physical keyboard or native Turbo firmware acceptance. No five
commercial games are newly qualified by this single homebrew trial.
## October 10 fitted-profile follow-up

The subsequent source repairs remove the raw-reset bypass into palette
selection D inputs and add an opt-in two-stage HDMI measurement synchronizer.
Their local tests pass; see `HDMI_MEASUREMENT_CDC_STATUS.md`. These do not
alter the completed fifth-fit audit or qualify this DMA revision/new RBF.
The fresh source-bound `aa05dd2` handoff build's initial 10:30:32-UTC check
finds active DSPPC604 shell/fitter PIDs 2001830/2002631. No flow is launched
or competitor disturbed at that check; native follow-up remains pending.

The separately fitted `3c6242e` Z-handoff full flow's fifth physical HDMI
profile now passes native reporting-only discovery and independent original
artifact/source preservation auditing. The experimental guard recognizes
only that complete observed pattern; five scoped positives, 100 invalid
scope controls and 16,379 mixed-pattern rejections pass locally. See
[exact evidence and remaining gates](HDMI_MODE_STATUS.md#fifth-fitted-profile-discovery-and-guarded-scope-complete).
This does not qualify the DMA board or a new RBF: same-fit preservation,
full-flow constrained timing and hardware remain open. No MiSTer is loaded.

The new `--fit-3c6242e` auditor separately binds all eleven original/staged
hashes and the exact pin profile. Its synthetic 384-report/preservation and
36 provenance/actual-source rejecting checks pass alongside historical gates.
The native same-fit attempt at 09:33:45 UTC is not launched because another
project's actual synthesis is active; no native result comes from that attempt.

The subsequent idle-host same-fit run finishes at 10:06:42 UTC, zero errors/
warnings. Independent exact-source/artifact auditing passes 384 reports,
928 held-budget and 6,624 active/raw/mode rows unchanged; 848 inactive rows
remain excluded, not passed. Global setup **still fails at -9.659 ns**
(hold +0.010 ns). See the native fifth-profile evidence in
`HDMI_MODE_STATUS.md`. This does not qualify this DMA board, a fresh full
flow or any new RBF. Original artifacts are preserved; no MiSTer is loaded.
