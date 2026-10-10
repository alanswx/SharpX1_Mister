# Fixed FDC byte-slot scheduler

October 10, 2026. Original standalone implementation and executable gate;
not connected-controller, native X1 clock, disk or board acceptance.

## Contract and implementation

The inspected MB8877A datasheet gives 16-us MFM / 32-us FM bytes at 2 MHz;
1 MHz doubles these periods. Thus a byte occupies 32 / 64 FDC CLK cycles.
Its lost-data summary specifies failure to respond within one byte time,
but the guaranteed MFM service windows are shorter: 27 chip clocks for reads
and 23 for writes (13.5/11.5 us at 2 MHz, doubled at 1 MHz). These maxima
are not measured exact lost-data transition edges. This scheduler establishes
byte cadence only, not the DRQ service or sampling deadline. See the separately
inspected [primary timing/design evidence](HD_FDC_BYTE_TIMING_DESIGN.md).
Source: local `references/manuals/MB8876A_MB8877A_Datasheet.pdf`, SHA-256
`3358e0cefabb858261177d3f658c63db3f4142f9bfb826339135d5c19ab1b91b`.
This does not resolve CZ-880 MB4107 clock routing or capacity-to-clock policy.

`rtl/x1_fdc_byte_slots.sv` implements exact 32/64-enable boundaries. All state
uses SYS clock; `fdc_ce` denotes a real FDC-clock edge. Start establishes a
fresh slot and snapshots density, without counting that edge as elapsed.
Stop/reset dominate start and suppress any coincident boundary. Paused enables
hold elapsed position. Boundary is combinational and consumed on that SYS
edge, not a delayed pulse. CPU servicing cannot rephase the stream because
the scheduler has no CPU-service input.

Density snapshot is an explicit functional interface policy, not a resolution
of illegal DDEN changes during BUSY. The caller must obey the documented
fixed-density contract. Reset is synchronous to SYS. This module is deliberately
outside `machine.qip` until its controller consumer exists; no board or runner
uses it, and ordinary state/default behavior is unchanged.

## Executed evidence

```sh
make -C verilator test-fdc-byte-slots
```

Frozen source/fixture/checker copies run under Verilator 5.044 with timing and
assertions enabled, without warning suppressions. The positive checks both
densities at six enable spacings (1/2/4/8/16/32 SYS edges): 84 recurring boundaries,
paused enables, density retention, explicit restart, stopped/inactive state,
reset-before-due and coincident stop/start priority. An independent countdown
checks boundary before each active SYS edge and active state afterward. SYS
is explicitly 32 MHz; consecutive boundary timestamps must match the expected
physical period. At enable spacings 16/32, MFM intervals are 16/32 us and FM
32/64 us. These are explicit nominal clocks, not inferred Sharp drive modes.
The review follow-up checks first-boundary elapsed time at all 96 combinations
of density and start phase at these two rates, active restart at terminal count
and terminal-count enable pause. A real posedge consumer must agree with the
pre-edge oracle after every edge. Total coverage is 181 consumed boundaries.

A disposable mutation moves only boundary assertion from remaining=1 to 2.
The same frozen fixture rejects that early boundary at its exact edge oracle.
Compilation/timeout cannot count as this negative. All three original source
hashes are checked again after both runs.

The initial positive/negative passes retain three warnings (timescale and
fixture conditional widths) in `/tmp/x1-fdc-byte-slots-first.log`. They are
corrected, not suppressed. The ten-profile warning-free recheck completes
zero in `/tmp/x1-fdc-byte-slots-clean.log`. The expanded physical-clock check
also completes zero without warnings in `/tmp/x1-fdc-byte-slots-physical.log`;
its historical frozen evidence:
`/var/folders/sv/859j7h856t5gzg1kv3nnqdj40000gn/T/x1-fdc-byte-slots-8ygqdphq`.

| Source | SHA-256 |
| --- | --- |
| Scheduler | `cc8708f013ef810df1eab5dd49069f00345f444bd146e5c8aa1a29fb2a432ba7` |
| Edge fixture | `339a7b499b3c7426d5f5546733325fd1fd63014f13267a5e1f6d0add93f730fc` |
| Frozen checker | `32b803ac39818ba2d23ec55b5c956ca45195ed924716a4d9afe0785ba8fa1121` |

## Connected work still required

The independent review finds no blocking helper defect and separately exercises
irregular CE/held-start/synchronous consumption in a scratch fixture. Its
retained start-phase/consumer follow-up above completes zero in
`/tmp/x1-fdc-byte-slots-phase-final.log`, with frozen inputs under
`/var/folders/sv/859j7h856t5gzg1kv3nnqdj40000gn/T/x1-fdc-byte-slots-40mw_wpg`.
Current default-warning builds are clean. Separate `-Wall` review reports
declaration-initialization style warnings (`PROCASSINIT`); no claim of a clean
all-warning lint is made. Start must be an intentional event: held start
continually reloads. Never derive stop combinationally from boundary; boundary
already depends on stop, so doing so creates a feedback loop.

Replace CPU-service-paced transitions, not merely their initial 15-enable
delay. Reads need a real holding data register, arrival-driven advance and
lost-data overwrite semantics. Writes need a captured holding byte independent
of live CPU DIN, initial-underrun abort and subsequent zero insertion. Qualify
accepted-byte/boundary races with CPU and DMA, last-byte completion, READ
ADDRESS CRC, multi-sector continuation, cancellation and retained reset.
SD prefetch/flush and metadata ACK ownership remain separate from byte slots;
host latency must not silently stretch an already-running byte stream.

Resolve the board FDCCLK source independently of capacity class; retain default
state/layout and existing disk tests. The slot engine alone implements neither
FM encoding, rotational/search/mechanical timing nor READ/WRITE TRACK. Actual
connected CPU/media traces, native software, Quartus timing and hardware are
still required. See [the complete disk plan](TURBO_HD_DISK_PLAN.md).
