# Z80 DMA register and acceptance contract

October 5, 2026. Read-only source/manual/firmware audit, followed by creation
of this document only. **No DMA implementation, emulator execution, native
probe, synthesis or hardware acceptance was performed for this audit.**
The active shared machine is `rtl/sharpx1.v`; DMA is still absent. The new
CPU BUSRQ/BUSACK seam is a prerequisite, not a connected DMA bus owner.
Preserve the baseline model and keep Turbo DMA explicitly opt-in.

## Evidence and attribution

- Primary: local [Zilog UM008101-0601](../references/manuals/Z80_CPU_Peripherals_UM0081.pdf),
  SHA-256 `b4efc81540c05990883cf4c7792c2a3d49fb7471bb5502931383ab55b4540886`.
  DMA chapter PDF page numbers below are **1-based**; printed page numbers
  in this chapter are PDF page minus 18. PDF 94 (printed 76), Table 11,
  describes terminal counters; PDF 96–103 cover bus/interrupt structure;
  PDF 108–110 describe programming; PDF 111–132 cover WR0–WR6;
  PDF 133–135 cover read registers; PDF 139 (printed 121) specifies the
  fixed-destination loading workaround. Figures 40/41/44 were also rendered
  and visually inspected. Some figure labels are internally inconsistent;
  the prose and explicit bit descriptions must be consulted, not OCR alone.
- Secondary implementation: existing sibling MAME checkout, read-only,
  commit `f4bfc5a423f48d48e809c01fc70a47c0c00d40a2`:
  `src/devices/machine/z80dma.cpp`, especially register macros near line 55,
  read/write parser near 621/681, and sequencer near 463;
  `src/mame/sharp/x1.cpp`, DMA map near 1403, DRQ wiring near 802,
  and device configuration near 2277. MAME explicitly lists incomplete
  reset/documentation/features in its DMA TODO. It is not a silicon oracle.
- Firmware: unchanged ignored 32 KiB Turbo IPL,
  `software/turbo-firmware/212895703175-ipl.x1t`, SHA-256
  `212895703175665be8544daa55b65da1aebcf1e9a2db65bcc1622e564b802b71`.
  Existing installed `z80dasm` and bounded binary inspection were used
  offline. See [firmware provenance and prior execution limits](NATIVE_TURBO_FIRMWARE_STATUS.md).
  The semantic observations below are **not proof the paths executed**.
  No firmware/game byte stream, disassembly listing or private table is
  reproduced here; command encodings below are the public chip interface.

## One stream, not seven separately addressed registers

Turbo DMA registers occupy `1F80..1F8F`, aliases of one stream in MAME.
Low address bits do not select WR0–WR6. Select the group by the base byte,
then consume exactly the requested associated bytes, in order. While any
associated byte is pending, **every next write is data**, even if its value
resembles RESET, ENABLE or another base byte. Reads do not consume the write
queue. A stretched CPU I/O cycle must create only one stream transaction.

Base decode, when no associated byte is pending:

| Group | Identification | Bit fields and associated-byte order |
|---|---|---|
| WR0 | D7=0, D1:D0 != `00` | D6=count high follows; D5=count low follows; D4=A address high follows; D3=A address low follows; D2=source (`1` A, `0` B); D1:D0=`01` transfer, `10` search, `11` transfer/search. Consume A low, A high, count low, count high, skipping unselected fields. |
| WR1 | `(byte & 87h)==04h` | Port A: D6=timing follows; D5:D4=`00` decrement, `01` increment, `1x` fixed; D3=`0` memory, `1` I/O; D7,D2:D0 identify group. |
| WR2 | `(byte & 87h)==00h` | Same programmable fields as WR1, for Port B. |
| WR3 | `(byte & 83h)==80h` | D6=enable DMA; D5=enable interrupts; D4=match follows; D3=mask follows; D2=stop on match. Consume mask then match. Mask bit `1` ignores that comparison bit; `0` compares. D7=1, D1:D0=00. |
| WR4 | `(byte & 83h)==81h` | D6:D5=`00` byte, `01` continuous, `10` burst, `11` prohibited; D4=interrupt control follows; D3=B address high follows; D2=B address low follows. Consume B low, B high, interrupt control. |
| WR5 | `(byte & C7h)==82h` | D5=`1` auto restart, `0` stop at end-of-block; D4=`1` CE/WAIT multiplex, `0` CE only; D3=`1` Ready active high, `0` active low. D7=1,D6=0,D2:D0=010. No associated byte. |
| WR6 | `(byte & 83h)==83h` | Complete-byte commands below; BB requests one read-mask byte. Not every value matching this mask is a documented command. |

