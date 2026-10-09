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
an edge, twelve source phases, exact frame-event counts, configuration enable/
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
