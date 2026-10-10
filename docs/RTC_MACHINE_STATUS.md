# Opt-in running RTC: sub-controller and shared Z80 evidence

This is an experimental replacement-MR16 integration, not native 80C49 firmware
or complete CZ-880 calendar compatibility. `RTC_ENABLE=1` is currently selected
by original SystemVerilog diagnostics and a separately qualified C++ runner.
Ordinary machine/C++ and FPGA revisions remain disabled. The default machine still has the static-clock
defect; the new profile is non-savable and has no accepted RBF.
The RTC sub-controller already selects MR16 response retention; ordinary
profiles leave it disabled. Current reset-vector retention has the separate
bounded public-bus reset/stack/IRQ gate in `RTC_COMMAND_STATUS.md`. That gate
does not broaden the connected-machine/native/hardware scope recorded here.

## Concurrent real keyboard/mailbox qualification

`make -C verilator test-rtc-keyboard` passes six original Z80 diagnostics with
genuine PS/2 packets: F, Space, Enter, cold/steady caps-off and caps-off plus
Shift. The CPU repeatedly reads EF and polls E4/E6 while the inherited MR16
keyboard ISR/timer runs. Initial/final EC..EF data, translated ASCII and native
HALT/`RTCK` stores are required; no IRQ, mailbox or result memory is injected.
The 16-bit CPU counter records 127 clock polls in five cases and 502 in the
steady caps case. These 125-ms runs do not qualify elapsed-second progression.
The absent PS/2 stream fails the unchanged CPU completion oracle as required.

Ignored evidence is `verilator/obj_dir_v17_rtc/keyboard-qualified-zaba35ou/`,
log `/tmp/x1-rtc-keyboard-counted.log`. Independent auditing verifies all 136
original/frozen inputs, 13 generated assets, the frozen executable, identical
before/after manifests and six positive plus one negative result. The machine
uses delay-aware SYS 32 MHz / VID 28.571428 MHz with RTC enabled; ordinary
profiles remain disabled. This closes this bounded PS/2/mailbox coexistence
gate, not Z80 interrupt, FDC, native MCU, X3 or hardware acceptance.
This frozen checkpoint predates the separate X3 collector/build additions;
its original test/Makefile hashes must not be presented as current-source matches.

## Separate nominal-X3 combination: bounded qualification passes

`rtc-x3` builds in `obj_dir_v17_rtc_x3`, with RTC enabled, independent
32-MHz SYS / nominal 42.954540-MHz VID, timing delays and no savable model.
`test-rtc-x3-runner` and `test-rtc-x3-keyboard` use the same original CPU
fixtures/oracles, explicitly require the X3 JSON identity/frequency and freeze
their own inputs. The ordinary `rtc` target remains unchanged. The new build
and missing/short/save/restore rejection controls pass; the runtime rejects an
ordinary 28.571428-MHz override before execution. Elapsed/warm and all six X3
keyboard cases now complete zero. The first collector terminates after elapsed execution with a Python
argument-name collision: its negative-control loop overwrote the parsed options.
The collector now uses a distinct negative-argument variable; no RTL, CPU fixture
or result oracle is changed. Failed log: `/tmp/x1-rtc-x3-first.log`; corrected
repeat: `/tmp/x1-rtc-x3-corrected.log`. Its independently audited
`obj_dir_v17_rtc_x3/qualified-z0dbcoyy/` contains 138 original/frozen inputs,
three assets and identical before/after manifests. The real CPU observes
initial `31 C6 99 12 34 56`, elapsed seconds 57 and retained-IPL second-boot
`31 C6 00 12 34 59`, with no firmware/IPL reupload. The X3 keyboard evidence
`keyboard-qualified-545bxfvx/` separately passes independent 136-input/13-asset
auditing and its absent-key rejecting control. No programmed CRTC/pixel,
native calendar, complete device coexistence or hardware gate follows from this.
An ordinary-clock keyboard repeat
completes zero in `/tmp/x1-rtc-keyboard-x3-controls-baseline.log`, frozen
`keyboard-qualified-r79o5t56/`: six positives and absent-key rejection pass,
and an independent original/frozen 136-input and 13-asset audit passes.
The ordinary-clock elapsed/warm collector repeat also completes zero in
`/tmp/x1-rtc-runner-x3-controls-baseline.log`, frozen
`obj_dir_v17_rtc/qualified-hus1mnof/`. Independent auditing verifies all 138
current/frozen inputs, three assets, both native CPU results, four rejection
logs and the unchanged state sentinel. The X3 option does not replace or
silently reclock the ordinary profile.