WR1/WR2 must be decoded before the general D7=0 case. Do not turn the
reserved WR0 class `00` into a transfer. The figure for WR3 appears to print
D7=0, inconsistent with stream identification/MAME; D7=1 is the usable
WR3 encoding. Figure 40 also repeats a direction label; WR0 prose explicitly
defines D2=1 as A source.

### Timing and interrupt associated bytes

WR1/WR2 timing byte: D1:D0=`00` 4 clocks, `01` 3 clocks, `10` 2 clocks,
`11` prohibited; D5:D4=00. D7, D6, D3, D2 control early termination of
WR, RD, MREQ, IORQ respectively: **0 selects termination half a clock
earlier** (Figure 41). Merely using D1:D0 is not full variable-cycle timing.
The manual requires early IORQ termination on the memory side of variable
I/O/memory sequential transfers for the NMOS part; CMOS differs.

WR4 interrupt control: D7=0; D6=interrupt on Ready; D5=status affects
vector; D4=vector follows; D3=pulse control follows; D2=pulse generation;
D1=end-of-block interrupt; D0=match interrupt. Nested associated order is
**pulse control, then vector**, when selected. Pulse control is an 8-bit
offset compared with the low byte of the byte counter, generating a pulse
every 256 operations after that offset. The vector is an 8-bit IM2 vector.
MAME modifies D2:D1 as `00` Ready, `01` match, `10` end-of-block,
`11` match plus end-of-block, preserving other vector bits. The rendered
Figure 44 prints all four causes as zero; do not cite that defective graphic
as proof of the distinct cause encodings. The cause map here is MAME evidence.

## WR6 command contract

Except ENABLE DMA, WR6 commands disable bus-request operation. UM0081 PDF
132 further states that all other control bytes disable DMA, with WR3 D6
as the other enabling exception. Interrupt enable is **not** DMA enable.
Configuration, LOAD, CONTINUE and read-sequence commands must not silently
start transfers. ENABLE must be last in an ordinary programming sequence.

| Hex | Command | Required distinction |
|---|---|---|
| C3 | RESET | Disable interrupt/request logic, clear interrupt latches and Force Ready, reset restart/WAIT/timing functions. Not a complete reset of every register/read sequence. |
| C7 | RESET PORT A TIMING | Restore standard timing for A. |
| CB | RESET PORT B TIMING | Restore standard timing for B. Figure 46's `C8` label conflicts with command bits, prose and MAME; CB is the encoding. |
| CF | LOAD | Load programmed source address, arrange destination loading as documented, clear byte counter and Force Ready; do not enable. Fixed destination requires the workaround below. |
| D3 | CONTINUE | Clear byte counter/restart counting with current addresses, not starting addresses; require subsequent ENABLE. |
| AF | DISABLE INTERRUPTS | Disable interrupt output, without resetting IP/IUS latches. |
| AB | ENABLE INTERRUPTS | Enable interrupt circuitry; retained event conditions may then generate an interrupt. |
| A3 | RESET AND DISABLE INTERRUPTS | Clear IP/IUS, clear Force Ready, disable interrupts. |
| B7 | ENABLE AFTER RETI | Ready-interrupt recovery/IOR latch handling; pair with ENABLE and RETI in the documented order. Not equivalent to immediate unconditional ENABLE. |
| BF | READ STATUS BYTE | Select status for the next read; complete an existing read sequence before using this command. |
| 8B | REINITIALIZE STATUS BYTE | Reinitialize match/end-of-block flags; not a blanket reset of Ready, operation or IUS status. Manual Figure 34 also connects it to IP reset. |
| A7 | INITIATE READ SEQUENCE | Start at the lowest selected read register; do not reset transfer addresses/count. |
| B3 | FORCE READY | Internal Ready override; not interrupt enable or bus grant. |
| 87 | ENABLE DMA | Permit requests only when Ready/Force Ready and interrupt/service constraints allow them. |
| 83 | DISABLE DMA | Prevent further bus requests; complete/release an already-owned transaction safely. |
| BB | READ MASK FOLLOWS | Consume one mask byte, then use A7 to initialize the read sequence. |

