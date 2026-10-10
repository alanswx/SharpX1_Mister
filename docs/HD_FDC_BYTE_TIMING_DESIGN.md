# MB8877A byte timing: evidence and proposed experiment

October 10, 2026. Read-only research plus an original design proposal; no
production RTL implementation or new simulation/hardware acceptance.
The implemented HD-media class gate is separate from this work.

## Result and qualification boundary

A nominal MFM byte occupies **32 controller-clock periods**: 16 microseconds
at 2 MHz, 32 microseconds at 1 MHz. A fixed-slot scheduler must not restart
its phase when the CPU/DMA services DRQ. However, the guaranteed DRQ service
window is shorter than the byte period, and reads physically follow recovered
RCLK. Neither the physical Sharp FDCCLK selection nor BUSY-time mode-change
behavior is resolved here. Do not connect capacity selection directly to a
clock divider, infer RPM, or enable an ordinary board profile from this result.

## Locally inspected primary evidence

The following existing ignored PDFs were read locally, without downloads.
Fujitsu PDF pages 12/13 and Sharp service sheets 47/48 were also rendered and
visually inspected in `/tmp/x1-fdc-timing-ref-JRUYxb/`. No private disk, ROM,
font or snapshot bytes are included in this note.

### Fujitsu chip documentation, not Sharp board documentation

`references/manuals/MB8876A_MB8877A_Datasheet.pdf`, October 1986, edition 2.0,
SHA-256 `3358e0cefabb858261177d3f658c63db3f4142f9bfb826339135d5c19ab1b91b`:

- PDF page 1, printed 4-27: double-buffered data I/O, DMA capability, and
  MB8877A upward compatibility with WD FD1793-02.
- PDF page 2, printed 4-28, pin descriptions: CLK pin 24 is a fixed 2-MHz
  input, or 1 MHz for mini-floppy operation. DDEN pin 37 selects MFM when
  low and FM when high and must remain fixed during BUSY. DRQ means the
  data register is full for reads or empty for writes.
- PDF page 3, printed 4-29: RCLK pin 26 is a data-window signal from an
  external VFO, derived from read data. READY and read timing are not CPU
  service clocks.
- PDF page 5, printed 4-31: serial DSR transfers assembled read bytes to
  the parallel DR; writes transfer DR into DSR. This is not a sector-sized
  CPU-facing FIFO.
- PDF page 7, printed 4-33: Type-II/III status bit 2 reports failure to
  respond to DRQ within a byte time; bit 1 copies DRQ; bit 0 is BUSY.
- PDF page 12, printed 4-38: the read waveform shows approximately
  16-us MFM / 32-us FM DRQ recurrence. Its table gives maximum read service
  time `tSEVR=13.5 us` with RCLK period 2 us. The starred values double
  when CLK is 1 MHz. RE pulse width minimum is 280 ns; data delay and DRQ
  reset maxima are 250 ns. The drawing distinguishes RE assertion,
  duration, data validity, and completion: do not treat software instruction
  completion or bus release as an unspecified instantaneous acknowledge.
- PDF page 13, printed 4-39: write recurrence is 16-us MFM / 32-us FM;
  maximum MFM write service time `tSEVW=11.5 us`. Starred values double
  at 1 MHz. WE pulse minimum is 200 ns and data setup minimum is 250 ns.
- PDF page 14, printed 4-40: nominal recovered RCLK period is 2 us for
  MFM and 4 us for FM at the 2-MHz setting, doubled at 1 MHz.

Derived nominal MFM quantities, independent of capacity labels:

| Explicit CLK setting | Byte period | Byte periods in chip clocks | Maximum read service | Maximum write service | Decoded data bit rate |
| --- | --- | --- | --- | --- | --- |
| 2 MHz | 16 us | 32 | 13.5 us / 27 clocks | 11.5 us / 23 clocks | 500 kbit/s |
| 1 MHz | 32 us | 32 | 27 us / 27 clocks | 23 us / 23 clocks | 250 kbit/s |

