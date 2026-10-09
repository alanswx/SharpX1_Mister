# Opt-in shared-machine functional SIO

Follow-up: [asynchronous ×1](SIO_X1_STATUS.md) extends the functional serial
engine and adds an externally synchronized shared-machine test profile.
Existing C++/board profiles still disable SIO; native pin phases remain open.

October 9, 2026. `rtl/sharpx1.v` now has a default-zero `TURBO_SIO`
parameter, active only with `TURBO=1`. It instantiates the original decoder,
asynchronous serial/interrupt subset, clock-event queue and CZ-851 functional
interrupt chain. All dependencies are in `rtl/machine.qip`. Existing board
and C++ simulator profiles remain disabled with explicitly idle serial pins;
there is no advertised FPGA revision or native serial/mouse capability.

## Integration contract and remaining native limits

- SIO is selected only at `1F90..1F93` on unambiguous non-ACK CPU read/write
  cycles, outside DAM/reset and actual DMA bus ownership. No ASIC mirrors or
  extended ports are invented.
- Real channel data feeds the CPU, including the retained synchronous IN
  response tail. Functional channel WAIT joins existing CPU WAIT conditions.
  Ready is deliberately **not** connected to DMA: no native schematic net
  establishing that connection has been found. DMA-owned SIO accesses are
  not implemented by this CPU-only decode increment.
- The SIO → DMA → CTC → keyboard owner uses actual IUS, preserves the chosen
  vector through ACK and routes RETI to only the highest serviced device.
  An absent DMA now passes IEI through rather than hard-wiring IEO high;
  ordinary profiles still present IEI=1 and retain previous behavior.
- DTRB selects external A clocks vs CTC1; B receives CTC2. This uses the
  previously traced CZ-851 net routing, not a presumed common CZ-880 route.
  **CTC ZC remains a one-SYS terminal event, not a native-width pin waveform.**
  The queue preserves rising-RX/falling-TX events at the serial advancement
  CE. Native CTC phases/counter synchronization, source-switch transients and
  physical serial timing remain unqualified. See [the phase audit](CTC_PIN_TIMING_AUDIT.md).
- External clocks/RX/modem inputs must already be synchronous to SYS. There
  is no physical pin CDC or RS-232 electrical mapping. Idle ties in the board
  wrapper do not constitute a usable serial connector.
- Device/event/read-tail state resets on the drained shared `core_reset`.
  CPU-owned transfers still use the existing DMA reset guard; this increment
  does not bypass its actual BUSACK drain or host-SD ACK handling.

Snapshot format is now **v15** after the shared interface/model increment.
The ordinary runner rejects v14 and earlier; regenerate from actual execution,
never patch/convert private states. No enabled-SIO savable C++ profile exists
yet, so no serial event/FIFO/service snapshot acceptance is claimed.

## Executed shared-machine verification

```sh
make -C verilator test-machine-sio HEADLESS_DIR=obj_dir_v15_sio_machine
```

Verilator 5.044, exit zero; final log `/tmp/x1-machine-sio-wait-final.log`.
`machine_sio_tb.sv` uploads an **original generated 8 KiB IPL through ioctl**,
honoring `ioctl_wait`. The actual CPU initializes its IM2 table/payload in RAM
and programs devices through real OUT instructions. No BIOS/private disk,
snapshot, patched game, forced trigger/service, PC or register state is used.

Two models run: SIO with completion-IRQ DMA, and SIO without DMA. Actual CTC0
timer interrupts the CPU; its handler stops the timer while retaining service.
The optional real DMA completes a four-byte `31..34` memory transfer through
CPU BUSRQ/BUSACK. Actual RX pins then supply B=`B6`, A=`A5`, nesting two SIO
slots over the lower devices. B's clocks come from the real CTC2 timer; A's
external clock uses the real DTRB selector and event queue. Both real IN results
and exact owned ACK/RETI order are asserted; low CTC IEI during SIO service
specifically detects the formerly incorrect absent-DMA pass-through.

CTS polling through actual SIO RR0 holds/releases the lower CPU handlers:
there is no invented host-release port in this shared-machine fixture.
After A RETI, warm reset clears remaining B/DMA/CTC service with the DMA bus
already drained. The CPU reboots its **unchanged retained IPL**, reinitializes
its own RAM table/payload and repeats the complete nested test without asset
reload. Finally an actual empty-RX WAIT-mode IN must remain stalled for 256
SYS edges until pin-driven `53` arrives; its stored byte and released WAIT are
checked. Exact four-byte DMA reads/writes/payload, final empty service, no
queue overflow/unsupported mode and DTR/TX idle outputs are checked.

The disabled-SIO model executes the unchanged IPL and must fail its real
programmed RR0 read assertion, rather than time out. Five PASS reports cover
the two cold/warm models and required negative control. The complete-machine
build retains inherited CPU/MR16/CRTC/PSG/FDC warnings; the disabled profile
also reports an unreachable constant WAIT condition after the expected earlier
read failure. No warning suppression or inherited chip behavior was changed.

