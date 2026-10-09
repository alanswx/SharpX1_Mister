# Experimental combined Turbo Z video FPGA profile

October 9, 2026. New default-off `sharpx1_turbo_z_video.qsf` inherits
`sharpx1_turbo_video.qsf` and enables only the explicit
`X1_TURBO_Z_VIDEO_EXPERIMENT` wrapper macro. It requires Turbo foundation,
independent X3 video and no single-clock mode. It does not advertise a native
Turbo Z machine identity or complete CZ-880 behavior.

The later [destination-local ownership reset refit](TURBO_Z_OWNER_RESET_STATUS.md)
also completes, with six fresh pixel passes, but still fails eight-corner
setup/recovery/hold. Its current RBF/path/probe identities are recorded there;
the following first-fit evidence remains source-bound history.

The shared machine enables external palette CPU access/video, multi-mode
fetch/shifting, internal-eight palette and text/priority CPU/composition
together. Existing board revisions remain unchanged. SYS is requested at
32 MHz, VID at nominal 42.954540 MHz through the inherited experimental PLL;
fitted frequency must be recorded separately. DMA/SIO/FM/Kanji remain off;
audio remains unsigned PSG. Existing RGB12-to-eight-bit-component wrapper
outputs carry the result. No private BIOS/font bytes are added.

## Completed source-bound flow / failed timing

Ordinary, X3, FM, DMA and new combined-Z wrapper lint all finish zero with
Verilator 5.044 (`/tmp/x1-z-board-profile-lint.log`). This uses a PLL interface
stand-in, not physical clock simulation, Quartus or pixel acceptance. Both
build helpers pass `bash -n` and explicitly admit the new revision. Existing
shared-machine experimental pixel/control evidence remains source-bound;
lint does not qualify every combination of the jointly enabled features.

Read-only inspection of `misterubuntu` finds the authorized checkout clean at
`a7e100731cae6eb450737d1a7a0ebb78c487f57e` and no active Quartus flow. The next
step fast-forwarded from the user's fork and started the frozen-source native
17.0 helper for this revision. The full flow finishes zero, but reports
unmet timing requirements; it is not a hardware-qualified candidate:

- Source `c3906aeda8b5d3b560e772579a3ee3424d4d46de`.
- Frozen host folder `/home/alans/mister/SharpX1_Mister/output_files/quartus-linux-yoGgHbzg`.
- Observation log `/tmp/x1-quartus-c3906ae-turbo-z-build-retry.log`.

The first fetch fails before Quartus because the host calls the fork remote
`origin`, not `alanswx`; its log is preserved separately. The retry fetches
the explicit alanswx URL, verifies a clean checkout and expected commit, and
checks no competing Quartus process before launching. The flow finishes at
15:00:39 UTC after ten minutes seven seconds. Initial reports/RBF are retained
locally in `output_files/quartus-linux-yoGgHbzg/completed-flow/`; supplemental
all-corner/path reports are separate in `all-corners/`. A zero flow exit is
not timing acceptance. Supplemental STA started only after confirmed host-idle
state and finishes zero; no RTL or constraints were changed.

The exact jointly enabled video combination also builds a delay-aware C++
runner successfully. Six original CPU-written custom/retained-reset pixel
tests cover internal-eight, wide/tall/selected-screen 64-color, paired text
and full-color text. Frozen runner/emitter/oracle/ANK source are under
`verilator/obj_dir_headless/z-board-combined/qualification-CBgbK8/`, hashed
before the runs, and final hashes match. All six finish zero and byte-compare
their actual/expected frames exactly (704,000 pixels). Three-clock combined
control/reset and disabled negative also pass. See
[combined qualification](TURBO_Z_COMBINED_STATUS.md) for identities and scope.

Analysis and synthesis succeeds at 14:52:00 UTC: 33,378 registers,
3,192,734 block-memory bits, 32 DSPs and four PLLs. The report retains external,
internal-eight and text palette/control hierarchy. These are synthesis counts,
not final fitted resource acceptance. Static synthesis report and initial
manifests are retrieved under `output_files/quartus-linux-yoGgHbzg/map-stage/`.
Input-manifest hash `d2c2997791e136c79ab94b89dcd6f548beac20ab50606cd7c63e402138c1e73b`.

