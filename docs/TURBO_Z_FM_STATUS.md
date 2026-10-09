# Turbo Z FM foundation

October 9 follow-up: [conservative decode and CPU isolation](FM_DECODE_STATUS.md)
adds exhaustive control/address guards and real neighboring-port transactions
to the standalone CPU/JT51 fixture. Shared-machine decode/IRQ/audio integration
is still required; the earlier qualifications below retain their source hashes.

October 6, 2026. Original standalone adapter/mixer and executed JT51 tests;
**not connected to the shared machine or accepted as native Turbo Z sound**.
Default X1/Turbo builds, machine.qip, audio ports and snapshot v12 are unchanged.

## Sources and frequency contract

Unchanged JT51 RTL comes from the collected `985a573dcfc1ff135553a39f7eae21d18ba57cbe`
snapshot. Its GPL-3.0-or-later notices remain intact. New adapter, mixer and
diagnostics are original GPL-2.0-or-later code; importing/testing the candidate
does not resolve the project's combined release license. [Provenance](CHIP_REUSE.md).

New local primary references (ignored PDFs, not bundled) are Yamaha's
[YM2151 datasheet](https://ftpmirror.your.org/pub/misc/bitsavers/components/yamaha/YM2151_199112.pdf)
and [OPM application manual](https://map.grauw.nl/resources/sound/yamaha_ym2151_synthesis.pdf).
Visually inspected datasheet pages 3–5, 8–10; application PDF 1, 7, 13–15, 23
(printed contents, 6, 12–14, 22). Rendered but not visually read pages are not
claimed as inspected. The application manual supplies timer periods
`64*(1024-NA)` / `1024*(256-NB)` input clocks and the A4 reference at
3.579545 MHz with KC=4A, KF=0, MUL=1, no detune/PMS.
The datasheet distinguishes the external input from its half-rate internal
clock. The [CZ-880 clock audit](TURBO_Z_PLAN.md) provisionally requires 4 MHz,
not MAME's 2 MHz. Physical oscillator/phase measurement remains open.

## Implemented adapter and mixer

`rtl/x1_fm.sv` drives JT51 on one master clock with fractional 4 MHz and
half-rate 2 MHz **enables**, no derived/gated clocks. Reset fixes accumulator
and half-rate phase; a stopped `enable` stops both rates without stopping
host transaction capture. `MASTER_HZ` must be at least 4 MHz.

The selected write interface captures A0/data once per held strobe and
dispatches a single immutable operation on a half-rate enable. A one-entry
pending slot asserts functional WAIT until dispatch. Writes attempted by
an invalid synthetic host while that slot is occupied are rejected and set
`protocol_error`; it is an adapter diagnostic, not a Yamaha status bit.
Reset, including a raw between-edge pulse, clears the pending slot and fault.
Status reads select genuine JT51 busy/timer bits; inactive reads return FF.
Caller software must honor busy—this adapter does not turn arbitrary writes
while busy into invented successful transactions. WAIT latency is not a
qualified X1 ASIC or Yamaha physical pin-timing model.

Signed stereo output uses JT51's native-resolution DAC-equivalent path,
not its higher-resolution alternate output. `rtl/x1_fm_mix.sv` adds an already
centered/scaled signed PSG value equally to L/R with saturation. A separate
mono sum includes FM L+R and PSG **once**. Unity digital gains are an explicit
functional policy, not measured board resistor gains/filter/speaker response.
The current unsigned base PSG interface has not been silently reinterpreted.

Standalone sources live in `rtl/x1_fm.qip`, read by the new Verilator target.
Do not add that manifest to shared-machine/Quartus builds until decode, bus
and IRQ integration are implemented and qualified.

## Executed verification

All three complete commands exit zero with Verilator 5.044 / macOS Clang:

| Master Hz | Executed `Vfm_tb` SHA-256 |
|---|---|
| 32,000,000 | `2da9136a20fa7386dd63f0ce0ed74f3ec89740cd982b314bd13a40d6be82fa56` |
| 28,636,364 | `9c567f588fc3f911f7ffe4e2ca047386fd8755f816202267f8f7adcd8c088f13` |
| 28,571,428 | `ec088dba0a1d53866ed9b5b82441fee489c97471debe33f5ba4659068d22bee1` |

```sh
make -C verilator test-fm HEADLESS_DIR=obj_dir_v12_fm
make -C verilator test-fm HEADLESS_DIR=obj_dir_v12_fm FM_MASTER_HZ=28636364
make -C verilator test-fm HEADLESS_DIR=obj_dir_v12_fm FM_MASTER_HZ=28571428
```

- Every running master edge checks the exact fractional-enable count and
  half-rate phase; stopped enables emit neither chip/half/sample strobes.
- Held writes dispatch once; poisoned external A0/data after capture cannot
  change the transaction. A stopped-enable queued write retains WAIT/data;
  negative queue overwrite preserves the original operation and reset recovers.
- CT1/CT2 programming, selected/inactive status, busy hold and exactly 32
  JT51 half-rate ticks (64 input clocks) per compliant data-write busy interval.
  This qualifies the candidate/adapter, not exact silicon busy/pin timing.
- Timer A presets 1020/1000 and Timer B 254/240: five genuine IRQ events each,
  four successive exact periods (256/1536/2048/16384 input clocks), flag
  isolation/clear, timer stop and raw queued-write reset. No forced chip state.
- Five original note profiles: left only, right only, both, neither, and an
  independently reset/reprogrammed repetition. Each captures 6250 stereo
  samples at exactly 64 input clocks/sample. Pitch is 491.619 Hz at the 4 MHz
  input, within the independent scaled Yamaha reference tolerance (0.5%).
  Routing isolation, silence and exact repeated samples pass.
- All 729 combinations of nine signed boundary values verify stereo/mono
  saturation without wraparound or duplicated PSG contribution.

Generated CSV/WAV files are ignored under the isolated output directories.
Logs: `/tmp/x1-v12-fm-32000000-3.log`, `/tmp/x1-v12-fm-28636364.log`,
`/tmp/x1-v12-fm-28571428.log`. The original failed
`/tmp/x1-v12-fm-32000000.log` is retained: its synchronous test counter missed
a raw asynchronous reset; the monitor now observes reset edges. It was not
fixed by masking an assertion or altering the FM engine. Earlier second-run
warnings were corrected with explicit arithmetic widths; vendor warnings,
where emitted, remain visible and no new suppression was added.

## Integration/acceptance still required

### Actual CPU bus qualification (October 6)

`make -C verilator test-fm-cpu HEADLESS_DIR=obj_dir_v12_fm` exits zero,
as do separate `FM_MASTER_HZ=28636364` and `28571428` invocations.
An original generated RAM program executes on the same `cpu`/TV80 as the
machine at CPU CE periods 1, 4 and 8 (nine clock combinations). Real OUT/IN
instructions poll busy, program CT1/CT2 and Timer A, wait for its flag,
stop/clear it, read both status ports and reject an unselected address.
Each completed program dispatches exactly ten writes; busy reads and CPU
WAIT stalls are observed, not assumed.

The first data write stops FM enables for 200 master edges while the CPU
continues; address/data/strobe remain held until dispatch. Retained-program
warm resets restart the CPU from HALT and from an asserted timer flag, the
latter with FM enables stopped. Once the CPU owns its queued write, another
200-edge hold passes before it resumes and completes independently.
Raw between-edge reset pulses are simulation stress, not silicon minimum
reset-width acceptance. No CPU/chip state is forced; RAM results are written
only by executed CPU stores. CPU interrupt service is not tested here.

| Master Hz | Executed `Vfm_cpu_tb` SHA-256 |
|---|---|
| 32,000,000 | `cee729850ca99c950f0779a004775a21c3baab7934b5088dfa13b58dc26a204b` |
| 28,636,364 | `54acb052a826ea42e1771b8e6277fd0a24e2891678d5f0d285f297397bdd8838` |
| 28,571,428 | `02232659742128420baf3cd3f209eee95ba2b9d93b86db371a0bf109904130d4` |

Logs: `/tmp/x1-v12-fm-cpu-32000000-4.log`,
`/tmp/x1-v12-fm-cpu-28636364-3.log`, `/tmp/x1-v12-fm-cpu-28571428-3.log`.
The original first-run watchdog is preserved: its clocked read-only response
presented the prior instruction byte during TV80 I/O sampling. The fixture
now selects live FM status during the read and retains it through the trailing
I/O wait, as in the existing CPU/SIO diagnostic. A later reset fixture checked
for a queue after 200 edges before slower CPUs had executed the write; it now
waits for real ownership before the unchanged 200-edge hold. Neither fix
changed the adapter or bypassed WAIT.

Exact test addresses `0700/0701` agree with local MAME and X Millennium,
not a proof of board ASIC aliases, DAM exclusion or IRQ routing. X Millennium
`io/sndboard.c` returns constant zero status, so it cannot qualify busy/timers;
its `io/ctc.c` selects an OPM CTC at `0704..0707`. MAME exposes this CTC but
marks interrupt wiring/order unverified and programs YM2151 at 2 MHz.
CZ-880 sheets 47/48 were reread for clock/data/analog mixing; visible sections
do not settle the optional-board CTC/daisy-chain contract. Do not invent IRQ
wiring from agreement between incomplete emulators.

The [21-target hosted run](https://github.com/alanswx/SharpX1_Mister/actions/runs/37497785084)
passes on `abda8ee`, including the earlier FM waveform fixture. The subsequent
workflow adds CPU/FM: [run 37515820620](https://github.com/alanswx/SharpX1_Mister/actions/runs/37515820620)
passes all 22 targets on `421f5c9`, including CPU/FM CE=1/4/8. The other two
FM master frequencies are locally executed gates, not hosted by this workflow.

### October 9 primary board-pin follow-up

The same hashed local CZ-880 service manual was rendered and visually inspected
again: main-board sheets 43/44 and sub-board sheets 47/48, with enlarged IC404
crops. This is a drawing audit, not measured hardware or an emulator run.

| IC404 YM2151 connection | Visible primary evidence |
|---|---|
| Clock pin 24 | Sheet 48 labels the net 4 MHz; sheet 47 connector T-2 carries 4 MHz |
| CS pin 7 | Sheet 48 labels YM2151; sheet 47 connector T-1 carries that select; sheet 43 IC17 IX0861CE names YM2151CE at pin 35 |
| A0 pin 4 | Sheet 48 labels AB0 |
| WR/RD pins 5/6 | Sheet 48 labels IOWE/IORD |
| Data pins 10,12–18 | Sheet 48 labels BD0–BD7 |
| CT1/CT2 pins 8/9 | Sheet 48 explicitly marks both NC |

The [Yamaha application manual](https://map.grauw.nl/resources/sound/yamaha_ym2151_synthesis.pdf)
pin diagram independently identifies 8/9 as CT1/CT2 and 2 as the IRQ output.
The CT output NC markings therefore must not be replaced with an invented
CTC trigger connection. IC17's select label does not disclose the ASIC's
address truth table, aliases, DAM/WAIT rules or interrupt arbitration.

The inspected sub-board sheets show no separate OPM CTC; main sheet 44
identifies the existing main Z80 CTC. This is bounded drawing evidence, not
proof that every optional expansion is absent. In particular it does not
authorize treating local MAME's optional `0704..0707` CTC as the built-in
Turbo Z sound path. The IC404 IRQ pin-2 route is not resolved by these crops;
do not infer direct CPU IRQ or physical NC merely because a line was not
found. Trace the full select/interrupt/expansion path before connecting it.

Ignored renders are `/tmp/x1-fm-net-audit-{47,48}.png`,
`/tmp/x1-fm-main-{decode,ctc}.png` and enlarged
`/tmp/x1-fm-chip-{left,right}.png`. No PDF/scan was added to the repository.

### Remaining machine gates

Trace native decode/aliases, CTC IRQ input/polarity, CT outputs and bus/WAIT
connections against the actual board. Add a separate capability/profile only
with real behavior; no fake identification/readback. Connect genuine CPU and
DMA transactions, qualify concurrent CTC/SIO/keyboard IRQ and reset phases,
then unchanged native register streams/games. Resolve signed PSG conversion,
analog gain/filter response, eight-channel clipping/noise/LFO/CSM/envelope
coverage, stereo simulator WAV interfaces and MiSTer audio delivery.
Current-source resource/timing/CDC and physical note-pitch/output checks remain
open. This first increment does not close Z5 or work groups 1–6.
