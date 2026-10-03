# Isolated Quartus 17 build sidecar

Use the already-installed Apple container runtime from
`/Users/alans/dev2/apple-containers-example`. No installer, image build,
license acceptance, service startup, or source download is performed here.
Read that repository's README and `scripts/quartus-core-apple.sh` before
changing this flow.

From the Sharp X1 repository root:

```sh
bash scripts/build_quartus.sh
```

The optional single-clock experiment selects a separate revision:

```sh
QUARTUS_REVISION=sharpx1_single bash scripts/build_quartus.sh
```

`sharpx1_single.qsf` sources the unchanged baseline QSF and adds only
`VERILOG_MACRO X1_SINGLE_CLOCK=1`. The root project still defaults to `sharpx1`;
the sidecar explicitly passes the requested revision and records it in the
manifest. Outputs use that revision's name. Snapshot inputs contain both
revision files so the two runs can be compared against identical source hashes.
The board experiment uses the existing 28.571428 MHz video PLL output as the
machine clock, rather than claiming the intended 28.636 MHz has been corrected.

The script creates a unique ignored `output_files/quartus-XXXXXXXX/source/`
snapshot, including tracked and untracked board/machine sources, firmware,
IP and chip snapshots. Paths and notices are preserved. Private downloaded
game disks and simulator outputs are excluded. Source hashes are checked
before and after copying and against the snapshot; an overlapping edit
during copying stops the build. Later edits cannot alter this build's inputs.

The main `sharpx1` project/revision is used, never the historical Q13 project.
The supplied builder runs the project's build-ID pre-flow hook, then:

```text
quartus_map --parallel=1 sharpx1 -c sharpx1
quartus_fit --parallel=8 sharpx1 -c sharpx1
quartus_asm sharpx1 -c sharpx1
quartus_sta sharpx1 -c sharpx1
```

Single-threaded synthesis avoids the documented Rosetta helper deadlock.
Eight fitter threads are pinned because thread count affects placement.
`QUARTUS_CPUS` and `QUARTUS_MEMORY` retain the builder defaults (all host
CPUs and 16 GiB). Override `QUARTUS_BUILDER_ROOT` or `QUARTUS_CACHE_DIR`
only to select another existing, approved installation.

Each build directory retains `input-files.txt`, per-file `input.sha256`,
the original working-tree status, a build manifest and complete `build.log`.
Quartus reports and any RBF remain under its source snapshot's
`output_files/`. The manifest records the source commit plus dirty-tree
hash identity, builder-script hash, UTC timestamps, exit status, generated
build-ID hash and RBF hash when present. A dirty-tree build is development
evidence, not a clean reproducible release. Generated build dates also
affect output identity. Preserve artifacts locally; inherited source/firmware
license questions remain unresolved.
Later script revisions also retain `runtime-image.json` and its hash, host
CPU/memory configuration and sidecar-script identity in the manifest. The
installed image inspected for the initial build has index digest
`sha256:6edc7bc0edee8c0a3f332ced040776c459287e856ee3ba85992512b7b313a370`.

## Hardware access

Read-only SSH to `root@mister.local` succeeded on 2026-10-03. The existing
system reports Linux `5.15.1-MiSTer`, with `/media/fat/_Computer` available.
No core was copied, overwritten, loaded, or rebooted by the sidecar. Hardware
boot/video/storage validation must be reported separately from compilation.
The inspected machine was already running
`SharpMZ-std_20261003.rbf` with the SharpMZ `K08.mgl` hardware test. Coordinate
with the parent before interrupting this existing session. The local
`/media/fat/Scripts/remote.sh` is actually a packed ELF executable despite
its suffix, not a shell script; do not execute it blindly to discover commands.

## Initial build