Initial reported timing: worst setup **−14.815 ns** and recovery **−13.494 ns**;
initial hold/removal/pulse minima are positive (0.190/1.170/0.529 ns). Several clocks
have nonzero setup TNS. Do not mask these with broad false paths or treat the
simulation passes as timing closure. All eight corner reports now complete;
their global hold/removal/pulse minima are 0.057/0.478/0.529 ns, with the same
negative setup/recovery extrema. Unconstrained I/O remains three input ports /
seven paths and 44 output ports / 50 paths. Generated-clock logging selects
50 MHz ×189/(10×22), approximately 42.954545 MHz for VID; final reports still
do not establish a measured board clock.

Final fit: 20,894/41,910 ALMs (50%), 33,273 registers, 3,192,734 RAM bits (56%),
400/553 M10Ks (72%), 32/112 DSPs (29%) and four/six PLLs. Experimental RBF:
`output_files/quartus-linux-yoGgHbzg/completed-flow/source/output_files/sharpx1_turbo_z_video.rbf`,
SHA-256 `6f0e3e27d07a0f2024bbd3e5297c3172e286852edfe0ebe3540ebf09c995bea8`.
This is an **unqualified** artifact, not a timing-passing replacement for the FM build.
The post-flow input audit reports 379 files matching and only `sharpx1.qpf`
changed (Quartus generated revision/date). Its exit is one, not a clean manifest
exit; inspected RTL/QSF/SDC inputs match the pre-flow manifest.

## Path diagnosis and next acceptance gates

Reporting-only sidecar extension runs on this same fitted database under
native 17.0.2, terminal zero (`/tmp/x1-quartus-c3906ae-z-sameclock.log`). Its
SHA-256 is `1d5ec6a2109b444e3b290fcd8b1dfbc5c7bfdf791287d67e52fbe6f71d4daa9a`.
Each selected clock must resolve uniquely; no timing exceptions are added.
At the reported Slow 1100 mV / 100 C corner:

| Same-clock domain | Worst setup | Worst recovery |
|---|---:|---:|
| System PLL | +6.728 ns | +10.477 ns |
| Independent video PLL | +8.123 ns | +11.368 ns |
| HDMI PLL | **−2.172 ns** | +3.364 ns |

The global worst setup path is `d[13]` → `hdmi_out_d[13]` with HDMI launch
and video latch clock labels. Both registers use the same physical selectable
`hdmi_tx_clk`: `sys/sys_top.v` selects core video or HDMI PLL. The inherited
`sys_top.sdc` clock-group pattern includes the original core PLL but not the
new `turbo_video_pll`. This explains why both alternative clocks are analyzed
together, not why every physical path is safe. The **same-HDMI-clock** version
of this path also fails (6.732 ns relationship; 9.578 ns data delay, mostly
routing), so merely excluding alternatives does not repair this fit.

PCG setup failures include held `response` → `cpu_q` (−9.562 ns), selector
payload → video response and first-stage ACK synchronizers. They require a
bounded bundled-data/toggle-handshake constraint audit, not a blanket false
path. Recovery failures include system-domain `ioctl_download` → video-domain
palette ownership reset (−13.494 ns) and video-reset release → CPU ownership
reset. The ownership module shares one reset across two independent clocks;
destination-local release and reset/drain semantics must be checked before
changing that interface.

Next: audit each crossing and its allowed transfer/reset latency; express
targeted clock-mux and handshake constraints without suppressing same-clock
HDMI failures; then refit and inspect all corners and unconstrained paths.
If HDMI routing still fails, use measured placement/path evidence for the
smallest necessary board-specific change. Same-clock positive reports above
cover one corner, not eight-corner closure. Native firmware/palette traffic,
exact reset frames and physical acceptance remain outstanding.

