# Frozen Turbo PCG / disk metadata Quartus build

This audit records the build of checkpoint **`15a065513f42a39204d944e9abf511aba46111d0`**
for revision `sharpx1_turbo_video`. The original flow **fits and assembles
SOF/RBF artifacts, but fails primary setup, hold and recovery timing**.
Completed eight-corner STA fails **setup/recovery at all eight corners and
hold at five**. Physical font storage is **eight M10Ks**; selector and
disk metadata/ACK/abort state survive. The fitted audit is complete.
Assembly alone is not timing closure or hardware acceptance.

## Frozen source and workflow

The unique ignored evidence directory is
[quartus-pcg-metadata-15a0655-lu6EJraq](../output_files/quartus-pcg-metadata-15a0655-lu6EJraq/).
The source is extracted from `git archive --format=tar 15a0655`, not copied
from a changing working tree. The full archive preserves checkpoint files
and notices, including tracked historical generated simulator sources.
No ignored private ROMs, fonts, disks or simulator states were copied.
No ignored nonprivate dependencies were needed: the checkpoint contains the
framework, PLL/IP and firmware build inputs. The build hook generates its
own `build_id.v` and `jtag.cdf` inside this isolated source directory.

All **342 FPGA manifest inputs** were independently hashed from
`git show 15a0655:<path>` and compared with the extracted files before
Quartus ran: 342 matches, zero differences. The
[input manifest](../output_files/quartus-pcg-metadata-15a0655-lu6EJraq/input.sha256)
and [checkpoint manifest](../output_files/quartus-pcg-metadata-15a0655-lu6EJraq/checkpoint-input.sha256)
are identical. [Validation output](../output_files/quartus-pcg-metadata-15a0655-lu6EJraq/input-validation.log)
records every checked file. This binding does not validate subsequent HEAD
or working-tree changes. The archive and original manifest are preserved
even if Quartus serializes project assignments during its flow.

**Explicit boundary:** Main's newer X3 PPI two-stage level synchronization
and simulator snapshot **v08** follow-up, subsequently committed/pushed as
**`ac170be`**, is excluded from this frozen `15a0655` build. The newer
digital text/raster-boundary checkpoint **`29755e7`** and subsequent
documentation/fixture checkpoint **`6ea8da7`** are also excluded. Their simulation/native
results must not be attributed to this RBF. Main reported a passing fast CPU
disk matrix and an ongoing delay-aware matrix; those are separate simulation
evidence, not tests executed or source-qualified by this Quartus audit. This
fit audit does not wait for native/matrix runs or modify current RTL.
Later text/raster-boundary, fixture, reset-release or DMA work and its
simulation/native results are not qualified by this frozen artifact.
The subsequently pushed **`274883f` / v10 X3 reset-release increment** is
also excluded, as is current DMA integration. Its passing simulation does
not change this frozen fit's reset recovery results.

| Input identity | SHA-256 |
| --- | --- |
| `checkpoint.tar` | `b360b2961e1c21e0f66fc11fe94ef1da9a9b9cf659bb1cc334120e7e6bd0c182` |
| `input.sha256` / `checkpoint-input.sha256` | `18719296b0e9b9176831e42a25efb6dceb5b84e197519db3d5a55fb4d9efd9ea` |
| Runtime inspection JSON | `6550dd9261ca3b1397e53a2c063d71d6fe646a238fda876c75773ee05be96b3e` |
| Existing Apple core builder | `49a5c3a8c4fa9a6718c96310469b3defc5a4bdeda6908e250383af53e0552fd2` |

Read the repository `AGENTS.md`, `Readme.md`, `docs/SHARP_X1_TODO.md`,
the preceding [snapshot build report](TURBO_VIDEO_CDC_QUARTUS_BUILD.md),
`scripts/build_quartus.sh`, and the local Apple-container README, runtime
Containerfile and applicable build scripts before building. The existing
Apple builder was reused without edits. Its runtime is cached
`docker.io/library/quartus17-runtime:apple-amd64`, index digest
`sha256:6edc7bc0edee8c0a3f332ced040776c459287e856ee3ba85992512b7b313a370`.
Quartus identifies itself as **17.0.0 Build 595, 04/25/2017 SJ Lite Edition**.
No installation, image build, licence acceptance or tool download was performed.
Container progress uses generic “Fetching” labels for the existing runtime;
the cached image was inspected before invocation.

The preparation and exact invocation are preserved in
[freeze-build.sh](../output_files/quartus-pcg-metadata-15a0655-lu6EJraq/freeze-build.sh)
and [build-manifest.txt](../output_files/quartus-pcg-metadata-15a0655-lu6EJraq/build-manifest.txt).
The repository snapshot script's working-tree copy was replaced by archive
preparation in this ignored script; the existing local core builder then ran:

```sh
QUARTUS_FIT_THREADS=8 QUARTUS_CPUS=16 QUARTUS_MEMORY=16g \
  /Users/alans/dev2/apple-containers-example/scripts/quartus-core-apple.sh \
  /Users/alans/dev2/SharpX1_Mister/output_files/quartus-pcg-metadata-15a0655-lu6EJraq/source \
  sharpx1 sharpx1_turbo_video
```

The hook runs `quartus_sh -t sys/build_id.tcl compile sharpx1
sharpx1_turbo_video`; `BUILD_DATE=261005`. The stepwise flow is
`quartus_map --parallel=1`, `quartus_fit --parallel=8`, `quartus_asm`,
`quartus_sta`, each with project `sharpx1 -c sharpx1_turbo_video`.
Serial mapping avoids the documented Rosetta helper-process deadlock.
Device `5CSEBA6U23I7`, seed 1, FPGA top `sys_top`; active machine path is
`sharpx1.sv` → `rtl/sharpx1.v`, with `X1_TURBO_FOUNDATION=1` and
`X1_TURBO_VIDEO_MASTER=1`. No single-clock mode is selected.

