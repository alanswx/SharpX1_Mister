# Calendar/RTC contract and current missing-tick diagnostic

October 9, 2026. The machine presently implements partial MR16 command
storage, not a working battery-backed clock. No firmware/RTL/default profile
has been changed in this investigation. Z7 and the sub-CPU milestone remain
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

The actual CZ-880 serial wiring, controller-maintained year, invalid-date
policy, leap correction, warm reset/power-loss retention and physical phase
still require tracing and tests. Do not substitute a uPD4990 serial-command
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

1. Trace CZ-880 RTC/control-processor serial nets and year storage; reconcile
   EC/EE host byte order with primary X1 command documentation. Keep native
   pin-chip behavior distinct from host command emulation.
2. Add a deterministic running clock with an explicit initialization/retention
   contract. Keep clock advancement independent of CPU HALT, stopped enables
   and MR16 mailbox activity; do not derive battery persistence from RAM alone.
3. Require the unchanged elapsed-time test to pass in fast and delay-aware
   profiles, then add carry/short-month/year-policy, manual leap correction,
   command/tick overlap, partial input, pending replies and warm-reset cases.
4. Qualify host synchronization, snapshots, single-clock timer compensation,
   native firmware, Quartus and physical behavior separately. Do not expose
   Turbo Z identification merely because EC..EF now accept stored bytes.