RESET recovery: a C3 written while a follow-byte queue is pending can be
consumed as ordinary register data. At power-up one RESET is sufficient;
six consecutive RESET writes guarantee recovery from an interrupted stream,
because WR4 can have five associated bytes. Do not add an out-of-band C3
escape inside a pending queue. MAME's reset-column algorithm is explicitly
marked improper; implement/test the manual's observable recovery contract,
not that internal algorithm.

### Readback, loading and terminal counts

Read-mask D6..D0 select RR6..RR0; D7=0. RR0=status, RR1/RR2=byte counter
low/high, RR3/RR4=A address counter low/high, RR5/RR6=B address counter
low/high. A7 begins the ascending selected sequence; after its end it
repeats. A single selected register repeats. Complete the current sequence
before BF or another A7. Define deterministic behavior for reserved/zero
masks without advertising undocumented compatibility.

Status in UM0081 PDF 134 (printed 116): D0=bus requested since LOAD
(`1` yes), D1=current pin Ready (`1` active), D3=IP (`0` pending),
D4=match (`0` found), D5=end-of-block (`0` reached); D2/D6/D7 undefined.
**MAME disagrees on D1**, reporting `!is_ready()`, and can include Force
Ready in that result. Keep this explicit discrepancy as an acceptance gate;
do not assume MAME's full status byte is the primary hardware contract.
Fixtures should mask undefined bits.

For ordinary sequential transfer with nonzero programmed terminal count N,
Table 11, PDF 94, specifies N+1 transferred bytes; stopped byte counter=N,
variable source counter=start +/- (N+1), variable destination counter=start
+/- N. The first destination byte still goes to its starting address.
MAME instead increments both addresses and its byte counter after each
completed byte. A RAM-copy test alone cannot validate counter readback.
CONTINUE must account for the silicon pipeline's next operation, not blindly
reuse a last-address counter as the next destination.

Zero is special: PDF 113 (printed 95) explicitly says programmed zero
produces 2^16+1 bytes, not one; MAME instead avoids terminal completion for
zero, with a game-specific comment. The earlier implementation plan's blanket
N+1 statement does not resolve zero. Require a deliberate, documented choice
and fixture for zero rather than silently mapping it to one byte. Table 11/12
also have different search/simultaneous-transfer counts and 2-cycle Ready
exceptions; a sequential-only increment must not claim those modes.

LOAD does not immediately load both silicon address counters. A fixed
destination must first be temporarily declared source and loaded, then the
true source declared and loaded (PDF 139). MAME loads both counters eagerly;
that convenience must not erase the IPL's direction-switching sequence.

## Ready, WAIT, ownership and interrupts

- FDC DRQ is a DMA pacing input, not an invented base-X1 CPU interrupt.
  MAME X1 Turbo feeds `DRQ xor 1` to DMA RDY. With WR5 active-low Ready,
  this yields one active request when FDC asserts DRQ. If direct DRQ is used
  instead, polarity must be matched explicitly; do not invert twice.
- Enabled plus Ready/Force Ready permits BUSRQ; only BUSACK grants bus
  ownership. No DMA strobe before grant. Use the same memory/I/O decode,
  IPL overlay, RAM-under-ROM writes, banking and DAM/GRAM side effects as
  CPU transactions, through an owner mux with one completion per access.
- Byte mode releases after each byte; burst releases when Ready becomes
  inactive; continuous retains ownership while Ready is inactive but pauses
  operations. Test Ready loss during read, write and inter-byte phases;
  complete an in-flight source/destination pair without duplicate data.
