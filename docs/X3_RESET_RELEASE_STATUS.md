# X3 destination-clock reset release

October 5, 2026. Functional increment after `b8f7855`, not a timing-closed
FPGA build or physical reset/OSD validation.

## Evidence and change

The frozen `15a0655` reports distinguish same-clock timing from crossings.
At Slow 85 C the audited SYS→SYS setup path has +6.077 ns slack. The worst
setup path is framework HDMI `d[15]`→`hdmi_out_d[15]` under the selectable
HDMI/core-video clock mux, not a 32 MHz CPU same-clock path. The X3 clock is
absent from the inherited framework's clock groups; selecting the appropriate
data/clock modes and reviewing the crossings must precede any new exception.

Recovery paths include SYS `ioctl_download`→video PCG stage, timing divider
and SCRN synchronizer reset pins. Raw machine reset was released directly
into the independent X3 video domain. `x1_reset_release.sv` now asserts that
domain's reset asynchronously and releases after two destination edges.
The shared machine connects it to video control latches, the PCG video side
and the renderer's video state. CPU palette/transaction reset remains SYS
reset. Base/ordinary Turbo/single profiles bypass it, preserving their phase.
Storage and the font's availability survive warm reset as before.

The reset chain is marked `preserve`; that alone does not prove recognition,
placement or MTBF. No global clock-group/false-path exception was added.
The first reset-release stages' asynchronous pins and functional downstream
recovery/removal paths must be reviewed separately in a source-bound refit.
The frozen older RBF does not contain this change. State advances to **v10**;
reject v09/older states rather than editing their serialized bytes.

## Confirmed functional tests

- Destination half-periods 3/7/31: short pulses and phase sweeps assert without
  waiting for a clock, hold through a stopped destination and release on
  exactly the second edge. `/tmp/x1-v10-reset-pcg-unit.log`.
- Original high-speed PCG assertions pass all 16,395 transactions at six
  window/rate settings with the new reset release, alongside selector/font
  and base-PCG tests. No count, WAIT or one-write assertion was weakened.
- Delay-aware real CPU/PPI cold/warm polling passes the original 50 ms runs,
  25 ms/10 us reset and 512 polls. `/tmp/x1-v10-x3-ppi-cpu.log`.
- Delay-aware ANK16 40-column/raster-3 pixels pass at the original 200 ms,
  120 ms/10 us reset and retained font; unchanged 320×400 hash
  `8ec9d6393e3dde65`. `/tmp/x1-v10-x3-ank16-warm.log`.
- Fast expanded high-scan 80×12 passes all 640×384 pixels and periods for a
  full second, unchanged hash `8917c4ceac813725`.
  `/tmp/x1-v10-reset-high12.log`.
- Rebuilt base timing/reset/enables/delayed events/FST and base v10 snapshots
  pass continuity, rejected v09 header, clock mismatch and SDL joystick.
  `/tmp/x1-v10-base-timing.log`, `/tmp/x1-v10-base-snapshot.log`.
- Actual X3 wrapper lint passes with inherited warnings, not FPGA acceptance.
  `/tmp/x1-v10-x3-savable-lint.log`. X3 savable continuation/profile rejection
  also passes (`/tmp/x1-v10-x3-snapshot.log`).

| Runner | SHA-256 |
|---|---|
| Delay-aware X3 | `f5024d0073d7ca3487dda7e9b883ae4080a255298d680cbbd4ab09ed25d20267` |
| Fast X3 | `b80d0be25fdfcb24e092689df9cf8012cc2bd8720f7d69daf8695d605e038343` |
| Delay-aware base | `4779d8d7b0a0de14ade54dc5aefe4bb627431367109fda3c7053fb4b3654eafa` |
| Fast base SDL/savable | `c91280bb807ceeb3e000911769be708532e837ef5bdfea2196250af4b871cb9f` |

The 16/16 text matrix and complete fast/delay disk matrices are confirmed on
their earlier frozen binaries, not newly claimed as v10 acceptance. Native
v05 controls remain historical. Kanji, attribute combinations, active mode
switches, source-bound STA/CDC and MiSTer/OSD reset are still required.

## Next DMA ownership seam

`rtl/x1_dma_reset.sv` is an original standalone production-intended reset
guard, not yet connected to `machine.qip` or the shared machine. It retains
short reset requests, immediately stops CPU execution, and defers machine
reset while both actual ACK and BUSRQ assert ownership. Integration must
keep DMA/targets enabled to drain the started pair, then reset for four SYS
edges after ownership releases. A stalled target retains ownership without
a timeout. Reset can commit an already-started write; it is not rollback.
`test-dma-reset` passes idle/request/grant-release boundaries, owned stalls,
short pulses, stopped clock and held reset. Those synthetic ownership inputs
do not replace the actual CPU/FDC integration tests. Upload flow control,
shared decode/overlay, Ready polarity and coupled reset still need integration.