The initial isolated build is in `output_files/quartus-2anzd0um/`.
It uses Quartus Prime Lite **17.0.0 Build 595**, not the project's historical
17.0.2 tool label. Input manifest SHA-256:
`16fcd53b299df82792ef99830dfc227dd9b774a4f93ad9d75b81d11a8085af6f`.
The build-ID hook completed. Analysis and synthesis passed in **2 min 19 s**
with **0 errors, 79 warnings**, using 31,632 registers, 2,071,224 block-memory
bits, 32 DSP blocks and 3 PLLs (pre-fit counts, not final utilization).
Fitter, assembler and TimeQuest all completed with zero errors: **6 min 49 s**,
**15 s**, and **10 s**, respectively. The full tool flow took about 9 min 42 s.
Final utilization: **20,258 / 41,910 ALMs (48%)**, 31,494 registers,
**2,071,224 / 5,662,720 memory bits (37%)**, 263 RAM blocks (48%),
32 DSP blocks (29%) and 3 PLLs (50%).

**Timing does not close.** Setup slack is **−3.391 ns** on the video-clock
domain and **−2.348 ns** on the system-clock domain. Recovery slack is
**−2.575 ns** on the video domain. Worst hold slack is positive, **0.249 ns**.
TimeQuest also reports one unconstrained clock, 3 unconstrained input ports
and 44 unconstrained output ports; tool exit success is not timing signoff.

Generated `source/output_files/sharpx1.rbf` SHA-256:
`6e8a0fe331d05763b360afb492807847ee6bda1c4b59a75a2b24ef4ea99113eb`.
It has not been loaded on hardware. The initial sidecar exited after Quartus
completed because the script was edited while Bash was still executing it,
shifting the resumed source line. Stage reports/RBF are intact; the manifest
explicitly distinguishes the sidecar failure from successful tool stages.
The script now parses its complete main function before execution, avoiding
this particular mid-build edit hazard.
This initial snapshot predates the parent's final disk-controller changes;
it cannot establish their synthesis compatibility.

Warnings requiring follow-up include the unrecognized `async_reg` attributes
on both PCG synchronizer chains, the implicit `text_cs` net in `x1_adec.v`,
dual-clock RAM same-address collision behavior, and unconnected PLL reset/lock
signals. These are not compile errors, but synthesis success does not resolve
the PCG CDC placement/bundled-data and reset-release review. No broad false-path
exceptions or unrelated framework fixes were added to make the build pass.

Supplemental `sidecar_setup.rpt`, `sidecar_recovery.rpt` and `sidecar_pcg.rpt`
under the initial snapshot's output directory identify important failures:

- System-domain HPS `status[0]` / `ioctl_download` reset signals feed video-domain
  PCG RAM write enables (worst setup −3.391 ns) and renderer `ppres` / `pris`
  asynchronous-reset recovery (−2.575 ns).
- Bundled PCG `plane` bits feed video-domain write enables and `response`
  selection (−3.385 ns and −2.259 ns). TimeQuest applies a 1.250 ns clock-edge
  relationship; the handshake intentionally waits several destination edges,
  but that bundled-data contract has not yet been encoded in constraints.
- Renderer `pris[3]` clocks the CRTC directly and is the unconstrained clock.

Proposed follow-up, **not applied by this sidecar**: review domain-local
reset-release synchronization; use Intel-recognized synchronizer assignments;
constrain the precise bundled-data paths with a justified physical max-delay
budget and inspect placement; constrain the CRTC generated clock or refactor
to a verified clock enable. Do not blanket-disable all system/video timing or
claim these violations are all harmless CDC artifacts. Functional tests and
a fresh fit/timing report are required after any such changes.

## Frozen disk and optional-clock checkpoints

The first frozen disk snapshot, `output_files/quartus-QZ2jOSke/`, failed
analysis/synthesis in 17 seconds with three errors: `x1_disk_control.v` used a
SystemVerilog sized cast while its manifest declared `VERILOG_FILE`. It produced
no RBF. Original input manifest SHA-256:
`7490430b4cfc1a933014db32e88d8eeb56a1403ad05b59614ae349ed06457e0d`.