The byte and service counts are arithmetic derived from these tables, not
separately measured silicon state transitions. A maximum guaranteed service
time is **not** proof that lost-data flips exactly on clock 27/23, nor that
service between those maxima and the next byte is always safe. Preserve
that distinction in the oracle and in any implementation claim. The read
32-clock model assumes nominal recovered RCLK; it does not implement a VFO
or raw flux timing. FM byte cadence is different and remains out of scope.

### Western Digital primary compatibility-family evidence

`references/manuals/FD179X-01_Data_Sheet_Oct1979.pdf`, SHA-256
`e51aef0933d88e7705f6f774ffb3238e8e8096bd9b9d774a985d95ef5766e3ce`:

- Printed/PDF page 6, general disk read/write operation description: a new assembled byte
  can replace unread DR contents, sets lost-data, and reading continues to
  sector end. GENERAL DISK WRITE OPERATIONS: missing a subsequent byte
  substitutes zero and sets lost-data.
- Page 7: the first write byte must be supplied before write gate activates.
- Pages 11/12, READ SECTOR: first DRQ follows assembly of the first payload
  byte; a subsequent byte overwrites an unread previous byte. The transfer
  continues; servicing a later byte does not undo an earlier loss.
- Page 12, WRITE SECTOR: initial DRQ follows finding the matching ID. Write
  gate is checked after 22 byte times from the ID CRC in MFM (11 in FM).
  An unserviced initial request terminates with lost-data, without write gate.
- Page 13: subsequent write underruns substitute zero without terminating
  the command; CRC follows the payload. READ ADDRESS produces six requested
  bytes (C,H,R,N,CRC high,CRC low) and copies C into the sector register.

This is manufacturer-authored FD179X-01 documentation, **not** a Fujitsu
MB8877A detailed command manual or a Sharp timing measurement. Fujitsu
names FD1793-02 compatibility, so exact startup/gap/last-byte/IRQ edge
equivalence to this -01 document is not established. The short Fujitsu
sheet independently confirms DR/DSR, byte-time lost-data and nominal timing;
the more detailed overwrite/initial-abort/zero-fill rules have this explicit
compatibility-family provenance. Do not apply the periodic write budget to
the initial ID-to-write-gate request: its startup sequence is distinct.

### Sharp-authored board evidence and unresolved routing

`references/manuals/CZ-880_Service_Manual.pdf`, SHA-256
`70a5f8da327ed25710e76d60117c4f82a655e6a7b29a34cb3239c75f0bd65a81`:
sheet 47 shows IC417 MB8877A CLK pin 24 connected to IC416 MB4107 CK pin 8.
DDEN pin 37 has a separate FM/MFM route into MB4107. MB8877A RCLK pin 26
is connected to MB4107 DW pin 4 (corrected by re-reading sheet 47;
pin 1 is MIN, not DW). Sheet 48 shows IC420 IX0870CE gate-array
controls and distinct MIN, MFM, 1.6M, low-current, index and drive routes;
the drive connector separately labels its 500K-1M/(1.6M) class signal.

This confirms a VFO/controller-clock path rather than a demonstrated direct
CPU-enable connection. The exact MB4107 oscillator/divider behavior and
gate-array MIN/class truth table still need tracing or a local primary part
specification/measurement. There is no established class-to-1/2-MHz mapping
in this note. No Sharp-authored native BUSY-time capacity/clock-switch
contract, installed-drive RPM, or reset phase is established. The existing
third-party Techknow IN-port labels are capacity labels, not clock evidence.

October 10 follow-up: the original MB4107 manufacturer data sheet is now
retrieved and visually inspected. It resolves MIN polarity and the chip's
CK frequency selection, not the Sharp ASIC's capacity-to-MIN truth table.
See [the original VFO evidence](FDC_VFO_CLOCK_STATUS.md). The preceding
statement about unresolved chip divider behavior is superseded only to that
documented extent; native BUSY/rate/drive acceptance remains open.

## Inspected emulator code: cross-checks, not native authority

