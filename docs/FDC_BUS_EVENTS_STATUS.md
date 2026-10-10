# FDC transaction capture prerequisite

October 10, 2026. Original standalone digital adapter, not connected to the
WD controller, CPU/DMA or a board. Ordinary machine source lists are unchanged.

## Interface policy

`rtl/x1_fdc_bus_events.sv` accepts once at the first selected, bus-enabled SYS
edge of a raw read/write strobe. Simultaneous read/write is ineligible. Once
accepted, deselection/reselection cannot rearm it; raw release must be sampled
on a SYS edge. Release tracking continues when bus enables stop. Inputs must
already be SYS-synchronous and address/transaction identity must stay stable
until release; the helper has no address input or physical pin CDC.

Before acceptance, an eligible read sees the live register. After acceptance,
its captured response stays stable despite later data arrivals or deselection.
Write capture changes only on acceptance. `accepted_write_value` supplies live
DIN to a same-edge consumer, then the captured value; pairing `write_accept`
with the old post-edge `captured_write` would be a one-transaction error.

Synchronous reset clears transaction identity even with CE stopped. A strobe
still held after reset can therefore be accepted again; connected reset drain
must prevent unwanted replay. Command completion/abort/media changes must not
reset this helper while a read remains held. The helper does not acknowledge
DR on bus release; the future DR/DSR consumer must handle one accepted
generation, data-port decode and explicit same-edge arrival/service policies.

First-edge acceptance is an experimental digital interface, not native RE/WE
waveforms, propagation delays or exact 27/23-clock service failure thresholds.
See [primary timing and integration design](HD_FDC_BYTE_TIMING_DESIGN.md).

## Executed evidence

```sh
make -C verilator test-fdc-bus-events
```

Frozen RTL/fixture/checker run under Verilator 5.044 with timing/assertions and
default warnings fatal. The independent event/response model and synchronous
consumers qualify **260 reads and 260 writes**, all 256 data values, arbitrary
holds, CE-independent raw release, delayed eligibility, deselection/reselection
while held, conflicting strobes and CE-stopped held-read/held-write reset.

Three independently built disposable mutations must fail the unchanged oracle:
repeated read acceptance, live rather than held read response, and previous
transaction data delivered to the same-edge write consumer. Build failure,
timeout or an unrelated assertion cannot count. Source hashes remain unchanged
after all four runs. The initial 260/258 gate passes; review additions increase
write count to 260 without changing RTL. Final log
`/tmp/x1-fdc-bus-events-reviewed.log`, terminal zero; frozen inputs/logs:
`/var/folders/sv/859j7h856t5gzg1kv3nnqdj40000gn/T/x1-fdc-bus-events-678phpvw`.
All four default-warning builds are clean. Independent review finds no blocking
defect under the stated interface contract; optional `-Wall` reports initializer
and fixture blocking-counter style warnings, not an all-warning-clean result.

| Source | SHA-256 |
| --- | --- |
| Bus helper | `9a9c99affd1c2ef3cba26a47959df64398e6d313a53e43a2b0e8270f4aa20a83` |
| Event fixture | `c7a36b2fb2f1f050b5218e7b6e98c31531e595373c820bf2a434cd09515549da` |
| Frozen checker | `a550eaadce0d053fe137de6e43a1998752939ba24cfd25ce4741bf4739b84c7f` |

## Remaining gates

Combine real raw bus cycles with the fixed-slot DR/DSR consumer; verify held
responses across unread replacement, initial/subsequent write misses, command
end and reset/abort. Integrate SD staging and actual CPU/DMA accesses with
source-bound default-state preservation, native software and FPGA acceptance.
This helper is deliberately absent from `machine.qip` until its consumer is
connected. No existing board/runner enables it and no hardware was changed.