The parent authorized and applied a behavior-preserving syntax fix: a
26-bit `MOTOR_HOLD_TICKS` localparam instead of the cast. The corrected disk
baseline in `output_files/quartus-disk-fixed-BRaJxFnN/` reconstructs the original
input set and applies only that fix. Its per-file manifest differs in exactly
`rtl/x1_disk_control.v`; the QSF tool-version rewrite left by the failed
Quartus project-open was restored byte-exactly from the original root QSF hash.
Corrected input manifest SHA-256:
`2b77ec40cda839c07dde14fa92fef187aae7591eecdf4b53ab8e2dbbaeb6e8be`.

The optional single-clock frozen working-tree snapshot is
`output_files/quartus-Rc7U8tGG/`, revision `sharpx1_single`, source commit
`f9a8313bfd0b948dab06e0a95b38b7826c3291b8` plus the recorded uncommitted RTL.
Input manifest SHA-256:
`db32dd559844b1f873649a322a783c738d1715cd3685323701e746f7dfe3b8a6`.
Unlike the reconstructed disk baseline, this includes optional fractional
clock-enable/CRTC-enable RTL and the single-clock QSF. The main revision remains
the default. These two snapshots are a development comparison, not a controlled
same-input synthesis run with only one macro changed.

### Single-clock completed result

`quartus-Rc7U8tGG` completed with sidecar exit status **0**. Map/fit/asm/STA
took **3:48 / 11:48 / 0:16 / 0:11**; wall time including snapshot/runtime
startup was **16:34**, with the disk-baseline build concurrently active.
RBF SHA-256:
`cf0b0e0e754bed2e6a7d9233f25d8163f714b6277111fe2b8c504eba411095d7`.
Final utilization: **19,927 ALMs (48%)**, 31,566 registers, 2,071,408 memory
bits (37%), 263 RAM blocks, 32 DSP blocks and 3 PLLs.

Reported constrained-path timing passes: worst setup **+0.401 ns**, hold
**+0.173 ns**, recovery **+3.698 ns**, removal **+0.967 ns**, minimum pulse
width **+1.122 ns**. Machine-domain setup/hold/recovery are
**+10.397 / +0.245 / +12.244 ns**, respectively. There are **zero
unconstrained clocks**, removing the legacy CRTC fabric-clock gap, but **3
input ports / 44 output ports** remain unconstrained (7 input and 50 output
paths). This is not complete I/O timing or hardware signoff. No new false-path
exceptions were added. The project's inherited single-corner timing setting
also remains unchanged.

Supplemental read-only reports from `scripts/quartus_timing_paths.tcl` show
PCG register-path setup **+26.820 ns** and MR16 CPU endpoint setup
**+15.449 ns** at the reported slow 1100 mV / 100 C corner. These establish
timing margin for the selected paths, not cycle-accurate firmware behavior.
MR16 firmware/timers still follow the reduced master clock, reset/device
protocol and real-time scaling require further review, and the parent reports
single-clock native gameplay equivalence is **not yet passing**. Native boot
and diagnostic passes must not be promoted to full gameplay compatibility.
PLL lock/reset handling, PCG reset-release/placement, physical inputs/audio
and hardware storage remain unverified.

Synthesis reports ignored `async_reg` attributes and inferred-latch warnings
for fractional accumulator low bits 0–1, plus existing width/connectivity
warnings. The low bits are mathematically constant for this board rate;
the warnings remain explicitly recorded, not suppressed as signoff.

### Corrected disk baseline completed result

`quartus-disk-fixed-BRaJxFnN` also completed with exit status **0**. Map/fit/
asm/STA took **3:44 / 11:28 / 0:15 / 0:11**, wall time **16:16**. RBF SHA-256:
`16b464cfcdecc53899344062c5956a7af56516be40a18e7cd328a3f89cf114cd`.
It uses **20,195 ALMs (48%)**, 31,533 registers and 2,071,408 memory bits
(37%). Timing still **fails**, with worst setup **−3.261 ns** and recovery
**−2.450 ns**; hold is **+0.254 ns**. One clock remains unconstrained, as do
3 input and 44 output ports. No hardware deployment was performed.

