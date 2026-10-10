# Opt-in running RTC: sub-controller and shared Z80 evidence

This is an experimental replacement-MR16 integration, not native 80C49 firmware
or complete CZ-880 calendar compatibility. `RTC_ENABLE=1` is currently selected
only by original SystemVerilog diagnostics. Ordinary machine, C++ runner and
FPGA revisions remain disabled. The default machine still has the static-clock
defect; the new profile is non-savable and has no accepted RBF.

## Architecture and upload contract

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

## Default regression and remaining gates

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

Still required: enabled C++ runner/identity or explicit save rejection;
short/in-flight shared-Z80 reset; partial/malformed upload and
owned-DMA drain; real DMA/FDC/PS2/IRQ coexistence; native host byte-order/year/
carry/leap/power policy; native BASIC/software; other clock/profile combinations;
FPGA ROM inference, timing/CDC and physical clock behavior. No Turbo Z work
group is complete from this elapsed-time pass.
