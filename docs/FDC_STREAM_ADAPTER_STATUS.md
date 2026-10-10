# Fixed-slot DR/DSR prototype

October 10, 2026. Original standalone functional prototype, not connected
WD/SD/CPU/DMA, native MB8877A timing or board acceptance.

## Implemented scope

`rtl/x1_fdc_stream_adapter.sv` consumes the fixed 32-chip-enable MFM slot
helper. Reads publish opaque source bytes independently of CPU servicing.
Unread replacement and a missed final service slot set sticky loss. A
captured response/generation survives subsequent arrivals and stop; release
retires the response without acknowledging a newer byte. Writes request
pre-stream prefill, abort with no emitted byte if missing at explicit launch,
then consume captured data at fixed slots. Later misses substitute zero and
continue. Last-read/write completion includes a separate final slot.

Explicit nominal `fdc_ce` is independent of capacity, CPU/bus CE and SD.
Initial launch/gap timing, final service tail, same-edge old-read/new-arrival
and accepted-write/load ordering are experimental digital policies, not
measured native transitions. Guaranteed read/write service maxima of 27/23
chip clocks must not be confused with this 32-clock byte cadence.
READ ADDRESS here is six opaque bytes including supplied CRC, not computed
CRC or selected-medium command execution. FM stream decoding is not supported.

The prototype owns an internal holding register. That is **not** interchangeable
with WD's physical `wdreg_data`: idle/non-DRQ DATA writes are not represented.
It is deliberately absent from `machine.qip`; no machine or board uses it.
Ordinary state and defaults are unaffected by these unconnected source files.

## Independently executed gate

```sh
make -C verilator test-fdc-stream-adapter
```

Main's separate frozen run completes zero in
`/tmp/x1-fdc-stream-main-independent.log`; frozen sources, commands, build/run
logs and manifest reside under
`/var/folders/sv/859j7h856t5gzg1kv3nnqdj40000gn/T/x1-fdc-stream-adapter-z_n89mmz`.
Verilator 5.044 uses timing/assertions and default fatal warnings. Both nominal
rates execute 33 counted payload cases plus held/tie/restart/abort/reset
scenarios. Each reports 7,717 arrivals, 5,766 emitted writes and 7,701 read
acknowledgements. Supported payloads are 128/256/512/1024 bytes, plus six-byte
ID streams and a sole write byte; successful services stay inside the
documented guaranteed windows. The externally counted chip-edge oracle checks
events, values, indices/generations, loss, DRQ and responses on every SYS edge.

Four disposable mutations are rejected by the unchanged frozen oracle at
their required diagnostics: service-dependent rephase, live DIN instead of
captured write data, release acknowledging a new DR, and stale data rather
than zero on underrun. Build failure/timeout cannot qualify those negatives.
Source hashes remain unchanged after all tests. Main's separate default-warning
lint completes zero in `/tmp/x1-fdc-stream-main-lint.log`.

Review catches an internal registered-stop conflict with immediate next-command
restart. The corrected helper suppresses that old internal stop for explicit
new starts, while external stop still wins. Retained tests cover immediate
read restart, prefill/launch restart and simultaneous external stop/launch.
This is a functional prototype repair, not a native command-gap policy.

| Source | SHA-256 |
| --- | --- |
| Stream prototype | `449afda52ff4644e537286b763189a54bdbaee510a4a1c02914f45e37f2aba0b` |
| Stream fixture | `2701a2df9fd2539d29f56686cbbdae0ad4ab42a953611f6d5101bd738ee8626b` |
| Frozen checker | `3b1946b8f3aa3bacc1e62efca67fec121abb8f477b0fd0a0867dc7b5f4fa84e6` |

## Required connected architecture

- Keep `wdreg_data` the single physical DR under its existing process owner.
  Separate DR contents from request validity/generation and serialized DSR.
  Idle/non-DRQ stores and early reads must remain coherent. An underrun's
  substituted zero changes DSR, not automatically DR. An initial-DR seed alone
  cannot fix writes during a command.
- Expose same-SYS-edge read-arrival update intent/value to the DR owner, or
  align DR/DRQ/generation publication explicitly. Mirroring registered arrival
  one edge later would temporarily expose mismatched data and request state.
- Capture completion/result on SYS into a held lease consumed once by WD's
  slower CE-gated FSM. One-SYS `done` pulses can otherwise be missed. Qualify
  all eight CE phases, pending-completion cancellation and context replacement.
- Consume captured write events on SYS into the sector buffer, independent of
  CPU CE; retire the final store before SD flush. Gate cancelled emissions
  from reaching reused storage. SD ACK/LBA/metadata ownership must survive
  reset/abort drains independently of command cancellation.
- Preserve procedure-local legacy flags and default v17 identity. Test the
  actual vendor and whole-machine generated headers/serializers, not assumptions
  about constant-dead new state. Keep nominal clocks separate from Type-I/index
  enables and still-unresolved board FDCCLK/RPM/class routing.
- Combine raw held bus accesses with shared-DR streams, then the real scanner/
  three-block unaligned-sector staging, CPU/DMA, protected media, native
  software and source-bound FPGA timing/hardware. Do not enable a board from
  standalone success.

See [primary evidence and complete integration design](HD_FDC_BYTE_TIMING_DESIGN.md)
and [the full HD plan](TURBO_HD_DISK_PLAN.md). These remaining gates are not
completed by this prototype or its compile/lint results.
