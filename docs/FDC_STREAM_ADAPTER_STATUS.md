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

### Current request-eligibility repair and shared-DR work

Review subsequently finds a bounded helper defect: during the final write
serialization slot, active remains set but DRQ is low. The old service predicate
nevertheless accepts another write and changes holding. The oracle duplicates
that predicate, so earlier passes cannot qualify this case. Service now requires
actual DRQ; the independently stated reference requires an outstanding request
and remaining payload. A retained one-byte final-tail write must leave internal
holding unchanged and cannot delay completion. A fifth disposable mutation
restores exactly the old predicate and must fail the DR/index assertion.

The current `EXTERNAL_DR=0` gate completes zero at both rates: 34 counted cases,
7,717 arrivals, 5,767 emitted writes and 7,701 acknowledgements per rate, plus
all five matched negatives. Actual Make target log:
`/tmp/x1-fdc-stream-tail-final.log`; frozen sources/logs:
`/var/folders/sv/859j7h856t5gzg1kv3nnqdj40000gn/T/x1-fdc-stream-adapter-zampflaa`.
The preceding four-negative repair run also completes zero in
`/tmp/x1-fdc-stream-tail-request-fixed.log`.

That checkpoint additionally introduces default-off `EXTERNAL_DR=1`,
caller-owned physical DR and same-edge read-load intent/value. **The gate above
does not enable or qualify that mode.** Shared-DR/raw-bus acceptance was then
in progress; the separate gate below now covers it. No WD/machine/manifest/board
connection follows these results.
The internal-mode tail rule is request servicing, not permission to discard
native CPU DATA stores: the future physical DR owner must retain those stores
independently, including DRQ-low writes. Current frozen hashes:

| Source | SHA-256 |
| --- | --- |
| Stream prototype | `50a4007b51f9fd28bf804d5b50d42b51cea201b87b6fd76d20013da11c469372` |
| Stream fixture | `1b0d238a4352bf4dddb506cd75c9e2fbd8d61930821b26b21ca70be121e2a9fb` |
| Frozen checker | `2cfbe5bfb3d1add50351003112756e6548ddedbde0f1d0af4ee6f6018c0c6e98` |

### Shared physical DR with actual raw bus strobes

`make -C verilator test-fdc-stream-external-dr` now completes zero in Main's
independent frozen run, `/tmp/x1-fdc-external-dr-main.log`. Frozen sources,
commands and logs:
`/var/folders/sv/859j7h856t5gzg1kv3nnqdj40000gn/T/x1-fdc-external-dr-yqni676c`.
Main also independently reads and hashes the agent's earlier `aea9434z` gate.
Current source hashes match both manifests.

Both nominal 1/2-MHz rates pass 32 counted payload scenarios plus targeted
raw-bus cases: 7,711 read arrivals, 5,766 DSR loads, 7,694 acknowledgements,
5,761 DATA stores and one explicit arrival/store tie per rate. A single fixture
SYS process owns physical DR. Actual held strobes go through the bus helper;
all-register acceptance is filtered for DATA before stream service. Idle and
non-DRQ stores update DR independently of validity; initial missing prefill
cannot use an old nonzero DR, and underrun zero affects DSR without altering DR.
Same-edge accepted DIN bypasses the old DR at both initial and periodic loads.
DR, DRQ and generation are checked after every edge. Responses survive stream
completion, new command and stream-only reset while the raw bus remains held.

Private-DR, late-arrival intent and stale-DIN mutations all fail the same oracle
at their required diagnostics. The first agent run, preserved under
`x1-fdc-external-dr-j4a7966e`, fails overall because stale-DIN initially escapes:
it lacks simultaneous accepted-store/load coverage. The expanded fixture fixes
that test gap; it does not relax a production assertion. Independent review
finds no blocking issue under the stated digital contract. Read-arrival-over-
store priority and unsolicited-store replacement are fixture policies, not
measured native bus collisions. This still instantiates no actual CPU, WD
controller, SD scanner or board.

Fixture/checker SHA-256:
`208cadb9bbe1909f04a353f67c03c377391eab08901d6e302c6dfcbf69b0a830` /
`44d1fcf9a22a047a309ae2bf878edf21abb52d9389da8e115f49353303696427`.
Adapter stays `50a4007b...`; slot/bus hashes stay as previously recorded.

### Actual-stream completion held for a slower consumer

Original `rtl/x1_fdc_completion.sv` holds SYS-produced completion, loss and
initial-abort result until consumption. Cancel/reset wins; completion wins
consume to permit an exchange. `taken` qualifies consumption with valid and
no cancel/reset, preventing a controller from applying the old visible lease
on a cancelling edge. Results remain stored after consumption but are invalid.
One outstanding completion is required; its simulation assertion rejects
overwrite, not a claim of synthesizable backpressure or command-ID protection.
Stop/restart the producer and cancel its lease together on context replacement.
SD ACK ownership is not part of this cancellation interface.

`make -C verilator test-fdc-completion` completes zero in
`/tmp/x1-fdc-completion-consumer-final.log`, with frozen inputs/logs under
`/var/folders/sv/859j7h856t5gzg1kv3nnqdj40000gn/T/x1-fdc-completion-6n8cvj8i`.
The actual stream producer drives 48 transfers/64 phase-matrix captures;
separate read and write masks cover all eight slower-controller CE phases at
both rates. Results survive 73 stopped-consumer SYS edges and are consumed
once. Additional actual-producer tests qualify pending/not-yet-captured cancel,
cancel+consume suppression, old-result/new-completion exchange and reset at a
source event. A real posedge consumer makes 50 accepted consumptions.
Two unconsumed actual aborts reject the one-outstanding contract. Pulse-only,
drop-loss and ignore-cancel mutations fail the per-edge unchanged oracle.
Current default-warning builds are clean; the earlier original completion
gate remains in `/tmp/x1-fdc-completion-frozen.log`.

| Source | SHA-256 |
| --- | --- |
| Completion lease | `f1b0507dbf5557a90545336c1ed1e63f2a6501a713cff94ac3e905304928c929` |
| Actual-stream fixture | `7851a999ef15947394505e3b3d132e94b4c22d510446de611dd3d7c29bed524e` |
| Frozen checker | `1b23eece616a159e1d516e6e69b62b4c89d5f27354e07add41f1d01e88e2940b` |

This is a same-SYS/enable handshake, not CDC, WD/SD integration, reset-drain
ownership or hardware acceptance. These five asset-free FDC prerequisite
targets are now scheduled in CI; no hosted success is claimed yet.

### Still-required machine integration

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