The initial checkout status was clean. Subsequent concurrent machine changes
belong to other work and were preserved. No subagent tool is available in
this session; the authorized build runs directly. Apple service access required
sandbox escalation, which automatic review allowed. Only this new report and
files inside the unique ignored directory are written by this audit. No RTL,
constraints, existing documentation, sibling repository, private assets,
commits, or hardware deployment are in scope.

## Synthesis observations

Analysis & Synthesis passed (summary **20:00:50 UTC**, processing ended
**20:00:54 UTC**), with **zero errors / 114
warnings**. Its summary reports **32,513 registers**, **3,141,480 block
memory bits** and an ALM estimate of 23,496. This estimate is not fitted
utilization. The PCG selector hierarchy has **56 synthesized registers**
and no memory bits. Fitted register names/counts and resources are audited
separately below.

The font's newly consumed CPU read output results in **two** inferred
simple-dual-port **4096×8** memories (`mem_rtl_0`, `mem_rtl_1`), each
32,768 bits. This is 65,536 synthesized memory bits despite one behavioral
array in `x1_video_ram.v`; reuse of the RTL CPU port is not evidence that
Quartus retains the preceding build's four-M10K allocation. The total
synthesized RAM-bit increase versus the preceding `c0d1042` fit is 32,768.
The sector index remains **2048×57**, rather than an FF array. Both the
font and index require the physical fitter evidence before allocation claims.

Quartus ignores nine `async_reg` declarations: three in `rtl/sharpx1.v`,
two in `rtl/x1_pcg_access.v`, one in `rtl/x1_font16.sv`, two in
`rtl/x1_cdc_snapshot.sv`, and one in `sys/hps_io.sv` (warning 10335).
Attribute text and retained register names do not establish recognized
synchronizer chains, metastability margin or CDC acceptance. Existing RAM
read-during-write, parameter/width/implicit-net and framework connectivity
warnings remain; no suppressions were added.

## Resume after agent/daemon restart

Read-only inspection at **20:31 UTC** confirms host PID **38449** is still
the original Apple core builder, parented by the original `freeze-build.sh`
PID **36239**. Its existing container
`b31eba01-fe02-4ea3-ae88-38bd1e86b45f` started at **19:51:22 UTC**;
container PID **138** is `quartus_fit`, actively accumulating CPU time.
The last logged stage is placement preparation / Advanced Physical
Optimization. No duplicate compile, map, fit, assembly, or stop was issued.

Independent resume validation rehashes every manifest input against
`git show 15a0655:<path>`: **342/342 checkpoint matches**. During the flow,
**340/342 extracted files remain byte-identical**. The two differences are
the QPF's generated Intel header/date/revision list and the revision QSF's
serialized sourced assignments/tool metadata, as in the preceding build.
The original manifest/archive identities above remain intact; these generated
project files do not replace the frozen-input identity. The ignored
`resume-input-audit.rb` records exact original/current hashes and checks the
manifest cardinality instead of relying on the earlier 344-input estimate.

The fitted audit distinguishes the twelve declared selector bytes
and validity bits from bits actually retained, and inspect ACK/metadata/abort
state, both inferred font arrays' physical allocation, the width-57 index,
all eight timing corners, first-stage paths and recognized synchronizers.
`ac170be` and checkpoint **`29755e7`** (**v09 text/raster-boundary correction**) remain
excluded. No newer CPU/video, native game or reset simulation result is
attributed to this build.

**Provisional checkpoint, 20:57 UTC:** the same container fitter PID 138
remains alive and continues accumulating CPU time (56 minutes elapsed,
over 6½ CPU-hours at the latest completed check). Placement preparation
finished in **27:09**; that remains the last logged stage. No final fit
report, timing report, SOF or RBF has appeared, and no audit blocker is
established. The fit has not been stopped or restarted. Final allocation,
retained-state, all-corner timing, synchronizer and artifact-hash results
remain pending; synthesis estimates above are not substituted for them.
Later checkpoint `6ea8da7` and Main's newer pixel/reset/native/matrix results
remain outside this source binding. The report is not staged; no commit is created.

**Host-pipeline caveat, 21:06 UTC:** the original host wrapper/parent are
now absent, and `build-manifest.txt` records **21:02:13 UTC / exit 141**.
That status is consistent with SIGPIPE, but the cause is not established.
It is **not** a successful compile completion. The original container still
contains PID 1 `sh` and fitter PID 138; its CPU time continues increasing.
Read-only `container logs` finds the newer **“Fitter placement operations
beginning”** message absent from the disconnected host `build.log`.
The container remains the source of live progress; downstream assembly/STA
completion is unconfirmed. No replacement/restart/stop was attempted.

## Completed original fit and assembly

The surviving original container advanced to `quartus_asm`, then
`quartus_sta`, without another map/fit/assembly invocation. The original
container was subsequently removed by its existing lifecycle. Final stage
reports confirm completion; the host manifest's **exit 141 is preserved**,
not rewritten as an aggregate successful-flow exit. Its disconnected
`build.log` is incomplete. The preserved
[container resume log](../output_files/quartus-pcg-metadata-15a0655-lu6EJraq/container-resume-2106.log)
captures the additional placement-start message; subsequent stages are
established by their fitted/assembler/STA reports and the flow log.

| Original stage | Processing timestamps UTC | Elapsed | Errors / warnings |
| --- | --- | ---: | ---: |
| Map | 19:51:48–20:00:54 | 9:06 | 0 / 114 |
| Fit | ending 21:14:09 | 1:12:55 | 0 / 11 |
| Assembly | 21:14:13–21:14:38 | 0:25 | 0 / 0 |
| Primary STA | 21:14:40–21:14:57 | 0:17 | 0 / 1 |

