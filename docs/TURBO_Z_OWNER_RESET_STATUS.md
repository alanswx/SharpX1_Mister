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

## Pending source-bound acceptance

The new delay-aware combined C++ runner builds successfully. Six unchanged
full-duration custom/warm pixel cases are launched from a newly frozen runner
in `verilator/obj_dir_headless/z-owner-combined/qualification-5S0L7l/`,
pre-hashed before launch. Executable SHA-256
`6c2d657da0821c25bdeeac5ab13ecc0d7817405010592a659d3b336c193e02df`;
logs `/tmp/x1-z-owner-pixel-{internal8,paired-text,full-text,wide64,tall64,dual64}.log`.
They must reach terminal status, exact frame comparisons and post-hash checks
before being described as passing. The prior six passing cases bind the
previous shared-machine SHA, not this release change.

Ordinary snapshot model remains v17: this new state exists only in an enabled
X3 palette profile, whose C++ runner is non-savable. A fresh ordinary delay-aware
build and `test_timing.py` finish zero, including reset/enable/delayed-event,
repeatability and FST checks (`/tmp/x1-z-owner-baseline-timing.log`).
`test-reset-release test-turbo-pcg-access` also finishes zero
(`/tmp/x1-z-owner-pcg-reset.log`), including 16,395 high-speed CDC transactions.
These focused checks do not establish full baseline/game/snapshot acceptance.
The full ordinary delay-aware suite is now running separately
(`/tmp/x1-z-owner-baseline-full.log`), with no completion claim yet.

A source-bound Quartus flow is now confirmed live on `misterubuntu`:
source `c05edb03a6ea587e3ca9e23600872a2e9bb40a65`, revision
`sharpx1_turbo_z_video`, frozen build folder
`/home/alans/mister/SharpX1_Mister/output_files/quartus-linux-nyZrupn1`,
observation log `/tmp/x1-quartus-c05edb0-z-owner-build.log`. The checkout was
clean and the host idle before fast-forward/build; actual `quartus_sh` and
`quartus_map` processes are observed. It must finish before supplemental STA,
input/report/RBF audits or any timing claim. No hardware is contacted/loaded.
This change does not
fix the same-clock HDMI routing failure or constrain bundled-data transfers.
Destination-local reset recovery, first-stage synchronizers, all corners and
native/physical reset acceptance still require source-bound timing review.