| Reported metric | Initial bring-up, older RTL | Corrected frozen disk baseline | Optional single-clock snapshot |
| --- | ---: | ---: | ---: |
| ALMs | 20,258 | 20,195 | 19,927 |
| Worst setup (ns) | −3.391 | −3.261 | +0.401 |
| Worst recovery (ns) | −2.575 | −2.450 | +3.698 |
| Unconstrained clocks | 1 | 1 | 0 |
| Unconstrained input/output ports | 3 / 44 | 3 / 44 | 3 / 44 |

The initial bring-up snapshot is **older RTL**, not a controlled same-source
A/B. The reconstructed disk baseline and single-clock snapshot also have
different source sets as documented above. These results support continued
development of the optional revision; they do not isolate every timing/resource
change to one macro, prove complete constraints, or establish hardware/gameplay
compatibility. The default revision is unchanged.

### Supplemental-report provenance

`scripts/quartus_timing_paths.tcl` is read-only timing analysis against an
existing fitted database; it does not rebuild the FPGA. Select either supported
revision as its argument from the corresponding snapshot working directory:

```sh
quartus_sta -t /path/to/scripts/quartus_timing_paths.tcl sharpx1_single
```

For the reported single-clock supplemental run, script SHA-256 is
`e0dc080aa4bebce8faf938bf6c76cbbeb17379c7d77a21456ddf66beed0a6437`.
The ignored `quartus-Rc7U8tGG/supplemental-manifest.txt` binds that script,
input manifest, RBF and the four generated report hashes. It ran Quartus 17.0.0
Build 595 at 12:22:29–12:22:35 UTC on 2026-10-03, using the same installed
runtime image, with 4 requested CPUs and 8 GiB memory. No additional builds,
constraint edits, core copies, core loads or reboots were made for these reports.

## Compensated MR16 timer increment

Frozen single-clock snapshot `output_files/quartus-qOsoLktO/` records source
commit `9098c3366decbe8f4fc9c9673975176ea62cc58d` plus the parent's uncommitted
clock-path changes. Input manifest SHA-256:
`5c13db814bc609f7cccdd5ac03bc272f7c679166fdaa7fe180b164cf5f44547c`.
Against the earlier single-clock manifest, machine-source differences are
limited to `rtl/mr16_x1.v`, `rtl/sub_cpu.v`, `rtl/sharpx1.v` and
`rtl/x1_clock_enables.v`; `AGENTS.md` also differs. The timer synthesizes
32 MHz virtual ticks, carrying reload overshoot at the slower master rate;
`CLOCK_HZ` is forwarded through the machine/sub-CPU path. Fractional enable
accumulators are normalized by four to remove constant low-bit storage.
The board still uses 28,571,428 Hz, not the simulator's 28,636,364 Hz.

The parent reports the original 200 ms single-clock game test now passes both
movements and matches baseline frame hashes. This supersedes the earlier
software gameplay failure for that diagnostic; it does not retroactively change
the old RBF's behavior or establish broader software/hardware compatibility.
This sidecar verifies synthesis/timing for the frozen increment, not a fresh
execution of the parent's gameplay regression. The parent subsequently committed
the increment as `f45918dd5ac5aa3ebd622f1f8386a36e616abc16`; the four changed
machine files in that commit were individually hash-checked against this snapshot
and match exactly. This mapping does not change the originally recorded
working-tree source identity.

### Completed timer-increment build and comparison

All stages and the sidecar finished with exit status **0**. Map/fit/asm/STA
took **2:21 / 6:39 / 0:15 / 0:10**; recorded wall time was **9:34**
(12:47:59–12:57:33 UTC, 2026-10-03). RBF SHA-256:
`b2ca0708fc679a7babb52bd29dfec994839f5f429dac7b5c67a2b2799866886b`.

