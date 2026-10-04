# Turbo foundation Quartus 17 build — October 4, 2026

The isolated `sharpx1_turbo_single` revision compiled successfully and produced
an RBF. Supplemental TimeQuest analysis passes all reported constrained paths
at all eight available corners. External I/O remains incompletely constrained;
this is development build evidence, not full timing signoff or hardware/Turbo
compatibility. MiSTer was unavailable while travelling; no hardware access,
deployment, boot or physical input/audio/storage testing was performed.

## Frozen source and flow

Executed from the repository root:

```sh
QUARTUS_REVISION=sharpx1_turbo_single bash scripts/build_quartus.sh
```

The main Quartus 17 project is `sharpx1`, FPGA top `sys_top`, device
`5CSEBA6U23I7`, seed 1. The revision sources `sharpx1_single.qsf`, inheriting
`X1_SINGLE_CLOCK=1`, and adds `X1_TURBO_FOUNDATION=1`. The active machine is
`sharpx1.sv` → `rtl/sharpx1.v`, with the explicit receive-only sub-CPU firmware
profile, D88 scanner guards, experimental banked 96 KiB GRAM, 2 KiB KVRAM,
black clipping and 32 KiB IPL capacity. This does not implement 400-line video
or a complete Turbo machine. The machine master remains the existing board
PLL's 35.000 ns / 28.571428 MHz; it is not the simulator's 28.636364 MHz.

Build directory: `output_files/quartus-t7wQxGHo/`. Original source identity:

```text
source_commit=00fe84367d3bc45c9296b6dc4d1e7883876d4280
input_manifest_sha256=b19989053a7b4ce23e20e6c01bce457f31999fa4e8a81af4a34bce0795d85bec
sidecar_sha256=e7edd73862ad1b65f1c662b6be9d7a937f6c9ebba1a3ce1d51649d845f887de6
builder_sha256=49a5c3a8c4fa9a6718c96310469b3defc5a4bdeda6908e250383af53e0552fd2
runtime_identity_sha256=6550dd9261ca3b1397e53a2c063d71d6fe646a238fda876c75773ee05be96b3e
runtime_index_digest=sha256:6edc7bc0edee8c0a3f332ced040776c459287e856ee3ba85992512b7b313a370
```

This is the recorded commit **plus frozen uncommitted changes**, not that
commit alone. The 331 per-file hashes are retained in `input.sha256`; the
before/after-copy and original snapshot manifests compare byte-for-byte.
After compilation, all 331 original input hashes also passed against the
current working tree. Documentation and test-helper edits outside this input
set are not FPGA inputs. Later source changes require their own build binding.
After the parent committed the implementation, each of the 331 input hashes
was independently recomputed from Git commit
**`7c7b6dbaa7601c6d91c741a6e5ec32fe43502ae2`**: all match, with zero differences.
This binds the artifact to that commit's complete input set while preserving
the original pre-commit manifest above.
Quartus itself added top-level/version metadata to the snapshot revision QSF;
the manifest preserves its original bytes' identity. Root project files were
not edited by this build.

Used the existing Apple container installation and cached Quartus Prime Lite
**17.0.0 Build 595**, with a read-only tool mount. No installation, image build,
source download or license acceptance was performed. The sandbox initially
denied container access; the authorized escalated invocation succeeded.
Container progress labels such as “Fetching image/kernel” do not establish a
new download; the existing runtime image was inspected before compilation.

The builder explicitly ran the build-ID pre-flow hook and the equivalent
stepwise main-project flow: map with one thread, fit with eight threads,
assembly, then STA. The build container requested 16 CPUs / 16 GiB.

| Stage | Elapsed | Errors | Warnings |
| --- | ---: | ---: | ---: |
| Analysis/synthesis | 2:26 | 0 | 93 |
| Fit | 7:11 | 0 | 9 |
| Assembly | 0:16 | 0 | 0 |
| Original single-corner STA | 0:11 | 0 | 0 |
| Supplemental all-corner STA | 2:10 | 0 | 0 |

Sidecar exit was 0; recorded build wall time was **10:13**,
2026-10-04 **23:04:04–23:14:17 UTC**. Supplemental analysis ran
**23:14:38–23:16:48 UTC** in the same cached runtime, requesting 4 CPUs /
8 GiB (Quartus reported five detected processors). The original build log,
manifest, runtime identity and working-tree status remain in the build directory.

## Artifacts

The latest experimental Turbo foundation artifact is
[sharpx1_turbo_single.rbf](../output_files/quartus-t7wQxGHo/source/output_files/sharpx1_turbo_single.rbf).
It is local build output, with no hardware validation.

| Artifact | SHA-256 |
| --- | --- |
| [sharpx1_turbo_single.rbf](../output_files/quartus-t7wQxGHo/source/output_files/sharpx1_turbo_single.rbf) | `4f54f9679e5436936fb8a362cb7af3bb571c09bcbfcf61c532a5e3e39ef83376` |
| [sharpx1_turbo_single.sof](../output_files/quartus-t7wQxGHo/source/output_files/sharpx1_turbo_single.sof) | `0aba7fcb6a35e9b4dceea94cc61f3219eaedafe6e8514b19539559dcda37396c` |
| Generated `build_id.v` (`BUILD_DATE=261004`) | `b0621fcb81a99f5e97e67d3681c4ff0888baa6d54f43aa9ddc69753d04ffa3e4` |
| [All-corner STA report](../output_files/quartus-t7wQxGHo/source/output_files/sharpx1_turbo_single.sta.rpt) | `3f7901cee7c7932cd9236992c338e6e787122a26a155f957835fbffd929849d3` |
| [All-corner log](../output_files/quartus-t7wQxGHo/all-corners.log) | `1619c5ab6b8c9d4bf360e93304bec3a3a448c300631cf60a3f556daa933d43ca` |

