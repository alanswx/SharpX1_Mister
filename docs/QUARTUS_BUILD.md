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
execution of the parent's gameplay regression. Stage results are pending.

A fresh **read-only** SSH check at **12:48:00 UTC, 2026-10-03** succeeded.
MiSTer was running `/media/fat/_Computer/SharpMZ-std_20261003.rbf` with
`/media/fat/games/SharpMZ/HWTest/mgl/V05.mgl`, kernel `5.15.1-MiSTer`, uptime
2 days 13:05, load average `1.00, 0.00, 1.00`. `/media/fat/_Computer` was
accessible. Availability means SSH connectivity, **not** permission to interrupt
the active hardware-test session. Nothing was copied, loaded, stopped or rebooted.