Existing local MAME:
`../FM-7_MiSTer_alanswx/refs/mame/src/devices/machine/wd_fdc.cpp`, SHA-256
`ed2fa75117adef97af6d43f7fb4d2ffad9e7509ae183aa81d2daf6081139e3d7`.
`READ_SECTOR_DATA`/`READ_SECTOR_DATA_BYTE` advance with serial byte boundaries,
replace `data`, and call `set_drq()`. `SECTOR_WRITE` substitutes zero when a
request remains outstanding and continues writing; READ ADDRESS also follows
serial bytes. This supports an independent stream rather than service-paced
advancement. But `set_drq()` suppresses a fresh assertion after S_LOST, while
`command_end()` has an explicit unresolved lost-data/DRQ comment and
`drop_drq()` an IRQ-delay hack. Do not copy those latter policies as chip law.

Existing executed Xmil source copy:
`output_files/xmil-reference-build-ZFOimE/source/io/fdc.c`, SHA-256
`7ef1c7c040741a0527a8ce15e87b4e4b43b1fb59213c1ce5884489c89a3661b9`.
`neitem_fdcbusy()` releases an initial delay and sends DMA ready. Data-register
reads/writes advance the software buffer when no longer busy. `fdc_i0ff8()`
increments `curtime` on status polling and, after eight polls, sets lost-data
and advances the buffer. This is a compatibility heuristic, not a fixed
physical DRQ deadline. Its capacity reads update `media`; FM/MFM reads are
not evidence of a timed clock consumer. Neither emulator was run anew here.

## Current RTL discrepancy

Inspected vendor SHA-256
`2affa0bd8a6bf504247dd917a86902508c1efb8f5e6143f2e90706f438a6b75a`.
`STATE_READ_1` and `STATE_WRITE_1` use `read_timer=15` and old-value-zero
testing (16 CE visits). The next states advance after service or watchdog,
then restart that delay. The watchdog reloads 4096 CE ticks. The shared
machine supplies `pe4M4`, not an established physical MB4107 FDCCLK.
At nominal 4 MHz, the short delay is approximately 4 us and watchdog span
approximately 1.024 ms, before FSM transition overhead. Thus the current
byte cadence depends on service latency; adjusting watchdog alone cannot
implement a fixed 16/32-us stream. Existing sticky loss and zero-fill tests
qualify those functional paths, not native byte-slot timing.

## Proposed split: scheduler, DR/DSR adapter, and SD transport

No competing RTL is implemented here. Main's proposed original standalone
scheduler can be the first gate:

1. Synchronous SYS with an explicit `fdc_ce` representing an independently
   chosen 1- or 2-MHz nominal chip clock. Count exactly 32 accepted CE edges
   between MFM payload boundaries. Start/stop define phase; CPU reads,
   writes, DRQ clearing, DMA grants and status polls never reload it.
   Define whether start marks the beginning of assembly or an already
   completed byte. A start coincident with CE must not accidentally count
   twice; stop/reset wins and stale slot pulses are discarded.
2. Keep DR/DSR transaction semantics in the controller, not the scheduler.
   Reads publish byte 0 only after its assembly interval; at each later
   boundary replace DR with the next byte regardless of service, marking
   unread replacement as sticky loss. DRQ is a level, not necessarily a
   pulse per byte: an unread byte may leave it asserted across replacements.
   READ ADDRESS uses the same six-byte stream policy.
3. Writes require a separate pre-stream first-byte request/arming state.
   No first byte means initial abort and no payload/metadata SD writes.
   Once writing starts, load each scheduled DSR slot from the holding DR;
   if empty, emit zero, set sticky loss, and keep phase/length advancing.
   Request the next byte when DR transfers to DSR, not when the CPU releases
   its previous bus transaction. Never use a changing live DIN as the
   scheduled write byte. Do not request a nonexistent byte after the last
   payload. Model CRC/end draining separately from payload DRQ slots.
4. Capture one register transaction per real CPU/DMA access, including held
   strobes. A read response must remain stable throughout its held bus cycle
   even if another serial byte arrives. Only the serviced DR generation is
   acknowledged; an old held read cannot clear a newly published byte.
   Early DR consumption and late strobe release are distinct events. Derive
   the final bus acceptance edge from existing machine bus timing and the
   primary RE/WE waveforms; document/test ties as digital policy rather than
   claiming a measured silicon boundary. Do not depend on CPU CE continuing
   while DMA owns the bus; scheduler/controller events need their own CE.
