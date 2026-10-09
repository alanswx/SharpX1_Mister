# Experimental Z palette ownership: destination-local reset release

October 9, 2026. The first combined Z fit identifies recovery paths from
system-domain reset sources into video-domain palette ownership, and from
video-reset release back into CPU ownership. That source had one shared
`core_reset || video_reset` input driving both clock domains. Its source-bound
[failed timing evidence](TURBO_Z_BOARD_BUILD_STATUS.md) is preserved.

The owner now has a default-off `LOCAL_RESET_RELEASE` parameter. When selected,
two existing `x1_reset_release` instances assert immediately from the original
reset request and release only after two edges of their respective destination
clocks. Neither domain's release output drives the other's asynchronous reset.
The machine selects this only for an enabled palette owner with independent
X3 video (`TURBO_VIDEO_MASTER`), and supplies `core_reset`, not the video-domain
release signal. Ordinary non-X3 ownership keeps its prior raw-release behavior.
RAM/palette contents, addressing, lease protocol and WAIT semantics are unchanged.

## Executed checks

October 9 follow-up: `test-reset-release` now adds native half-periods
15,625/17,500/11,640/25,000 ps to the three inherited ratios. It tests short
asynchronous pulses, release 1 ps before an edge, four reassertions during
pending release, and a stopped clock. All seven cases finish zero, no emitted
warnings (`/tmp/x1-reset-release-native-final.log`); both PCG SDC inventory
tests also pass. This is unchanged reset RTL and digital phase/reassertion
evidence, not metastability, minimum physical pulse width or a reset-path
timing exception. Raw asynchronous pipeline-input recovery and downstream
synchronous release/placement must be audited separately.
An [input-pin-only timing experiment](VIDEO_RESET_TIMING_EXPERIMENT.md) now
passes its mocked exact-scope/negative tests; native STA is still unexecuted
and it is not selected by a project. No reset timing exception is qualified.

`make -C verilator test-z-palette-owner test-z-palette-owner-local-reset`
finishes zero (`/tmp/x1-z-owner-local-reset.log`), with no emitted warnings:

- Three inherited raw-release adapter/actual-RAM cases remain passing.
- The same three connected cases with local release pass active/stopped-video
  WAIT, exact physical writes, held strobes, read-response retention,
  consecutive leases and retained display contents.
- Three new directed cases acquire a real owned lease, stop both clocks,
  assert/deassert reset between edges, and require display to remain masked
  without VID edges. CPU restart cannot invent a grant while VID remains
  stopped. Video release takes two edges, followed by a fresh lease.
- Reset with only CPU stopped permits independent video restart, but CPU
  reset remains asserted until two CPU edges. A new grant and final drain pass.
- The unchanged directed oracle with local release disabled fails specifically
  at `display released without video edges`, not a watchdog. Negative log
  `/tmp/x1-z-owner-reset-negative-dBvMER`.

All three video half-periods are 17,500/11,640/25,000 ps; CPU is 32 MHz.
Checks observe real handshakes and outputs, plus the reset-release wire;
they do not inject ownership registers. Digital tests do not simulate
metastability or establish placement/MTBF/native ASIC behavior.

`test-machine-z-combined-control-reset` also finishes zero at all three video
rates, including stopped-VID pending control reset and the missing-priority
negative. `lint-wrapper-turbo-z-video` finishes zero with its PLL stand-in;
log `/tmp/x1-z-owner-machine-regression.log`. These are control/reset and
wrapper checks, not new exact palette pixels or FPGA timing closure.

| Current source | SHA-256 |
|---|---|
| Palette owner | `1d7ac1118368f1dd0896764f67aee0996c4173e85e03c5afea366c09b4aad54d` |
| Shared machine | `060d753fe9e82c292e013a4ab902fc3612c4dea79ab787ab2caabb84c57be578` |
| Directed reset fixture | `56d53f4150484a805fedff009532a0554d39dc7b96f917932da9f027f92fe2bc` |

## Fresh combined pixel and ordinary baseline acceptance

