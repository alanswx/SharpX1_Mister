# Turbo Z FM foundation

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

Trace native decode/aliases, CTC IRQ input/polarity, CT outputs and bus/WAIT
connections against the actual board. Add a separate capability/profile only
with real behavior; no fake identification/readback. Connect genuine CPU and
DMA transactions, qualify concurrent CTC/SIO/keyboard IRQ and reset phases,
then unchanged native register streams/games. Resolve signed PSG conversion,
analog gain/filter response, eight-channel clipping/noise/LFO/CSM/envelope
coverage, stereo simulator WAV interfaces and MiSTer audio delivery.
Current-source resource/timing/CDC and physical note-pitch/output checks remain
open. This first increment does not close Z5 or work groups 1–6.
