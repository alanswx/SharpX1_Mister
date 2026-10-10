# Proposed combined RTC/cassette controller

October 10, 2026. **Design proposal only: no combined firmware, shared RTL,
runner or board implementation is qualified or enabled.** Existing independent
RTC/cassette profiles and their mutual-exclusion fatal remain unchanged.

## Observed native/reference evidence

The untouched native Rally-X program requests EF at PC 321B. In the frozen
MAME memory follow-up `output_files/mame-rallyx-memory-mStnwi`, actual three
mailbox reads at PC 322A return `12 03 47` at 71.435821750 seconds and
`12 03 49` at 73.973969750 seconds. Code beginning 157B discards hour and
stores minute/second into seed addresses 1577/1578. The helper at 1540–1576
is identical to the RTL 130-second RAM dump. Only the seed bytes differ in
1540–1580: RTL `00 00`, MAME83 `1A FC`, MAME130 `F7 70`.
These observations identify a seed-initialization difference, not proof that
it causes the partial playfield. No seed or program-memory patch is proposed.

Inherited `bios/reference/fw_subcpu/x1sub.asm:710–712` maps ED/EF to
`host_w3`; the clock-update branch at 330–334 is commented out. The cassette
extension does not supply a running RTC. Local MAME `x1.cpp:655–659` returns
hour/minute/second, initializes them from host time at 2141–2154, and uses a
software BCD timer. MAME runs therefore have time-dependent seeds. Preserve
each run's observed EF bytes rather than treating one seed as a reference constant.

The distinct third MAME reference `output_files/mame-rallyx-gram-4US3JD`
completed exit 0, session 90080, MAME PID 6678, with no input. At 83/130 seconds
it captures program/work RAM, PCG, TVRAM, AVRAM and 49,152-byte currently mapped
GRAM bank 0. Local `luaengine_mem.cpp:477–496` implements direct reads through
`get_read_ptr`; the observer never invokes CPU I/O reads, changes bank entry,
or writes emulated memory. Earlier reference folders and observers are preserved.
The GRAM follow-up observer SHA256 is
`0debe3c56ea1b7d6d023479ef4624d758565493f1ccd0b9d923108cffcad96fa`.
These are emulator-reference observations, not native hardware ground truth.

## Explicit opt-in configuration and replacement GPIO

Propose a new `RTC_CASSETTE_ENABLE=0` parameter. Setting it requires both
`RTC_ENABLE=1` and `CASSETTE_ENABLE=1`; reject inconsistent combinations.
The old two-flag combination still fails unless this third explicit opt-in is
set. Initially use a separate non-savable diagnostic runner, no board revision.
Preserve the default generated serializer declarations/order and ordinary interfaces.

Proposed combined-only OP5 layout:

| Bits | Owner | Meaning |
| --- | --- | --- |
| 5:0 | RTC | Existing RTC serial-output signals, unchanged order |
| 7:6 | Neither | Reserved zero |
| 9:8 | Deck | 0 eject, 1 stop, 2 play; 3 reserved/rejected by admission |
| 10 | Deck | Commit rising edge |
| 15:11 | Neither | Reserved zero |

This is a **replacement MR16 GPIO convention**, not Sharp pin wiring. Retain
the existing RTC return input and live cassette mode/sensor input packing;
preserve IP1 lower six host-control bits. Do not reuse OP6 joystick or OP7
seven-segment aliases. The legacy cassette-only nine-bit OP5 interface is unchanged.
The combined adapter translates the compact mode to existing deck commands;
unsupported native E9 arguments must not acquire an invented error response.

One shared RAM GPIO shadow owns all OP5 output values. Neither driver reads
PORT5 to reconstruct outputs: its inherited input is HWD_CLR. Each GPIO-store
routine saves the incoming interrupt-enable/flag state, masks interrupts,
updates only its owner mask, writes the complete shadow and restores the
original state (not unconditional STI). Explicitly test entry with IF already
disabled and ISR/nested-call use. Exact assembler operations need executed proof.