| Metric | Previous single-clock `Rc7U8tGG` | Compensated timer `qOsoLktO` |
| --- | ---: | ---: |
| Core setup / hold / recovery (ns) | +10.397 / +0.245 / +12.244 | +10.144 / +0.247 / +13.106 |
| Global worst setup / hold / recovery (ns) | +0.401 / +0.173 / +3.698 | +0.513 / +0.178 / +3.446 |
| ALMs | 19,927 (48%) | 20,023 (48%) |
| Registers | 31,566 | 31,569 |
| Memory bits | 2,071,408 (37%) | 2,071,408 (37%) |
| Map warnings | 79 | 81 |
| Fit / STA warnings | 9 / 0 | 9 / 0 |
| Unconstrained clocks | 0 | 0 |
| Unconstrained input / output ports | 3 / 44 | 3 / 44 |

Global removal/minimum-pulse-width slack is **+1.011 / +1.122 ns**.
RAM/DSP/PLL counts remain **263 / 32 / 3**. The additional timer logic costs
96 ALMs and 3 registers in these fits; placement-dependent timing changes should
not be attributed solely to that arithmetic. Reported constrained-path timing
continues to pass, but the inherited single-corner setting, 7 unconstrained input
paths and 50 unconstrained output paths still prevent full timing signoff.

The two accumulator latch warnings disappeared without suppressions. One old
enable arithmetic truncation warning also disappeared, while five warnings were
added: `x1_sub` body parameters `RAM_DEPTH`/`JOY_EMU` are treated as local
parameters after introducing a module parameter-port list, plus three timer
constant/step width truncations. The normalized master localparam still produces
one width warning. Existing ignored PCG `async_reg`, implicit `text_cs`,
PLL/reset/connectivity and memory-collision warnings remain open. No RTL,
constraint, installation or licensing changes were made by the sidecar.

**Scope boundary:** this RBF excludes the parent's later FDC D0 silent-abort
regression/fix. Its snapshotted `rtl/vendor/wd1793.sv` SHA-256 is
`c4b71f361da354c57e2d5b579316b61032c390ce48f4d8993c45bfb4c02e3a5d`.
It is evidence for this frozen timer/clock checkpoint only, **not timing coverage
of the latest whole working tree**, future disk changes, or a default-baseline
rebuild. No additional build/revision was run for this increment. Full peripheral
compatibility, asynchronous reset-release/PLL behavior, physical inputs/audio
and hardware operation remain unverified; the baseline remains the default.

A fresh **read-only** SSH check at **12:48:00 UTC, 2026-10-03** succeeded.
MiSTer was running `/media/fat/_Computer/SharpMZ-std_20261003.rbf` with
`/media/fat/games/SharpMZ/HWTest/mgl/V05.mgl`, kernel `5.15.1-MiSTer`, uptime
2 days 13:05, load average `1.00, 0.00, 1.00`. `/media/fat/_Computer` was
accessible. Availability means SSH connectivity, **not** permission to interrupt
the active hardware-test session. Nothing was copied, loaded, stopped or rebooted.

## Committed D0 silent-abort checkpoint

The `sharpx1_single` snapshot in `output_files/quartus-AtFLTCqB/` was captured
from committed HEAD **`7831f81a8eaeff2cfa0725eea92c0a153c299fe7`** with no
dirty RTL. Input manifest SHA-256:
`57095c0a5ba813b1d0e0146ad27b0e82cec135ab2331acc4445f01b9b564081d`.
Relative to the timer snapshot `qOsoLktO`, the only machine-source difference is
`rtl/vendor/wd1793.sv`; `AGENTS.md` also changed. The included WD1793-family
source hash is
`4a251706b566e99ad795796d9c825a66c499fe2c258803fb4e5ba97e24799d40`.
It contains the busy D0 silent-abort fix. This supersedes the earlier RBF's
exclusion of that fix, **only for this new artifact**.