## Short reset during actual RTC/keyboard polling

From `verilator/`, run
`python3 tests/test_rtc_keyboard_reset.py obj_dir_v17_rtc/Vtop`.
The unchanged original keyboard IPL is reset at 15 ms for 10 microseconds,
then genuine F/Space/Enter packets arrive at 25 ms. Each 125-ms run requires
the actual `RTCK`/ASCII/date/time stores and observer-only I/O traces showing
EC, EF and E6 traffic before and after reset. Exactly one cold firmware/IPL
upload is required. Removing the real reset still permits key completion but
fails the unchanged two-command-boot oracle; it cannot falsely qualify reset.

All three cases and the no-reset control pass in
`obj_dir_v17_rtc/keyboard-reset-7bj65duk/`, terminal-zero log
`/tmp/x1-rtc-keyboard-short-reset-controlled.log`. Independent auditing verifies
137 original/frozen inputs, seven assets, the executable, manifests and actual
two-versus-one EC command traces. The earlier three-case positive-only run is
preserved in `keyboard-reset-ely4gepi/`, not counted as rejecting-control coverage.
The X3 repeat (`--x3`, qualified frozen X3 runner) also completes zero in
`/tmp/x1-rtc-x3-keyboard-short-reset-controlled.log`, frozen
`obj_dir_v17_rtc_x3/qualified-z0dbcoyy/keyboard-reset-t9c7kwo9/`. Independent
137-input/seven-asset and actual command/store auditing passes at that clock.
This is a bounded short
mailbox/keyboard-reset gate, not caps-state retention, Z80 IRQ, simultaneous
FDC/DMA, native MCU or OSD-command dispatch acceptance.

## Architecture and upload contract

### Separate X3/Kanji combination: bounded simulation gates pass

`rtc-x3-kanji` builds a separate non-savable runner in
`obj_dir_v17_rtc_x3_kanji`, with the existing first-level Kanji renderer,
SYS 32 MHz / VID 42.954540 MHz and RTC. Ordinary profiles and board revisions
remain unchanged. `test-rtc-x3-kanji-runner` and
`test-rtc-x3-kanji-keyboard` require both clock and Kanji identities; no font
pixels are implied by their mailbox checks. The build, actual CPU elapsed and
retained-IPL warm-reset cases, six keyboard cases and absent-key rejecting
control now complete zero in `/tmp/x1-rtc-x3-kanji-first.log`.
Independent auditing checks identical before/after manifests, all 138/136
original and frozen inputs, executable/controller/fixture assets, actual
RTC2/RTC3 stores and keyboard translations. Frozen evidence is
`obj_dir_v17_rtc_x3_kanji/qualified-3npf1bl3/` and
`obj_dir_v17_rtc_x3_kanji/keyboard-qualified-v2kvwwi2/`.
The executable SHA-256 is
`eeb70f1a1ccac785c29edc2a0f8fc506a66c6ba35310615c57a9b6175eaa265e`.
Native game/font, broader device coexistence and hardware gates remain open.
Fresh protected native Kanji probes now complete their first cold executions:
Arcus has a readable disk-error dialog and actual DMA programming with DMA
disabled; Bastard remains at title. Repeats and combined DMA/ROM ownership
qualification remain open; see `COMMERCIAL_COMPATIBILITY.md`. These are not
native gameplay or complete font acceptance.

