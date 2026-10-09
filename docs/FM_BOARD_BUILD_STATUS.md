# Opt-in FM FPGA build status

October 9, 2026. `sharpx1_turbo_fm.qsf` separately enables
`X1_TURBO_FM_CPU` on `sharpx1_turbo_single.qsf`: actual existing PLL
28.571428 MHz single master, compensated MR16 timer, genuine JT51 CPU bus
and provisional signed PSG/FM stereo. Native FM IRQ remains unrouted.
DMA/SIO/Z/X3/Kanji are off. Existing board revisions stay unchanged.
Both baseline-clock and single-clock FM wrapper lint exit zero with a PLL
stand-in (`/tmp/x1-fm-board-profile-lint.log`), not a physical PLL simulation.
Shell syntax checks for both build helpers pass; no vendor RTL is changed.

Read-only host inspection confirms no active Quartus project before starting
this flow; the clean authorized checkout fast-forwards from the user's
alanswx fork. Quartus 17.0.2 Build 602 starts the source-bound frozen build:

- Source: `a7e100731cae6eb450737d1a7a0ebb78c487f57e`.
- Host snapshot: `/home/alans/mister/SharpX1_Mister/output_files/quartus-linux-Iypv1tpH`.
- Flow: `QUARTUS_REVISION=sharpx1_turbo_fm bash scripts/build_quartus_linux.sh --build`.
- Live local observation: `/tmp/x1-quartus-a7e1007-turbo-fm-build.log`.

The initial direct helper invocation exits 126 before starting any Quartus
flow because the tracked shell script is not executable; preserve
`/tmp/x1-quartus-a7e1007-turbo-fm.log`. Invoking it through bash fixes launch,
without chmod/source changes. The helper freezes/hashes inputs and refuses
competing Quartus jobs. No separate STA process runs during this build.

The build is **running**, not a completed fit/timing/RBF acceptance. Retrieve
terminal reports/manifest, audit input mutations, run supplemental corners
only after the build/host are free, and record actual FM resource/path
retention. Do not reuse earlier feature-disabled RBF/timing claims for this
FM-enabled source. No MiSTer is contacted, loaded or claimed available here.
Native software, IRQ, exact pins, analog and physical sound remain open.