The RBF/SOF hashes were independently checked after supplemental STA; they
remain unchanged. Artifacts and private firmware/source snapshots stay local
and ignored. Existing attribution/licensing limitations remain unresolved.

## Timing at every available corner

The inherited QSF keeps `TIMEQUEST_MULTICORNER_ANALYSIS OFF`. Original STA
reports were preserved in `single-corner-reports/` before this supplemental
command was run against the **existing fitted database**, without rebuilding,
editing assignments or adding exceptions:

```sh
quartus_sta sharpx1 -c sharpx1_turbo_single --multicorner=on --all_corners
```

The snapshot's `source/output_files/sharpx1_turbo_single.sta.rpt` and
`.sta.summary` now contain this all-corner result. All corners are 1100 mV.
Global worst slack, in ns:

| Model / temperature | Setup | Hold | Recovery | Removal | Min pulse width |
| --- | ---: | ---: | ---: | ---: | ---: |
| Slow / 100°C | +0.455 | +0.199 | +4.498 | +0.995 | +1.122 |
| Slow / −40°C | +0.233 | +0.086 | +4.616 | +0.928 | +1.122 |
| Slow / 85°C | +0.467 | +0.171 | +4.531 | +0.992 | +1.122 |
| Slow / 0°C | +0.315 | +0.093 | +4.623 | +0.923 | +1.122 |
| Fast / −40°C | +3.857 | +0.108 | +5.618 | +0.407 | +1.122 |
| Fast / 0°C | +3.779 | +0.118 | +5.587 | +0.421 | +1.122 |
| Fast / 85°C | +3.422 | +0.128 | +5.471 | +0.474 | +1.122 |
| Fast / 100°C | +3.301 | +0.129 | +5.430 | +0.486 | +1.122 |

Machine-domain slack, in ns, for
`emu|pll|pll_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk`:

| Model / temperature | Setup | Hold | Recovery | Removal | Min pulse width |
| --- | ---: | ---: | ---: | ---: | ---: |
| Slow / 100°C | +8.637 | +0.241 | +11.393 | +1.008 | +16.062 |
| Slow / −40°C | +9.016 | +0.212 | +11.672 | +0.928 | +16.044 |
| Slow / 85°C | +8.742 | +0.245 | +11.467 | +0.996 | +16.071 |
| Slow / 0°C | +9.083 | +0.216 | +11.699 | +0.923 | +16.045 |
| Fast / −40°C | +13.524 | +0.115 | +14.446 | +0.428 | +16.388 |
| Fast / 0°C | +13.397 | +0.118 | +14.336 | +0.450 | +16.380 |
| Fast / 85°C | +12.952 | +0.128 | +13.937 | +0.522 | +16.380 |
| Fast / 100°C | +12.818 | +0.129 | +13.822 | +0.536 | +16.380 |

All reported endpoint TNS values are zero. Worst global setup/hold is in the
HDMI domain at Slow / −40°C, **+0.233 / +0.086 ns**. Across corners, machine
setup/hold/recovery minima are **+8.637 / +0.115 / +11.393 ns**; machine removal
and pulse-width minima are **+0.428 / +16.044 ns**. The original Slow / 100°C
same-clock machine Fmax is 40.03 MHz; this metric excludes cross-clock paths
and does not establish a supported operating frequency.

There are **zero illegal or unconstrained clocks**, but setup and hold each
retain **3 unconstrained input ports / 7 paths** and **44 unconstrained output
ports / 50 paths**. Inputs are `HDMI_I2C_SDA`, `IO_SDA` and partially constrained
`VGA_EN`. Outputs cover HDMI I²C/I²S/clock/data/control, IO I²C, selected LEDs,
SPDIF, SD SPI CS and USER_IO pins; the full pin list is in STA. TimeQuest emits
“Design is not fully constrained” as informational messages despite its zero
warning count. Positive analyzed timing is not complete external-I/O signoff.

## Final resources and warning review

| Resource | Used / available |
| --- | ---: |
| ALMs | 20,019 / 41,910 (48%) |
| Registers | 31,647 |
| Block-memory bits | 3,069,504 / 5,662,720 (54%) |
| RAM blocks | 384 / 553 (69%) |
| DSP blocks | 32 / 112 (29%) |
| PLLs | 3 / 6 (50%) |
| Pins | 145 / 314 (46%) |

Normalized synthesis warning messages compared with the previous renderer
single-clock build `quartus-IwtYVtRu` add two ignored `async_reg` attributes
on the Turbo control latches in `rtl/sharpx1.v` and another synthesized-away
node group (FDC `tsizes` RAM). Nested warnings account for the 93 total; no
new width/truncation warning message appeared in this comparison. This is
a comparison with an older source snapshot, not a controlled macro-only A/B.

Inherited warnings remain: ignored PCG synchronizer attributes, implicit
`text_cs`, width/truncation and parameter declarations, dual-clock RAM
read-during-write behavior, undriven/unused framework signals, PLL reset/lock
connectivity, incomplete I/O assignments, ignored fitter assignments and the
subscription-only LogicLock feature. No suppression or false-path exception
was added. MTBF cannot be calculated for 99.2% of the 386 detected synchronizer
chains; the headline MTBF estimate is not CDC/reset-release validation.
FDC INTRQ/DRQ remain intentionally unconnected in the base-X1 integration.

The parent separately reports the current full base native CROSS Chase cold,
repeat and control regression passing, with executable SHA-256 abbreviated as
`31586f55…ed515`. That software result was not executed by this build sidecar
and does not verify Turbo software or this RBF on hardware. The parent owns
parallel software probes, any later commit/push, and subsequent hardware work.
This sidecar changed only this tracked documentation destination; no commit
or push was performed.