The installed Quartus 17.0.0 Build 595 stepwise flow remains map(1), fit(8),
asm, STA with unchanged settings/constraints. Private software and simulation
assets are excluded. The build is isolated from subsequent parent edits;
later FDC implementations are not covered by this source identity. The sidecar
made no hardware connection or deployment
for this checkpoint: the parent owns the separately authorized MiSTer test.

### Completed committed-checkpoint result

All stages and sidecar exited **0**. Map/fit/asm/STA took
**2:11 / 6:27 / 0:15 / 0:10**, wall time **9:13**
(13:20:16–13:29:29 UTC, 2026-10-03). Complete stage logs, source/runtime
manifest and map/fit/asm/STA reports are retained in the snapshot directory.
Output is `source/output_files/sharpx1_single.rbf`, SHA-256:
`b2ca0708fc679a7babb52bd29dfec994839f5f429dac7b5c67a2b2799866886b`.

This RBF is **byte-identical** (`cmp` verified) to the compensated timer
snapshot `qOsoLktO`, despite the separately hashed D0 source fix. The machine's
FDC instance explicitly leaves `.intrq()` unconnected (`rtl/sharpx1.v` line
174 in this snapshot); Quartus's connectivity report confirms this. The fix
changes that output only, so its logic has no board-visible fanout in the current
machine. This is not proof of an integrated hardware FDC interrupt path or a
hardware execution of the controller's D0 regression. The new source-bound build
is still necessary to establish compilation of the committed checkpoint.

| Reported metric | Committed single revision `AtFLTCqB` |
| --- | ---: |
| Core setup / hold / recovery (ns) | +10.144 / +0.247 / +13.106 |
| Global worst setup / hold / recovery (ns) | +0.513 / +0.178 / +3.446 |
| Global removal / pulse-width slack (ns) | +1.011 / +1.122 |
| ALMs / registers | 20,023 (48%) / 31,569 |
| Memory bits / RAM blocks | 2,071,408 (37%) / 263 |
| DSP blocks / PLLs | 32 / 3 |
| Map / fit / STA warnings | 81 / 9 / 0 |
| Unconstrained clocks | 0 |
| Unconstrained input / output ports | 3 / 44 |

Timing, utilization and warning counts match the timer build. Reported
constrained paths pass, but the 7 unconstrained input paths / 50 output paths,
inherited single-corner timing, PLL/reset handling and hardware validation
remain open. Baseline defaults remain unchanged. No further build, source/
constraint edit, installation, license acceptance or hardware operation was
performed by the sidecar for this checkpoint; later parent changes require
their own source-bound build evidence.

## Conditional Type IV interrupt snapshot

A second, independently frozen `sharpx1_single` build is in
`output_files/quartus-atzbOrkj/`. It records base commit
`7831f81a8eaeff2cfa0725eea92c0a153c299fe7` **plus uncommitted conditional
interrupt RTL**, not committed `7831f81` alone. Input manifest SHA-256:
`7eb2b4b9eacf95a1c27d21cce54f92febf26c748b55fe1d5d8acca8a9b49a9b7`.
Its per-file input manifest differs from `AtFLTCqB` in exactly one file,
`rtl/vendor/wd1793.sv`, now hashed as
`7230919cdc6415ad7972477ae18581da6c193e76f889fdb60dc94042d2768549`.

The included change arms Type IV interrupt conditions for ready transitions
and index, retains immediate D8 INTRQ over status reads, and cancels masks on
the next accepted command/reset. The parent reports focused controller tests
passing; this sidecar is verifying synthesis/timing, not rerunning those tests.
The FPGA machine still leaves FDC INTRQ unconnected, so a successful build or
game boot cannot validate hardware consumption of those interrupt conditions.

### Completed conditional-checkpoint result and commit binding

