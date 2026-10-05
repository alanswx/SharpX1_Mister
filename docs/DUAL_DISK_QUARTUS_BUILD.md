# Source-bound two-image Quartus build — October 5, 2026

The isolated retry **succeeded**, and supplemental STA passed constrained
paths at all eight corners. Its 334 frozen inputs match implementation
commit `ffc1c1c`. See the retry results below; external I/O constraints,
CDC/reset review and hardware acceptance remain open. The original failed
attempt is retained unchanged as historical evidence below.

## Historical failed attempt

The frozen two-image increment failed Analysis & Synthesis in Quartus Prime
Lite **17.0.0 Build 595**. No fit, assembly, original STA or supplemental
all-corner STA ran; no RBF/SOF was produced. This attempt supplies a
source-bound compilation failure, not timing or hardware validation.

## Failure and execution

Executed the existing script without edits:

```sh
QUARTUS_REVISION=sharpx1_turbo_single bash scripts/build_quartus.sh
```

Build directory: [output_files/quartus-sk8PX1hy](../output_files/quartus-sk8PX1hy/).
The main project is `sharpx1`, revision `sharpx1_turbo_single`, top `sys_top`,
Cyclone V device `5CSEBA6U23I7`, seed 1. The active machine path is
`sharpx1.sv` → `rtl/sharpx1.v` through `rtl/machine.qip`, with
`X1_SINGLE_CLOCK=1` and `X1_TURBO_FOUNDATION=1`. The board PLL master remains
35.000 ns / 28.571428 MHz; the simulator's single-clock setting differs.

The pre-flow build-ID hook succeeded and generated `BUILD_DATE=261005`.
Map ran with one thread and failed after 17 seconds, with **1 error and
8 warnings**. The script exited **3**, running from **12:58:18–12:58:41 UTC**
(07:58:18–07:58:41 America/Chicago). Its configured subsequent stages were
fit with eight threads, assembly and STA, but the builder stopped on map failure.

```text
Error (10839): Verilog HDL error at x1_disk_control.v(37): declaring local loop variables is a SystemVerilog feature
```

The frozen `rtl/x1_disk_control.v:37` uses
`for(integer d=0; d<2; d=d+1)` in the separate-motor branch.
`rtl/machine.qip:18` assigns that source as `VERILOG_FILE`, so Quartus parses
it as Verilog. The new `x1_disk_media.sv` is separately assigned as
`SYSTEMVERILOG_FILE`. No source, assignment, constraint or suppression fix
was made. This is the first reported blocking error; later stages and
potential later errors were not evaluated.

## Frozen inputs and implementation binding

The script froze **334 inputs**, including dirty and untracked RTL, and
verified identical hashes before/after copying and in the isolated snapshot.
The full [input list](../output_files/quartus-sk8PX1hy/input-files.txt) and
[SHA-256 manifest](../output_files/quartus-sk8PX1hy/input.sha256) are retained.
After the parent committed the implementation, all **334 input hashes** were
independently recomputed from commit
**`c6eab7d473751b105bffbca5f9bfc4bbf0a6792d`**: **334 match, zero differences**.
All 334 also matched the working tree when the failed build completed,
before the parent applied the language fix described in the retry section.
The original snapshot-time HEAD below is retained, rather than relabeled as
the implementation commit. Documentation and simulator tests are outside
this FPGA input manifest.

```text
snapshot_source_commit=9ea551581ad450a13c839c9a448640f5b6f796a9
implementation_commit=c6eab7d473751b105bffbca5f9bfc4bbf0a6792d
input_manifest_sha256=da206bd036e29179f2e63d50252660e58822f714a2e6dee0160ba55c0dfed4f0
runtime_identity_sha256=6550dd9261ca3b1397e53a2c063d71d6fe646a238fda876c75773ee05be96b3e
runtime_index_digest=sha256:6edc7bc0edee8c0a3f332ced040776c459287e856ee3ba85992512b7b313a370
sidecar_sha256=e7edd73862ad1b65f1c662b6be9d7a937f6c9ebba1a3ce1d51649d845f887de6
builder_sha256=49a5c3a8c4fa9a6718c96310469b3defc5a4bdeda6908e250383af53e0552fd2
```

