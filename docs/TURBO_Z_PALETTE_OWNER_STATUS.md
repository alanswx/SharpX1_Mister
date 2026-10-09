# Functional palette ownership checkpoint

Original `rtl/x1_z_palette_owner.sv` is now connected to the opt-in shared
CPU palette experiment. It is a **provisional blank-window lease policy**, not
native IX0868CE BUSRQ/WAIT pin timing, a DMA arbiter or a finished Z renderer.
The [CPU report](TURBO_Z_PALETTE_CPU_STATUS.md) records the corrected width,
actual CRTC/CPU wait evidence and preserved late-read failure/fix.

The video domain acknowledges a held CPU request only during `video_blank`,
then masks `display_allowed`. Two-stage level synchronizers transfer request
and grant. CPU permission requires an acknowledged lease and a pending real
access. The CPU request is held through acknowledgment even if an early
selector-only bus operation finishes. On release, a DRAIN state waits for
grant to fall before another request can acquire: a previous delayed grant
cannot admit a new operation. Video resumes only after request deassertion
crosses back. Common reset masks both owners and flushes protocol state.

A future display consumer must honor `display_allowed` and its response tags;
the storage's unused internal reads can still clock, but collision values must
remain unobservable. No deterministic dual-clock read/write collision data is
claimed. An abnormally long/stopped CPU lease remains exclusive even if blanking
ends; this can suppress display pixels. Exact native active-display behavior,
deadline/availability and fitted metastability/CDC constraints remain gates.
The CPU-only profile still disables display reads. The separate
`TURBO_Z_VIDEO` [full-color experiment](TURBO_Z_VIDEO_STATUS.md) now honors
display permission and response tags with actual identity/custom pixels and
retained-reset checks. Current RBFs are unchanged.

## Executed connected fixture

```sh
make -C verilator test-z-palette-owner
make -C verilator test-z-palette-access
make -C verilator test-machine-z-palette-video
```

Verilator 5.044 with assertions and no new warning suppressions. The owner
fixture connects the real adapter and three-component dual-clock palette RAM;
CPU clock 32 MHz, independent video half-periods 17,500 / 11,640 / 25,000 ps.
It checks actual RAM operation counts and display RGB12 before/after leases:
active-video and physically stopped-video WAIT, held-strobe single writes,
all sixteen values, retained reads, pending-reset no replay, and a granted lease
held across a physically stopped CPU and blank exit. Reset before that lease's
write edge cancels it without modifying retained colors. Sixteen further writes
with just one inactive CPU edge each require sixteen fresh video leases.
Ownership is checked on both physical clocks; no CPU/video overlap is allowed.
This fixture drives bus strobes rather than instantiating a CPU; the separate
shared-Z80 CRTC tests qualify real execution and 12.54 ms held I/O.

All three owner profiles and all nine exhaustive adapter profiles exit zero in
`/tmp/x1-z-palette-owner-tail-unit-final.log`. Owner/adapter runner SHA-256:
`a6c28d472ea6f06bf20344a14e2c1a4f6201c3a5a025792fd1d2e4238e1561ac` /
`4e5782ad739b186f2dab6cd13736000afcae57f87e553eba9e04035506e5b390`.
Owner RTL / fixture SHA-256:
`bd37fdbf73aada9f75474ee98a9e7bc5bda200df58b3f00e45c747f57b9b2380` /
`39a60e1ef0610d0bd0f57195f3630a2bae38e37ca197939766f1bb36d0726705`.
The extended adapter also asserts retained nibble validity after bus inactivity
and clearing on the next OUT; the nine-profile matrix still exhausts all
indices/components/values and delayed-backend validity, not CPU instructions.

Isolated mutations removing blank-window admission or bypassing grant-drain
fail the unchanged owner fixture: active-display write escape and CPU/video
overlap respectively. Original early logs and final source-bound retries are
separate: `/tmp/x1-z-owner-negative-{active,drain}-final-{build,run}.log`.
No production RTL is mutated. These checks are not hardware timing acceptance.

Next: connect actual CRTC/GRAM/pixel and synchronous palette response stages;
qualify display deadlines, resets/mode exits, text/reduced modes and DMA;
then native software and combined Quartus/CDC/physical RGB12 acceptance.
