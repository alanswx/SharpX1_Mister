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
