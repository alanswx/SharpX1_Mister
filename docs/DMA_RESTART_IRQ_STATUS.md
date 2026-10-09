# DMA auto-restart EOB interrupt increment

October 8, 2026. Work group 2 remains incomplete. This is an explicit,
device-only `x1_dma #(.COMPLETION_IRQ(1), .RESTART_IRQ(1))` profile; ordinary
machine/board profiles retain `RESTART_IRQ=0`. No private assets are needed.

## Primary contract

[Zilog UM008101-0601](https://www.zilog.com/docs/z80/um0081.pdf), printed
80–81 (PDF pages 98–99), specifies an interrupt per automatically repeated
block, requiring acknowledgement for continued operation, while EOB status
stays clear. Printed 102 explicitly prohibits Status Affects Vector with
auto-restart/EOB IRQ. Printed 60 describes clearing the byte count and
reloading both address counters from their starting buffers.

The new profile captures a separate terminal event at an accepted last source
read (pure search) or destination write (transfer). The existing real count
and both address reloads run unchanged; no fake EOB flag supplies the IRQ.
The event releases ownership and prevents the next request until ACK. ACK
clears the terminal event; IUS independently blocks transfers until RETI.
Service/ACK/reset processing remains active with transfer CE stopped.
AF retains an already pending event. A3/C3/hardware reset clear the event.
An already-started pair still drains under owned reset and real WAIT.

This first profile accepts EOB-only, unmodified-vector interrupts. Mixed
match/Ready, stop-on-match restart, pulse and reserved configurations remain
rejected. This does not redefine the full DMA milestone: combined causes,
late arming, buffer changes, long-count boundaries and exact silicon timing
still require implementation/qualification. Existing restart-without-IRQ and
completion/Ready profiles keep their previous behavior and command rejection.
The subsequent [reload-buffer correction](DMA_RELOAD_BUFFER_STATUS.md) reproduces
and fixes a first-destination/live-buffer defect and extends both-direction,
three-block and delayed-grant tests. Its state/acceptance scope is separate
from this historical first increment.

## Executed checks

```sh
make -C verilator test-dma-restart-irq test-dma-restart-irq-cpu \
  HEADLESS_DIR=obj_dir_restart_irq
```

Both targets exit zero on final source in `/tmp/x1-dma-restart-final.log`:

- 4,608 register-stream cases: every vector, transfer/pure search,
  Byte/Burst/continuous, CE=1/4/7. Two real blocks per case, each four reads
  (four writes for transfer), exact data/addresses, both counters/count reload,
  no next-block access before ACK, IEI/AF retention, held ACK/stopped CE,
  RR0 with clear EOB and ACK-cleared IP, ENABLE blocked by IUS, RETI and A3.
- Six owned read/write reset cases, with WAIT held and CE stopped, drain
  exactly one pair. Three stopped-CE held-ACK resets clear retained state.
- Three real TV80 programs use native WR4/WR6, IM2/HALT, genuine ACK and
  handler RR0/ENABLE/RETI. Each services two block interrupts, executes 8R/8W
  in two grants, verifies destination guards and retains the first ACK/vector
  across eighty stopped-enable master edges. The handler disables after the
  second block; this is a diagnostic bus mux, not native Turbo firmware.
- Status-modified restart configuration is rejected and cannot transfer.

An ignored RTL negative control substitutes cleared EOB status for the
terminal condition. It builds, then exits one with the unchanged fixture's
`restart block overran retained interrupt` assertion in
`/tmp/x1-dma-restart-negative.log`. This catches the missing independent event,
not merely compilation or a screenshot. No new warning suppression was added;
the inherited TV80 DIRSET warning remains visible in CPU builds.

## Remaining acceptance

The broader nine-target default/completion/Ready/search/service regression
also exits zero in `/tmp/x1-dma-restart-default-regressions.log`: original
transfer/restart boundaries, comparison/search/stop matrices, 36,864 completion
register cases, Ready's 9,216 cases and owned/grant/mask extensions, and all
27 existing CPU service/completion/Ready profiles. The combined command is:

```sh
make -C verilator test-dma-native-irq test-dma-native-irq-cpu \
  test-dma-ready-irq test-dma-ready-irq-cpu test-dma test-dma-compare \
  test-dma-search test-dma-service test-dma-service-cpu \
  HEADLESS_DIR=obj_dir_restart_irq
git diff --check
```

Final executed SHA-256 identities:

| Artifact | SHA-256 |
|---|---|
| DMA RTL | `94f8874bb997eac790f0d0abc75bdfbcfba8fe7206dea8a14512ab0e33d05670` |
| Restart register executable | `860a4953e13082241360a63f3cfa3683817278ba8e4bccf12d5d8b2e88e68cc5` |
| Restart real-CPU executable | `d26c74b66d73c3c893af42362e89ba0905e8d1ee84a6f94c7cf34196fed06107` |

Hosted CI now includes both new targets, but hosted acceptance is not inferred
from local success.
Shared-machine profile identity, FDC/SIO/multi-device service, snapshots,
native Turbo firmware, Quartus and physical MiSTer qualification remain open.
The subsequent [shared restart increment](DMA_RESTART_MACHINE_STATUS.md) now
qualifies its explicit profile identity, actual CPU handler snapshots and A/B
sector-boundary service; SIO, mixed/native/reset/hardware gates remain open.
The current recommended RBF does not enable this parameter. No work group or
Turbo Z milestone is marked complete by this increment.