From `verilator/`, `python3 tests/test_rtc_kanji_pixels.py
obj_dir_v17_rtc_x3_kanji/Vtop` independently freezes the executable, shared
source graph, original Kanji emitter/oracle and RTC controller, then runs the
unchanged ten-case CPU/pixel matrix with an explicit controller upload. Its
loaded/missing, low/high-scan, width, bank/half/reversal/absent-level2 and warm
cases now complete zero in `/tmp/x1-rtc-x3-kanji-pixels-first.log`, frozen
`obj_dir_v17_rtc_x3_kanji/kanji-pixels-dqw01_sx/`. Independent auditing verifies
137 original/frozen inputs, the runner/controller/oracle/emitter, exact generated
font and all ten original IPLs, then checks all **1,536,000** actual RGB pixels.
No private native font is used in this matrix. It qualifies these original
CPU/loader/video cases while the controller runs, not simultaneous calendar
commands, native game/ASIC, full device coexistence or hardware.

`rtl/sub_cpu.v` uses the source-derived firmware from
`scripts/build_mr16_rtc_firmware.py`, without embedding private derivative bytes.
Its public firmware-access pins program/read a packed 8-KiB image while the
controller is reset. Active-controller writes are rejected; warm reset retains
the image. Hosts must upload the complete image before first release. Malformed,
partial or adversarial firmware images are not validated by this increment.

CPU ROM is 0000–0FFF plus 4000–4FFF. Actual work RAM remains the inherited
2 KiB at 1000–17FF; the enabled profile rejects 1800–1FFF and other aliases.
Ordinary decode/ROM behavior is unchanged. RTC P1 uses replacement OP5[7:0],
with T1 on the previously unused IP1[5]. This is proposed replacement GPIO
wiring, not a claim that MR16 port numbers are native MCU pins.

The synchronous 32.768-kHz enable follows `CLOCK_HZ` SYS events independently
of controller reset/wait. A separate `I_rtc_power_reset` initializes/loses clock
storage. It must not be connected to ordinary warm reset. No running time while
FPGA SYS is stopped, battery persistence or host synchronization is modeled.

The shared machine accepts these experimental ioctl operations only with
`RTC_ENABLE=1`, drained `core_reset`, and `!ioctl_wait`:

| Index | Address / payload | Operation |
| --- | --- | --- |
| 6 | 0–8191, packed little-endian controller image | Firmware upload |
| 7 | Address 0, byte 1 | Explicit simulated configuration/storage loss |

Index 7 is a qualification transport command, **not native CPU I/O**, model
identification or an ordinary reset action. Other bytes/addresses and running
uploads do not meet its admission expression. Enabled DMA/reset-drain and
adversarial transport qualification remain open; the existing admission guard
alone does not establish them. Existing board menus do not expose this profile.

## Actual sub-controller acceptance

`make -C verilator test-sub-rtc` runs at SYS 32,000,000, 28,636,364 and
28,571,428 events/second. The bench serializes all 8,192 firmware bytes through
actual public upload pins and checks every byte through the read interface.
It exercises unrelated E7/E8 and EC/ED/EE/EF through the actual host pins with
the inherited timer/RTOS interrupts running, not a substituted mailbox.

It programs date `31 C6 99` and time `12 34 56`, observes initial replies,
rejects an active firmware overwrite, holds warm reset for two seconds of SYS
events, then requires time `12 34 58` and date `31 C6 00` after reboot without
reupload. Zero YEAR explicitly reflects inherited RAM clearing, not a native
or battery-backed year policy. At every frequency, connecting warm reset to
the chip's power reset instead fails the unchanged retained-time assertion.
The bench steps nominal SYS events; it is not a physical crystal/RTC pin-phase
or rendered-video timing test.

The first run's ignored frozen evidence is
`verilator/obj_dir_headless/sub-rtc-32000000/qualified-xvcltpjn/`, log
`/tmp/x1-sub-rtc-first.log`. Its before/after manifest agrees at completion.
A later unrelated Makefile target addition means this is historical source
evidence; the current-source repeat is logged in `/tmp/x1-sub-rtc-current.log`.
Do not silently accept changed originals as a current hash match.
That repeat completes zero in
`verilator/obj_dir_headless/sub-rtc-32000000/qualified-cqfeotf6/`.
Independent auditing verifies all 41 original/frozen inputs, three executable
copies, unchanged emitted firmware and identical before/after manifests,
alongside all six actual positive/rejecting logs. Positive timer-ACK SYS-event
counts are 1,234 / 1,232 / 1,232 at the three listed frequencies.

## Actual shared Z80 elapsed-time acceptance

