# Calendar/RTC contract and current missing-tick diagnostic

October 9, 2026. The machine presently implements partial MR16 command
storage, not a working battery-backed clock. No active-machine firmware/RTL
or default profile has been changed in this investigation. Z7 and the sub-CPU milestone remain
open; the two physical 80C49 processors are not interchangeable with MR16.

## Primary chip contract

The NEC 1983 Consumer IC Data Book, PDF pages 800–803 / printed 795–798,
was rendered and visually read. [Manufacturer scan mirror](https://ftpmirror.your.org/pub/misc/bitsavers/components/nec/_dataBooks/1983_NEC_Integrated_Circuits_for_Consumer_Use.pdf).
The uPD1990AC has a 40-bit serial calendar, **no year field**, and no automatic
leap-year adjustment. Its month is hexadecimal; other fields use BCD, with
weekday 0–6. Seconds shift first, least-significant bit first, followed by
minutes, hours, date, weekday and month. Register and pulse-control command
groups retain independent selections. Register Hold stops shifting, not
timekeeping; Time Set holds the counter until another register-group command.
These rules contradict a naive year-aware Gregorian chip replacement.
The local MAME host-time/year policy is not native chip qualification.

The CZ-880 serial wiring is now traced below. Controller-maintained year,
invalid-date policy, leap correction, warm reset/power-loss retention and
physical phase still require tracing and tests. Do not substitute a uPD4990 serial-command
table or infer new pins from its backward-compatible mode.

## Existing firmware evidence

`bios/reference/fw_subcpu/x1sub.asm` stores three command bytes for EC/date
and EE/time; ED/EF use `host_w3`. Calendar and time occupy separate four-byte
slots. The timer interrupt toggles the blink bit every 500 ms, but its
calendar/one-second follow-up is commented out. No year/month/date increment
routine is present at that site. Source SHA-256:
`54722d7147f1a02395b68932dca3742e9e0f8639b4f6ebba6c4552fd214bfdc2`.
Current firmware ROM `rtl/sub_rom.v` SHA-256:
`232493977317551351623d19f85f15e2bfac45609d1f853245de0aa02c3908db`.
No RTC host-time port is currently connected in the wrapper. Source inspection
alone was not treated as an executed missing-tick result.

## Original CPU diagnostic

`verilator/tests/test_rtc_commands.py` builds a small original IPL and loads
it through ioctl. Real Z80 OUT/IN poll PPI mailbox status and send EC/EE,
read ED/EF, execute four 65,535-iteration instruction delays, then read both
again and HALT with `RTC2`. There is no private ROM, injected RAM, forced
clock/timer state, disk or keyboard input. The instruction delay exceeds
1.57 seconds at the native 4 MHz; the whole simulation lasts 2.2 seconds.
Date bytes are `31 C6 99`, time `12 34 56`. The test first requires exact
set/read bytes, then checks completion, clock/profile and asset identity.
Default acceptance requires seconds to advance; the explicit `--characterize`
mode instead requires the static-clock defect and **never sets RTC accepted**.

Initial fast characterization terminates zero on frozen ordinary runner
`e21f57815b0967ed804f2e7f1689858aa836f38da7b2daca7eadcc7960906b1f`:
both actual RAM readbacks are `31c699123456`, with `RTC2` and HALT. Log:
`/tmp/x1-rtc-command-characterization-fast.log`. The generated IPL SHA-256 is
`48508a1cf3d60df0c952d9bf6650f0673d1cc5586238b1e7f8ade6a979cf93cd`.
Zero disk requests/writes and PS/2 bytes confirm the fixture's isolated path;
zero frames without a programmed CRTC do not invalidate mailbox execution.
This is a reproduced defect, not RTC acceptance.

The final collector adds explicit ordinary-profile and collector-hash checks:
`ec026877ca73aaa4cedd100b6b960e1828861bc23e872fef11c9781e530640e2`.
It and the emitter are copied before new execution under ignored
`verilator/obj_dir_headless/rtc-command-characterization-fast/`; emitter hash:
`8dcc3c61cf7127ef36e374f8926ac6face79f36e588506cc5c39f0c9e1fc5ee2`.
An initial isolated launch failed on a missing emitter before native execution;
that log is retained, not counted as a clock failure or pass. After copying
the actual emitter, ordinary default acceptance terminates **one**, failing
precisely the elapsed-second assertion. Its native command terminates zero,
but retained evidence correctly keeps `rtc_accepted=false`. The independent
1.2-second probe terminates zero: actual RAM is `RTC1`, initial bytes are
correct, the second readback is still untouched and the CPU is not HALTed.
This verifies an actual elapsed window rather than relying only on instruction
timing arithmetic. A separate delay-aware characterization also terminates
zero on frozen `520d17f2...8d7321`, reproducing the same missing tick with
the same generated instructions and ordinary clocks/profile.
Logs: `/tmp/x1-rtc-command-acceptance-negative-final-fast.log`,
`/tmp/x1-rtc-command-delay-probe.log`,
`/tmp/x1-rtc-command-characterization-timing.log`.
Independent final checks verify all executable/collector/program hashes,
actual reports/readbacks and false acceptance. Delay-aware and fast full
main/sub/text/attribute/CPU dumps are byte-identical. These results establish
the current defect and a rejecting acceptance test, not a fixed RTC.

## Implementation and acceptance sequence

### Implemented calendar backend, not a clock fix

The new original `rtl/x1_upd1990_calendar.sv` implements the valid packed
calendar's next-second arithmetic. It has no oscillator, register storage,
serial commands, year field, MCU memory interception, board port or capability
signature. It is not in `machine.qip` or any board/runner profile, and does
not modify the frozen games/matrices. Invalid inputs retain their bytes with
`state_valid=false`; this explicit caller contract is not measured invalid-data
silicon behavior. `month_wrapped` is a helper result, not an invented RTC pin.

`make -C verilator test-upd1990-calendar` terminates zero without warning
suppressions. Its independent integer-time/table oracle checks **351,748**
cases: every second at four boundary profiles, every ordinary date plus
manually set February 29 at every weekday (midnight and midday), and all
independently invalid byte aliases. Three matched candidate mutations fail
the unchanged oracle: naive hexadecimal seconds, automatic February 29, and
ignoring invalid-state permission. The test asserts its full case count.
Log: `/tmp/x1-upd1990-calendar-final.log`. RTL SHA-256:
`a4f2ade6c2c1b8de7bfeed4e738faf8f6743bb09f79ba7e4a050869996315188`;
fixture:
`d8106eb631eac0b54797e23a23973676090e60441392b4b21c27086b793a9dd7`.
CI now schedules the asset-free target; hosted results remain separate.
The real-CPU elapsed-time test is still failing: this backend is necessary
calendar behavior, not a connected running or battery-backed clock.

The existing local MAME generic device `src/devices/machine/upd1990a.cpp`
is now inspected separately from the X1 driver's host-time callback, not
executed or downloaded anew. SHA-256:
`3c12ef633ee513eec80682a5ae4ca318ac62f5943334a6cbc79b3f4dc448b3fb`.
Its inherited RTC interface defaults to no automatic leap support, corroborating
that boundary; the X1 driver does not instantiate this generic chip device.
The generic implementation shares a latched command variable across group
operations and resets TP on Register Hold, whereas primary group retention
needs separate qualification. Its divider-reset comment/implementation also
differs from the primary numbered-stage description. Do not copy those
details, untested test-mode behavior or uPD4990 extensions as native acceptance.

### Implemented independent normal-mode counter backend

`rtl/x1_upd1990_counter.sv` now stores the tested packed calendar and counts
qualified oscillator events independently of CPU/MR16 enable or mailbox state.
Its caller must provide exactly one synchronous SYS event per crystal edge;
it does **not** generate or synchronize a physical oscillator. Power/configuration
reset produces explicitly invalid state, not an invented date. Do not wire
ordinary warm machine reset to that input as a shortcut for retention.
Time Set holds calendar advancement and preserves the specified lower divider
stages. `load_time` is a caller-qualified one-SYS command pulse, admitted only
in that mode. Raw CS/STB/CLK decode belongs to the separate serial frontend below.
Invalid loaded bytes stay invalid under the continuing divider. Tick/month-wrap
outputs are internal test interfaces, not claimed physical RTC pins.

The final `make -C verilator test-upd1990-counter` completes zero without
warning suppressions. Its separate integer-phase/original-calendar oracle
checks **1,201,499** SYS edges: uninitialized operation, exact division, held
low-stage wrap/release, two elapsed increments, midnight/month carry, manually
loaded February 29, invalid state, stopped oscillator and power reset. Twenty
additional load/hold/oscillator coincidence cases cover phases 1/1023/1024/
31744/32767. The full count is asserted. Three matched mutations fail the
unchanged oracle: gating crystal events on host activity, losing Time Set
qualification, and retaining the wrong number of low divider stages.
Log: `/tmp/x1-upd1990-counter-qualified.log`. Counter SHA-256:
`ebc4ce607e589a6ff40d44fbe006cb6bb341b1f0868e800ecc8cc179de677b6d`;
fixture:
`c971a9a9d04ea26c31b4d271c29b14d961acccda51d95d109009a511b5118228`.
The earlier calendar/negative target also passes again. CI schedules the new
asset-free target; hosted execution is not inferred from local completion.

This backend is not in `machine.qip` or any board/C++ profile. Serial and TP/
test-mode behavior, a real clock-event producer, MCU byte/year integration,
native physical phase, snapshots, fitted timing and battery persistence remain
required. The whole-machine EC..EF elapsed-time test still fails on the
unchanged machine; these event-count tests do not fix or qualify that path.

### CZ-880 pin audit and functional serial frontend

The existing [CZ-880 service scan](https://eaw.app/Downloads/Manuals/Sharp/CZ-880_Service_Manual.pdf)
sheet 47 is now inspected at pin-level resolution, with sheet 48 checked for
adjacent routing. Scan SHA-256:
`70a5f8da327ed25710e76d60117c4f82a655e6a7b29a34cb3239c75f0bd65a81`.
IC410 is the uPD1990AC; IC403 is the 80C49 sub-CPU. Exact connections:

| RTC pin | Function | IC403 connection |
| --- | --- | --- |
| 8 | CLK | P15, pin 32 |
| 6 | DATA IN | P14, pin 31 |
| 4 | STB | P13, pin 30 |
| 11 | DE/OE | P12, pin 29; also a power/diode/capacitor network |
| 2 | C1 | P11, pin 28 |
| 3 | C0 | P10, pin 27 |
| 9 | DATA OUT | T1, pin 39; **not P17** |
| 1 / 10 | C2 / TP | Grounded, not extra controller/timer inputs |

C2 being grounded makes register commands 0–3 the reachable command set on
this board, not an arbitrary simplification. CS is main-power-qualified through
the R424/D407/C418/R423 network. The separate X402 32.768-kHz crystal and
battery/diode supply are not the MCU instruction clock. Controller year storage
and power retention still need investigation; absence of a chip year field
does not establish absence of machine-level year handling.

Manufacturer PDF pages 804–805 / printed 799–800 were also rendered and
visually checked. They specify rising-edge serial shifting, open-drain outputs
and electrical setup/hold/propagation bounds. Those bounds are not fixed
measured delays and are not modeled by a zero-SYS functional event transition.

New original `rtl/x1_cz880_rtc.sv` decodes these synchronous P1/T1 connections,
qualifies command/shift edges with CS, retains mode and the 40-bit shifter,
and connects Time Set/Time Read to the independent counter. Held CLK/STB
does not repeat operations. Read capture retains a coherent pre-event calendar
while elapsed time continues. OE supplies sink/release permission and the
resolved T1 level assumes a pull-up, not a push-pull physical pin. Time Read
uses a provisional live-seconds-parity .5-Hz output policy; native phase after
selection remains unqualified. The tested no-invented-edge policy when CS is
asserted with pins already high is outside the native setup/hold contract,
not measured hardware behavior. CS/DE RC and voltage behavior are not modeled.

`make -C verilator test-cz880-rtc test-upd1990-calendar test-upd1990-counter`
terminates zero. The serial fixture asserts **137,050** scaled SYS edges:
all 40 walking/complement bits, real serial write/read, held strobe/clock,
coherent read across ticking, Time Set divider retention, Register Hold
timekeeping, CS-inactive timekeeping with unrelated P16/P17/serial activity,
OE release in every mode and configuration reset. Three matched wrong-pin
candidates (CLK, command and OE) fail the unchanged oracle. Calendar and
counter targets, including their negative controls, pass again. No warning
suppressions were added. Log: `/tmp/x1-cz880-rtc-qualified.log`.
Frontend SHA-256:
`bfb37a237f0767ba85b0fea516141bfb4918361976c3133723eaebec90710b9e`;
fixture:
`146bc7eb4ae4ef7835ae950c64ff021de243675d25f76f5094e64028e5709a4b`.
CI schedules the asset-free target; hosted execution is not claimed.

This module is **not** in the shared machine manifest or any board/C++ profile.
Scaled fixture edges do not qualify electrical delays, an oscillator producer,
MCU firmware, snapshots, native year handling or battery persistence. The
unchanged real-CPU EC..EF elapsed-time test still fails; this serial component
is not a machine RTC fix. The inherited MR16 listing ends at `0FEA`, leaving
only 22 bytes in its 4-KiB ROM. Its AASM 3.71/MR16 toolchain and a verified
storage/driver solution are integration dependencies, not permission to insert
a hidden main-CPU port or overwrite work RAM to make the test pass.

### Nominal SYS-derived crystal-event producer

Original `rtl/x1_rtc_clock_enable.sv` now produces a synchronous 32.768-kHz
event enable from the declared SYS frequency. It does not create another clock
domain. A bounded phase accumulator supplies exactly `floor(N*32768/CLOCK_HZ)`
events in N post-configuration-reset edges, with individual event intervals
rounded to whole SYS edges. There is no CPU/MR16 enable or warm-reset input.
Power/configuration reset clears phase; stopped FPGA time and crystal tolerance
are not modeled. Frequency/phase match to physical hardware is still separate.

`make -C verilator test-rtc-clock-enable test-cz880-rtc test-upd1990-counter
test-upd1990-calendar` terminates zero without warning suppressions. The new
test programs the serial chip solely through P1 pins while the producer is
held in configuration reset, then releases the source and compares every
elapsed edge with independent absolute rational event deadlines. A separate
counter initialized through its qualified load interface must match the serial
consumer's calendar, phase and tick on every measured edge. Each profile runs
two nominal seconds plus 17 SYS edges from December 31, weekday 6, 23:59:59:
the final calendar is January 1, weekday 0, 00:00:01, without inventing a year.

| Declared SYS Hz | Measured edges | Crystal events |
| --- | --- | --- |
| 32,000,000 | 64,000,017 | 65,536 |
| 28,571,428 | 57,142,873 | 65,536 |
| 28,636,364 | 57,272,745 | 65,536 |
| 65,536 | 131,089 | 65,544 |
| 32,768 | 65,553 | 65,553 |

The last two profiles check the high event-density boundaries, including one
event per SYS edge. Wrong declared frequency and host-gated consumer events
both fail the unchanged oracle. Power reset clears the source and invalidates
the calendar. Earlier serial/calendar/counter and negative-control targets all
pass again. The fixture time scale is arbitrary: frequency claims describe
declared elapsed-edge ratios, not the simulator's picosecond time scale.
Log: `/tmp/x1-rtc-clock-enable-final.log`. Source SHA-256:
`b96460a0de2e92a8ad281c3d0017c5f41f488b7a4a0cc882aacb79b137916ffe`;
fixture:
`e43725e9fbcabfff9f5d18ff59de83e1d1148279717c97e5288dd712b71d5fea`.
The first fixture attempt had width warnings; the next had the month/weekday
nibbles swapped in its expected January value. Both failed logs are retained;
the oracle was corrected from the primary packed-field contract, not by
loosening assertions. The final five-profile run above is the acceptance evidence.

The producer and connected test are still standalone, not added to any machine
manifest, profile or snapshot layout. Thus the machine's EC..EF elapsed-time
acceptance remains failing until a verified controller driver connects them.
These tests do not establish host-time initialization, battery persistence,
native pin phase, FPGA fitting or hardware RTC acceptance.

### Original real-MR16 driver diagnostic

`test-rtc-mr16-driver` now runs an original 572-word diagnostic ROM through
the actual `rtl/mr16_x1.v` / `rtl/mr16core.v`, with synchronous ROM/work-RAM
access and a real reset vector. Its explicit instruction encodings are derived
from the checked-in `MR16.MAC` operand tables, not a retrieved AASM executable
or a claim that the complete inherited assembler workflow now works. The ROM
size is asserted; no CPU registers, RTC internals or RAM result bytes are forced.

The proposed replacement-controller connections use the existing **unused
OP5 output** for native P1 bits, and spare **IP1 bit 5** for the resolved T1
input. This is test wiring only, not a newly invented main-CPU device port or
a native 80C49 pin claim. The driver executes real STM writes for serial
programming, a firmware-ready polling loop, Time Read/Shift commands and real
LDM reads stored into ordinary RAM. After programming `C6 31 12 34 56`, the
controller enable is stopped for exactly 64,000,000 SYS edges while the
32-MHz-derived RTC continues. The calendar must become `C6 31 12 34 58`;
after resuming, all 40 resolved T1 bits must match in RAM.

The final target terminates zero with the inherited controller running at its
ordinary full-SYS instruction cadence. Inverted T1 and gating RTC events on
the stopped controller both fail the unchanged oracle. Log:
`/tmp/x1-rtc-mr16-driver-qualified.log`. Fixture SHA-256:
`8c8e516e1d720ca2d2018e16c1f861b3472ea11b563c0bb0224325b80ea9e442`.
The fixture adds no warning suppressions; its target uses the existing style
of `-Wno-fatal` for inherited MR16 missing debug pins, vector/timer widths,
casex and incomplete-case warnings. No warnings originate in the new fixture.
CI schedules this asset-free target; hosted success is not inferred.

An earlier fixture with a 1-in-32 instruction enable failed real GPIO readback,
returning the read opcode instead of the input (`/tmp/x1-rtc-mr16-driver.log`).
It is retained as an unresolved response-retention/cadence experiment, not
silently counted as passing and **not yet proven a whole-machine defect**.
The successful ordinary-cadence diagnostic does not qualify arbitrary CE gaps,
electrical pulse widths or native controller firmware. The 572 words also do
not fit in the inherited firmware's 22 free bytes; a compact driver/verified
ROM-budget solution and EC..EF integration still need implementation. This
fixture does not patch the firmware, change machine behavior or close Z7.

### Opt-in MR16 response retention experiment

The sparse-CE diagnostic now has a default-off `RETAIN_RESPONSE` option in
`rtl/mr16_x1.v`. The ordinary mux remains a direct alias of its original raw
response. When selected, the experiment captures the one-SYS response tail
on the first stopped edge after an enabled instruction edge and holds it
until the next instruction enable. Reset clears validity. This does not
invent a main-CPU port, gate the RTC clock, modify firmware or introduce a
native bus WAIT model. Every existing machine/board instantiation leaves it off.

The RTC fixture also now requires actual writes to all 40 RAM result slots,
not only final bytes that might accidentally match untouched zeros. Frozen
executables and source/oracle copies are under ignored
`verilator/obj_dir_headless/rtc-retention-qualified-kW6Bv0OD/`. Five retained
cadences (1/2/3/17/32) and the ordinary unretained full-rate case all complete
the original serial programming, two stopped-controller seconds and 40-bit
RAM checks. The matched unretained 32-cadence control fails the stronger
actual-store coverage check, before the older T1-byte assertion. A first
collection stopped because its expected-negative filter recognized only the
older byte failure; no positive assertion was relaxed. The collector now
accepts these two explicit expected failure sites, not arbitrary process failure.
The remaining inverted-T1 and host-gated-clock controls also terminate with
their precise readback/stopped-clock assertions. Final SHA-256 checks pass all
fourteen frozen source/executable inputs. The final collection therefore
qualifies six positive profiles and three expected failures without changing
the binaries or test oracle after freezing.

Current RTL SHA-256:
`ab8cabbd687abb8b1c5cf540bff0c4de17bf2ae6081115601180973d5998dbdd`;
fixture:
`b613c190981d4569fa05986f6c65d5feb8f630e4b0a15b4ac594cb3d37429051`.
The ordinary `test-ctc` target independently completes zero again: eleven
reports include real MR16 receive-only keyboard/vector/held-ACK checks at
32,000,000 / 28,636,364 / 28,571,428 Hz. Log:
`/tmp/x1-rtc-retention-default-ctc.log`. This verifies the disabled path's
bounded keyboard/IRQ behavior, not all ordinary games or snapshot layouts.

Enabled-profile reset/stack/RAM-read/IRQ, snapshots, native timing and fitted
hardware still need qualification before any shared profile selects this
option. The fixture demonstrates a response-retention/cadence problem in
its explicit controller/memory configuration, not native RTC or whole-machine
compatibility. The real-CPU EC..EF clock test remains unfixed; controller
driver/ROM-budget integration is still the next machine-level dependency.

### Reproducible restricted source rebuild, not an RTC fix

The local/sibling tool survey found the inherited `a.bat` recipe and saved
HEX/BIN/listing, but no usable AASM 3.71 executable. The inherited macro
requires multipass immediate sizing. A new original restricted assembler,
`scripts/assemble_mr16.py`, implements the syntax actually used by this source,
with bounded layout convergence, strict final validation and no default file
writes. It is **not** an AASM implementation or a qualification of arbitrary
MR16 firmware. Its encoding references are the unchanged `MR16.MAC` and
`mr16core.v`; inherited notices and unresolved distribution limits remain.

`make -C verilator test-mr16-assembler` terminates zero. Six test groups cover
an independent checksum-valid Intel HEX reconstruction, exact saved binary
and 4,096-byte source parity, twelve literal encoding vectors, relocated
forward labels and separate code/data segments, conditional/comment handling,
seventeen rejecting syntax/range/overlap controls, and recursive-include
rejection. The CLI independently compares all 2,048 literal words in active
`rtl/sub_rom.v`. No firmware or active machine path is changed.
Log: `/tmp/x1-mr16-assembler-tests-first.log`.

The rebuilt image SHA-256 is
`2d9c9745e0a1a09d98c0e14ace627c03cd39d71ceb21e3fef5957e7a62428c01`.
It has `code_end=0FEA` and data end `1156`, leaving **22 bytes / 11 words**
in the existing ROM. The saved HEX has 255 valid data records and 4,071
explicit bytes through `0FE8`. Internal holes `0F6D` and `0FAB` are filled
with FF by the saved HEX-to-BIN path; the converter pads after its last byte
with zero. Treating every hole as zero would fail parity. The receive-only
ROM override remains separate and unchanged.

Initial parity attempts are retained as failures: Latin-1 `splitlines()`
misread a Shift-JIS comment byte as NEL; missing `.if` handling then failed
closed. The subsequent nine-byte mismatch exposed two inherited macro quirks
and the fill policy, rather than justification to patch the reference ROM.
The absolute JCS alias uses table index 16 without masking; prefixed
`_MEM_DISP11` places register fields differently from unprefixed LDM/STM.
The assembler reproduces those **historical bytes**, including STW `7100`,
`7101`, `7102`; it does not claim these implement the intended native memory
operations on the active MR16 CPU. Correcting either would be a separate
functional change requiring execution evidence. RTC driver development should
use qualified instructions, not infer working STW from artifact parity.

Assembler SHA-256:
`5f225a64639ed3c1626d55f8069a6a5f35e6a8aabade724884340bec5e8bc8fc`;
test SHA-256:
`ce80e2249568ff605157466eab5af18cc219f45c46a864b710e360388e8bd8ad`.
Original ASM, macro, HEX, listing and active ROM hashes remain unchanged.
This removes the missing executable dependency for reproducing this exact
source, but not the compact-driver/ROM-space, year/retention, real mailbox,
warm-reset, native software or hardware acceptance gates. In particular,
removing FDC/DMA support is not an acceptable space shortcut; an extended
replacement-controller ROM would require non-overlapping decoding and its
own explicit profile rather than aliasing work RAM at `1000`.

### Remaining integration order

1. Finish tracing controller year storage and power retention; reconcile
   EC/EE host byte order with primary X1 command documentation. Keep native
   pin-chip behavior distinct from host command emulation.
2. Connect the tested producer/serial chip through a verified controller driver,
   with an explicit initialization/retention contract. Keep clock advancement independent of CPU HALT, stopped enables
   and MR16 mailbox activity; do not derive battery persistence from RAM alone.
3. Require the unchanged elapsed-time test to pass in fast and delay-aware
   profiles, then add carry/short-month/year-policy, manual leap correction,
   command/tick overlap, partial input, pending replies and warm-reset cases.
4. Qualify host synchronization, snapshots, single-clock timer compensation,
   native firmware, Quartus and physical behavior separately. Do not expose
   Turbo Z identification merely because EC..EF now accept stored bytes.