Compared with the previous CTC snapshot `quartus-CEhveaur`, five existing
inputs changed and one was added; all other inputs match. Current hashes:

| Input | SHA-256 |
| --- | --- |
| `rtl/machine.qip` | `2fd107fa536a0365111b11e513675e102230c79a600a91b0f6b34c9f9b5683fb` |
| `rtl/sharpx1.v` | `8f11e7cb899b102fc16818a22447e1805c6d038773b3d79f6f579a225091d46b` |
| `rtl/vendor/wd1793.sv` | `18c4575cb1578ed916c668c3685808036b9490511357379d454f725859492062` |
| `rtl/x1_disk_control.v` | `a6019e8a9b1e6553704ce15e29091be5c4dfcbb19ed987d52dc2652d441b2f06` |
| New `rtl/x1_disk_media.sv` | `af9e9ca71b60ab2c4a5e66b8f45837d8beaab1f7e02bcd0c12b56eebc83f38a8` |
| `sharpx1.sv` | `e23fc6e56426f71afcdbd2c629e09558dd01f0c0e3dc4689b4157858792cead4` |

The snapshot includes `PHYSICAL_DRIVES=2` head storage, shared WD registers
and retained `step_direction`, independent motor holds, the media-owner
module and wrapper `VDNUM=2`. Their presence in the inputs is not evidence
of successful synthesis or physical behavior. Quartus generated project
metadata in the isolated tree; the original input bytes remain identified
by the manifest, and root project files were not changed by this attempt.

## Warning comparison, resources and timing

The eight warnings emitted before failure match the **first eight** warnings
of `quartus-CEhveaur/build.log` after normalizing source line numbers:
one processor-count warning, four ignored `async_reg` attributes, the
implicit `text_cs` net and two sub-CPU parameter-declaration warnings.
No new warning appeared before the error. This is a partial comparison:
the previous successful CTC map/fit totals were 93/9 warnings, whereas this
attempt stopped during parsing before elaboration and fitting. The smaller
count does not demonstrate warning resolution or absence of width problems.

The generated map summary lists ALMs, registers, pins, block-memory bits
and PLLs as **N/A until Partition Merge**. Current resource utilization,
timing slack, TNS, Fmax, unconstrained clocks and unconstrained I/O counts
are therefore **unavailable**. Supplemental STA cannot evaluate this source
without a successful fitted database and was not attempted on a previous
design. For context only, the previous CTC build reported 3 unconstrained
input ports / 7 paths and 44 unconstrained output ports / 50 paths for both
setup and hold, with zero illegal/unconstrained clocks; those results do
not validate the current increment. See [the CTC report](CTC_QUARTUS_BUILD.md).

## Runtime and retained evidence

Used the existing cached `docker.io/library/quartus17-runtime:apple-amd64`
Apple container runtime under Rosetta, with the installed Quartus payload
mounted read-only. The build container had 16 CPUs and 16 GiB memory.
No tool download/install, image build or license acceptance was performed.
Existing output directories were preserved; only the newly allocated
ignored build directory was used. Read the repository instructions,
README/TODO, dual-disk status, previous CTC report and existing Apple
container README/builder before evaluating this attempt.

