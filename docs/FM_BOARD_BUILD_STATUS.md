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
- Completed local observation: `/tmp/x1-quartus-a7e1007-turbo-fm-build.log`.

The initial direct helper invocation exits 126 before starting any Quartus
flow because the tracked shell script is not executable; preserve
`/tmp/x1-quartus-a7e1007-turbo-fm.log`. Invoking it through bash fixes launch,
without chmod/source changes. The helper freezes/hashes inputs and refuses
competing Quartus jobs. No separate STA process runs during this build.

## Completed fit and timing audit

The full flow terminates zero at 13:50:56 UTC (seven minutes four seconds),
zero errors/162 warnings. Fit uses 21,104/41,910 ALMs, 34,086 registers,
3,145,726 memory bits, 398 M10Ks, 33 DSPs and three PLLs. The retained FM
bus/JT51 hierarchy has 1,891 registers, five M10Ks/one DSP; the audio sampler/
converter/mixer hierarchy has 80 registers. Entity ALM estimates are not a
simple additive difference from a separately fitted baseline. ROM unused
write-side inputs and inherited PLL reset/lock warnings remain unsuppressed.

[Local experimental FM RBF](../output_files/quartus-linux-Iypv1tpH/source/output_files/sharpx1_turbo_fm.rbf):
SHA-256 `6c2ac5c94ec604b54be6cc7365f631e2767c92a60b7a3353aa1da53b06913568`.
Reports, manifests and RBF are retrieved; the complete frozen source remains
on the host. Post-build audit: 379 inputs, 378 match; only Quartus-rewritten
`sharpx1.qpf` differs (post hash
`a28f240f7b5511bd2ccc52d5fa5d8f4056ee0c8b09c0b41293f5d421a388b244`).
Audit exits 1, not a full-manifest pass. Host `rg` was unavailable; retrieving
the audit and parsing locally confirms the single exception. Checkout stays
clean. Log `/tmp/x1-quartus-a7e1007-post-input.log` preserves that failed rg.

Initial reported Slow 1100 mV 100 C STA: five tables/33 numeric rows,
no negative slack/nonzero TNS. Min setup/hold/recovery/removal/pulse:
0.535/0.152/3.417/1.020/1.122 ns. These initial reports are preserved locally.

After the full flow and read-only host-idle check, supplemental eight-corner
STA plus detailed path reports terminate zero. Independently parsed **40
tables/264 numeric rows** have no negative slack/nonzero TNS. Across all
corners, minima are **0.206/0.041/3.417/0.440/1.122 ns** respectively.
Supplemental artifacts are separate under `all-corners/`; STA report hash
`39f58bd7b163fd45e9265521a04e2c21ddf395fe6b3684b243071c980780e5c2`.
No constraints, RTL, fit or assembly are changed for this analysis.

Three input ports/seven paths and 44 output ports/50 paths remain
unconstrained. This is **not full timing closure** or physical sound
acceptance. Do not substitute feature-disabled RBF evidence for this build.
No MiSTer is contacted/loaded; availability is requested for an owned test.
Native software, IRQ, exact pins, analog and physical sound remain open.