Fitter CPU time is **7:08:16**, peak virtual memory **4,249 MB**.
Placement preparation/placement/routing/post-fit take **27:09 / 6:18 /
9:37 / 1:09**. Router estimated average/peak interconnect use is **25%/39%**;
the separate final resource table reports total average/peak **29.3%/47.6%**.
Router-added aggregate hold delay is approximately **3,000 ns / 1.4%** of
available device routing delay, not delay on one path.

| Resource | `15a0655` fit | Prior `c0d1042` fit | Change |
| --- | ---: | ---: | ---: |
| ALMs / 41,910 | 20,627 (49%) | 20,608 (49%) | +19 |
| Registers | 32,404 | 32,172 | +232 |
| RAM bits / 5,662,720 | 3,141,480 (55%) | 3,108,712 (55%) | +32,768 |
| RAM blocks / 553 | 393 (71%) | 389 (70%) | +4 |
| DSP blocks / 112 | 32 (29%) | 32 (29%) | 0 |
| PLLs / 6 | 4 (67%) | 4 (67%) | 0 |
| Pins / 314 | 145 (46%) | 145 (46%) | 0 |

The font really occupies **eight M10Ks**, not the preceding four:

| Inferred array under `turbo_font.font16\|storage` | Mode | Logical / implemented bits | M10Ks | Sites |
| --- | --- | ---: | ---: | --- |
| `mem_rtl_0` | Simple dual-port, single clock (CPU read/write copy) | 32,768 / 32,768 | 4 | X41 Y47/Y48; X38 Y47/Y48 |
| `mem_rtl_1` | Simple dual-port, dual clocks (video read copy) | 32,768 / 32,768 | 4 | X41 Y45/Y46; X38 Y45/Y46 |

Each is **4096×8**, with zero MLABs and no initialization file. CPU-copy
mixed-port read-during-write is **Old data**; video-copy mixed-port behavior
is **Don't care**. Same-port read-during-write columns report New data.
These reported modes do not verify real upload/read collisions. The font
hierarchy uses **28.1 ALMs / 25 registers**. The RAM-bit/block increase
exactly matches the extra four-M10K font copy.

The sector index `image_index.edsk_ram` remains **single-clock true
dual-port 2048×57**, **116,736 logical/implemented bits**, **12 M10Ks**,
zero MLABs and no initialization file. Sites are X41 Y55–59, X38 Y55–59,
and X49 Y55/Y56 (all `M10K_*_N0`). It is not a large FF array.
The complete physical allocation/modes are in the
[Fitter RAM Summary](../output_files/quartus-pcg-metadata-15a0655-lu6EJraq/source/output_files/sharpx1_turbo_video.fit.rpt).

The fitted X3 PLL again uses **50 MHz reference, M189/N10/C22, VCO
945 MHz**, yielding nominal **42.954545454545… MHz**, period
**23.280423280423… ns**: **+5.454545… Hz / +0.126984143… ppm** versus
the requested 42.954540 MHz. The system PLL remains **32 MHz / 31.250 ns**.
These are fitted nominal divider values, not measured oscillator, phase,
jitter, reset/lock or hardware acceptance.

Primary STA reports **Critical Warning 332148: timing requirements not met**:
setup **−15.089 ns**, hold **−0.827 ns**, recovery **−9.530 ns**, removal
**+0.687 ns**, minimum pulse width **+0.529 ns**. The primary report/summary
were preserved in
[single-corner-reports](../output_files/quartus-pcg-metadata-15a0655-lu6EJraq/single-corner-reports/)
before sequential `quartus_sta --multicorner=on --all_corners` and the
read-only fitted-register/path extraction. Neither analysis repeats mapping,
fitting or assembly, nor adds constraints or exceptions.

## Retained selector, transaction and disk state

The twelve declared selector bytes are **not twelve full fitted bytes**:
unused bits are removed, while all twelve validity bits remain. Under
`emu:emu|sharpx1:sharpx1|x1_pcg_selector:turbo_pcg_selector.selector`:

| Selector state | Fitted bits |
| --- | ---: |
| Four `text_cell` glyph bytes | 32 (all eight bits of each byte) |
| Four `attr_cell` bytes | 4 (only bit 5 of each) |
| Four `kan_cell` bytes | 8 (bits 4 and 7 of each) |
| `text_valid`, `attr_valid`, `kan_valid` | 4 each / 12 total |
| Entire selector | 56 registers, 29.5 ALMs, no RAM bits |

The frozen selector has no reset input and initializes only the validity
vectors. Thus retained accepted-write metadata survives machine warm reset
by construction; this fit does not establish hardware warm-reset behavior.

PCG bridge `x1_pcg_access:cg_bus` retains **71 registers / 34.1 ALMs**.
Its `payload`, `response`, `cpu_q` are eight bits each; `access_addr` is
eleven bits, `font_cpu_addr` twelve; high-speed/font16/unsupported request
flags and `cpu_read_hold` each remain. `request/ack` and both stages of
each handshake remain. The stage state is recoded into three one-hot
registers plus a duplicate of `stage.01`.

The map's merge table explicitly maps **`frozen_addr[4:10]` to
`font_cpu_addr[5:11]`**, while `frozen_addr[0:3]` remain separately named.
These seven bits were shared, not lost. Initial four-name-only address
reports are preserved but are incomplete address-bus measurements. The
sequential supplemental
[merged-address audit](../output_files/quartus-pcg-metadata-15a0655-lu6EJraq/merged-address-audit.log)
checks exactly **11 physical source registers / 11 capture registers**,
and reports **11 address register-pairs at every corner**, plus all eight
response-to-CPU register pairs. It adds no constraint or exception.