After the build, every snapshotted input hash was compared with commit
**`658e27fd5363236f941092621d6cd1f0382199da`**. All machine RTL, board RTL,
project/IP files and other included assets match that commit exactly. The
**only** input difference is the non-synthesis `AGENTS.md` document. Thus this
artifact is source-bound to the machine implementation in `658e27f`, without
rewriting the original pre-commit snapshot identity or claiming a byte-identical
whole-tree snapshot. The commit-derived comparison manifest is retained as
`commit-658e27f-input.sha256` (SHA-256
`e380d75f2f58731e31b9684270d698f7dff19b2dca3b864f320ba923f0c5be61`).

All stages and sidecar exited **0**. Map/fit/asm/STA took
**2:21 / 6:39 / 0:15 / 0:09**, wall time **9:34**
(13:31:40–13:41:14 UTC, 2026-10-03; STA finished 13:41:13).
Complete logs, input/runtime manifests and reports remain in the snapshot.
Output is `source/output_files/sharpx1_single.rbf`, SHA-256:
`9126a87ab79ce45c7875bc110c316b20fc7c0e2b5e47c3e0e48781abf46b2851`.
Unlike the earlier D0-only checkpoint, this RBF differs from `AtFLTCqB`;
that does not establish hardware consumption of the unconnected INTRQ output.

| Reported metric | Conditional single revision `atzbOrkj` |
| --- | ---: |
| Core setup / hold / recovery (ns) | +8.761 / +0.244 / +10.174 |
| Global worst setup / hold / recovery (ns) | +0.537 / +0.244 / +3.892 |
| Global removal / pulse-width slack (ns) | +0.959 / +1.122 |
| ALMs / registers | 19,961 (48%) / 31,554 |
| Memory bits / RAM blocks | 2,071,408 (37%) / 263 |
| DSP blocks / PLLs | 32 / 3 |
| Map / fit / asm / STA warnings | 81 / 9 / 0 / 0 |
| Unconstrained clocks | 0 |
| Unconstrained input / output ports | 3 / 44 |

All reported constrained paths pass with the unchanged single-clock settings
and constraints. The 7 unconstrained input paths / 50 output paths, inherited
single-corner analysis, PLL/reset handling and full hardware/I/O signoff remain
open. Positive slack is not full hardware validation. Compared with `AtFLTCqB`,
core setup/recovery slack is lower but positive; global worst setup/recovery is
higher. These are separately placed builds, not evidence that the FDC interrupt
output is retained or connected.

The parent reports all three software suites and native baseline/single game
tests passing for `658e27f`. It also reports deploying this exact RBF and
capturing the native CROSS Chase title matching the earlier build. The parent
subsequently confirmed a live playfield and directional remote-key response,
unchanged test-disk hashes and zero write-protected config; evidence belongs
in `HARDWARE_BRINGUP.md`. Those
are parent observations, not sidecar hardware tests or an integrated FDC IRQ
gate. The sidecar performed no hardware access/deployment and starts no further
build for this checkpoint. The earlier `AtFLTCqB` source identity/result remain
separate; baseline defaults are unchanged.

## Host-transport abort/reset snapshot

The isolated opt-in `sharpx1_single` build in
`output_files/quartus-4celr5Kr/` was captured from
`9716cc0fda072d2a5dca33d8d8c6236a1443f89f` plus the uncommitted
`rtl/vendor/wd1793.sv` transport fix. Its vendor SHA-256 is
`5a2b21563fabd66dbce7f6963cf6132961cae09abf9367fb029d175e3108dc60`;
input-manifest SHA-256 is
`7a633c160cfccfa6692382714b1605d2b0ecdc9da13f3334a70a1007b57e693f`.
The snapshot retains notices and relative synthesis/IP/firmware paths, excludes
host C++/test changes and private software downloads, and is independent of
subsequent working-tree edits or commits.

The parent subsequently committed this increment as
**`4d22dc3acf2eaf17bc343e03c8a0a1ad22db77f3`**. Comparing a SHA-256 manifest
generated directly from every commit blob listed in `input-files.txt` with
the original `input.sha256` passes byte-for-byte: **all snapshot inputs match**,
including machine/board RTL, project/IP/firmware and included metadata. The
original base-plus-dirty snapshot manifest is preserved, with this later
commit binding recorded separately.