- WR5 CE/WAIT multiplexing permits WAIT to stretch owned cycles. Keep
  address/data/strobes stable; advance counters only on completed operations.
  Host SD ACK processing remains on clk_sys even if CPU/FDC/DMA enables stop.
- Force Ready is cleared by RESET, LOAD, A3, termination and DMA bus release
  (PDF 131). Consequently Force Ready in byte mode permits only one byte
  absent external Ready. MAME does not implement all these clearing points.
- Event selectors in WR4 and global enable in WR3/AB are separate. Conditions
  can latch while interrupt output is disabled (PDF 127); MAME's
  `trigger_interrupt` gates pending generation on global enable. Do not lose
  a disabled event merely because MAME does.
- DMA releases ownership before a CPU interrupt. Interrupt acknowledge is
  M1+IORQ, distinct from an ordinary DMA-port read. ACK takes IP to IUS and
  supplies one stable vector; IUS blocks this DMA's bus requests and lower
  daisy-chain interrupts until genuine RETI/reset handling. Plain RET must
  not release it. Ready interrupts additionally require IOR/B7 recovery.
- Pulse-generation INT activity while bus master is not a CPU interrupt.
  Auto Restart plus end-of-block interrupts requires special status/vector
  handling: the manual forbids status-affects-vector for that combination.
- Resolve physical priority from the local schematic and existing
  [CTC integration decisions](CTC_STATUS.md), not MAME's explicitly uncertain
  X1 Turbo daisy-chain order. The current bridge ties upstream IEI high;
  adding DMA IRQ requires a real upstream service/priority contract.

## What this Turbo IPL actually programs

These are offline semantic findings, not reproduced ROM tables and not an
executed boot trace. ROM addresses are evidence locators only.

| Inspected path | Semantic requirement |
|---|---|
| Startup at 1062 | Select the DMA stream and DISABLE DMA, then return to startup continuation. This alone establishes no addresses, count, Ready mode or interrupts. The older label “DMA initialization” must not imply full initialization. |
| Stream emitter at 753E; tables referenced from 74D4/74D9 | Programs transfer direction, all WR0 associated fields, fixed I/O versus incrementing memory port, byte mode, active-low Ready and CE/WAIT multiplex. Runtime substitutions supply an I/O address component and a memory address; literal table marker values are not DMA bytes. |
| Same disk setup, read masks and continuation at 75AF | Selects either A or B address-counter low/high readback, issues INITIATE READ SEQUENCE and performs two reads, then CONTINUE and ENABLE. One branch adjusts the returned address before subsequent work. Last-address versus next-address semantics are therefore firmware-visible. |
| Fixed-destination helpers at 7AA3/7AB8/7ABE | Programs a temporarily reversed direction, LOAD, then true direction and LOAD, matching the primary fixed-destination workaround. Includes runtime address/count values, byte mode and active-low CE/WAIT Ready. |
| Reverse transfer helper at 7AE2 | Fixed I/O Port A destination and variable memory Port B source; separately programs B address before LOAD. |
| Disable/re-enable paths at 756D, 7982 and 7ECC | DISABLE and later ENABLE are genuine independent commands, not implied by LOAD or port configuration. |

The inspected disk streams do **not** request interrupt-control follow bytes
or enable DMA interrupts. One explicitly writes WR3 with interrupts/DMA enable
clear. They also do not request variable-timing follow bytes, auto restart,
search/match or Force Ready in these bounded paths. This prioritizes byte-mode
DRQ-paced memory/I/O transfers and address readback for an initial increment;
it does not prove other firmware paths/software never use the omitted modes.
The older BIOS-style paths use an I/O-port layout different from the current
base FDC register block: inspect the runtime-selected port and actual Turbo
alias/control semantics before attributing failure to DMA alone. Do not
patch firmware or invent Ready just to bypass that acceptance gate.

## Original sequence acceptance, before native firmware

Construct new synthetic register sequences and media, not copied IPL tables.
Run at CE=1 and a divided enable; add stopped-enable and held-strobe cases.
These are proposed tests, **not tests run by this audit**.

