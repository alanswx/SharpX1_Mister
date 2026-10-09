# Externally synchronized asynchronous SIO ×1 increment

October 9, 2026. Original RTL and original pin-driven fixtures; no emulator
code, firmware or private data imported. This adds functional ×1 RX/TX to the
existing asynchronous engine, not synchronous/SDLC operation or native pins.

## Primary contract

The existing local Zilog UM008101-0601 PDF has SHA-256
`b4efc81540c05990883cf4c7792c2a3d49fb7471bb5502931383ab55b4540886`.
Printed pages 285–287 (PDF pages 305–307, one-based) were rendered and visually
read. Table 23 distinguishes one, 1.5 and two stop bits; the receiver checks
one. Figure 118/Table 25 encode ×1 as WR4 D7:D6=00. The prose permits all
clock multipliers for asynchronous operation, requires the system clock to
be at least 4.5× the data rate, and assigns ×1 bit synchronization to external
circuitry. [Official manufacturer manual](https://www.zilog.com/docs/z80/um0081.pdf).

The implementation samples an externally aligned start on an RX event and
samples data bit zero on the following event. It does not wait for an
unrepresentable half-start validation in ×1. Oversampled ×16/32/64 start
validation is unchanged. Existing TX framing/divisor logic handles one or
two integral stop periods at ×1. Parity and short RX fill use the same public
format contract as the oversampled modes.

×1 **1.5-stop TX remains unsupported**: this interface has only falling TX
events, not an independent half-bit phase. WR4=08 is diagnosed and inhibits
this unsupported configuration rather than silently shortening the stop.
Full ×1 acceptance requires that phase extension and native timing checks.
No synchronous-mode configuration is accepted as a UART alias.

## Tests and controls

`test-sio-x1` uses separate RX/TX events, each one per eight accepted device
clocks, respecting the documented rate bound. Both real channel pins run
24 combinations of 5–8 bits, N/E/O parity and one/two stops, plus parity and
framing-error cases. Real FIFO reads, retained held-read values, short-data
fill, parity retention, every TX bit and all-sent through exact stop duration
are checked at CE=1/4/7. Stopping TX events while SYS advances must not shorten
the stop. Unsupported half-bit and synchronous-mode guards are required.

The unchanged new fixture initially fails on pre-extension RTL at the legal
format assertion (`/tmp/x1-sio-x1-before.log`). After implementation, all three
rates and the existing asynchronous/108-format tests pass
(`/tmp/x1-sio-x1-after.log`). An isolated `/tmp` source mutation accepts ×1
but incorrectly retains the old half-start receive state. The same fixture
fails its actual byte assertion (`00` versus `E5`), not a timeout or capability
check (`/tmp/x1-sio-x1-wrong-start.log`). The mutation is never applied to the
working RTL. Its source/executable remain under
`/tmp/x1-sio-x1-wrong-start.KZ1WJF` for inspection.

The shared-machine fixture adds a separate `SERIAL_X1=1` profile. The unchanged
generated IPL programs WR4=04 through actual CPU OUT. External A is 500 kHz
against 4 MHz device advancement; B uses the existing CTC2 event route.
Both DMA-present/absent models must pass real received bytes, nested IM2,
WAIT, partial-frame abort/reset and unchanged-IPL reboot. SYS=32 MHz and
VID=28.571428 MHz remain unchanged. This is experimental CTC event transport,
not native CTC pulse-width/phase acceptance.

The first shared ×1 execution fails its byte/nesting assertion
(`/tmp/x1-sio-x1-regressions.log`). Its start stimulus could count an already
queued idle event as the start sample, violating the externally synchronized
×1 contract. The stimulus now begins after a pin-clock falling edge and
sixteen SYS drain edges before the next rising event, with byte/interrupt
assertions unchanged. The complete 24-target SIO/decode/clock/modem/format/
IRQ/CPU/reset/DMA/chain/shared-machine recipe terminates zero with 206 PASS
reports (`/tmp/x1-sio-x1-regressions-synchronized.log`). Both ×1 machine
profiles pass, alongside both ordinary ×16 profiles and the disabled-SIO
negative. No warning suppression was added; inherited machine warnings and
the disabled model's unreachable WAIT warning remain.

Final source SHA-256:

| Source | SHA-256 |
|---|---|
| `rtl/x1_sio_async.sv` | `903e0f9b90678f29485cb0287ce253cb7c82a46e68247615d9bc0532c9788892` |
| `verilator/tests/sio_x1_tb.sv` | `7b5a9f89de3053549ed679bcf04801eab19e82b10aee663ad8d01f6377fbca2a` |
| `verilator/tests/machine_sio_tb.sv` | `b507bb0ebdbf7c63d4c949e4c29fdf84f6adcb0e914aae6c6f25f78b3f213301` |

Hosted diagnostics selects the new target; no new hosted outcome is claimed.

## Compatibility and remaining gates

Existing C++/board profiles still disable SIO. Ordinary fast rebuild exits
zero (`/tmp/x1-sio-x1-fast-build.log`) and yields the exact previously qualified
runner SHA-256 `f484bede6fde9a1f0bbba6ff30b6f5727c05041762a5b6179520b3b094e987f9`.
No state fields or top-level ports are added; ordinary snapshots remain v15.
There is still no enabled-SIO savable C++ profile. Older ordinary five-game
evidence binds this identical executable; it does not exercise serial ×1.
The rebuilt delay-aware ordinary runner also has its exact prior SHA-256,
`f1af4f88f4d3ba1c2467558ae7ca408444f98c6a4f0d34daa0f3bdcca1aad6d7`.
A fresh full delay-aware baseline invocation is running separately in
`/tmp/x1-sio-x1-baseline.log`; no terminal outcome is claimed at this checkpoint.

First-character implicit reset arming remains unresolved: inspected manufacturer
prose describes rearming but does not unambiguously specify the reset flag.
The explicit WR0 arming contract is unchanged. Native CTC/SIO clock phases,
physical input CDC, ×1 fractional stop, receive/busy-transmit break, remaining
serial modes, mouse/native software, enabled snapshots and enabled FPGA/
physical acceptance remain open. No new RBF or MiSTer load is claimed.