`make -C verilator test-machine-rtc` loads an original generated IPL through
ioctl index 0 and the derived controller through index 6, after the explicit
index-7 initialization. The IPL emitter is the **unchanged**
`verilator/tests/test_rtc_commands.py` diagnostic used to expose the defect.
Its actual Z80 configures the PPI, sends EC/EE, reads ED/EF, executes its native
delay loop and reads again. No CPU registers, RAM result bytes or RTC state
are forced. Observer-only RAM reads verify the real CPU's stores.

The enabled delay-aware shared machine completes: early date/time
`31 C6 99 12 34 56`, late seconds **57**, actual HALT/`RTC2` and **195,916**
observed MR16 timer-ACK SYS events. SYS is exactly 32 MHz and VID is the
independent checked-in 28.571428-MHz test clock (35,000-ps period). No CRTC is
programmed, so this is not an RGB/frame gate. The same original IPL and
transport with `RTC_ENABLE=0` reaches the missing-tick assertion with seconds
**56**, rather than falsely passing on command storage alone.

Frozen evidence:
`verilator/obj_dir_headless/machine-rtc-1/qualified-qcbyb2ky/`;
log `/tmp/x1-machine-rtc-compile-fixed.log`. Independent checks verify all 133
original/frozen source inputs, both copied executables, emitted firmware/IPL,
identical before/after manifests and the positive/required negative logs.
The earlier bench syntax failure is retained in `/tmp/x1-machine-rtc-first.log`.
Derived controller image SHA-256:
`bb8254c9b83a61184dcc58fa938129ea909977e08047c14fb1582bcf9859522b`.
Frozen derivatives retain inherited restrictions; they are ignored, not
release/distribution assets.

## Actual shared Z80 retained-IPL warm reset

`make -C verilator test-machine-rtc-reset` now passes a separate original
dual-boot IPL. Its first real Z80 boot sets/reads the clock, executes the native
delay loop, and halts with seconds 57. The bench holds ordinary reset for
64,000,000 SYS events (two seconds), without reuploading either firmware or IPL.
The second real CPU boot reads, rather than reprograms, the clock and stores
date `31 C6 00`, time `12 34 59`, and marker `RTC3`. Cleared software YEAR is
inherited controller behavior, not a native year-retention claim.

The required negative performs explicit index-7 clock-storage loss during the
same reset. It completes the actual second CPU branch but fails the unchanged
retained-time oracle with date/time all zero. No CPU state or result RAM is
forced in either run. This is a bounded idle/HALT reset at SYS 32 MHz and
independent VID 28.571428 MHz, not short/in-flight reset or owned-DMA acceptance.

Terminal-zero log: `/tmp/x1-machine-rtc-warm-first.log`; ignored frozen evidence:
`verilator/obj_dir_headless/machine-rtc-reset/qualified-l8_jw2ym/`.
Independent auditing verifies all 132 original inputs and frozen copies,
the copied executable, emitted controller/IPL memories, identical before/after
manifests, and both actual positive/rejecting logs. This follow-up changes the
bench/Makefile after the earlier elapsed-time and sub-controller qualifications;
those earlier frozen runs remain checkpoint-bound evidence, not current hash
matches for these changed files.

## Public ioctl admission and rejecting controls

`make -C verilator test-machine-rtc-transport` passes the delay-aware shared
machine at SYS 32 MHz / VID 28.571428 MHz, using its actual public ioctl inputs.
All 8,192 source-derived firmware bytes are uploaded while reset, then all
4,096 stored words are observed after each attempted overwrite. It rejects
high-address aliases at both image ends for bits 13–24, address `1FFFFFF`,
the wrong index, absent download/write strobes and running-machine writes.
Clock-storage loss is rejected for every wrong payload byte, every individual
nonzero address bit, absent strobes, wrong index and running-machine traffic.
The legal index-7 token does reset the oscillator phase while held reset.
In total **314 inadmissible transactions** pass the retention oracles.

Two required controls send legal traffic: an admitted firmware overwrite fails
the unchanged image-integrity oracle, and an admitted storage-loss token fails
the unchanged nonzero clock-phase oracle. These are actual writes, not forced
internal state. No game, CPU command or native clock policy is qualified by
this short transport test; partial valid images remain the host's responsibility.
Owned-DMA backpressure/drain is explicitly not covered.