FDC `wd1793:fdc` retains the complete metadata identity and transport state:

| FDC state | Fitted bits / registers |
| --- | ---: |
| `metadata_entry` | 57 |
| `metadata_index` | 11 |
| `metadata_mark_address` | 20 |
| `metadata_deleted/second/busy/inflight/invalid/aborted/commit_mark/commit_crc/repair_crc/dirty` | 1 each / 10 total |
| Host `ack` shift register | 6, plus duplicate `ack[2]` |
| `sd_busy`, `sd_rd`, `sd_wr`, `mount_pending` | 1 each |
| `write_byte_seen`, `write_data`, `pending_read_crc`, `s_wrfault` | 1 each |
| Scanner `image_index.edsk_wrdata/wraddr/wren` | 57 / 11 / 1 |
| Scanner `image_index.d_crc/d_deleted` | 2 / 1 |

This is **98 metadata registers** plus the separately listed transport /
scanner state, not optimized-away metadata publication. Source inspection
confirms ACK shifting, falling-ACK bookkeeping and retained reset-abort
handling remain outside the stopped `ce` controller branch on `clk_sys`.
Fitted retention and positive metadata-register setup (minimum **+8.712 ns**
across the eight requested metadata queries) do not execute the transport,
prove short-reset behavior on hardware, or qualify Main's later disk matrix.

Both HPS snapshots survive: dimensions **20.0 ALMs / 152 registers** and
timings **30.1 ALMs / 263 registers**. Dimensions retains **72 held / 72
captured bits** of its declared 74-bit bus (constant interlace bits 0/1
removed); timings retains **128 / 128**. Dimensions has duplicates of both
`request` and `acknowledgement`; timings has an acknowledgement duplicate.
The four snapshot first-stage and four second-stage registers remain;
`mode_meta/mode_sync` are optimized away, as in the preceding fit.

Full names are preserved in
[all-registers.tsv](../output_files/quartus-pcg-metadata-15a0655-lu6EJraq/source/output_files/metadata_audit/all-registers.tsv)
and targeted
[registers.tsv](../output_files/quartus-pcg-metadata-15a0655-lu6EJraq/source/output_files/metadata_audit/registers.tsv).

## Eight-corner slack and endpoint audit

Sequential eight-corner STA used the completed original database:

```sh
quartus_sta sharpx1 -c sharpx1_turbo_video --multicorner=on --all_corners
```

Container 4 CPUs / 8 GiB, **21:15:30–21:20:15 UTC**; Quartus elapsed
**4:43**, CPU **7:49**, exit **0**, zero errors / eight timing warnings.
The detailed eight-corner extraction completed at **21:21:02 UTC**, elapsed
**0:45**, exit **0**, zero errors/warnings, with eight `CORNER_COMPLETE`
markers and `AUDIT_COMPLETE`. The merged-register supplemental extraction
completed at **21:23:18 UTC**, elapsed **0:17**, exit **0**, eight
`MERGED_CORNER_COMPLETE` markers and `MERGED_ADDRESS_AUDIT_COMPLETE`.
Successful report extraction is not a passing timing assertion.

All slack/TNS values below are ns, at 1100 mV. Minima cover reported
constrained clocks. Minimum pulse width belongs to the X3 PLL VCO phase.

| Model / temperature | Setup | Hold | Recovery | Removal | Min pulse |
| --- | ---: | ---: | ---: | ---: | ---: |
| Slow 100°C | -15.089 | -0.827 | -9.530 | +0.687 | +0.529 |
| Slow -40°C | -14.471 | -0.963 | -9.431 | +0.636 | +0.529 |
| Slow 85°C | -14.927 | -0.808 | -9.475 | +0.682 | +0.529 |
| Slow 0°C | -14.519 | -1.012 | -9.413 | +0.629 | +0.529 |
| Fast -40°C | -7.217 | -0.090 | -4.553 | +0.263 | +0.529 |
| Fast 0°C | -7.453 | +0.024 | -4.645 | +0.269 | +0.529 |
| Fast 85°C | -8.138 | +0.107 | -4.877 | +0.302 | +0.529 |
| Fast 100°C | -8.383 | +0.107 | -4.939 | +0.307 | +0.529 |

TNS sums **reported per-clock endpoint TNS**, not deduplicated physical
endpoints across mux alternatives. Removal/pulse TNS are zero throughout.

| Model / temperature | Setup TNS sum | Hold TNS sum | Recovery TNS sum |
| --- | ---: | ---: | ---: |
| Slow 100°C | -8038.924 | -0.827 | -553.548 |
| Slow -40°C | -7709.716 | -1.096 | -546.554 |
| Slow 85°C | -7958.273 | -0.808 | -550.261 |
| Slow 0°C | -7738.065 | -1.137 | -546.024 |
| Fast -40°C | -4028.212 | -0.271 | -263.772 |
| Fast 0°C | -4133.589 | 0.000 | -268.739 |
| Fast 85°C | -4462.715 | 0.000 | -281.496 |
| Fast 100°C | -4551.051 | 0.000 | -284.812 |

The following keys identify actual **worst setup/hold/recovery endpoints
at each corner**. `sys`, `video`, `HDMI` and `HPS` mean respectively the
32 MHz core PLL output, X3 PLL output, HDMI PLL output and 100 MHz HPS user
clock. Machine-relative names below are under `emu:emu|sharpx1:sharpx1`;
snapshot-relative names are under
`emu:emu|hps_io:hps_io|video_calc:video_calc`.

