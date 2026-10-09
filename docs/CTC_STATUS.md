# Experimental Turbo CTC and interrupt integration

October 4, 2026. The active shared machine `rtl/sharpx1.v` now connects an
original four-channel `rtl/x1_ctc.sv` when `TURBO=1`. Base `TURBO=0` retains
unmapped CTC ports and its existing keyboard path. This is a tested peripheral
increment, not full Turbo software or hardware acceptance.

## Reference decisions

The locally inspected CZ-851/852 model 20/30 schematic, PDF pages 1 and 5,
shows one onboard LH-0082A CTC (IC53). Channel 0 trigger is tied high;
channels 1/2 receive 2 MHz; channel 0 ZC/TO feeds channel 3. The clock is the
inverted CPU clock. SIO/DMA precede CTC, and CTC IEO qualifies the downstream
keyboard interrupt/acknowledge. With SIO/DMA absent, **CTC precedes keyboard**.
The parent inspected the rendered chain and keyboard qualification details.
The later [contiguous SIO route audit](SIO_MACHINE_WIRING_AUDIT.md#end-to-end-cz-851-ctc-routes-and-connected-diagnostic)
also traces CTC1 ZC/TO to A's alternate clock and CTC2 ZC/TO to B's shared
clock. Standalone distinct-rate transport tests pass; physical ZC pulse width
and connected shared-machine SIO remain open.

MAME uses keyboard-first ordering; the legacy X1 RTL agrees with the schematic.
MAME's keyboard has no in-service state, and X Millennium excludes keyboard
from its service mask. Therefore the new bridge does **not** invent a keyboard
service-until-RETI latch. Physical priority for other model revisions remains
a model-specific review gate.

`1FA0..1FA3` and `1FA8..1FAB` select the same four channels, following local
MAME. X Millennium models these as separate CTC instances. One physical chip
does not settle this disagreement: ASIC IC2 receives A3 and supplies chip
select, but its internal decode is not visible in the schematic. Cross-alias
read/write behavior remains an explicit experimental contract pending ASIC
documentation or hardware tests. Adjacent four-port ranges remain unmapped.

The [official Zilog peripheral manual](https://www.zilog.com/docs/z80/um0081.pdf)
is saved locally as `references/manuals/Z80_CPU_Peripherals_UM0081.pdf`.
Printed pages 15, 30 and 31 specify that a new constant without reset takes
effect after the current count finishes. RTL preserves that count and partial
divider phase, rather than copying MAME's immediate restart. Software reset
stops counting but does not invent a service release; bit 7 masking clears
pending requests, while RETI releases service. Global reset clears both.

## Implemented contract

- Four down-counters with /16 and /256 timers, 0-as-256 constants, periodic
  reload, current-count reads, rising/falling counter edges and triggered start.
- Constant bytes take precedence over vector/control decoding; channel 0
  supplies the vector base, with channel bits selecting four even vectors.
- Timers use the existing 4 MHz CPU enable in `clk_sys`; no fabric clock is
  added. A toggle on that enable supplies the channels 1/2 2 MHz triggers.
  External counter edges are sampled on every master edge, independent of CE.
- Explicit pending/in-service state; channel 0 has highest priority. Service
  blocks itself and lower channels, while higher requests can nest. ACK consumes
  one eligible request; RETI releases the highest in-service channel.
- `x1_irq_bridge.sv` fixes owner/vector through a stretched M1/IORQ ACK. CTC
  is acknowledged once. A spurious ACK has no owner and returns FF.
- Turbo MR16 `IRQ_ACK_ONCE=1` keeps its synchronous mailbox address selected,
  but consumes once on ACK edge three. The bridge captures the vector on that
  same edge, before firmware can publish a reply. Base/legacy keep the default
  inherited behavior. Both supported CPU clock profiles have adequate latency.
- RETI is decoded once from completed M1 memory fetches, not data reads or
  interrupt ACK. RETN, ordinary CB operands and indexed DD/FD-CB tails are
  distinguished; indexed tails cannot swallow a subsequent real RETI.

New RTL/tests are original project code. No inherited CTC or emulator source
was copied. Existing firmware/renderer notices and release licensing limits
remain; the new peripheral does not resolve them.

## Verification

```sh
make -C verilator test-ctc test-turbo turbo-single
cd verilator
python3 tests/test_ctc.py ./obj_dir_turbo_single/Vtop
python3 tests/test_ctc_base.py ./obj_dir_headless/Vtop
```

Standalone CTC checks cover both prescalers, TC1/3/256, CE stalls, both edge
polarities, triggered starts, deferred reload/phase, masking, simultaneous
requests, nested service, ACK/terminal coincidence, RETI and reset. A connected
CTC/bridge bench checks vectors 44/46 through 40-clock ACK holds with CE stopped,
higher pending requests, service blocking, both cascade edges and RETN/RETI.

The real MR16 bench passes at 32,000,000, 28,636,364 and 28,571,428 Hz: vector
52 is consumed/captured on edge three, stays fixed through a 200 us ACK, and
the newly published B7 response remains available. A subsequent spurious ACK
does not consume it; ordinary mailbox reads return B7/46.

Original CPU IM2 fixtures perform two cold repeats with and without native
keyboard input, using delay-aware baseline 32 MHz / video 28.571428 MHz and
single 28.636364 MHz. Each runs 150 ms including reset/download, with identical
reports/RAM and channel IRQ counts **18, 14, 10, 9**. Channel 0/3 cascade,
all four vectors, DD/FD-CB followed by actual TV80 RETI, and active rising/falling
2 MHz trigger counters pass. Concurrent cold F/I/J make/break input gives all
six native replies. Separate cold/steady/overlap and Caps/Shift polling pass
with CTC inactive. Base unmapped-port, memory, keyboard and warm-reset checks
pass. Turbo bank/IPL regressions also pass. These fixtures use synthetic CPU
programs, not injected commercial-game state or authentic Turbo firmware.

The runner additionally supports bounded bus diagnostics:
`--bus-trace PATH --io-only --bus-events --bus-start-ms START --bus-end-ms END`.
The half-open window uses absolute simulation milliseconds. Event mode emits
the final sampled data/time for each contiguous address/strobe transaction;
default trace mode still emits every master edge. CSV retains its first eight
fields and appends actual drive-control, motor and effective media-ready state.
Synthetic fixtures compare raw/event/window data and verify identical execution
with tracing disabled/enabled, plus invalid-option rejection. Private native
probe helpers accept these same switches with `--io-trace`.
An additional generated D88 fixture repeatedly selects unsupported B and
mounted A, checking actual drive/motor/ready/status fields, deterministic
recovery and unchanged disk bytes. It explicitly guards against faking B ready.
Two cold repeats pass in delay-aware baseline and single-clock builds, and
in the fast Turbo profile. This checks the existing single-drive contract,
not a completed second drive.

## Remaining limits

Exact CTC pin/setup timing, inverted CPU-clock phase and physical ZC width are
not reproduced: ZC is currently a one-master-edge event. Bus writes supersede
counting on their selected channel, so coincident write/tick timing needs
silicon-level review. Triggered-start delay is deterministic, not the exact
datasheet T-state delay. Aliases and other-model daisy chains remain open.

The [CTC-inclusive Quartus build](CTC_QUARTUS_BUILD.md) binds all 333 input
hashes to implementation commit `0115a38`. It uses 20,115 ALMs (48%), 384 RAM
blocks (69%) and the board's 28.571428 MHz master. All eight reported timing
corners pass constrained paths, with worst global setup/hold +0.359/+0.055 ns.
External I/O constraints, CDC/reset and physical tests remain open; no
hardware acceptance is inferred from successful compilation/timing.

SIO/DMA/external-slot/FM-board interrupts are absent. Authentic Turbo IPL,
400-line clocks/addressing, glyph ROM/high-speed PCG, native game controls and
physical hardware tests remain separate gates. A CRTC-programmed 640x400
capture is not evidence of correct Turbo video timing. Older RBF reports
predate this CTC increment; new synthesis/timing evidence must bind its source.