Terminal-zero log: `/tmp/x1-machine-rtc-transport-first.log`; ignored evidence:
`verilator/obj_dir_headless/machine-rtc-transport/qualified-k1_r22eq/`.
Independent auditing verifies 130 original inputs and frozen copies, the
copied executable, emitted firmware memory, identical before/after manifests
and all three actual logs. Inherited machine warnings remain; no suppression
was added to hide a new transport warning. This adds a Makefile target after
the earlier qualifications, whose unchanged frozen checkpoints remain valid.
After the separate HDMI provenance test's Makefile addition, the transport
test repeats zero against current inputs in
`verilator/obj_dir_headless/machine-rtc-transport/qualified-uz4c7cx7/`, log
`/tmp/x1-machine-rtc-transport-current.log`. Independent auditing again verifies
all 130 current/frozen inputs, executable/MEM and before/after manifests.

## Real CPU/DMA reset drain with RTC enabled

`make -C verilator test-machine-rtc-dma-reset` now combines `RTC_ENABLE=1`,
`TURBO=1` and `TURBO_DMA=1` in the delay-aware shared machine. An original
ioctl-loaded Z80 program sends actual EC/EE/ED/EF commands, then programs a
real continuous Force-Ready 16-byte high-RAM DMA transfer. Observer counters
use actual owner/read/write transitions, never forced BUSACK or bus state.

Six cases request reset during the owned read or write phase, stop SYS for
1.25 microseconds, and select hostile controller-firmware, clock-loss or IPL
uploads. Reset must retain the actual CPU ACK, stop CPU CE, assert ioctl wait
and leave the controller/clock/IPL admission signals inactive. Traffic remains
selected through one real blocked SYS edge, then is removed before drain ends;
holding it into an admitted reset upload would instead be legal host behavior.

Exactly one started pair drains before machine reset. Both uploaded images
remain byte-for-byte intact. The retained IPL's second actual Z80 boot reads
date `31 C6 00`, time `12 34 56` without reprogramming the clock, programs a
fresh complete DMA and halts after all sixteen payload bytes match. Totals
require two genuine grants and seventeen read/write pairs. This short test
qualifies retention, not elapsed seconds (the separate warm-reset gate does).
Two controls deliberately upload after ownership release: an admitted
firmware overwrite fails image integrity; an admitted clock-loss token reaches
the actual second CPU read and fails calendar retention.

The first six-case run is retained in `/tmp/x1-machine-rtc-dma-reset-first.log`;
the subsequent positive/negative run completes zero in
`verilator/obj_dir_headless/machine-rtc-dma-reset/qualified-0ddkgc55/`, log
`/tmp/x1-machine-rtc-dma-reset-controls.log`. Independent review verifies all
131 original/frozen inputs, copied executable, emitted firmware/IPL memories,
identical before/after manifests, six actual positives and two rejecting logs.
A follow-up replaces an integer-as-condition with an explicit comparison;
current repeat completes zero in
`verilator/obj_dir_headless/machine-rtc-dma-reset/qualified-m8bigfk7/`, log
`/tmp/x1-machine-rtc-dma-reset-current.log`. Independent auditing again proves
131 current/frozen inputs, executable/MEM, manifests and all eight logs;
no bench warning remains. Earlier source hashes stay historical.

This covers the ordinary memory-target/Force-Ready DMA reset seam at SYS
32 MHz / VID 28.571428 MHz, not FDC/PCG/CRTC targets, Ready/IRQ/restart semantics,
serial/PS2 coexistence, arbitrarily long or partial uploads, enabled snapshots,
native calendar/year, stopped-FPGA battery time or physical hardware.

## Default regression and remaining gates

### Separate non-savable C++ runner qualification

`make -C verilator rtc` now builds a separate delay-aware Turbo/RTC runner in
ignored `obj_dir_v17_rtc/`, not an ordinary profile or Turbo Z identification.
It requires `--rtc-controller` with an explicit local packed 8,192-byte image.
Cold launch sends one index-7 initialization token, then uploads that image;
scheduled warm resets neither reload it nor issue storage-loss tokens.
Enabled output JSON identifies `rtc_experiment` and the controller byte count.
Both snapshot options fail before touching a state file. No enabled snapshot
identity or serialization compatibility is inferred.