| Key | Start → endpoint | Launch → capture | Classification |
| --- | --- | --- | --- |
| S1 | `d[15] → hdmi_out_d[15]` | HDMI → video | Alternative clocks on shared `hdmi_tx_clk` mux; both registers use that clock in `sys_top.v` |
| S2 | `hdmi_dv_data[13] → d[13]` | HDMI → video | Same mux-alternative issue |
| H1 | `ascal:ascal\|i_ohsize[3] → ascal:ascal\|o_ihsize[3]` | video → HDMI | Real framework scaler input/output size crossing, separate `i_clk`/`o_clk` processes marked ASYNC in `ascal.vhd` |
| H2 | `dimensions_to_sys\|held_data[18] → destination_data[18]` | video → sys | Real bundled-data snapshot crossing |
| H3 | `dimensions_to_sys\|held_data[55] → destination_data[55]` | video → sys | Same crossing, positive worst hold at Fast 0°C |
| H4 | `sysmem_lite:sysmem\|sysmem_HPS_fpga_interfaces:fpga_interfaces\|f2sdram~FF_1795 → ascal:ascal\|avl_dw[121]` | HPS → HPS | Same-clock framework path, positive worst hold at hot fast corners |
| R1 | `emu:emu\|hps_io:hps_io\|ioctl_download → x1_pcg_access:cg_bus\|stage.01` | sys → video | Real asynchronous machine-reset release / recovery |
| R2 | `emu:emu\|hps_io:hps_io\|ioctl_download → turbo_scrn_meta[1]` | sys → video | Real asynchronous control-register reset release / recovery |

| Corner | Worst setup key | Worst hold key | Worst recovery key |
| --- | --- | --- | --- |
| Slow 100°C | S1 | H1 | R1 |
| Slow -40°C | S1 | H1 | R1 |
| Slow 85°C | S1 | H1 | R1 |
| Slow 0°C | S1 | H1 | R1 |
| Fast -40°C | S1 | H2 | R2 |
| Fast 0°C | S1 | H3 | R2 |
| Fast 85°C | S2 | H4 | R2 |
| Fast 100°C | S2 | H4 | R2 |

Worst removal at **every corner** is
`x1_vid:display|vid_reset → x1_vid:display|crtc6845s:crtc6845s|crtc_gen:crtc_gen|R_LAST_LINE`,
video→video; minimum **+0.263 ns at Fast -40°C**. Worst hold overall is
**H1 / -1.012 ns at Slow 0°C**. These are this fit's paths, not copied
from the prior snapshot audit.

Inherited clock-group matching misses `turbo_video_pll|oscillator`, so the
HDMI/video mux alternatives need targeted exclusivity review. That does
not remove the real H1/H2 and reset crossings. All-corner full paths
(`*_setup_worst.rpt`, `*_hold_worst.rpt`, `*_recovery_worst.rpt`,
`*_removal_worst.rpt`) and failing-endpoint summaries are retained in the
[audit directory](../output_files/quartus-pcg-metadata-15a0655-lu6EJraq/source/output_files/metadata_audit/).
The latter query uses `-less_than_slack 0 -npaths 0 -nworst 1`: one worst
path per endpoint, not exhaustive physical route/clock-alternative
enumeration. Reported negative setup/hold/recovery/removal row counts are
**847/1/59/0**, **847/3/59/0**, **847/1/59/0**, **846/3/59/0** for the
four slow corners above; **843/5/59/0**, then **843/0/59/0** at each
remaining fast corner.

## Independent machine CDC failures and held-data measurements

Slow 100°C examples show remaining machine paths even apart from S1/S2:

| Path | Direction | Setup slack ns |
| --- | --- | ---: |
| `hps_io\|status[0] → pcg_b\|mem_rtl_1\|…\|ram_block1a0~porta_we_reg` | sys → video | -10.813 |
| `display\|…\|R_V_SYNC → Cpu\|Z80CPU\|di_reg[2]` | video → sys | -9.729 |
| `dimensions_to_sys\|held_data[37] → destination_data[37]` | video → sys | -9.227 |
| `dimensions_to_sys\|request → request_meta` | sys → video first stage | -7.236 |
| `dimensions_to_sys\|acknowledgement~DUPLICATE → acknowledgement_meta` | video → sys first stage | -8.945 |
| `cg_bus\|request → request_meta` | sys → video first stage | -7.178 |
| `cg_bus\|ack → ack_meta` | video → sys first stage | -8.839 |
| `cg_bus\|font_cpu_addr[9] → access_addr[8]` (merged address) | sys → video | -8.000 |
| `cg_bus\|response[2] → cpu_q[2]` | video → sys | -9.173 |
| `font16\|loaded~DUPLICATE → loaded_meta` | sys → video first stage | -7.448 |

The CPU VSYNC return explicitly **predates and excludes `ac170be`**.
First-stage timing is conventional setup in this frozen SDC; same-clock
second-stage setup remains positive (Slow 100°C: PCG request **+21.640**,
PCG ACK **+28.082**, dimensions request **+21.724**, dimensions ACK
**+30.155**, font readiness **+21.591 ns**). This does not constitute
metastability or CDC signoff.

HPS-100-MHz↔sys timings-instance handshake/payload ordinary setup reports
find no constrained paths because inherited clock groups cut them.
The supplemental `-false_path` query exposes the cut payload (Slow 100°C
example `held_data[59] → destination_data[59]`, hypothetical **+2.410 ns**),
which is **not constrained-path acceptance**. The
[frozen SDC report](../output_files/quartus-pcg-metadata-15a0655-lu6EJraq/source/output_files/metadata_audit/frozen_sdc.rpt)
preserves the inherited clock groups; no targeted held-bus bound or new
first-stage exception was added.