5. Use sector staging to keep SD latency outside an active stream. For reads,
   prefetch the entire supported payload before starting byte phase. A
   1024-byte payload at an unaligned byte offset can need three 512-byte SD
   blocks, not two. A sector cache needs 1024 payload bytes for the existing
   N=0..3 subset, plus host/RMW scratch and the CPU DR/DSR holding registers.
   For writes, collect scheduled bytes/zero fills into staging, then perform
   payload and header RMW/CRC/deleted metadata commits. Preserve neighboring
   bytes and concatenated volumes. Do not restart slots at block boundaries
   or call an SD refill delay a CPU lost-data event.
6. BUSY may include adapter prefetch/commit latency, explicitly non-native.
   Before streaming, wait for valid cache ownership; after streaming, retain
   BUSY until protected host writes/metadata drain under the existing safety
   contract. A timeout must be a reported adapter failure, not an invented
   chip underrun. Retain published ACK-owned drive/LBA/buffer through reset
   or abort; accepted external writes cannot be rolled back. Stop byte phase
   and discard uncommitted staging without reusing an outstanding SD lease.

Keep the experiment default-off and non-savable initially. It may select
an explicit nominal CLK for diagnostics, without claiming that HD capacity
chooses it natively. For initial tests, forbid mode/drive changes during an
active command; command-captured settings are an explicit experimental safety
policy, not proof the native chip/ASIC latches or ignores those inputs.
Fujitsu specifically requires stable DDEN during BUSY. Do not change index,
motor, seek delays, CPU frequency or RPM as a side effect of byte scheduling.

## Independent tests and acceptance sequence

No tests in this section were built or executed during this research.

- Standalone scheduler: use physical SYS timestamps and a reference event
  schedule independent of DUT counters. Cover 1/2 MHz, all SYS-to-CE start
  phases, exact 32-edge spacing, stop/reset coincident with CE, restart,
  stopped chip CE, and arbitrary service patterns. Assert that servicing
  early/late cannot change any later scheduled boundary. Include a disposable
  service-rephase negative with the same unchanged oracle.
- Standalone DR/DSR adapter: payloads with distinct bytes; service near start,
  well within 27/23 clocks, and after complete missed slots. Compare every
  byte publication/consumption, DRQ level, slot index and sticky loss, not
  just final counts. Separate guaranteed-service tests from the unresolved
  late-window/same-edge cases. Cover first/middle/final misses, consecutive
  misses, recovery, retained DR readback, and READ ADDRESS six bytes/CRC/C.
  First-write miss must leave media unchanged; later misses must replace
  precisely the scheduled payload bytes with zero, not shift subsequent data.
- Real scanner/SD path: generated D88 only, both nominal clocks and classes
  selected independently. Cover 128/256/512/1024-byte sectors, unaligned
  three-block prefetch, high addresses/index, metadata splits, both drives,
  selected concatenated volume, random ACK delays and stalled SD. During
  streaming assert no refill pauses and no stream-buffer mutation by SD.
  Check whole-medium preservation, failed initial write, protection, abort
  and reset before/after ACK, and no false CPU loss from slow prefetch.
- Actual CPU and DMA: independently timed CPU polling, delayed service and
  real DMA ownership/strobes. Freeze runner/oracle/emitter/assets before long
  runs. Require physical-time byte spacing and precise missed-byte contents,
  not only DMA byte totals. Test CPU enable stops during BUSACK/reset drain
  without stopping chip timing or ACK processing. Do not invent native DMA
  Ready wiring or enable currently excluded HD-media/DMA combinations before
  an explicit integration design and gate.
- Default regression: compare original-port vendor internal state and the
  whole-machine default generated declarations/serializers/checksums. Added
  experiment state must not silently change ordinary v17. Native boot/game
  acceptance, board FDCCLK routing, physical timing and hardware remain later
  separate gates.

Capacity is header-class admission; FDCCLK is a physical chip input; MFM
byte cadence assumes its nominal recovered data stream; RPM/index determines
rotational timing. Enlarged image addressing, successful class matching and
32-edge scheduler tests qualify none of the other three automatically.
