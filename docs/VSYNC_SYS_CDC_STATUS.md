# Experimental SYS VSYNC synchronization

The independent-X3 Turbo Z board revision now samples `HDMI_TX_VS` through
`rtl/x1_vsync_sys.sv` before the SYS-domain frame-wait filter and PLL/configuration
gate. Two initialized registers sample on every SYS edge, with no CE/reset.
Only the second stage feeds those consumers. Their existing filter and gate
equations remain unchanged; the input acquires two sampling stages.
Ordinary board revisions retain the inherited raw input branch.

This addresses the raw reread in the old frame filter and first-stage use in
the configuration edge detector. The preceding `6133f27` fit exposes raw VSYNC
SYS paths, including a −47.729 ns path. That historical fit does not qualify
this new implementation. No new timing exception is added: actual fitted
stage inventory, first-stage fanout, downstream timing, physical placement/
MTBF, pulse widths and mode switching still require acceptance.

## Local acceptance

```sh
make -C verilator test-vsync-sys-controls
```

The actual helper and mirrored existing consumer equations pass nine clock
combinations: SYS half-periods 15,625/17,500/10,000 ps crossed with source
half-periods 3,366/11,640/25,000 ps. Checks cover initialized low output,
two-sample latency, output changes only on SYS edges, a transition 1 ps before
an edge, twelve source phases, exact frame-event counts and actual mirrored
frame-wait retention/clear behavior, configuration enable/
disable/not-ready behavior and a stopped SYS clock with a held input level.
Raw-input and one-stage negative controls both fail the fixture. CI selects
the same target. This is not full `sys_top` simulation or metastability modeling.

The helper is a level synchronizer, not a short-pulse queue. It intentionally
does not promise delivery of a pulse entirely between SYS sampling edges.
Hardware VSYNC width must be checked for each supported output mode.

The raw VSYNC HPS interrupt and `hps_io`'s separate 100 MHz measurement path
are unchanged. Feeding them a SYS-qualified level would not qualify their
different clock-domain contracts. They remain separate review items.

Machine RTL, ordinary game runners and private assets are unchanged.
Fresh Quartus fitting, eight-corner timing and physical/native tests remain
open. This change does not make the Turbo Z RBF timing-qualified.

## In-flight source-bound fit and reporting

Checkpoint `e32bd6967577580ea9724e5d0bc3bf4f4129b45a` is pushed to alanswx.
The authorized idle Linux host starts its frozen-source full flow in
`output_files/quartus-linux-1uPykZZ7`; local observation log is
`/tmp/x1-quartus-e32bd69-vsync-build.log`. This records a started build, not
a completed fit or RBF qualification. Ordinary and experimental wrapper lint
finish zero with inherited warnings; those checks do not elaborate `sys_top`
or the VHDL scaler.

`scripts/quartus_vsync_sys_paths.tcl` prepares reporting-only acceptance of
exactly two actual, distinct `sample_pipe[0/1]` registers. Missing, duplicated,
replicated, misnumbered and unresolved stage inventories reject before reports.
Its 64 scopes cover input, stage transfer, all reported stage-zero fanout and
stage-one consumers, setup/hold at eight corners. No exception is issued;
raw input timing may fail, and empty reports are not acceptance. Native
connectivity/physical fanout must still be inspected in addition to these
bounded path reports. Mock coverage and eight rejecting inventories pass via
`make -C verilator test-vsync-sys-paths`; CI selects it. Native execution waits
for the build to become idle and original reports to be preserved.