`report_path -npaths 0 -pairs_only -summary` measures all **72 dimensions,
128 timings, 11 physically aliased PCG-address and 8 PCG-response pairs**
at every corner, including cut paths. These are pure reported data delays,
without a constraint or clock relationship/skew, not CDC acceptance.

| Corner | Max dimensions delay | Max timings delay | Max PCG address delay | Max PCG response delay | Same-clock sys setup | Same-clock video setup |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Slow 100°C | 11.740 | 2.363 | 1.445 | 11.648 | +5.932 | +8.485 |
| Slow -40°C | 11.150 | 2.307 | 1.390 | 11.016 | +6.299 | +8.234 |
| Slow 85°C | 11.604 | 2.344 | 1.428 | 11.483 | +6.077 | +8.545 |
| Slow 0°C | 11.122 | 2.304 | 1.395 | 11.018 | +6.454 | +8.422 |
| Fast -40°C | 6.205 | 1.185 | 0.709 | 6.187 | +11.599 | +16.216 |
| Fast 0°C | 6.505 | 1.233 | 0.733 | 6.506 | +11.443 | +15.977 |
| Fast 85°C | 7.549 | 1.385 | 0.822 | 7.534 | +10.883 | +15.196 |
| Fast 100°C | 7.845 | 1.434 | 0.848 | 7.804 | +10.686 | +14.934 |

The snapshot maxima are below the source comment's two-sys-period
**62.500 ns** budget, but that budget is **not enforced** by this frozen
SDC. Measured delay and positive same-clock setup do not prove held-bus
stability/skew, reset release, correct timing exceptions or hardware behavior.

## Requested same-clock core and shadow/write-payload addendum

The additional **read-only** existing-fit extraction completed at
**21:44:35 UTC**, elapsed **0:21**, exit **0**, zero errors/warnings,
with eight `SHADOW_PAYLOAD_CORNER_COMPLETE` markers and
`SHADOW_PAYLOAD_AUDIT_COMPLETE` in
[shadow-payload-audit.log](../output_files/quartus-pcg-metadata-15a0655-lu6EJraq/shadow-payload-audit.log).
Installed Quartus help confirms `report_timing` can combine endpoint and
clock filters; the script applies both `-from/-to` machine-hierarchy
filters and `-from_clock/-to_clock` filters. No map, fit, assembly, source,
assignment or exception was repeated/changed.

The earlier **whole-domain** VID minima include the framework scaler.
The table below instead gives **machine-only SYS/VID setup**, with both
ends under `emu:emu|sharpx1:sharpx1`. All are positive. SYS minima are
unchanged from the whole-domain query; machine-only VID has more margin.

| Corner | Machine SYS setup ns | SYS endpoint key | Machine VID setup ns |
| --- | ---: | --- | ---: |
| Slow 100°C | +5.932 | C1 | +11.863 |
| Slow -40°C | +6.299 | C1 | +12.489 |
| Slow 85°C | +6.077 | C1 | +11.999 |
| Slow 0°C | +6.454 | C1 | +12.473 |
| Fast -40°C | +11.599 | C2 | +17.152 |
| Fast 0°C | +11.443 | C2 | +16.882 |
| Fast 85°C | +10.883 | C3 | +15.935 |
| Fast 100°C | +10.686 | C4 | +15.658 |

Machine-relative exact SYS endpoints: **C1** `x1_sub:subCPU|sub_rom:sub_rom|DO[4]
→ x1_sub:subCPU|dpram:sub_w_ram|q_b[3]`; **C2** `ce[1] →
jt49_bus:psg|jt49:u_jt49|log[2]`; **C3/C4** `ce[2]~DUPLICATE →
cpu:Cpu|tv80e:Z80CPU|tv80_core:i_tv80_core|IR[0]/IR[3]` respectively.
The worst machine VID path is the **same at all eight corners**:
`x1_vid:display|crtc6845s:crtc6845s|crtc_gen:crtc_gen|R_MA[4] →
x1_video_ram:gram_r|altsyncram:mem_rtl_1|altsyncram_mgj1:auto_generated|ram_block1a7~portb_address_reg4`.
Full paths are `*_machine_sys_sameclock.rpt` and
`*_machine_video_sameclock.rpt` in the
[fitted audit directory](../output_files/quartus-pcg-metadata-15a0655-lu6EJraq/source/output_files/metadata_audit/).

Shadow selection is a **SYS→SYS combinational decode**, followed by frozen
CPU request registers; it is not a direct video-domain selector-memory read.
The measurement covers **56 selector registers → 18 request registers**
(`font_cpu_addr`, separately retained `frozen_addr`, `font16_request`,
`unsupported_request`), **412 connected register pairs at every corner**.
The eight-bit write payload reaches fitted RAM data register/port keepers
across all three PCG planes and both inferred read copies: **8 sources /
192 queried keepers / 192 connected pairs**. The held control group contains
**5 bits** (`plane[1:0]`, `write_request`, `high_speed_request`,
`unsupported_request`) to stage/address/response and RAM-WE captures:
**35 queried captures / 78 connected pairs**. These pair counts include
fitted RAM register/port representations and copies, not 192 logical
payload bits or 78 independent control bits.

All data-delay maxima below are ns. Previously measured complete physical
PCG address/response maxima are repeated to keep the settling review together.

| Corner | Shadow decode → SYS capture | Frozen address → VID | Write payload → VID RAM | Held control → VID | Response → SYS |
| --- | ---: | ---: | ---: | ---: | ---: |
| Slow 100°C | 10.039 | 1.445 | 2.225 | 4.932 | 11.648 |
| Slow -40°C | 9.984 | 1.390 | 2.063 | 4.826 | 11.016 |
| Slow 85°C | 9.970 | 1.428 | 2.192 | 4.894 | 11.483 |
| Slow 0°C | 9.917 | 1.395 | 2.081 | 4.829 | 11.018 |
| Fast -40°C | 4.634 | 0.709 | 1.154 | 2.400 | 6.187 |
| Fast 0°C | 4.792 | 0.733 | 1.210 | 2.486 | 6.506 |
| Fast 85°C | 5.311 | 0.822 | 1.386 | 2.728 | 7.534 |
| Fast 100°C | 5.467 | 0.848 | 1.439 | 2.797 | 7.804 |