Later `89f8226` placement reconnaissance finds the existing final HDMI outputs
already packed into I/O registers: `sys/sys.tcl` selects FAST_OUTPUT_REGISTER
for data/DE/HS/VS, and the fitted report maps `hdmi_out_d[22]` into
`HDMI_TX_D[22]~output`. The same-HDMI-clock path at Slow 100 C is −2.485 ns,
with 9.898 ns data delay/9.119 ns interconnect (92%) and zero logic levels,
from `FF_X31_Y1_N32` to `DDIOOUTCELL_X30_Y0_N61`. Adding the existing packing
assignment again cannot repair it. Disabling I/O packing to improve an
internal path would also require external HDMI output-delay qualification,
not a claim based on unconstrained pins. No packing or pipeline-latency
change is selected. Intel's [Cyclone V output-register description](https://docs.altera.com/r/docs/683375/current/cyclone-v-device-handbook-volume-1-device-interfaces-and-integration/output-registers)
is a physical architecture reference, not proof of this fit's timing.

Prepared `scripts/constraints/hdmi_mux_candidate.sdc` extracts the prior
native mux-probe idea into an **unselected, analysis-only** candidate. It
requires three distinct masters and exactly three identified mux pins;
only divide-one generated clocks at `hdmi_clk_sw|outclk` are mutually
exclusive. No master-clock groups or pipeline RTL changes are added.
`test-hdmi-mux-sdc` checks the exact alias source/master/target/group scope
and rejects 18 missing/duplicate/wrong-pin/merged-master cases. CI selects
the mocked test; native pin matching/clock propagation remain pending.

The mux probe now accepts an optional explicit candidate argument. Candidate
reports have a distinct prefix and include both selectable same-clock modes
and both SYS/VID master directions at every corner, setup and hold. Existing
no-argument behavior and report naming remain available. Before any QSF
selection, confirm native scope and retained real same-clock/master crossings;
then refit and repeat coverage, I/O and physical HDMI acceptance. Suppressing
impossible alternative-clock pairings is not a remedy for real routing or CDC.

The exact candidate now runs on the preserved `ed3c332` fit, native 17.0.2,
terminal zero, at 18:09:28 UTC. Retrieved reports share its separate
`acceptance/` folder, prefix `mux_candidate_probe`. Native pin names and
distinct masters resolve; the QSF and fitted RBF are unchanged. At Slow 100 C,
alias HDMI setup still fails **−2.401 ns**; SYS → VID **−11.385 ns** and
VID → SYS **−9.091 ns** remain visible. Candidate global setup is −12.642 ns.
Original HDMI → original VID reports no paths after mux aliases; no claim of
retaining that particular master pair is made. The selectable same-clock and
SYS/VID setup/hold corner files are retained (bounded 100-path reports, not
exhaustive CDC acceptance). Across all eight HDMI same-clock setup reports,
440 paths remain with minimum −2.401 ns. The candidate is still unselected;
native syntax/scope success is not physical timing closure.

After the six-pin scaler experiment preserves all stage/downstream checks,
the mux candidate is now selected only for experimental Z, alongside the
scaler raw-input candidate, pending fresh fit. Its header update is
comment-only. `sys/sys_top.v` connects mux input 2 to HDMI and input 3 to VID,
with select restricted to 2/3; only output-clock aliases are exclusive.
Both masters remain concurrent, and no HDMI pipeline or I/O packing change
is made. Refit all corners and audit retained real same-clock/CDC paths,
output constraints and physical mode switching before any timing claim.

Selected aliases require separate post-fit reporting: the old original-HDMI
same-clock report no longer represents all final HDMI pipeline registers.
`scripts/quartus_x3_clock_paths.tcl` therefore requires all five distinct
clocks (SYS/VID/HDMI and both output aliases), reports same-clock setup/hold/
recovery/removal and six SYS/master-or-alias crossing directions at all eight
corners. It reads real project SDC and adds no exception. Mocked
`test-x3-clock-paths` validates 256 report scopes and rejects 15 missing/
duplicate/merged inventories before reporting; CI selects it. Native execution,
clock frequency/propagation and coverage review remain pending on the new fit.
Bounded 100-path reports are diagnostics, not full CDC or I/O acceptance.

## Selected reset/mux refit and real remaining crossings