| Evidence | SHA-256 |
| --- | --- |
| [Build manifest](../output_files/quartus-sk8PX1hy/build-manifest.txt) | `0c38c2c7ce91d48a1b7e5df37dd34b582763bd892c7b9504319d95500ecf7860` |
| [Full build log](../output_files/quartus-sk8PX1hy/build.log) | `c178e40ab9934744b48305403f35826f7058c7036720ec292fcb41c4472938f2` |
| [Map report](../output_files/quartus-sk8PX1hy/source/output_files/sharpx1_turbo_single.map.rpt) | `e0898cac1df752e2a496e42a4c81df4884e532cf441a6628281e78fa166fd34b` |
| [Map summary](../output_files/quartus-sk8PX1hy/source/output_files/sharpx1_turbo_single.map.summary) | `19dd0152870753e56ad111bd29854d4629a237a76ea69888f1ac5f387c81464d` |
| Generated `build_id.v` | `ab6f6e17454d678dfff7f5cd8f753698aa3f5842ba310c324a316a2f1dbeff06` |

## Scope and handoff

This build task ran Quartus only. The parent owns functional regressions,
native probes and other documentation. Parent-reported A/B tests and
CE-stopped accepted-write reset checks are separate evidence and were not
executed here. No hardware was contacted or deployed; no movie, game,
HPS mount/write, OSD reset or complete two-drive compatibility acceptance
is inferred. No source/constraint/suppression edits, commit or push were
performed by this task. Its only non-ignored write is this report.

## Isolated retry after the parent language fix

The parent moved `integer d` into the `motors` generate scope and changed
the loop to `for(d=0; d<2; d=d+1)`, then committed the language fix as
**`ffc1c1cc25fd85f8f7686f71c7b137bc08ee06ad`**. This task made no source
edits. The failed `sk8PX1hy` attempt and its evidence above are preserved.

The same unmodified build script started a fresh isolated attempt at
**13:03:05 UTC** in
[output_files/quartus-JC4BFj9f](../output_files/quartus-JC4BFj9f/).
All **334 inputs** matched before/after copying and in the snapshot.
Independent checks subsequently confirmed **334 matches, zero differences**
against both `ffc1c1c` and the working tree. The only input difference from
`sk8PX1hy` is `rtl/x1_disk_control.v`, now SHA-256
`d8a30b4b94195f5f4842416b3d5b86d4ed31b07bee254a87351563013b3d94fc`.

```text
snapshot_source_commit=c6eab7d473751b105bffbca5f9bfc4bbf0a6792d
implementation_commit=ffc1c1cc25fd85f8f7686f71c7b137bc08ee06ad
input_manifest_sha256=d56a6214b015fca24e55d0650ef01b0660b3064199532aa8e28d1aa3313997e6
```

Runtime image identity, installed tool, script hashes, revision, device,
seed and container resources are unchanged from the first attempt.
The pre-flow hook succeeded; synthesis completed at **13:05:37 UTC** in
**2:28**, with **zero errors / 93 warnings**. Top-level synthesis warning
messages match the previous CTC build after normalizing source line numbers.
The synthesized hierarchy includes `x1_disk_media`, both physical-head
arrays and both motor hold counters. Final fit, assembly, timing and
supplemental STA results follow below.

Parent-reported post-fix A/B CPU tests in both clock profiles and focused
disk/unit requalification are separate functional evidence, not executed
by this task. The parent's native Arcus 2×8-second evidence remains bound
to `c6eab7d`, before this language fix; it is not relabeled as post-fix
evidence. No hardware or full game acceptance is inferred.

## Successful retry: compile and supplemental STA

The retry completed the full stepwise flow with **exit 0** at
**13:13:45 UTC**, total build wall time **10:40**. Supplemental STA ran
**13:14:44–13:17:00 UTC**, with **exit 0**, using the same fitted database.

| Stage | Quartus elapsed | Errors | Warnings |
| --- | ---: | ---: | ---: |
| Analysis/synthesis | 2:28 | 0 | 93 |
| Fitter | 7:35 | 0 | 9 |
| Assembly | 0:17 | 0 | 0 |
| Original STA | 0:10 | 0 | 0 |
| Supplemental all-corner STA | 2:15 | 0 | 0 |