This increment latches each published host request's LBA, drains its ACK
handshake through controller reset/abort, and prevents a new ordinary command
from reusing an outstanding transfer. An already accepted host write cannot be
undone by abort/reset. The parent reports all twelve pending read/write D0/reset
before/during-ACK fixture cases passing, including held-reset-through-completion
and sampled pending-write buffer-data stability; the sidecar does not rerun that suite
or infer software correctness from synthesis.

The unchanged installed Quartus 17.0.0 Build 595 flow runs map(1), fit(8), asm
and STA on the existing Apple runtime, 16 CPUs/16 GiB, device
`5CSEBA6U23I7`, seed 1. Start: **14:11:31 UTC, 2026-10-03**.
All stages and sidecar exited **0**. Map/fit/asm/STA took
**2:17 / 6:39 / 0:15 / 0:10**, wall time **9:30**
(14:11:31–14:21:01 UTC, 2026-10-03). Logs, complete reports, original
source/runtime manifests and `commit-binding.txt` remain in the snapshot.
The artifact is `source/output_files/sharpx1_single.rbf`, SHA-256:
`7e9e3afe86c0dfb5172ee76d83e34f3db9909a4edfb7d229d2ff16554671185c`.
It differs from `atzbOrkj`. The generated build-date file is unchanged
(SHA-256 `84139c764f503782b8e01951d8b6ea26b6356c6f3569a213b74ec6acdf56c4f6`).

| Reported metric | Transport single revision `4celr5Kr` |
| --- | ---: |
| Core setup / hold / recovery (ns) | +9.952 / +0.244 / +11.473 |
| Global worst setup / hold / recovery (ns) | +0.572 / +0.244 / +4.370 |
| Global removal / pulse-width slack (ns) | +0.963 / +1.122 |
| ALMs / registers | 19,885 (47%) / 31,643 |
| Memory bits / RAM blocks | 2,071,408 (37%) / 263 |
| DSP blocks / PLLs | 32 / 3 |
| Map / fit / asm / STA errors | 0 / 0 / 0 / 0 |
| Map / fit / asm / STA warnings | 81 / 9 / 0 / 0 |
| Unconstrained clocks | 0 |
| Unconstrained input / output ports | 3 / 44 |

All reported constrained paths pass; settings and constraints were unchanged.
Relative to `atzbOrkj`, core setup/recovery improve by 1.191/1.299 ns and global
setup/recovery by 0.035/0.478 ns; hold is unchanged. Separately placed builds
are not a controlled demonstration of any individual path optimization.
Normalized synthesis warning messages match the prior build (ignoring shifted
WD1793 source line numbers). Inherited width/truncation and dual-clock RAM
warnings, fitter PLL reset/lock, incomplete I/O and ignored-assignment warnings
remain unresolved; no suppressions or broad false paths were added.

There are still **7 unconstrained input paths / 50 output paths**. Input ports
are `HDMI_I2C_SDA`, `IO_SDA` and partially constrained `VGA_EN`; the full output
list is in the STA report. Inherited single-corner analysis, external I/O
constraints, reset/PLL review and hardware validation remain open. The
metastability report could not calculate MTBF for 99.2% of detected chains;
its headline estimate must not be treated as CDC signoff. Base-X1 FDC INTRQ/DRQ
remain intentionally unconnected, so this does not validate an integrated
hardware interrupt path.

The parent reports all three full diagnostic suites passing and fresh native
baseline/single-clock game boot and original movement passing with the previous
hashes; both local private checkpoints were regenerated. No deployment
or hardware verification of this increment is claimed; the parent reports a
MiSTer hostname-resolution problem and owns any subsequent hardware testing.
No tool installation, license acceptance, constraint/RTL change or MiSTer
access/deployment was performed by this sidecar. Earlier source-bound results
remain separate, and the main-project defaults remain unchanged.