Source `6133f27a2975f0ace85f9b341dc6384669a52a31` full flow finishes zero at
18:30:11 UTC after 8:42, frozen folder `output_files/quartus-linux-1wZ1xxDx`.
Original reports/RBF are local in `completed-flow/`, sequential native audits
in `acceptance/`. RBF SHA-256
`439cd3520d587e408168f7353be48e245f6751688c89bf4d52a0e4b19f9eca1a`
remains **unqualified**. Input manifest SHA-256
`68efe55068b056e21446db5a5ae16630e82fee5d765fc5e8a3619aa712a7e694`;
386 input files match, only Quartus-written QPF differs.

Sequential all-corner, inventories, global/clock, snapshot, PCG and scaler
audits finish zero at 18:36:31 UTC, log
`/tmp/x1-quartus-6133f27-native-acceptance.log`. All eight global minima:
setup **−47.729 ns**, hold **−1.275 ns**, recovery **+4.375 ns**, removal
+0.262 ns, pulse width +0.529 ns. Initial Slow 100 C hold is positive but
does not represent all-corner hold acceptance. Scaler recovery now reports
positive after the selected raw-input scope; physical reset review remains.

Alias inventory reports HDMI 6.732 ns /148.54 MHz, VID 23.280 ns /42.95 MHz,
both divide-one from their correct masters and inputs 2/3 at the mux output.
Internal post-mux HDMI same-clock setup now has minimum **+0.734 ns** across
440 reported paths/eight corners. This is a real routing improvement, not
full pipeline/I/O qualification. The reporter now also covers four related
master ↔ own-alias directions, in addition to six SYS crossings: 320 expected
reports. Mock scope controls pass; the extended native check finishes zero,
no warnings at 18:43:34 UTC, log
`/tmp/x1-quartus-6133f27-related-clock-acceptance.log`, reports separately in
`related-clock-acceptance/`. Master HDMI → HDMI alias setup/hold contains
464 rows/16 files, minimum +0.029 ns; VID → VID alias 384 rows/16 files,
minimum +1.759 ns. Both reverse directions are empty, not called passes.
These bounded reports do not establish exhaustive CDC or external pin timing.

The largest newly visible failure is `hdmi_out_vs~_Duplicate_1` → `vs_d0`,
alias HDMI → SYS, −47.729 ns with 46.472 ns data delay and zero logic levels.
`vs_d1` and `vsd` are also raw VSYNC endpoints. Source inspection finds
`vs_d0 <= HDMI_TX_VS` followed by `if(vs_d0 == HDMI_TX_VS) vs_d1 <= vs_d0`:
the second stage rereads the asynchronous signal. The configuration sampler
similarly uses first-stage `vsd` in edge detection. These are CDC-design and
physical first-stage scope questions, not permission for clock-wide cuts.
Next: destination-local synchronization before these SYS consumers, actual
edge/filter/configuration tests and stage-only timing review. Unselected
HDMI-OSD → video-mode data branches also remain reported; mode-aware static
analysis needs an explicit clock/data-selection contract, not a blanket
HDMI/VID exclusion. Physical switching/native software remain open.

The fresh full ordinary `make -C verilator test` also finishes zero with
143 PASS reports (`/tmp/x1-6133f27-full-local-test.log`). Its ordinary
delay-aware runner retains SHA-256
`166bf9129b272ce03b8d6c2d2d72ebf157627705fab59f569060a4c79cbd14e1`.
This is local regression execution, not new five-game/Turbo Z/hardware
qualification. No MiSTer is loaded.

```sh
QUARTUS_REVISION=sharpx1_turbo_z_video bash scripts/build_quartus_linux.sh --build
```

No timing exceptions or constraints are changed for this experiment. The
combined palette/control/GRAM reset and CDC paths need source-bound timing
and ownership review, all constrained corners and unconstrained I/O audit.
Physical scaler/analog output, native opacity/intensity/bank policy,
BIOS/software, pin timing and full multi-mode hardware qualification remain
open. No MiSTer is contacted/loaded. The prior FM RBF remains a different
feature profile; do not promote it to Turbo Z hardware evidence.
