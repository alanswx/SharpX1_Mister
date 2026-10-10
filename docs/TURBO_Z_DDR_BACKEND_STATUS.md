# Turbo Z full-font DDR backend prerequisite

October 10, 2026. Original GPL-2.0-only `rtl/x1_z_kanji_ddr.sv` is implemented
and tested as a standalone command engine. It is outside `machine.qip`, not
connected to the wrapper, loader or renderer, and not enabled by any RBF.
It does not replace the full-size simulation store yet.

## Executed verification

Run `python3 -B verilator/tests/test_z_kanji_ddr.py`. Main's independent rerun
completes zero in `x1-z-kanji-ddr-e9glnpw8`, log
`/tmp/x1-z-kanji-ddr-final-main.log`; the agent run is `5i86izdy`.
All sources and frozen copies remain unchanged.

- Every one of 262,144 physical bytes is written and read back at 32 MHz and
  100 MHz, and again at 32 MHz with maximum non-overflowing word base 1FFF8000.
  The latter is an interface-width test, not a valid MiSTer allocation claim.
- Each positive has 524,307 accepted requests/DDR commands and 524,297 consumed
  responses, with eleven reset cases. Suppressed cancelled responses explain
  the difference; no command replay is accepted.
- BUSY-held command payload, all eight byte lanes, immediate/delayed returns,
  held responses, blocked second requests, already-ready consumption, cancelled
  different-data write/readback and valid held through reset/drain are checked.
- Nine matched RTL mutations and an overflow-base negative reject at their
  exact assertions, not compiler failures or timeouts. Optimized Python is
  refused before evidence allocation or builds.
- All thirteen builds have zero warnings, without `-Wno-fatal`.

The responder drives data/READY before the sampling edge. Its independent
intent ledger follows accepted public requests, not DUT memory addresses;
the entire final medium is compared, including changed/cancelled writes.
Main's read-only review found no blocking defect within this single-outstanding,
synchronous-reset contract. Current DMA-wrapper lint also finishes zero; its
PLL stand-in does not establish Quartus timing or hardware acceptance.

Qualified SHA-256:

- RTL: `638861b6a6b06c0307e8bc045d239c766079b1875d6b8c3ab21fe4ea6248558d`
- Fixture: `51cddb8451b76fcdb2990703c878a0dbcaa416874c7c3c0f6d7eda15f4607025`
- Checker: `d8728b527b87791d567669eafa77d64f860d19245238581e6a7dc451b7901da5`

## Contract and remaining integration

One SYS-synchronous request transfers on valid/ready. No second request is
accepted until the response is acknowledged or cancelled. Reset suppresses
delivery but drains queued/accepted commands, including writes; memory clock
must continue. The caller retires valid after acceptance and cancels pending
valid on reset. Holding old valid through drain requests a new transaction at
the next ready edge—there is no caller-generation quarantine.

A write response acknowledges Avalon command acceptance only, not physical
persistence. Base allocation, read/write ordering and actual DDR behavior need
physical qualification. Do not connect backend reset blindly to held machine
reset: font loading while CPU/VID remain reset needs a separate frontend
ownership/drain lifecycle. Ordered image admission/publication, cache coherence,
concurrent display/CPU arbitration and the 93 ns glyph deadline remain open.
See [the full external-font plan](TURBO_Z_EXTERNAL_FONT_PLAN.md). Neither native
font conversion nor FPGA resource/timing closure is established by this test.
