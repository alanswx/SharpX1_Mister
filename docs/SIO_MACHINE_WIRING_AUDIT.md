# SIO machine-wiring audit and integration gates

October 9, 2026. Schematic/source research, not connected machine RTL,
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
| Clock selection | SIO DTRB pin 25 drives the LS157 select; enable G pin 15 is grounded. Alternate clock inputs share a routed internal net | B DTR is also a board clock-control bit. Finish the internal source/end-to-end CTC route and selector polarity audit before native clock integration |
| B RX/TX clock | SIO/0 pin 27 is the shared RxTxCB clock; CTC ZC/TO routing is visible across adjoining sheets | Trace the cross-sheet source and width/phase; a one-master-edge CTC event is not automatically a native clock level |
| A serial/modem | RD/CS/DR connector signals pass through 75189A receivers to RxDA/CTSA/DCDA; TxDA/RTSA/DTRA pass through 75188 drivers | Distinguish TTL input polarity from RS-232 voltages. Never connect raw FPGA pins to RS-232 electrical levels |
| B mouse controls | CZ-880 MS connector CTRL routes through LS07 from RTSB; TD routes through LS367A to RxDB. B TxDB is shown without an external routed connection on this sheet | Add an actual mouse protocol/pin source; a helper that directly inserts three FIFO bytes does not qualify serial timing or native mouse behavior |
| B carrier inputs | CZ-880 CI/CD receiver paths feed CTSB/DCDB. The older CZ-851 CTSB drawing instead runs to the grounded connector-side net | Preserve model-specific idle/modem policies. Do not silently tie both channels' CTS/DCD to one guessed constant |
| WAIT/Ready | CZ-880 W/RDYA/W/RDYB pins 10/30 are drawn as short unconnected stubs on the inspected sheet; no SIO-to-DMA Ready net is traced | Keep generic standalone SIO/DMA flow experiments distinct. Do not invent a native direct Ready connection because the chip supports one |
| IRQ/chain | CZ-880 INT pin 5 is SYSINT; IEI pin 6 is EXIEI and IEO pin 7 is SIOIEO. CZ-851 sheets 1/5 and legacy support SIO upstream of DMA/CTC/keyboard | Extend explicit ACK/RETI ownership, not just OR another IRQ into the CPU. Verify model-specific conditioning and downstream blocking |

The clock-selector endpoints are established; exact internal source routing,
selector interpretation, scan seams and physical phases remain open. Do not
turn the likely CTC channel assignment into a confirmed netlist simply from
the conventional use of CTC channels 1/2. The ASIC supplies SIOCE, but the
schematic exposes its inputs/outputs, not its complete internal alias decode.
Native `1F90..93` is the conservative local-emulator/software contract, not
proof of every hardware mirror. Adjacent `1F94..97` and external `1F98..9F`
must not accidentally address the onboard slice.

## Next implementation sequence and concrete tests

1. Finish the internal clock source/LS157 selection and model-specific idle
   contract using cross-sheet traces and original programming documentation.
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