Clock/reset scope: SYS=32 MHz, VID=28.571428 MHz, fixture external A clock
1 MHz synchronous to SYS, B timer constant 1 with /16 prescale. Each RX bit
spans sixteen accepted serial events; warm reset is held 256 SYS edges. These
are functional test clock choices, not an asserted native baud specification.
The existing board wrapper passes PLL-stand-in lint, not Quartus/hardware
acceptance (`/tmp/x1-v15-wrapper-lint.log`).

Source SHA-256: `rtl/sharpx1.v` is
`03aa7ba1d0d17f420723f4cfb92672f350fb1a27ee227cd48d3bf4593f901813`;
the executed fixture is
`2e686af430c115bf0c1b2d17e9c179dca99b4ff3d18475c5b4449c12fdd66e22`.
Both Turbo DMA and X3 board wrapper profiles also pass PLL-stand-in lint
(`/tmp/x1-v15-wrapper-profiles.log`). The hosted workflow selects the new
machine target; no hosted outcome is claimed here.

The complete ordinary `make -C verilator test-fast` exits zero
(`/tmp/x1-v15-fast.log`). Its separate snapshot test also exits zero
(`/tmp/x1-v15-snapshot.log`), with exact clock/RAM continuation, joystick input
persistence/override and rejection of a deliberately incompatible v14
negative header before deserialization. This changes a generated negative
fixture, never converts a real old state. Ordinary fast runner SHA-256 is
`f484bede6fde9a1f0bbba6ff30b6f5727c05041762a5b6179520b3b094e987f9`.
The [complete delay-aware v15 baseline](BASELINE_V15_STATUS.md) also exits zero.
Fresh five-game native v15 qualifications on that frozen fast runner pass under
ignored `obj_dir_v15_sio_machine/games-cRZFOe`; source/input and every native
checkpoint hash are independently rechecked after all processes terminate.
See [commercial evidence](COMMERCIAL_COMPATIBILITY.md). Those ordinary
gameplay checks do not enable or establish native SIO/Turbo Z compatibility.

## Still required

Native two-phase CTC/SIO pin timing and CDC; broader short/channel/held-ACK/
owned-SD reset phases; TX/Ready combinations and missing serial modes;
pin-driven mouse/native software; enabled-profile serialization;
enabled-SIO Quartus fit and available-board physical acceptance. Ordinary v15 baseline,
fast/snapshot and fresh commercial qualifications are tracked separately;
older v14 gameplay and fitted RBF evidence remain source-bound history.
Work groups 1–6 and Turbo Z are not complete.

## Quartus 17 parser portability follow-up

The source-bound `25e1c39` Turbo single-clock refit on misterubuntu terminates
with exit 3 before synthesis: Quartus 17.0.2 rejects module-level implicit
generate loops at `x1_sio_async.sv:403` and `x1_sio_irq.sv:100`. Source snapshot
and failure evidence remain under ignored `output_files/quartus-linux-dNvICqze`
locally and on the host; input-manifest SHA-256 is
`76d446426ada226957497420fb87176b892c62fd00bbc82fa262f4ee31c0f404`.
The build ran `2026-10-09T11:53:58Z` to `11:54:05Z`; it produced no qualified
new RBF, fit or timing result. The prior fitted `f013d02` artifact is unchanged.

The two original wrappers now use explicit `generate/endgenerate` around the
same named `channels` loops, preserving hierarchy and all functional logic.
All **23** SIO/decode/clock/format/modem/IRQ/CPU/reset/DMA/device-chain/shared-
machine targets exit zero with **195** PASS reports, including their required
wrong-owner/disabled/lost-event controls (`/tmp/x1-v15-sio-portability.log`).
Inherited complete-machine warnings remain; no suppression was added.
Updated wrapper source SHA-256:

| Source | SHA-256 |
|---|---|
| `rtl/x1_sio_async.sv` | `945b31ee8bbc6e14f9a52de1717418224179afb588371c635fd8d1862a0d46d0` |
| `rtl/x1_sio_irq.sv` | `1c1896f9891cca227da98c8abcb887750e80df20043a67e882297ba74f7f5576` |

Rebuilding ordinary `fast` also exits zero and produces the **identical**
`f484bede...` executable SHA-256 above (`/tmp/x1-v15-portability-fast.log`).
Thus the independently frozen five-game qualifications bind exactly the
ordinary executable still produced after this parser-only edit; no old state
conversion or relaxed assertion was used. Enabled serial snapshot/hardware
and the fresh native Quartus retry remain separate gates.