| Gate | Required checks |
|---|---|
| Grammar | Every WR0 pointer subset; WR1/2 identification and timing follow; WR3 mask/match order; WR4 B low/high then control with all pulse/vector pointer combinations; BB mask follow. Use payload bytes equal to C3/83/87/BB to prove they remain data. Mix stream aliases; each held write is accepted once. |
| Reset recovery | Interrupt the maximum five-byte follow queue at every position; six C3 writes restore disabled parser operation. RESET does not secretly reset the read sequence. Hardware reset has an explicit separate deterministic contract. |
| Enable separation | Ready asserted throughout programming must not produce an early request. LOAD/CONTINUE/BB/A7/AB are not ENABLE. Test WR3 D6 exception and direction changes only after disabling. |
| Transfer matrix | Both directions; memory/I/O and fixed/increment/decrement combinations; address wrap; nonzero N=1,255,65535 => 2,256,65536 bytes in sequential mode. Check sentinel memory, exact port events, bus release and primary Table 11 counter readback, not just payload. Test special zero separately. |
| Loading/continuation | Fixed-destination temporary-source LOAD followed by true-source LOAD; altered start registers must not affect live counters without LOAD. CONTINUE preserves address state, restarts byte count and requires ENABLE; verify consecutive blocks without a duplicate boundary write. |
| Readback | A7 with A-address-only and B-address-only masks; low/high order, wrap and single-register repeat; mixed masks; BF status with defined-bit masks. Test real Ready and Force Ready separately and record the D1 policy explicitly. |
| Pacing and WAIT | Both RDY polarities, all three bus modes if claimed, Ready loss at each transaction phase, held WAIT on each port, no pre-grant strobe, stable ownership and exact-once side effects. Force Ready clears on release; byte mode must not free-run. |
| Interrupts | Event selector versus enable; disabled-event retention; match/EOB simultaneous causes; IEI blocked/unblocked, ACK stretch, vector stability, IUS/lower-priority/request blocking, RET versus RETI, Ready-before-BUSRQ plus B7 recovery, AF versus A3, reset and pulse/IRQ separation. |
| Shared-machine integration | DMA writes under IPL, reads through overlay, RAM/GRAM/DAM decode, PCG WAIT, CPU no-owner control and resume after grant. See [CPU seam audit](CPU_BUSREQ_AUDIT.md); its passing fixture alone does not cover the owner mux. |
| FDC integration | Original generated D88 reads/writes paced by real DRQ; protected writes, missing/bad ID zero payload, data CRC after complete payload, last byte/count alignment, multi-sector boundaries, SD ACK stalls and drive ownership. Reset/abort/eject while granted must drain outstanding host ACK without invented completion or duplicate disk writes. |

## Partial-implementation risks and next-step boundary

A register-only recognizer can make startup appear healthier while doing no
transfers. A copy engine can pass RAM tests while failing IPL due to follow
byte parsing, fixed-destination loading, active-low Ready, counter readback,
WAIT or bus ownership. The inherited MR16 refresh/DMA hack is not the contract.

MAME additionally leaves B7 fatal/unimplemented, has incomplete search/match
status/stop behavior, ignores some timing fields, does not universally disable
on configuration writes, and contains special zero-count behavior. Treat its
grammar and useful X1 wiring as secondary evidence, not wholesale acceptance.
Reject or report unsupported classes/commands deterministically; do not silently
pretend search, interrupts, timing shortening or auto restart are supported.

Recommended first bounded implementation gate: complete stream parser and
byte-mode sequential engine, primary-consistent nonzero counts/readback,
fixed/increment/decrement ports, Ready polarity, LOAD/CONTINUE, WAIT,
reset/disable and real BUSRQ/BUSACK owner mux; then synthetic FDC DMA.
Specify zero-count and status-D1 discrepancies before claiming an exact chip
contract. Full interrupt/search/burst/continuous acceptance remains separate
unless implemented and tested. Finally trace the unchanged authentic IPL's
executed writes and actual native transfer; an offline table interpretation or
startup screen is not native DMA acceptance. No hardware or timing-closure
claim follows from this document.
