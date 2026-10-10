# Turbo Z capture line-buffer contract: researched, not implemented

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
