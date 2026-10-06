# DMA interrupt-service foundation (not machine IRQ support)

October 6, 2026. Original GPL-2.0-or-later `rtl/x1_dma_service.sv` and
`rtl/x1_dma_vector.sv` advance
work group 2. It is intentionally not in `rtl/machine.qip` or instantiated
by `x1_dma.sv`; existing board and simulator machine behavior is unchanged.
This is an executed service-engine and connected diagnostic increment,
not a completed DMA interrupt implementation or native Turbo acceptance.

## Primary contract and boundary

[Zilog UM008101-0601](https://www.zilog.com/docs/z80/um0081.pdf), printed
79–88, 100–103 and 108–111: completion interrupts follow bus release;
acknowledgement clears IP and sets IUS; IUS prevents further DMA requests
and downstream interrupt service. RETI releases service regardless of
upstream priority, and an uncleared condition can interrupt again.
AF disables delivery without clearing IP/IUS. A3 clears both, disables
interrupts and unforces Ready. AB can expose conditions retained while disabled.
The caller retains those conditions and implements enable/Ready programming;
the new engine implements IP/IUS, delivery gating and accepted-vector holding.

The engine consumes one rising ACK/RETI level, not one transaction per
enabled transfer tick. It has no transfer CE. A stretched ACK remains one
service even when candidate status, IEI or interrupt-enable changes. An ACK
that began while ineligible cannot become a second ACK merely because
ownership/priority later changes. Reset quarantines an already-held ACK/RETI;
reset/clear takes precedence over acknowledgement. Engine reset requires a
sampled system-clock edge; sub-clock reset capture belongs at the wrapper.

`bus_owned` must include outstanding BUSACK drain, not only BUSRQ. IRQ is
suppressed until that ownership ends. `block_bus_request` covers IUS; the
operation engine separately implements pending-event stopping and IOR. A3's
disable/Ready changes also belong to that caller. The vector boundary accepts
a caller-formed current-status candidate and holds the accepted byte through
ACK. The separate vector module forms bits 2:1 from current EOB:match
status when modification is enabled, preserving every other base-vector bit.

Printed Figure 44 was newly rendered/visually inspected at PDF page 121
(`/tmp/x1-dma-wr4-121.png`). Its vector rows show repeated zero values,
despite its prose describing cause-specific modification. This is not enough
to assign an encoding alone. Local MAME uses cause values 0/1/2/3, but is not
an authority for correcting the primary scan. The February 1980 publisher
[product specification](https://www.bitsavers.org/components/zilog/z80/Z80_DMA_Product_Specification_Feb80.pdf)
was downloaded from its trailing-edge mirror after the original host returned
403 and the web screenshot failed. PDF page 9/Figure 8b was rendered and
visually inspected: 00 Ready, 01 match, 10 EOB, 11 both in bits 2:1. This
corroborates the modification table independently of MAME and enables the
original vector module. Local ignored file and hash are in the
[manual inventory](../references/manuals/README.md). Likewise Figure 34's
8B/IP-reset label disagrees with the later status prose; do not silently
translate either into an integrated command policy.

## Executed diagnostics

```sh
make -C verilator test-dma-service test-dma-service-cpu \
    HEADLESS_DIR=obj_dir_v12_dma_service_vectors
```

Verilator 5.044, timing/assertions enabled. Standalone **4,096 cases** exhaust
256 vector bytes × condition/enable/ownership/IEI combinations. Directed
An additional **2,048 current-status vector cases** exhaust every base byte,
modification on/off and all four flag combinations, including odd vectors.
Directed cases cover retained disabled conditions, AF preserving IP/IUS, A3 priority,
held invalid ACK, current-service blocking, upstream-blocked RETI,
re-pending uncleared conditions, reset quarantine and held RETI not releasing
a subsequent service. No private assets or forced internal registers.

The connected original-program diagnostic passes **12 profiles**: four real
DMA completions at CE=1/4/7. Source/guard initialization, IM2 table, DMA
register stream and handler are executed by the real shared Z80 wrapper.

| Completion | Actual source reads | Destination writes |
|---|---:|---:|
| Sequential transfer EOB | 4 | 4 |
| Pure continuous match stop | 3 | 0 |
| Sequential Byte match stop | 2 | 2 |
| Pure continuous terminal match plus extra read | 5 | 0 |

Real DMA sticky flags drive the condition; no injected IRQ or debug PC/RAM
changes stand in for completion. An explicit upstream IEI input gates service
until the actual CPU reaches HALT, avoiding assumptions about DMA/EI/HALT
instruction order. The pending request survives that block. One genuine
IM2 ACK supplies D4 (EOB), D2 (match) or D6 (both), genuinely formed from
current DMA flags rather than a synthetic cause tag. Both CPU/DMA enables
then stop for 80 system edges while
the ACK vector and IUS remain stable. The CPU resumes, executes its handler,
disables DMA and clears real completion flags with 8B, stores A9 to RAM and
executes RETI. Exact transaction totals, destination bytes/guards, one ACK,
one RETI, deasserted IRQ and released service are asserted.

Fixture-only F1/F2 ports configure the service-enable seam and report results;
they are not Sharp port proposals or substitutes for tested WR4 programming.
Base D6 and modification-enable are fixture settings, not yet WR4-programmed.
The terminal-match/EOB operation policy remains the explicit functional
candidate described in [search-stop status](DMA_SEARCH_STOP_STATUS.md),
not silicon precedence acceptance. This fixture references actual DMA flags
but is not the shared machine's bus bridge.
Final-source log: `/tmp/x1-dma-service-vectors-four.log`.
Earlier fixed-vector gates pass in `/tmp/x1-dma-service-unit.log` and
`/tmp/x1-dma-service-cpu-priority.log`. Original early-fixture failures remain
in `/tmp/x1-dma-service-cpu.log`, `...-loaded.log` and `...-trace.log`: initial
WR0=0 was incorrectly checked before LOAD, and IRQ could service before the
unconditional HALT. They were resolved at the diagnostic boundary, not by
weakening transaction/handler assertions or changing the machine RTL.
`/tmp/x1-dma-service-vectors.log` retains an initial vector-fixture failure:
pure continuous N=3 exhausted its three-read block on the early match's extra
read, so EOB correctly produced D6, not the intended isolated-match D2. Pure
profiles now program N=4 (sequential still N=3/N+1), separating early match
from EOB while retaining exact three/five-read assertions.

## Remaining integration gates

Final-source diagnostics exit zero. The only CPU-build warning is inherited
TV80 core missing `DIRSET`; no new width warning or suppression was added.

| Artifact | SHA-256 |
|---|---|
| Service RTL | `134615ec1531816b70a70bc2404c60d1f9da6796cd98eae4622caf2b8fa7437f` |
| Vector RTL | `32b70449999705e5c6a7637cce538069a7888ce199ee4bda75cd9314f76db25e` |
| Standalone executable | `101cef6efaf746764d27e7b137ef3eb7275a9f4b79bfd3c3c7a339a4540346b5` |
| Connected CPU executable | `f1b2d3667507ec634d64d04426ed83eb272fc7ada0f26c243cd1d684d84c7a99` |

1. Resolve 8B/IP semantics; implement real WR3/WR4/WR6 programming and RR0
   pending. Vector encoding is corroborated, but its native command path is not.
2. Connect stop-qualified match/EOB events, including automatic restart's
   stop/ack/resume contract; preserve genuine extra-read/count behavior.
3. Implement Ready-before-bus IOR and B7/ENABLE/RETI ordering, physical vs
   forced Ready, masked/disabled event retention and command collisions.
4. Add bus-level ACK/RETI and request inhibition to the opt-in shared machine;
   qualify CPU/FDC/PCG/SD resets and multi-device daisy-chain priority/service.
5. Requalify native firmware, snapshot model identity and existing generated
   machine/game tests. Current-source Quartus/CDC and hardware gates remain.

The new two targets are added to hosted diagnostics. A successful local run
is not its hosted terminal result, a new fitted RBF or full IRQ support.