The new delay-aware combined C++ runner builds successfully. Six unchanged
full-duration custom/warm pixel cases finish zero from a newly frozen runner
in `verilator/obj_dir_headless/z-owner-combined/qualification-5S0L7l/`,
pre-hashed before launch. Executable SHA-256
`6c2d657da0821c25bdeeac5ab13ecc0d7817405010592a659d3b336c193e02df`;
logs `/tmp/x1-z-owner-pixel-{internal8,paired-text,full-text,wide64,tall64,dual64}.log`.
Independent byte comparisons of all six actual/expected PPMs pass, and the
final executable/emitter/helper/ANK manifest matches its pre-launch hashes.
Total: 704,000 exact pixels with retained reset/no refill. This covers the
same selected internal8/paired-text/full-text/wide64/tall64/dual64 custom/warm
cases as the previous qualification, not the complete cold/identity/front/order
matrix or native software/hardware. Prior passing cases remain historical.

Ordinary snapshot model remains v17: this new state exists only in an enabled
X3 palette profile, whose C++ runner is non-savable. A fresh ordinary delay-aware
build and `test_timing.py` finish zero, including reset/enable/delayed-event,
repeatability and FST checks (`/tmp/x1-z-owner-baseline-timing.log`).
`test-reset-release test-turbo-pcg-access` also finishes zero
(`/tmp/x1-z-owner-pcg-reset.log`), including 16,395 high-speed CDC transactions.
The full ordinary delay-aware suite now finishes zero with 140 PASS reports
(`make -C verilator test HEADLESS_DIR=obj_dir_headless/z-owner-baseline`,
`/tmp/x1-z-owner-baseline-full.log`). Final executable hash matches its initial
identity. This does not establish optional-Z/native Turbo/hardware acceptance.

The separately rebuilt ordinary fast/SDL/savable runner also finishes zero,
and `test_snapshot.py` passes continuation/RAM/clock phase, old-v16/time/
truncation negatives, clock mismatch and joystick persistence/override/live
SDL checks (`/tmp/x1-z-owner-snapshot.log`). Fresh ordinary binaries are
byte-identical to the previously fully qualified v17 runners:

| Ordinary runner | Fresh SHA-256 (matches prior v17) |
|---|---|
| Delay-aware | `166bf9129b272ce03b8d6c2d2d72ebf157627705fab59f569060a4c79cbd14e1` |
| Fast/SDL/savable | `73181a8f87e1194a8899bb2801263548ecb5c926ef7d8f78a87cb5983648c06f` |

This supports isolation of the opt-in ownership change from ordinary models.
The [prior full suites and five-game evidence](BASELINE_V17_STATUS.md) remain
valid for these identical executables/unchanged inputs, but are not new runs,
not enabled-Z/native Turbo evidence and not qualification of a new RBF.

A source-bound Quartus flow completes on `misterubuntu`:
source `c05edb03a6ea587e3ca9e23600872a2e9bb40a65`, revision
`sharpx1_turbo_z_video`, frozen build folder
`/home/alans/mister/SharpX1_Mister/output_files/quartus-linux-nyZrupn1`,
observation log `/tmp/x1-quartus-c05edb0-z-owner-build.log`. The checkout was
clean and the host idle before fast-forward/build. Full flow exit zero at
15:29:09 UTC, elapsed 9:24, does **not** mean timing passed. Local initial
artifacts are under `output_files/quartus-linux-nyZrupn1/completed-flow/`.
Input audit: 379 files match; only Quartus-rewritten QPF fails its hash. No
hardware is contacted/loaded. Final fit: 21,055 ALMs, 33,304 registers,
3,192,734 RAM bits, 400 M10Ks, 32 DSPs and four PLLs on 5CSEBA6U23I7.