Original `.sta.rpt` and `.sta.summary` were copied with metadata preserved
into [single-corner-reports](../output_files/quartus-JC4BFj9f/single-corner-reports/)
before running the existing Quartus command in the cached runtime:

```sh
quartus_sta sharpx1 -c sharpx1_turbo_single --multicorner=on --all_corners
```

The supplemental container used 4 CPUs / 8 GiB; Quartus detected five
processors. No synthesis, refit, assembly, assignment or constraint edits
were performed for supplemental analysis. RBF and SOF hashes were checked
before and after STA and are identical. All 334 inputs still match the
working tree after supplemental STA. The original retry manifest retains
its snapshot-time HEAD `c6eab7d`; the explicit independent binding to
`ffc1c1c` above supplies the language-fix identity.

### Final artifacts and evidence

Experimental RBF:
[sharpx1_turbo_single.rbf](../output_files/quartus-JC4BFj9f/source/output_files/sharpx1_turbo_single.rbf).
No hardware deployment or boot was performed.

| Artifact | SHA-256 |
| --- | --- |
| RBF | `78ca9ecf057e167fdbb38fafe4fe149c41ea416e259214bdd09b016a65ddc301` |
| SOF | `5aee59754ee595bdd7dd9e0078653fc97c3b5dfffbd307117ad61196bfac971d` |
| Generated `build_id.v`, `BUILD_DATE=261005` | `ab6f6e17454d678dfff7f5cd8f753698aa3f5842ba310c324a316a2f1dbeff06` |
| [Build manifest](../output_files/quartus-JC4BFj9f/build-manifest.txt) | `6b107dc01faaaf12488a79f84c9d21b2a342f1dda7378d0c6dad6ddb94374d3b` |
| [Full build log](../output_files/quartus-JC4BFj9f/build.log) | `523e7c543de4ae5dc0bfee914dcc2111870a8cc4d29ddbaed99a5d69373f6665` |
| Preserved original STA report | `89c8559665e36136c5aa71314f97d5b7c5f7c1333019e133f8e56e86f6c2a1d8` |
| [All-corner STA report](../output_files/quartus-JC4BFj9f/source/output_files/sharpx1_turbo_single.sta.rpt) | `58dec6907564f00bef6a960080946f01096b05aa18888ac98c1576fec0504bcc` |
| [All-corner STA log](../output_files/quartus-JC4BFj9f/all-corners.log) | `e1d0acaff30e7ac815378d3a4eb203a6a3e413f9e2a9db4fa7444b98d6f78e7b` |

The complete current source manifest is
[input.sha256](../output_files/quartus-JC4BFj9f/input.sha256), with its
[input list](../output_files/quartus-JC4BFj9f/input-files.txt), runtime image
identity, original Git status and before/after source hashes retained in
the build directory. The previous failed and CTC outputs were preserved.

### Resources and warning review

| Resource | Retry used / available | Difference from CTC snapshot |
| --- | ---: | ---: |
| ALMs | 20,294 / 41,910 (48%) | +179 |
| Registers | 31,785 | +33 |
| Block-memory bits | 3,069,624 / 5,662,720 (54%) | +120 |
| RAM blocks | 384 / 553 (69%) | 0 |
| DSP blocks | 32 / 112 (29%) | 0 |
| PLLs | 3 / 6 (50%) | 0 |
| Pins | 145 / 314 (46%) | 0 |

All top-level synthesis and fitter warning messages match
`quartus-CEhveaur/build.log` after normalizing numeric source locations.
Totals are unchanged at 93 synthesis / 9 fitter warnings. No new disk
width/truncation warning appeared. The inherited 32-to-26-bit motor-hold
constant warning remains, now at `x1_disk_control.v:14`. Other warnings
retain ignored `async_reg`, implicit `text_cs`, parameter/width declarations,
dual-clock RAM behavior, framework connectivity, PLL reset/lock wiring,
incomplete I/O, ignored fitter assignments and subscription-only LogicLock.
No warning suppression was added. FDC INTRQ/DRQ remain unconnected as before.

