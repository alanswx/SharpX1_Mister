# DMA Ready/IOR interrupt increment

October 6/7, 2026. This advances work group 2, not full DMA/Turbo/Z acceptance.
`x1_dma #(.COMPLETION_IRQ(1), .READY_IRQ(1))` is an explicit device-only
qualification profile. Existing machine/board profiles leave `READY_IRQ=0`;
their command rejection and generated state remain unchanged. No new machine
snapshot identity is invented or old state converted.

## Primary contract and implementation

Read the official [Zilog UM0081 peripheral manual](https://www.zilog.com/docs/z80/um0081.pdf),
printed 86–88, Figure 36, and 110–111/B7. IOR is distinct from IP and IUS.
B7 clears IOR; RETI releases IUS. Its prescribed handler sequence is B7,
ENABLE DMA, RETI. Retaining either latch prevents bus requesting. B7 does not
unconditionally enable DMA; RETI does not clear IOR.

Original RTL arms a physical Ready inactive→active transition with WR4's
associated interrupt-control bit 6 and WR3 delivery enable, using WR5 polarity.
IOR persists across ACK, AF and RETI until B7/A3/C3/hardware reset. Its level
feeds the existing pending/service engine. IDLE also gates the very edge
setting IOR, preventing a premature BUSRQ. IUS gates requests independently.
Associated data bytes retain precedence over commands. Vectors use current
status, not fabricated EOB/match. Physical Ready, not FORCE READY, supplies
the edge detector.

Inputs are synchronous to the master clock. Edge/service/reset processing
continues with transfer CE stopped; this is not silicon's exact two-clock
latency or asynchronous-pin timing. Pre-bus Ready edges are captured; edges
during ownership are not queued. Continuous-mode suppression agrees with the
inspected prose, but Byte/Burst ownership transitions, already-active arming,
changed polarity/live configuration and force-Ready combinations still need
qualification before integration. Ready/completion auto-restart IRQ, pulse
control and reserved interrupt-control bits remain fail-closed.

## Executed checks

```sh
make -C verilator test-dma-ready-irq test-dma-ready-irq-cpu \
  test-dma-native-irq test-dma-native-irq-cpu \
  test-dma test-dma-compare test-dma-search test-dma-service test-dma-service-cpu \
  HEADLESS_DIR=obj_dir_ready_irq
git diff --check
```

The register fixture programs real streams, all 256 vectors, both Ready
polarities, modification on/off and Byte/continuous/Burst modes at CE=1/4/7:
3,072 cases per rate (9,216 total). Half inject Ready with CE stopped, half
immediately before an enabled IDLE edge. It checks zero premature transfers/
ownership, IEI retention, held ACK/vector, RETI-alone re-pending, B7→ENABLE
blocked by IUS, exact four-read/four-write data after RETI, no duplicate event
with Ready held, a fresh Ready edge, AF/A3, sampled stopped-CE reset and
rejected auto-restart IRQ.

Three actual TV80 cases program native WR4/WR6, IM2/HALT, RR0 readback and
handler B7→ENABLE→RETI at CE=1/4/7. Ready arrives during sixteen stopped-enable
master edges; genuine ACK is held for eighty further stopped edges. DMA must
not own the handler bus. CPU polls the actual last destination byte before
success; data/guards, 4R/4W, one ACK/RETI and released service are checked.
This is a single-owner diagnostic mux, not shared-machine/native acceptance.

The pre-final broad regression exits zero in
`/tmp/x1-dma-ready-default-regressions.log`. Final combined acceptance is
recorded separately in `/tmp/x1-dma-ready-qualified.log`, terminal exit zero
on final source: all nine targets execute, including 36,864 completion-register
cases, original transfer/restart/comparison/search/service matrices, twelve
native completion CPU cases and twelve service-only CPU cases. The inherited TV80 DIRSET
missing-pin warning remains visible under existing `-Wno-fatal`; no new warning
category is suppressed.

The first three-mode fixture left its loop variable at reserved mode 3 before
a directed reset setup. It fails configuration in
`/tmp/x1-dma-ready-irq-modes.log`; selecting continuous mode fixes that fixture,
not its acceptance condition. A separate ignored RTL copy removes the IOR
request gate: it builds but fails the RETI-alone retained-IOR/no-request check,
exit one, in `/tmp/x1-dma-ready-negative.log`. Production keeps the gate. The
failure detects premature requesting; its error text does not imply the
mutated RTL actually cleared IOR.

Final-source SHA-256 identities:

| Artifact | SHA-256 |
|---|---|
| `rtl/x1_dma.sv` | `fbd1854912952c39f62e202ceff1419c79f1c5851b5d14489256ad4a89cd4f7a` |
| Ready register executable | `8d7a50e157a250e3ce8582326be64a79e87c66d5acb8911fe0f69dbad05b2d32` |
| Ready CPU executable | `4e7cf7eb86a03e28950279c3847218bf6b817a8cd050386bc52fa5b6a0a58ab0` |

## Remaining gates

Live/masked/late-arm and Byte/Burst owned Ready edges, Ready loss, combined
completion/restart causes, B7/A3/C3 and short-reset races, Ready-aware shared
machine identity/IRQ integration, SIO/FDC/multi-device and native Turbo tests.
Exact pin timing, source-bound Quartus/CDC and physical MiSTer testing remain
required. The recommended RBF predates this increment and does not enable it.
No work group is marked complete. Hosted CI includes the two new targets;
its terminal result is a separate gate.
