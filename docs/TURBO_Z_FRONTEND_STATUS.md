# Turbo Z full-font upload/CPU frontend prerequisite

October 15 follow-up: this component is now connected by the separate
[external-font machine/board profile](TURBO_Z_EXTERNAL_MACHINE_STATUS.md).
[Actual MiSTer testing](TURBO_Z_EXTERNAL_HARDWARE_STATUS.md) exposed a final-SPI-
ACK deadlock: terminal-count WAIT prevented Main from ending a complete upload.
WAIT now releases when the last backend command drains; a separate count
guard still rejects extra writes. The default gate passes **39** cases,
including an old-condition control rejected at `Z_FRONTEND_END_COMMAND_WAIT`.
The c6 RBF has bounded physical DDR/pixel acceptance; timing remains open.
A subsequent malformed-stream repair removes sticky error from transport WAIT
and independently suppresses all post-error write admission. This drains Main's
ACK while preserving failed-image rejection. See the
[HPS protocol gate](Z_FONT_HPS_UPLOAD_STATUS.md); its new RBF/hardware gate is
now complete for bounded malformed/retry Main, DDR and pixel cases; timing
still fails. Standalone-only statements below describe
the original October 14 checkpoint.

October 14, 2026. Original GPL-2.0-only `rtl/x1_z_kanji_frontend.sv` wraps the
qualified DDR byte backend as a standalone synchronous component. Neither is
in the machine manifest or connected to a board, renderer or existing runner.
The full 262,144-byte simulation-reference store remains in place.

## Public contract

All inputs are synchronous to SYS; SYS and the memory interface keep running
during consumer reset/cancellation. The frontend keeps the backend out of
machine reset and drains its own outstanding owner before reassigning it.
CPU requests latch the complete physical 18-bit byte address, retain their
response until ACK, and require an observed request low before another capture.
An ACK held across cancellation cannot retire the next response owner.

Index-5 download START immediately applies `ioctl_wait` and revokes readiness.
The caller must guarantee CPU/VID reset through `upload_permitted`; it is not
a reset controller. Addresses must be exactly 0 through 262,143. WR held under
WAIT is legal; after capture, a SYS-observed WR low rearms the next byte.
Both index 5 and permission must remain asserted through falling-download
commit, even if the final DDR command is still draining. Readiness publishes
only after every captured byte has drained. There is no display cache to
invalidate or publish in this isolated component.

Cold reset revokes font readiness; consumer cancellation retains it. Either
cancels CPU delivery and suppresses held request/ACK replay. Bad order, short/
empty/overflow uploads, permission/index loss and cold-reset overlap prevent
publication; a fresh download edge can retry the complete image. Changing
another download's index to 5 mid-session, or starting under cold reset, is
rejected. After cancellation, the caller must wait for the current upload to
finish draining before starting another session.

## Verification

`make -C verilator test-z-kanji-frontend` completes zero in
`x1-z-kanji-frontend-bbr7fokk`, log
`/tmp/x1-z-kanji-frontend-final-address-ledger.log`: twenty-four positive
profiles and fourteen exact rejecting RTL mutations. All sixteen builds have
zero Verilator warnings under `-Wall`, without warning suppressions. Current
and frozen sources, executable hashes and run-log hashes pass a separate
read-only recheck. Terminal report SHA-256:
`b861d3484c8c00aa467c9973b8a34cb3ef3d64a60ed4ce37ccdc0e8b048ac8b9`.
The report records exact cycles, clocks and duration for every positive;
physical simulated duration ranges from 72 to 377 ms, not a native boot run.

At each of 32 MHz and 100 MHz, the fixture checks:

- Four upload START preemption phases: staged CPU SEND, BUSY-held DDR command,
  accepted read awaiting data, and held CPU response. START plus byte zero is
  offered together and held through WAIT until ownership drains.
- Complete upload/readback while consumer cancellation remains asserted during
  loading; the caller's CPU/VID reset permission is also held throughout.
- Three cold-reset CPU phases, plus final-write acceptance coincident with
  cold reset, lost permission, lost index, or an attempted excess byte.
- Two complete generated images per profile, with every byte changed in the
  retry. Every reset/error profile must successfully upload the new image and
  read every byte through public CPU pins. Final-write error profiles suppress
  the first image before its CPU scan; other profiles scan both images.
- In ordinary profiles, unloaded reads, clean START WAIT, empty/short/missing/
  duplicate/reordered/overflow admission, initial WR/START under cold reset,
  mid-download index change, retained warm cancellation, stale ACK and request
  suppression, held WR, same-edge/delayed DDR returns, and address changes
  after CPU capture. Exact request/write/read/consumption counts are required.

The independent write ledger follows accepted public upload intent. It checks
every DDR address, byte enable and data value, then the entire medium. A separate
CPU read-intent ledger checks each DDR word address and rejects unsolicited
reads, independently of collisions in generated font bytes. Neither derives
expected contents or addresses from DUT output addresses. All fixture access
is through public pins; no private font, internal forcing or memory repair is used.
Optimized Python must refuse before evidence allocation or compilation.

The fourteen mutants reject at their exact assertions: unloaded admission,
START WAIT, low/high CPU address corruption, upload data corruption, premature
publication, cancelled result delivery, stale ACK, CPU/WR replay, address
overflow, permission-loss error suppression, ignored excess byte and a backend
reset that loses the frontend's outstanding owner. Compiler failures and the
whole-test timeout are never accepted as matched controls. The bit-15 mutant
specifically guards an address alias that both generated byte images would
otherwise conceal. Earlier failed/review runs remain preserved; their coverage
and marker adjustments do not replace this final frozen gate.

Qualified SHA-256:

- Frontend: `ad8d27b111d4e59d1e10398c6c2e30e20a674bd77efb1c7b50ebe4b7509af95e`
- Fixture: `529b3378b9ed239a577d9cfe89d3550afc4774ac98451b913b3e1f8eb2760c54`
- Checker: `5b1f0827ba3f69a421702bac78da19aaa9dac882ad4f85e560939b58aa39e11c`
- Backend remains `638861b6a6b06c0307e8bc045d239c766079b1875d6b8c3ab21fe4ea6248558d`.

## Remaining gates

DDR write completion means command acceptance, not physical persistence.
Actual allocation, DDR ordering, cache invalidation, atomic SYS/VID descriptor/
glyph publication, CPU/display fairness and the approximately 93-ns glyph
deadline remain open. There is no VID port here, so no stopped-VID or CDC
qualification follows. This does not qualify real Z80 integration, native
fonts/write visibility, broader raster modes, FPGA fit/timing or hardware.
See [the external-font plan](TURBO_Z_EXTERNAL_FONT_PLAN.md).
The subsequent standalone [cache/publication component](TURBO_Z_CACHE_STATUS.md)
uses this level-read service without changing the qualified frontend/backend.
The subsequent standalone [fair service/lifecycle components](TURBO_Z_FONT_SERVICE_STATUS.md)
now add arbitration and cache/consumer drain before frontend reset/upload
permission. Actual machine reset/consumer dispatch remains open.