Shadow capture setup is positive at every corner (**+20.915 ns minimum**,
**+26.444 ns maximum**). The worst shadow path is
`turbo_pcg_selector.selector|attr_valid[0] → cg_bus|font_cpu_addr[7]`.
Write payload and control remain **real held SYS→VID crossings** with
negative conventional setup at every corner:

| Corner | Write payload setup ns | Held control setup ns |
| --- | ---: | ---: |
| Slow 100°C | -8.649 | -10.512 |
| Slow -40°C | -8.372 | -10.227 |
| Slow 85°C | -8.578 | -10.426 |
| Slow 0°C | -8.388 | -10.241 |
| Fast -40°C | -4.217 | -5.031 |
| Fast 0°C | -4.317 | -5.154 |
| Fast 85°C | -4.575 | -5.474 |
| Fast 100°C | -4.642 | -5.557 |

Their worst endpoints are the same at every corner:
`cg_bus|payload[4] → pcg_g|mem_rtl_0|…|ram_block1a3~PORT_A_DATA_IN_6`
and `cg_bus|write_request → pcg_g|mem_rtl_1|…|ram_block1a0~porta_we_reg`.
Files `*_pcg_shadow_{delay,setup}.rpt`,
`*_pcg_write_data_{delay,setup}.rpt`, and
`*_pcg_control_{delay,setup}.rpt` preserve the measured paths.

**Settling classification:** the numbers are measured delay maxima, not
enforced SDC bounds. In an ordinary non-reset transaction, source request
data holds until ACK; the two-stage video request sampling places the first
address/control decision at least two VID periods after CPU acceptance,
and the RAM write a further video edge later. The response and ACK update
together; two-stage CPU ACK sampling precedes CPU capture by two SYS periods.
Thus **46.560846… ns (two fitted VID periods)** for forward settling and
**62.500 ns (two SYS periods)** for return settling are conservative
protocol review budgets, not new constraints or a metastability proof.
They require reset/abort stability and the exact capture paths to be reviewed;
normal-transaction spacing does not validate asynchronous reset release.
The shadow decoder already has ordinary same-clock acceptance; measured
10.039 ns does not make it a CDC problem.

**Actionable separation:** same-clock machine SYS/VID paths have positive
margin in this artifact. S1/S2 require a **mux-output exclusivity review**;
blindly adding X3 to global exclusive groups would also hide real scaler
H1 and other concurrently active crossings. Keep real SYS↔VID PCG payload,
handshake, direct CPU VSYNC return, scaler size and reset-release paths
visible. Review exact first-stage recognition/exceptions separately from
second-stage timing, and bound the full physical held buses including merged
address aliases and RAM data/WE captures. `274883f` may change reset paths,
but these old-fit results provide no timing verdict on that newer RTL.

## Synchronizer recognition, warnings and signoff limits

The fitted netlist has **17 unique retained first-stage registers** in the
requested core seams: four snapshot first stages, two PCG first stages,
one font `loaded_meta`, three `turbo_scrn_meta` bits (0/1/3), six
`turbo_black_meta` bits (0–5) and one `width_meta`. No `mode_meta` remains.
Second stages remain separately timed. Duplicated request/ACK/readiness
sources are not extra first-stage registers.

TimeQuest reports **386 synchronizer chains**, but **does not calculate
design MTBF because timing requirements are unmet**. Its full
[metastability report](../output_files/quartus-pcg-metadata-15a0655-lu6EJraq/source/output_files/metadata_audit/metastability.rpt)
recognizes the expected timings-instance `request → request_meta →
request_sync` and `acknowledgement → acknowledgement_meta →
acknowledgement_sync` chains, both Not Calculated / not included in design
MTBF. It does **not** list expected data-handshake chains for dimensions,
PCG, font readiness, SCRN, blackclip or width. Some such register names occur
inside **reset-origin** chains; that is not recognition of their intended
data CDCs. Seventeen retained first stages do not mean seventeen recognized
CDC synchronizers.

Quartus ignores **nine `async_reg` declarations (10335)**: three in
`rtl/sharpx1.v`, two in `rtl/x1_pcg_access.v`, one in `rtl/x1_font16.sv`,
two in `rtl/x1_cdc_snapshot.sv`, one in `sys/hps_io.sv`. No warning
suppression, SYNCHRONIZER_IDENTIFICATION override or new SDC exception was
added. Map/fit/primary STA have **114/11/1** warnings; inherited width,
parameter, implicit-net (`text_cs`), RAM collision, PLL reset/lock/compensation,
framework connectivity and ignored fitter/LogicLock assignments remain.

STA reports **0 illegal clocks / 0 unconstrained clocks**, but setup and
hold each retain **3 unconstrained input ports / 7 paths** and
**44 unconstrained output ports / 50 paths**. TimeQuest says the design is
not fully constrained for setup/hold. Timing-failed artifacts, incomplete
external I/O, real CDC/reset paths, unreviewed synchronizer treatment and
nominal PLL rates prevent hardware signoff. No hardware was deployed or
tested; no simulation/native result from newer HEAD was qualified here.

The audit leaves working-tree RTL, QSF, SDC, firmware/private assets, shared documents,
sibling repositories, and existing prior evidence untouched. Only this
report and unique ignored evidence outputs were edited; no staging, commit,
push, refit, duplicate build, stop or restart was performed.