### All-corner timing and remaining constraints

All corners use 1100 mV. Global worst slack, in ns:

| Model / temperature | Setup | Hold | Recovery | Removal | Min pulse width |
| --- | ---: | ---: | ---: | ---: | ---: |
| Slow / 100°C | +0.632 | +0.248 | +4.373 | +1.025 | +1.122 |
| Slow / −40°C | +0.394 | +0.170 | +4.443 | +0.960 | +1.122 |
| Slow / 85°C | +0.657 | +0.249 | +4.395 | +1.012 | +1.122 |
| Slow / 0°C | +0.465 | +0.179 | +4.465 | +0.945 | +1.122 |
| Fast / −40°C | +3.946 | +0.080 | +5.607 | +0.414 | +1.122 |
| Fast / 0°C | +3.853 | +0.090 | +5.578 | +0.429 | +1.122 |
| Fast / 85°C | +3.406 | +0.129 | +5.463 | +0.479 | +1.122 |
| Fast / 100°C | +3.383 | +0.134 | +5.429 | +0.493 | +1.122 |

Machine-domain slack, in ns, for
`emu|pll|pll_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk`:

| Model / temperature | Setup | Hold | Recovery | Removal | Min pulse width |
| --- | ---: | ---: | ---: | ---: | ---: |
| Slow / 100°C | +9.165 | +0.248 | +12.140 | +1.123 | +16.064 |
| Slow / −40°C | +9.566 | +0.234 | +12.393 | +1.042 | +16.044 |
| Slow / 85°C | +9.255 | +0.249 | +12.220 | +1.113 | +16.067 |
| Slow / 0°C | +9.626 | +0.235 | +12.405 | +1.034 | +16.044 |
| Fast / −40°C | +13.683 | +0.118 | +14.792 | +0.470 | +16.386 |
| Fast / 0°C | +13.547 | +0.122 | +14.685 | +0.488 | +16.377 |
| Fast / 85°C | +13.029 | +0.132 | +14.335 | +0.537 | +16.375 |
| Fast / 100°C | +12.870 | +0.135 | +14.242 | +0.550 | +16.376 |

All reported endpoint TNS values are zero. Global minima are setup
**+0.394 ns**, hold **+0.080 ns**, recovery **+4.373 ns**, removal
**+0.414 ns** and minimum pulse width **+1.122 ns**. Compared with CTC,
global setup/hold minima improve by 0.035/0.025 ns. Machine-domain minima
are setup/hold/recovery **+9.165 / +0.118 / +12.140 ns** and
removal/pulse width **+0.470 / +16.044 ns**. Slow / 100°C machine
same-clock Fmax is 39.32 MHz, versus 40.23 MHz for CTC; this report excludes
cross-clock paths and is not a supported operating-frequency claim.

There are **zero illegal or unconstrained clocks**. Setup and hold each
retain **3 unconstrained input ports / 7 paths** and
**44 unconstrained output ports / 50 paths**, unchanged from CTC.
Inputs include HDMI I²C SDA, IO SDA and partially constrained VGA enable;
outputs include HDMI I²C/I²S/clock/data/control, IO I²C, selected LEDs,
SPDIF, SD SPI CS and USER_IO. Full port/path lists remain in the STA report.
TimeQuest explicitly reports incomplete setup and hold constraints despite
zero warnings. It detects 386 synchronizer chains but cannot calculate
MTBF for 99.2% of them; its headline MTBF does not validate CDC or reset
release. Bundled-data placement and physical transport/reset acceptance
remain open.

This successful build establishes compilation, fit, assembly and positive
analyzed constrained-path timing for the source-bound retry. It does not
establish HPS A/B mount/write behavior, physical head/motor fidelity, OSD
reset, software/game acceptance or full timing/hardware signoff. This task
made no source/constraint/suppression edits, commit, push, install, download
or deployment; its only non-ignored write remains this report.