Eight-corner STA finishes zero but fails setup/recovery/**hold**:
global minima −14.883/−9.870/−0.143 ns respectively; removal/pulse minima
remain +0.397/+0.529 ns. Unconstrained I/O remains three inputs / seven paths
and 44 outputs / 50 paths. Actual RBF SHA-256
`3e078fdbc6e0940d0b4f14f740cf0644d181ca9a9e9e589b5081934d4129e5bf`,
local `output_files/quartus-linux-nyZrupn1/completed-flow/sharpx1_turbo_z_video.rbf`.
It is **unqualified**, not a replacement timing-passing Turbo Z build.

Detailed Slow 1100 mV / 100 C reports give same-clock setup margins
SYS +6.774 ns, VID +9.744 ns, HDMI **−2.240 ns**; same-clock recovery
SYS +10.462 ns, VID +15.538 ns, HDMI +3.952 ns. Remaining worst recovery
paths now terminate at video reset-release pipelines, not raw palette
ownership registers or video release feeding CPU ownership. This is the
expected structural correction, not permission to ignore asynchronous-reset
recovery or claim all-corner same-clock closure. PCG setup remains negative.

The Fast 1100 mV / −40 C hold sidecar identifies the −0.143 ns path as
`video_calc`'s `dimensions_to_sys` snapshot `held_data[67]` →
`destination_data[67]` (VID → SYS). It is a handshake-held bundle, not a
same-clock HDMI hold failure. Proper bounded payload and synchronizer
constraints still need protocol review and fitted checks; do not blanket
false-path the bus. Log `/tmp/x1-quartus-c05edb0-z-fast-hold.log`, terminal zero.
The reporting-only helper's optional `fast-hold` mode explicitly selects
Fast 1100 mV / −40 C; unsupported analysis names fail. Current helper SHA-256
`74786bee41a1ab816d1329dbf3a8ba73e44162d060eb482da999f847b10b8713`.
Its unchanged default report branch is re-executed on this fit and also
finishes zero with no warnings (`/tmp/x1-quartus-c05edb0-z-final-default-paths.log`).

## Executed reporting-only mux probe

`scripts/quartus_hdmi_mux_probe.tcl` creates two divide-by-one generated clock
aliases only at `hdmi_clk_sw|outclk`, with explicit HDMI/video masters and
mutually exclusive alias groups. Both original PLLs remain concurrent, so it
does not exclude their master clocks design-wide. Unique clock/pin collections
are mandatory; empty or ambiguous matches fail. The script reports before/
after same-HDMI-clock paths and remaining master crossings, plus global paths.
It is not connected to project assignments and changes neither QSF nor SDC.

The [Quartus 17 generated-clock API](https://resources.altera.com/quartushelp/17.0/tafs/tafs/tcl_pkg_sdc_ver_1.5_cmd_create_generated_clock.htm)
documents explicit masters and `-add` for multiple clocks at a node; the
[clock-group API](https://resources.altera.com/quartushelp/17.0/tafs/tafs/tcl_pkg_sdc_ver_1.5_cmd_set_clock_groups.htm)
supports logically exclusive groups. This supports the proposed syntax and
scope, not proof of constraint coverage. Native 17.0.2 execution starts only
after the flow is terminal and host idle. Initial and expanded probes both
finish zero. Expanded script SHA-256
`6e305e437b58d156e25cfd3f5c6a7f2c606cd5bb2344f0e62ff6572874b398fa`,
log `/tmp/x1-quartus-c05edb0-z-mux-cdc.log`, local reports in
`output_files/quartus-linux-nyZrupn1/mux-cdc/`.

The aliases retain the real same-HDMI-clock failure: −2.250 ns, versus
−2.240 ns before alias uncertainty rederivation. Both CPU/VID directions
remain visible with unchanged extrema before/after: SYS → VID −11.209 ns,
VID → SYS −9.325 ns. Original HDMI → original VID reports no remaining paths
after separating the mux output; this does **not** prove other crossings safe.
Global setup remains −12.391 ns, including alias-HDMI VS → system sampling
and original HDMI scaler data → video-selected mux registers. Video-selected
same-mux setup is +14.098 ns at this one corner. The probe has not been added
to project SDC/QSF and does not change the RBF. Clock alternatives, data
selection, CDC synchronizers and bounded transfers still need a production
constraint audit and refit; merely grouping aliases does not repair this fit.
