# DMA / Kanji shared-bus qualification

## October 10 local gate

`TURBO_DMA_KANJI_EXPERIMENT=1` is a separate shared-machine **SV diagnostic**
profile requiring Turbo, DMA, first-level Kanji and X3 video. Ordinary C++
runners and boards do not enable it; there is no combined snapshot identity,
native game acceptance or new RBF. The existing default prohibition remains
and its rejecting control is executable.

```sh
make -C verilator test-machine-dma-kanji
make -C verilator test-machine-kanji-reset test-machine-kanji-loader
```

The original asset-free fixture uploads its program and synthetic 131,072-byte
physical font through ioctl. The actual Z80 initializes the CRTC, PPI/DAM and
selector metadata, then programs an incrementing `1400..140F` I/O-source DMA
to RAM. It verifies all sixteen bytes with actual CPU instructions after the
real BUSRQ/BUSACK transfer. No forced grant or patched CPU/RAM is used.
SYS is 32 MHz; VID uses an integer-picosecond accumulator at nominal
42,954,540 Hz. This is delay-aware Verilator 5.044, not hardware timing.

Eight cases pass: loaded/absent font crossed with cold completion, owned-read
reset with stopped SYS, owned-read reset with stopped VID, and blocked font
upload during owned reset drain. Stopped VID holds the actual read strobe,
WAIT, shared address and frozen Kanji address for eighty SYS observations,
without starting a destination write. The wrapper counters count **strobe
starts**, not completed responses; the pending read already counts as one.
Reset drains exactly one pair, preserves the font, then restarts the retained
IPL. Actual CPU payload checks and 17 read/write starts qualify the restarted
transfer. Absent ROM terminates with sixteen FF bytes, not invented glyphs.

## Confirmed upload-start defect and repair

Before the repair, writes respected `ioctl_wait`, but Kanji upload START did
not. A DOWNLOAD edge while DMA owned a font response could invalidate readiness
and flag a live-upload error even though no byte was admitted. The fixture
holds the attempt over an actual SYS rising edge and asserts that the reset
drain still owns the bus on that edge; a pulse entirely between edges is not
an adequate negative control.

The pre-repair executable SHA-256 is
`f037c0f38385c10705bb5087e7e54de14371aa9774216879bbae6a7ac5867fde`.
Its loaded/reset-kind-3 case fails at `blocked upload invalidated owned Kanji
font`; evidence is `/tmp/x1-dma-kanji-upload-edge.log`, with the binary retained
in ignored `obj_dir_headless/dma-kanji-machine/pre-upload-gate-runner`.
The machine now gates upload START as well as byte writes with `!ioctl_wait`.
All eight unchanged positive assertions pass after this repair. Existing five
CPU pending-read reset cases and nine malformed-loader cases also pass.
The final fixture additionally checks every loaded physical font byte against
the independent synthetic pattern, not just the sixteen transferred bytes.
Logs: `/tmp/x1-dma-kanji-fixed-adjacent.log` and
`/tmp/x1-dma-kanji-guard.log`. The latter requires the precise default-profile
rejection, not just any nonzero simulator exit.

The final `test-machine-dma-kanji` gate also uploads one deliberately corrupted
font byte through the real loader. The actual CPU rejects it with marker EE;
the negative requires `CPU payload/restart mismatch marker=ee`, not a timeout.
Final eight cases and both rejecting controls complete zero in
`/tmp/x1-dma-kanji-final-controls.log`. Fixture SHA-256:
`b36ad7ec39e213fb1a131b37fa9c682e8e67d9d319ed91191306d61d40dd01d4`;
executable SHA-256:
`bfe2e9868af75997bf0ce974ef5262734ea367104ea8e4ebc1732dc515851b85`.
There are no fixture/shared-wrapper warnings in this build; inherited device
pin/width warnings remain accommodations, not correctness guarantees.
Four RAM, five PCG and five CRTC owned-reset cases also complete zero in
`/tmp/x1-dma-kanji-adjacent-dma.log`. Wrapper DMA lint completes zero using its
PLL stand-in, not Quartus or hardware. The ordinary `test`/headless/lint sequence
is still running under session 70443 in
`/tmp/x1-dma-kanji-baseline-regression.log`; it is not yet a completed gate.
CI now schedules the asset-free combined diagnostic; no hosted result is claimed.

## Still required

- Combined renderer pixels, RTC/mailbox/IRQ and real FDC Ready transfers.
- Fixed, decrementing, sequential/non-byte and mixed interrupt ownership.
- A separately identified non-savable combined native runner before Arcus
  trials; this fixture alone does not justify deleting all profile guards.
- Native physical Kanji identity/order, scanline WAIT and second-level Z ROM.
- Current-source synthesis, CDC placement/timing and physical MiSTer tests.

This advances the full DMA/Kanji coexistence goal; it does not close it.
