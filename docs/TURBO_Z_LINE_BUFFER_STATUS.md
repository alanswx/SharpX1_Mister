# Turbo Z capture line buffer: standalone digital prototype

October 10, 2026. Z8 remains incomplete. The earlier CZ-880 sheet-46 audit
identifies IC56/57 as uPD41101C; this follow-up retrieves the manufacturer's
device documentation rather than inferring a generic capture FIFO.

## Retrieved primary reference

Local ignored `references/manuals/NEC_1986_Memory_Data_Book.pdf`, retrieved
from the [Bitsavers mirror](https://ftpmirror.your.org/pub/misc/bitsavers/components/nec/_dataBooks/1986_NEC_Memory_Data_Book.pdf).
14,399,588 bytes, 433 PDF pages; SHA-256:
`1da5cf7a4a74ce268fefda3d3c90dd3c945d9f4c7b1d14137a74b0cf3f1d03c7`.
Printed 3-1/3-2/3-9/3-10 (PDF 30/31/38/39) were rendered and visually read,
including reset/disable waveforms, not merely OCR/search snippets.
Copyright notices remain intact; the PDF is not committed or republished.

## Settled device requirements

NEC describes 910 eight-bit words with independent read/write clocks,
modulo-910 addresses, active-low synchronous address resets and enables.
Read disable freezes progression and makes outputs high-impedance; reset is
not a memory-clear operation. Write controls start a cycle, but DIN is
sampled on the following rising WCK edge ending that cycle. Read access
starts at rising RCK. The specified delay-line minimum is ten cycles;
re-read retention is bounded to 1 ms without overwrite. Speed grades differ:
the fastest specifies 34 ns minimum read/write cycles.

Therefore (engineering inference) neither power-of-two pointer wrap nor a
same-edge control/DIN write model is justified. An enabled FPGA model must
represent output ownership separately from an invented valid-black sample.
Direct 42.954540-MHz clocking is also not a qualified native-chip rate:
23.28 ns is shorter than even the fastest specified cycle.

## Implementation and acceptance sequence

1. Trace each board WCK/RCK/reset/enable net and chip speed grade, including
   IC58 control outputs and data direction. Do not infer them from ADCCLK.
2. Resolve first/last reset and enable-transition cycles with the complete
   timing diagrams/application note before writing an edge oracle. Preserve
   pending writes across stopped WCK; do not accept a shorter generic FIFO.
3. Implement the exact 910-word pin contract with independent enables/clocks.
   Verify wrap, repeated reset-to-zero reads, full-line replay, held disables,
   final write completion, clock stops and noncolliding simultaneous accesses.
   Keep unwritten/colliding/expired data outside accepted pixel assertions.
4. Connect the traced IC56/57 packing to an explicit deterministic external
   source and IC58 experiment, then qualify GRAM ownership, mosaic and formats
   using CPU-written controls and exact pixels. Chip storage alone is not Z8.
5. Qualify current-source resources, CDC/timing and physical capture separately.

No new RTL, machine capability, capture input, framebuffer, RBF or hardware
acceptance is supplied by this research. The IC58 quantization/position/key/
scroll protocol remains open; see [the capture audit](TURBO_Z_EFFECT_CONTROL_STATUS.md).

## Follow-up storage-cycle prototype

The subsequent `rtl/x1_z_line_buffer.sv` is original standalone digital RTL,
**not** part of `machine.qip`, the wrapper, any existing simulator or board
revision. It models the 910-byte storage-cycle prerequisite without guessing
IC58 controls, ADC clocks, capture pixels or GRAM writes. The research-only
statement above describes the earlier retrieval checkpoint; this section
records the later implementation and its narrower acceptance scope.

The manufacturer pin descriptions on printed 3-1/3-2 and waveforms
83-0036458/83-0037238/83-003648B on 3-9/3-10 were re-read visually. The reset
waveform with enables asserted reads zero throughout reset; the first
non-reset cycle reads one. The write-disable waveform completes the last
previously accepted cycle at the first disabled edge. This is the following
digital edge contract, not a same-edge control/data FIFO:

| WCK edge | New controls | DIN at this edge | Completed write | Newly opened cycle |
| --- | --- | --- | --- | --- |
| 0 | Reset, enabled | Unqualified | None initially | Address 0 |
| 1 | Normal, enabled | A | Address 0 = A | Address 1 |
| 2 | Normal, disabled | B | Address 1 = B | None |
| 3 | Normal, disabled | C | None | None |

Pending address/write permission survives stopped WCK; DIN is sampled only
when a subsequent WCK edge closes that cycle. Synchronous reset selects zero
without clearing memory. Next-address counters wrap at 909, not 1023.
RCK starts reads using its own sampled reset/enable, independently of WCK.
`output_owned` represents driven versus high-Z ownership at an FPGA boundary:
it is **not** sample validity or a promise that disabled output is black.
Disabled reads retain the prior byte while withdrawing ownership. Before
caller-provided address reset, cursor/data behavior is unqualified; internal
known flags prevent fabricated accesses from initialized simulation counters.

The prototype has no tAC/tACR/tHZ/tLZ analog delay, dynamic decay model,
collision-forwarding contract or native rate detector. A future consumer must
track written/usable data, collision exclusions and retention/delay limits;
output ownership alone cannot admit a valid capture pixel. The disabled-reset
priority follows the pin-description functional contract, not measured board
behavior or an independent reset/enable interaction waveform.

```sh
make -C verilator test-z-line-buffer
```

Delay-aware Verilator 5.044 builds without warning suppressions. Both profiles
complete zero: WCK/RCK periods 70/110 ns with zero initial phase, and 102/146 ns
with a 17-ns read phase. They check 1,163 completed writes and 3,509/3,524
reads, all 910 locations and all 256 byte values; repeated zero-reset replay,
disabled progression/output ownership, modulo wrap, pending write completion
after stopped WCK/disable and stopped-RCK recovery are exercised. Simultaneous
clocks operate on explicitly disjoint address ranges, with a two-sided
same-address collision assertion. Accepted re-reads finish within 456/616 us;
the explicit stopped-write readback also waits at least twelve WCK cycles.
These selected tests stay inside the documented retention/minimum-delay
envelope; they do not establish an expiry model or an IC58 rate contract.

The matched negative feeds beginning-cycle DIN instead of ending-cycle DIN.
It fails the same `line-buffer ending-edge/reset/wrap byte oracle`; a timeout
or unrelated compile failure cannot count. This is a counterfactual input
pipeline, not an injected machine state or a claim to have modified a native
chip. The first ownership fixture compared a live control after its sampled
edge; the final oracle captures ownership on RCK and compares the settled
output with that sampled value.

Combined final/adjacent log: `/tmp/x1-z-line-buffer-final-adjacent.log`,
terminal zero. Existing exhaustive ADC pinmap and effect-control/negative
gates also pass; they still are not captured pixels. RTL SHA-256:
`1c287045227a5ede4e82683af13ae9fc46084144d4aac2d2258860dfe4a48c3f`;
fixture SHA-256:
`8e4c87cad962d64b944b35e2f13741614d4e8dceedd53915e8133350d960c138`.

## Remaining full capture gates

Trace actual WCK/RCK/reset/enable nets and speed grade, reconcile custom ASIC
packing/control phases, implement deterministic ADC-to-buffer-to-GRAM
ownership and effect processing, and qualify CPU-controlled formats/position/
mosaic/key/scroll/telopper with exact active pixels. Native software,
current-source FPGA resource inference/CDC/timing and physical capture remain
required. Standalone storage does not finish Z8 or the full goal.