The `b235004` retry also terminates before synthesis, exit 3: this parser
requires the loop `genvar` declaration outside the initializer even with
explicit generate blocks. Failure evidence remains separately under ignored
`output_files/quartus-linux-gBoi5VOJ`. Both wrappers now declare `genvar channel`
at module scope and retain the same named generated channels. All 23 targets
again exit zero with 195 PASS reports (`/tmp/x1-v15-sio-genvar.log`); ordinary
fast rebuild again produces the identical `f484bede...` executable
(`/tmp/x1-v15-genvar-fast.log`). A new frozen refit is required before any
updated FPGA artifact/timing claim; the first two failures are not erased or
described as successful fits.

Final module-scope-declaration source hashes are
`b0579b7c352d43a5564cf874fcfa5e6c334d56d591b030d1be9b2383c94c36f9`
for `x1_sio_async.sv` and
`304e778ae4f551476e9fd2d5cc235841658c5919098b7d447aef987816c8b194`
for `x1_sio_irq.sv`. A new clean, source-frozen refit of pushed
`0009dd1bddc43a1f373cdd39443f102065fe97c7` starts at
`2026-10-09T12:04:17Z` under host
`output_files/quartus-linux-WosvSRv1`. Input-manifest SHA-256 is
`b0a1e93399051a5dc24266ad47de34974dca02b72ac0474b61729a398ca42006`.
Analysis/synthesis now **passes**, zero errors/143 warnings, and the observed
process was fitting at that observation. Log: `/tmp/x1-quartus-0009dd1-turbo-single.log`.
The terminal results follow below. This revision still has SIO disabled; it does not synthesize or
physically qualify an enabled serial connector. No MiSTer is accessed/loaded.

## Completed source-bound refit

The frozen `0009dd1` full Quartus 17.0.2 flow terminates successfully at
`2026-10-09T12:11:21Z`, exit zero, 152 warnings. Fit uses 20,403/41,910 ALMs,
32,028 registers, 393/553 RAM blocks and three of six PLLs. The retrieved
artifact is `output_files/quartus-linux-WosvSRv1/source/output_files/sharpx1_turbo_single.rbf`.
Its SHA-256 is
`eaca279a7c137dd6b9cef50a3da2fbb793b558eced3c3177ebb5b454352a3e1d`,
identical to the earlier fitted `f013d02` artifact. This establishes that the
disabled SIO increment does not change this board bitstream, not that enabled
serial hardware has been built or tested.

Supplemental path reporting and explicit all-corner TimeQuest both terminate
zero (`/tmp/x1-quartus-0009dd1-corners.log`). Independent inspection of all
40 summary tables (eight models, five check types, 264 numeric rows) finds
no negative slack or nonzero TNS. Minimum slack in ns across all models:
setup 0.514, hold 0.064, recovery 4.078, removal 0.317, minimum pulse width 1.122.
There are still three unconstrained input ports/seven paths and 44 unconstrained
output ports/50 paths; this does **not** establish complete timing closure.

The post-build input audit has 374 entries: 373 match and only `sharpx1.qpf`
differs, after Quartus updates its revision/date metadata. The generated QPF
SHA-256 is `f89a37b47bc401061b78cac7f19579c259002e48d64eddc2c932d36bfabb6bca`.
The nonzero manifest-audit result is retained, not reported as a full pass.
Full frozen sources remain on the build host; local ignored outputs preserve
the reports, manifests, metadata and RBF, not a copy of every source input.
No MiSTer was contacted or loaded. Native serial, Turbo Z and physical
acceptance remain open.

## Shared-machine reset during blocked receive

The follow-up fixture runs three native executions per enabled model: nested
service reset, reset during an empty-RX WAIT read, then complete receive and
HALT. The actual CPU writes `99` to the destination before each execution.
After 256 edges of confirmed stalled IN, a pin-driven partial start frame
advances four accepted RX clocks; real channel RX-busy must be set, WAIT must
remain asserted and the destination must still be `99`.

Warm reset is then held for 256 SYS edges. Each edge checks stopped CPU/device
CE, released WAIT, cleared read tail, cleared partial RX state and cleared
SIO/DMA/CTC service. No device state is forced. Serial inputs return to idle
and the CPU reboots the unchanged retained IPL without an upload. The final
execution repeats real nesting and receives/stores a fresh `53`, with exact
ACK/RETI/payload checks. Both DMA-present and DMA-absent models are required;
the unchanged disabled-SIO negative still fails its programmed read check.

This extends local functional reset acceptance, not actual OSD dispatch,
owned DMA/SD reset, physical pin clocks, short-reset or enabled-SIO snapshots.
Machine RTL and snapshot version are unchanged.

`make -C verilator test-machine-sio HEADLESS_DIR=obj_dir_v15_sio_machine`
terminates zero with seven PASS reports in
`/tmp/x1-v15-machine-sio-reset-wait-partial.log` (Verilator 5.044).
The extended fixture SHA-256 is
`92402f6892ba4664b1a6ddeb26baee4d5fac0a056d9414981a3f83bcf71f46c5`;
the earlier fixture hash above remains historical. SYS=32 MHz,
VID=28.571428 MHz and synchronous external A=1 MHz are unchanged.
