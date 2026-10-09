# SIO machine-wiring audit and integration gates

October 9, 2026. Schematic/source research and standalone clock-route tests,
not connected machine RTL,
native serial/mouse acceptance or physical timing signoff.

## Sources actually inspected

Existing ignored PDFs are rendered locally and visually inspected, not
re-downloaded or added to source history:

- [Sharp CZ-851/852 circuit diagram](https://eaw.app/Downloads/Manuals/Sharp/CZ851_2C_Schematic.pdf),
  PDF sheets 1 and 5, including enlarged SIO pins, clock selector/routes and
  CPU/DMA/interrupt wiring. SHA-256
  `8784414a3aaa25e15b4afb3662967c395c3abd6b4204ab818c7b18ed07c33f5c`.
- [Sharp CZ-880 service manual](https://eaw.app/Downloads/Manuals/Sharp/CZ-880_Service_Manual.pdf),
  printed/PDF sheets 43–44 and 47–48. Enlarged main-board SIO/selector and
  CTC pins are inspected separately; the sub-board sheets do not contain
  the SIO. SHA-256
  `70a5f8da327ed25710e76d60117c4f82a655e6a7b29a34cb3239c75f0bd65a81`.
- Existing local MAME `src/mame/sharp/x1.cpp`: Turbo port map, daisy list,
  CTC/SIO configuration, not executed or copied. Its `TODO: clocks for SIO`
  is consequential: CTC channels 1/2 feed their own triggers, not SIO pins.
- Existing X Millennium `io/sio.c`: B RTS software transition synthesizes
  three mouse bytes into a software FIFO; serial clock/pin transmission and
  its old interrupt path are not reference hardware acceptance. This source
  was read, not executed for this audit, translated into RTL or imported.
- Inherited `sharpx1_legacy.v`: SIO is a zero-data/no-output-enable stub;
  its SIO-before-DMA-before-CTC chain is a reference, not device execution.
- [TI LS157 manufacturer datasheet](https://www.ti.com/lit/ds/symlink/sn74ls157.pdf),
  SDLS058 first scanned page: pinout and function table visually inspected.
  Download retained locally as ignored `references/manuals/TI_SN74LS157_SDLS058.pdf`,
  SHA-256 `998f4a5c11e3d83c3547aef0b5fbea36f0a6581dc7abb72be9183447ab9816ff`.
  Pin 1 low selects A; high selects B; pin 15 low enables non-inverted output.

Local diagnostic renders include `/tmp/x1-sio-pins.png`,
`/tmp/x1-sio-clock-routes.png`, `/tmp/x1-sio-ctc-pins.png`,
`/tmp/x1-sio-chain-page5.png`, `/tmp/x1-z-sio-pins43.png` and
`/tmp/x1-z-sio-ctc44.png`. They are generated views of the hashed PDFs, not
new manuals or redistributed private assets.

## Confirmed endpoints and implementation consequences

Keep model-specific wiring separate; do not assume CZ-851 and CZ-880 have
identical spare modem inputs or phase conditioning.

| Endpoint | Inspected evidence | Required implementation/acceptance |
|---|---|---|
| Device | CZ-851 IC52 and CZ-880 IC1 are LH-0084A / Z80A SIO(0) | Use SIO/0 behavior, not an SCC/8274 replacement or fake ready signature |
| C/D, B/A | CZ-880 SIO pins 33/34 are labelled AB0/AB1; CZ-851 corresponding shared bus wiring | Preserve A data/control then B data/control. Local MAME maps `1F90..93`; exact ASIC aliases still need evidence |
| CLOCK | CZ-880 SIO pin 20 is on the labelled `4MHz` net; CZ-851 pin 20 joins CPU clock circuitry, with CTC phase inversion conditioned separately | Use a system-clock enable for the chip rate, not a new fabric clock. Document actual enabled frequency and sampling phase per profile |
| A TX/RX clocks | CZ-851 IC51 and CZ-880 IC15 LS157 outputs 1Y/2Y feed SIO TxCA/RxCA pins 14/13. External ST2/RT pass through 75189A receivers into 1A/2A | Model separate RX rising / TX falling events. Do not substitute one arbitrary fixed baud generator or assume external clocks always selected |
| Clock selection | SIO DTRB pin 25 drives LS157 select; G pin 15 is grounded. CZ-851 pins 3/6 trace to CTC ZC/TO1 pin 8; the CZ-880 drawing instead appears to tie these to received RT | B DTR is also a board clock-control bit. Use numbered pins and preserve the model/drawing discrepancy; do not assume a common internal source on both boards |
| B RX/TX clock | CZ-851 SIO/0 RxTxCB pin 27 traces to CTC ZC/TO2 pin 9. CZ-880 cross-sheet source remains unresolved | Qualify width/phase; a one-master-edge CTC event is not automatically a native clock level |
| A serial/modem | RD/CS/DR connector signals pass through 75189A receivers to RxDA/CTSA/DCDA; TxDA/RTSA/DTRA pass through 75188 drivers | Distinguish TTL input polarity from RS-232 voltages. Never connect raw FPGA pins to RS-232 electrical levels |
| B mouse controls | CZ-880 MS connector CTRL routes through LS07 from RTSB; TD routes through LS367A to RxDB. B TxDB is shown without an external routed connection on this sheet | Add an actual mouse protocol/pin source; a helper that directly inserts three FIFO bytes does not qualify serial timing or native mouse behavior |
| B carrier inputs | CZ-880 CI/CD receiver paths feed CTSB/DCDB. The older CZ-851 CTSB drawing instead runs to the grounded connector-side net | Preserve model-specific idle/modem policies. Do not silently tie both channels' CTS/DCD to one guessed constant |
| WAIT/Ready | CZ-880 W/RDYA/W/RDYB pins 10/30 are drawn as short unconnected stubs on the inspected sheet; no SIO-to-DMA Ready net is traced | Keep generic standalone SIO/DMA flow experiments distinct. Do not invent a native direct Ready connection because the chip supports one |
| IRQ/chain | CZ-880 INT pin 5 is SYSINT; IEI pin 6 is EXIEI and IEO pin 7 is SIOIEO. CZ-851 sheets 1/5 and legacy support SIO upstream of DMA/CTC/keyboard | Extend explicit ACK/RETI ownership, not just OR another IRQ into the CPU. Verify model-specific conditioning and downstream blocking |

The CZ-851 clock-source routes and LS157 polarity are now traced; the CZ-880
drawing discrepancy/source routing and physical phases remain open. CTC1/2
assignment below is based on visible paths, not conventional channel use or
MAME's unconnected SIO callbacks. The ASIC supplies SIOCE, but the
schematic exposes its inputs/outputs, not its complete internal alias decode.
Native `1F90..93` is the conservative local-emulator/software contract, not
proof of every hardware mirror. Adjacent `1F94..97` and external `1F98..9F`
must not accidentally address the onboard slice.

### Numbered-pin correction and tested CZ-851 selector

Enlarged CZ-880 sheet 43 (`/tmp/x1-z-sio-expanded43.png`) exposes a discrepancy
that the initial audit did not resolve: its IC15 inputs numbered 3/6 are
labelled 3A/4A, but the manufacturer identifies those as 1B/2B. The visible
lines appear to join the RT receiver output. CZ-851 IC51 instead labels those
pins 1B/2B and routes their common net away from the external receivers.
**The initial table's implication that both boards have the same separately
routed internal alternate clock is withdrawn.** Whether the CZ-880 difference
is actual wiring or a drafting error remains unverified; do not silently repair
the schematic by importing the earlier board netlist.

`rtl/x1_sio_clock_select_851.sv` implements only the confirmed earlier-board
selector. DTRB's actual active-low output **level** selects external ST2/RT
when low and the caller-supplied alternate net when high. It does not use WR5
bit 7 directly, guess a CTC channel, add pin CDC, or claim CZ-880 equivalence.
`test-sio-clock-select` passes all 16 input-level truth cases. The extended
real CTC/SIO recipe passes all 36 clock/phase profiles: real B WR5 writes
deassert/reassert DTRB, select a deliberately stopped alternate source, then
restore external diagnostic pulses without reconfiguring A. Separate B clocks
remain independent. The direct-event negative still fails as required.
Terminal exit zero in `/tmp/x1-sio-selector-all.log` (47 PASS messages including
the nine queue-oracle profiles). No new warning suppression is used.
These are standalone diagnostics, not native CTC routing or shared-machine
integration; the current RBF and v14 snapshots remain unchanged.

### End-to-end CZ-851 CTC routes and connected diagnostic

A subsequent sheet-1 trace follows both nets in contiguous enlarged views:
`/tmp/x1-851-alternate-vertical.png`, `/tmp/x1-851-alternate-horizontal.png`,
`/tmp/x1-851-clock-left.png` and `/tmp/x1-851-clock-right.png`. The latter pair
uses adjoining crops of the same scale/vertical range, not assumed alignment
between separate drawings. The joined selector 1B/2B net rises from its two
marked junctions, crosses right, turns down and then across/up to CTC IC53
ZC/TO1 **pin 8**. SIO IC52 RxTxCB **pin 27** follows the separate horizontal
route and turns up to CTC ZC/TO2 **pin 9**. Crossings without junction dots
are not treated as connections. This resolves the earlier-board assignment:

| Source | Destination |
|---|---|
| CTC1, ZC/TO1 pin 8 | LS157 IC51 1B/2B pins 3/6, selected for A when DTRB level is high |
| CTC2, ZC/TO2 pin 9 | SIO IC52 shared channel-B RxTxCB pin 27 |
| External ST2/RT after receivers | LS157 1A/2A pins 2/5, selected for A when DTRB level is low |

Original `rtl/x1_sio_clocks_851.sv` encodes these nets with caller-supplied
clock levels. It is not in `machine.qip` and does not manufacture physical
CTC pin widths from the existing one-master-edge ZC event.

The revised `test-sio-clock-select` passes 16 selector plus 128 exhaustive
CTC0/1/2/3/external/DTRB routing truth cases. `test-sio-ctc-clock` now programs
real CTC0/1/2 timers with different constants 1/2/3. CTC0 supplies explicit
**external diagnostic** pulses, not native connector wiring. B receives from
CTC2 independently of A. Real SIO register writes select CTC1 for A, then a
real CTC1 software reset stops A while B's CTC2 events demonstrably continue;
reasserting DTRB restores the external diagnostic source. Distinct A/B bytes,
exact x16 8N1 TX ticks/full stop, held reads and stopped-enable reset pass all
36 master-label/CE/phase profiles. TX is checked at both the external
diagnostic CTC0 rate and the selected internal CTC1 rate, not just idle levels.
The bypass negative uses these same routed
clock levels and fails specifically on lost events, not swapped wiring.

Terminal exit zero, Verilator 5.044, `/tmp/x1-sio-routes-final.log`, 48 PASS
messages including the nine unchanged event-queue oracle profiles. No warning
suppression is added. The earlier common-CTC0 and selector-only logs remain
historical narrower diagnostics. No private asset, shared machine, snapshot
or fitted RBF is changed.
All fourteen existing SIO targets also terminate zero after this increment,
87 PASS messages in `/tmp/x1-sio-routes-existing.log` on the unchanged engine.

Next qualify actual CTC pulse width/phase and external pin CDC, then connect
the earlier-board profile with real CPU decode/daisy/reset ownership. The
inspected UM0081 CTC description confirms active-high terminal pulses and
timer periods, but that prose alone does not establish physical pulse width.
Counter input synchronization/clock phase also remains a separate native gate.
Resolve CZ-880's differing drawing before adopting these nets for Turbo Z.
The subsequent [CTC pin-timing audit](CTC_PIN_TIMING_AUDIT.md) establishes
distinct rising-clock/ZC-rise and falling-clock/ZC-fall phases. A locally
passing next-rising-CE pulse prototype was withdrawn because it does not
match that phase contract. Native pulse duration and two-phase implementation
remain required; the event-only routing evidence above is unchanged.

## Next implementation sequence and concrete tests

1. CZ-851 internal sources/LS157 selection are now traced and tested. Finish
   physical pulse/phase, CZ-880 routing and model-specific idle contracts
   using original documentation and model-specific evidence.
   Preserve unsupported x1/synchronous/break behavior; optional diagnostics
   cannot enable a fake complete-Turbo signature.
2. The original [clock-level-to-enable adapter](SIO_EDGE_CLOCK_STATUS.md) now
   passes standalone queue-oracle and real CTC/SIO diagnostics. The channel
   consumes serial events only on its accepted `ce`; CTC pulses generated
   just after that edge can disappear before the next accepted edge. Preserve
   each RX/TX event, sample RX data with its event, and specify overflow/reset
   behavior under stopped enables. Do not clock RTL from CTC ZC outputs.
   Three master labels, all tested relative CE phases, gaps, reset with clock
   high/low and simultaneous A/B pass. Native external clock selection and
   pin CDC/reset policy remain to be integrated and tested.
3. Introduce a separate default-disabled machine profile with real serial
   input/output ports and deterministic idle levels. Add dependencies through
   `machine.qip`; prove actual Z80 decode/pointer/status/read-write, held
   strobes, neighboring ports, DAM exclusion and interrupt-ACK exclusion.
   Keep the ordinary/base machine and board defaults unchanged until accepted.
   The [standalone decoder](SIO_DECODE_STATUS.md) now qualifies `1F90..93`,
   direction, neighboring-port, DAM, disabled and ACK/reset exclusions through
   exhaustive checks plus real CPU diagnostics/negative controls. Shared
   machine response/ownership, pin/model configuration and full integration
   remain open; no machine profile is claimed from the decoder alone.
4. Extend daisy-chain ownership for SIO before DMA/CTC/keyboard. Exercise
   simultaneous RX/TX/external/CTC/DMA/keyboard requests, nested service,
   stretched/stopped-CE ACK, stable vectors, RETI vs RETN/indexed opcode tails,
   HALT and warm reset during each actual service phase. Preserve MR16's
   third-master-edge vector consumption and real DMA BUSACK reset drain.
5. Drive serial loopback as an explicit diagnostic configuration, not native
   default wiring. Connect short frames, modem gating, error/FIFO state and
   retained external snapshots to actual CPU/Ready tests. Only wire native
   Ready if a board net or explicitly separate expansion profile establishes
   the connection. Regenerate/reject snapshots after shared state changes.
6. Implement the mouse pin/protocol source and real MiSTer input adaptation;
   qualify movement/buttons/packet boundaries through native SIO programming,
   not directly patched FIFO or CPU state. Then unchanged authorized native
   serial/mouse software, source-bound fit, physical connector/output and
   broader Turbo/Z acceptance. Update model capabilities only after behavior
   and those relevant gates exist.

This audit narrows integration decisions but completes neither work group 1
nor Z7. No shared-machine RTL, private firmware, snapshot format or fitted
RBF changes are made by the research checkpoint.