The deck routine emits commit low/high/low, each through serialized shadow
updates, preserving RTC bits on every store. RTC stores preserve deck bits.
ISR interleaving between deck stores must neither repeat a commit nor generate
an unintended RTC CLK/STB transition. A central masked-store routine is preferable
to duplicate implementations. Reset initializes shadow/commit low before any
command; startup STOP is an explicit command after reset release. Define reset
masking and mount/commit priority using the existing transport contract, not guesses.

## Firmware/API and initialization prerequisite

Use a fresh original combined builder, not edits to either independent builder.
Retain inherited copyright/comments and original source addresses. Assemble the
pristine source first, require exact baseline parity, and publish an exact
allowlist of changed low-bank bytes, new symbols, GPIO stores and RAM allocations.
Link the combined extension within 4000–4FFF only after proving that both
drivers plus shared routines fit; prove every new shadow/temporary fits the
existing 2-KiB controller RAM without overlap. Do not assume independent
extensions can simply be concatenated. Preserve index6 upload/readback and
the index7 non-RTC interpretation; no overlapping decode or silent aliasing.

GPIO sharing alone does not initialize the clock. `x1_upd1990_counter`
power reset produces zero/invalid state and cannot advance the calendar until
valid state is supplied. Keep that behavior; never manufacture a Rally-X seed.

First qualify a separate real-CPU EC/EE initialization test followed by a warm
reboot retaining calendar/year and running time, with no firmware/media reupload.
This establishes a valid CPU-programmed battery-state path, not untouched native
cold boot. Declare the programmed date/time in the evidence manifest.

For untouched native cold boot, propose a future public atomic battery-state
initialization API: valid calendar fields plus separately controller-maintained
year, accepted only during cold initialization before CPU/sub-CPU release.
Validate all fields, reject partial/invalid transactions, and acknowledge exactly
once. Retained-state boot must not silently overwrite battery state. A declared
fixed time is suitable for deterministic diagnostics; future HPS wall-clock input
requires a separate reviewed mapping and provenance. No host initialization port
or HPS mapping currently qualifies this proposal.

Warm machine reset must retain battery calendar/year; distinguish battery-clear
from reset. Counter phase remains retained across warm reset unless a genuine
Time Set command changes it according to the existing chip model. Define cold
initialization phase explicitly as replacement policy, not measured crystal phase.
Specify cold-init/reset/serial-command priorities and prevent concurrent partial
updates. Battery persistence across process/power loss requires a separate file/
hardware contract; no snapshot conversion or state-byte editing is acceptable.

## Required qualification before native experiment

1. Static baseline/patch/RAM/ROM ledgers and unchanged independent-profile gates.
2. Executed MR16 GPIO interleavings with saved IF, no HWD read-clear side effect,
   RTC serial edge counts and exactly one deck commit per command.
3. Real CPU EC/EE/ED/EF byte ordering, elapsed time, retained reboot, genuine
   PS/2 Ctrl+C/release and plain-C negative while waveform playback runs.
4. Cold public initialization admission, invalid/partial/repeated transactions,
   retained-state overwrite rejection, battery-clear and reset priorities.
5. Exact mutants for owner-bit clobber, unconditional interrupt enable, repeated
   deck commit, static EF, initialization loss and altered response ordering.
   Require matched data/control diagnostics, not generic failure or timeout.
6. Freeze all inputs/executable/assets before untouched native loading; preserve
   actual EF results, seed evolution, PCG/GRAM/text/attribute dumps and RGB.
   A changed scene alone is not compatibility or causal proof.

## Native boundary still open

`RTC_COMMAND_STATUS.md` records Sharp CZ-880 service sheet47 IC410/IC403 routing
and NEC uPD1990AC primary data-book pages800–803: a 40-bit calendar, no year
field, independent oscillator and register-hold versus time-set behavior.
The CZ-880 route must not be asserted as verified base-X1 routing. Obtain/inspect
the base-model primary route before native claims. Controller YEAR storage,
battery retention and native cassette STOP/PB0 policy remain separate questions.
Existing held-BREAK diagnostics are not MAME's read-cleared STOP behavior.

Next implementation requires Main review/approval of this contract, initialization
interface and combined ROM/RAM budget. No combined source implementation is made
by this document.
