# Keyboard receive-only profile and cold-start regression

The cold F/I/J loss is reproduced and fixed in delay-aware Verilator baseline
and single-clock simulation. This is a firmware transport mismatch, not a
full keyboard-compatibility or hardware acceptance result.

## Cause and trace evidence

The shared `rtl/sharpx1.v` machine passes the HPS PS/2 input stream to
`x1_sub` but leaves `O_PS2CT` and `O_PS2DT` disconnected. The simulator supplies
the same one-way stream, with 50 us half-bit periods and no device responses
to host commands. The inherited firmware expects bidirectional PS/2: it sends
reset at startup, and sends LED commands while `IND_REQ` remains pending.
With no keyboard ACK, each command switches `ps2_scnt` to transmit mode and
waits for a timeout. Incoming scan-code clocks can instead advance that
transmitter; they are not necessarily decoded as receive packets.

The exact cold fixture is unchanged:

```text
25 2b
45 f0
47 2b
60 43
80 f0
82 43
100 3b
120 f0
122 3b
```

Before the fix, both full-machine runners send all nine bytes but record
only four IM1 replies: `b746 f700 b74a f700`. The missing make is I, not
a serial-script parser failure or CPU interrupt-buffer overflow. Its release
is ignored because I never became the current pressed ASCII key.

The standalone MR16 trace at 32 MHz, reset for 64 clock edges and with no
Z80 mailbox traffic, reproduces the same loss. Representative times are
nanoseconds from test start:

| Time | Observation |
| ---: | --- |
| 26,061,609 | F stored as firmware word `46b7`. |
| 48,061,766 | F release stored as `00f7`. |
| 48,062,609 | LED request sets `ps2_scnt=0080` (TX request). |
| 48,372,203 | Timer changes `ps2_scnt=0040` (TX shifting). |
| 60,000,000 | I packet begins while firmware is in TX mode. |
| 61,051,109 | Incoming clocks finish TX and re-arm RX, without storing I. |
| 101,060,984 | J stored as `4ab7`. |

This trace also establishes that continuous host polling is not necessary to
trigger the loss. `test_keyboard_receiver.py` keeps the inherited profile
as an executable reproducer, asserting four replies and observed TX modes.

## Change and firmware provenance

The shared machine explicitly selects `x1_sub.PS2_RECEIVE_ONLY=1`, appropriate
for the active HPS transport. Standalone `x1_sub` and `sub_rom` defaults remain
the inherited bidirectional profile, preserving reference-only instantiations.
In the receive-only profile, the instruction at
byte address `$045c` (`PS2_TX`) changes from `mov r1,#0` (`$7100`) to
`bra ps2_rx_en` (`$2ffb`, target `$0452`). This tail-call initializes the
11-bit receiver and clears its timeout, then returns normally to firmware.
Reset/LED requests therefore leave reception armed. Scan-code decoding,
modifier state, key buffering, mailbox transfers and interrupt handling still
execute in the inherited MR16 firmware; no ASCII/IRQ emulation bypass is added.

The matching conditional instruction is recorded in
`bios/reference/fw_subcpu/x1sub.asm`. It occupies one word, retaining every
subsequent address. `MR16.MAC` encodes the relative branch as
`$2f00 | (((target-PC)/2) & $ff)`. The regression guards both listing symbol
addresses and the inherited binary entry word, then compares all 2048 ROM
words between profiles and asserts that only this instruction differs.
Future firmware layout changes must update this guarded profile deliberately.

No binary, HEX or listing was regenerated. The inherited AASM flow remains
`bios/reference/fw_subcpu/a.bat`: AASM with `MR16.MAC`, `hex_ut`, `bin2ver`,
then concatenation of `head.v`, `rom.v`, and `bottom.v`. Those tools were not
invoked. The parameterized instruction substitution is in the synchronous RTL
ROM output, so normal Verilator/Quartus source builds include it directly.

Inherited references retained unchanged:

| Asset | SHA256 |
| --- | --- |
| `verilog/X1SUB.BIN` | `575b7530e9d8396fe2b606d76a5eb282a40b8adc87e41ea8be6dd9c7f00bba4e` |
| `x1sub.LST` | `627172f6023999923a9f0d41a7a73b23dba7334db987b7734e2cc67862011049` |
| `MR16.MAC` | `b55c157845c4eb6c33961b5027ea4d00dce7cd0801093df81d1c85dc22e052ed` |

The code remains derived from Tatsuyuki Satoh's inherited Nise X1 firmware.
Existing notices and unresolved redistribution restrictions remain in force.
The new profile and regression fixtures are local changes, not original
Sharp MCU firmware. A physically bidirectional PS/2 integration must select
`x1_sub.PS2_RECEIVE_ONLY=0` and connect/test its transmit pins. The reference
legacy instantiation retains that default; the legacy machine was not tested.

## Verification and limits

Commands from `verilator/`:

```sh
python3 tests/test_keyboard_receiver.py
python3 tests/test_keyboard_irq.py ./obj_dir_headless/Vtop
python3 tests/test_keyboard_irq.py ./obj_dir_single/Vtop
python3 tests/test_keyboard_poll.py ./obj_dir_headless/Vtop
python3 tests/test_keyboard_poll.py ./obj_dir_single/Vtop
python3 tests/test_subcpu.py ./obj_dir_headless/Vtop
python3 tests/test_subcpu.py ./obj_dir_single/Vtop
python3 tests/test_key_script.py ./obj_dir_headless/Vtop
python3 tests/test_key_script.py ./obj_dir_single/Vtop
```

The full-machine tests use the shared `rtl/sharpx1.v` path with TV80 Z80,
MR16 and synthesized test Z80 programs, without IPL/game/disk assets or saved
states. Baseline uses 32 MHz system and 28,571,428 Hz video clocks. Single
uses 28,636,364 Hz for both clocks with the compensated MR16 timer. Each IM1
case runs for 8,000,000 32 MHz reference units (250 ms), including RAM download
under reset; the 612-byte IRQ fixture reports 676 baseline or 677 single
reset edges. These counts are not single-clock elapsed-edge counts.

Cold and retained steady fixtures each produce all six replies in order:
`b746 f700 b749 f700 b74a f700`. An overlapping F/I/J fixture also checks
the inherited last-key release policy: `b746 b749 b74a f700`; releases of
older held keys do not release the current key. Polling tests exercise held
F/Space/Enter, Caps-off during startup and steady state, and Caps-off plus
Shift under continuous E4/E6 mailbox traffic. E7/E8 mailbox and key-script
parser regressions remain separate checks.

The standalone firmware receiver test covers 32,000,000, 28,636,364 and
28,571,428 Hz for 125.1 ms, using a 64-edge reset without a loader. It verifies
six firmware key-buffer transitions, zero TX modes, released PS/2 output pins
after initialization, and the one-word ROM profile. The actual board-frequency
check is a focused MR16 test, not a full-machine/hardware clock validation.

Verilator 5.044 builds retain inherited width, unused-pin, timescale and
`casex` warnings; no new suppression was added. Quartus was unavailable in
this environment and no hardware deployment was performed. LED output,
physical keyboard behavior, typematic repeat, exhaustive modifiers, E0/E1
sequences, malformed packets, full interrupt interactions and game/hardware
acceptance remain unverified by this change. Regenerate game snapshots before
using them to evaluate changed firmware behavior.

The README and main bring-up checklist are owned by the coordinating agent;
this keyboard-only change records its result here for that status update.