## Final input validation and artifact identity

The final independent
[validation](../output_files/quartus-pcg-metadata-15a0655-lu6EJraq/resume-validation-final.json)
again checks **342/342 original manifest hashes against `git show 15a0655`**,
and **340/342 byte-identical fitted-tree inputs**. The same two
Quartus-serialized project files are the only differences, with unchanged
post-serialization hashes from the resume check:

| Generated project file | Final SHA-256 |
| --- | --- |
| `source/sharpx1.qpf` | `2b48ccb02902dc8c620fc74b678f8a8f2783264e6a56a83e10a8c7fae5f2d23c` |
| `source/sharpx1_turbo_video.qsf` | `5bb07fb8a1b5c3123441222f3f2830df976fd5977f05f62de345e36e9c8e3db7` |

The input manifests remain byte-identical to each other and retain the
original **`18719296…efd9ea`** identity; `checkpoint.tar` retains its
original **`b360b296…d0c182`** identity. Full hashes are listed above and
in validation. **342 is the actual checked count**, not 344. Prior
snapshot/font build documents, build log and SOF/RBF pass their preserved
[previous-evidence hash checks](../output_files/quartus-pcg-metadata-15a0655-lu6EJraq/previous-evidence.sha256).

RBF/SOF hashes are unchanged by all supplemental analyses. These identify
**timing-failed experimental artifacts**, not a release or hardware acceptance:

| Artifact | SHA-256 |
| --- | --- |
| [RBF](../output_files/quartus-pcg-metadata-15a0655-lu6EJraq/source/output_files/sharpx1_turbo_video.rbf) | `24ba6047f3e8814b1e007974bfb6a37b600b830a470ac36511336ea17c1ff32a` |
| [SOF](../output_files/quartus-pcg-metadata-15a0655-lu6EJraq/source/output_files/sharpx1_turbo_video.sof) | `e4897c645c8ff6488072f37db6fa46d1868957851f5255b793a1746e490f6aeb` |
| [Map report](../output_files/quartus-pcg-metadata-15a0655-lu6EJraq/source/output_files/sharpx1_turbo_video.map.rpt) | `ef02178027ab0937ab5f74e551fd616debc0a72b90f79df0362baeb08e90f793` |
| [Fit report](../output_files/quartus-pcg-metadata-15a0655-lu6EJraq/source/output_files/sharpx1_turbo_video.fit.rpt) | `1655c9373720b17fae43d7b8264a601a1471823c504ae0bced9fe06d93730322` |
| [Assembly report](../output_files/quartus-pcg-metadata-15a0655-lu6EJraq/source/output_files/sharpx1_turbo_video.asm.rpt) | `59c3689f9ca1f13bfba67aba30101eb50d5386cd9cd8c02dbe41d3de0bf96dc4` |
| [Preserved primary STA](../output_files/quartus-pcg-metadata-15a0655-lu6EJraq/single-corner-reports/sharpx1_turbo_video.sta.rpt) | `f54c0bb70e079cc063e032317e3111ffee7ac195e5e82bc3e8ac570a11008ac7` |
| [Preserved primary summary](../output_files/quartus-pcg-metadata-15a0655-lu6EJraq/single-corner-reports/sharpx1_turbo_video.sta.summary) | `d5b8451d9c35315004ff661f42a81fe948c0bef26efd4071bc19796e725751e8` |
| [Eight-corner STA](../output_files/quartus-pcg-metadata-15a0655-lu6EJraq/source/output_files/sharpx1_turbo_video.sta.rpt) | `08454cf991154cd4172d9f2669e02ae2e83356b32d4ad37d34c35a97ad2ca19e` |
| [Incomplete host build log](../output_files/quartus-pcg-metadata-15a0655-lu6EJraq/build.log) | `f09427bde70d98d808865698761ae90590cf52c38564cc8e8f908679440a4825` |
| [Original host manifest, exit 141](../output_files/quartus-pcg-metadata-15a0655-lu6EJraq/build-manifest.txt) | `06f323d1f5d5d2c88b933030d37216711be4beb2462139a2dc6dc03abdaf9f3a` |
| [Eight-corner log](../output_files/quartus-pcg-metadata-15a0655-lu6EJraq/all-corners.log) | `9d7db0f9fb86e6732d53dd1ca7dc04ff669ce94e8c2c11b24840fc2561b1957b` |
| [Completed register/path audit](../output_files/quartus-pcg-metadata-15a0655-lu6EJraq/audit.log) | `41b1b874424c984ef58b73743fa0f69d8e11282d2baa931db691d3e2abe1f805` |
| [Completed merged-address audit](../output_files/quartus-pcg-metadata-15a0655-lu6EJraq/merged-address-audit.log) | `65b7b1bfdaa43c22c3fdbfbc5a709b47cbff206c7ae72feb93e8982269c048fa` |
| [Completed same-clock/shadow/write-payload audit](../output_files/quartus-pcg-metadata-15a0655-lu6EJraq/shadow-payload-audit.log) | `158d5136dcc77774ef095666d68c95e522bcd452bf37017e7b6f0e2fcc4dedd8` |

No original aggregate successful exit status is available after the host
pipeline interruption; the preserved exit 141 remains explicit. Final stage
reports and artifacts establish fit/assembly/primary STA completion. All
requested eight-corner reports and retained-state/path checks are available;
inherited-cut timing paths have no ordinary constrained slack, as explained
above. Hardware timing/functional acceptance remains unavailable. The audit
is ready for review, with `ac170be`, `29755e7`, `6ea8da7`, `274883f` and subsequent
working-tree changes excluded from the artifact's source binding.