Build log `/tmp/x1-rtc-runner-build-first.log` completes zero. The frozen
`test-rtc-runner` collector in `/tmp/x1-rtc-runner-first.log` has passed missing/
short-image and save/restore rejection controls with an unchanged sentinel.
Both actual IPL executions now finish successfully and the collector terminates
zero. Elapsed-time execution runs for 2.2 seconds, stores `31 C6 99 12 34 57`
after initial `31 C6 99 12 34 56`, and halts with `RTC2`. The dual-boot case runs
for 3.75 seconds, holds scheduled warm reset at 2.5–3.5 seconds, then stores
`31 C6 00 12 34 59` and halts with `RTC3`. Download counts are exactly 8,193
controller/token bytes plus the emitted IPL length; no assets are reuploaded
during reset. This runner uses SYS 32 MHz and independent VID 28.571428 MHz.

Frozen evidence: `verilator/obj_dir_v17_rtc/qualified-8_zqm99d/`.
Independent auditing proves all 137 current/frozen inputs, executable copies,
all three emitted assets, identical before/after manifests, both real CPU
execution logs, four rejection logs and the unchanged state-file sentinel.
This qualifies the explicit non-savable Turbo/RTC runner subset, not native
CZ-880 firmware/calendar, video modes, enabled DMA/serial/FM coexistence or
physical hardware. It does not close Z7 or enable ordinary board profiles.
The derived image stays local/ignored, with inherited restrictions preserved.

After adding the default-off simulator parameter, the default runner rebuilds
and passes actual pre-RTC state restore, normal snapshot tests, real E7/E8/
PS2 and all six keyboard polling cases. Evidence:
`obj_dir_rtc_disabled_fast/rtc-disabled-state-gii5lylw/`; logs
`/tmp/x1-rtc-runner-default-builds.log`,
`/tmp/x1-rtc-runner-default-cross-snapshot.log`,
`/tmp/x1-rtc-runner-default-snapshot.log`,
`/tmp/x1-rtc-runner-default-subcpu.log`,
`/tmp/x1-rtc-runner-default-keyboard.log`.
Default `--rtc-controller` also rejects before opening a nonexistent asset.

### Earlier default checkpoint and remaining gates

The RTC-disabled delay-aware build passes actual E7/E8/PS2 and six cold/steady
Caps/Shift cases. CTC/IRQ tests, three real-MR16 stretched-ACK clock cases and
the original/receive-only keyboard stream regression also pass. Logs:
`/tmp/x1-rtc-default-connected-subcpu.log`,
`/tmp/x1-rtc-default-connected-keyboard.log`,
`/tmp/x1-rtc-default-connected-unit.log`.

The new isolated default fast runner passes normal snapshot/clock/RAM/joystick
tests. An actual pre-RTC default executable's generated counter state restores
unchanged and matches uninterrupted CPU/clock/RAM/text/attribute execution.
The default serializer body/check value is unchanged versus `obj_dir_fast`;
v17 is retained for disabled profiles. This does **not** qualify enabled RTC
snapshot storage or reuse/convert private game states. Cross-build evidence:
`verilator/obj_dir_rtc_disabled_fast/rtc-disabled-state-7tro4z4a/`;
logs `/tmp/x1-rtc-default-connected-snapshot.log` and
`/tmp/x1-rtc-default-cross-snapshot.log`.
`make -C verilator lint-wrapper-turbo-dma` also passes the disabled RTC board
interface check (`/tmp/x1-rtc-default-wrapper-lint.log`), using the PLL stand-in.
It is not synthesis, timing or hardware acceptance.

Still required: native/software qualification of the enabled runner;
short/in-flight shared-Z80 reset; partial/malformed upload and
other owned-DMA target/drain combinations; real DMA/FDC/PS2/IRQ coexistence; native host byte-order/year/
carry/leap/power policy; native BASIC/software; other clock/profile combinations;
FPGA ROM inference, timing/CDC and physical clock behavior. No Turbo Z work
group is complete from this elapsed-time pass.
