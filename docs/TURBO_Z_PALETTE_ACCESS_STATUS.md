# External palette transaction adapter

October 9, 2026. Original `rtl/x1_z_palette_access.sv` connects to the real
`x1_z_palette_ram.sv` in an asset-free diagnostic. It is **not connected to
the shared machine** and does not establish Turbo Z support.

The normal explicit selector/write/read sequence follows the primary
[programming audit](TURBO_Z_PALETTE_CONTRACT.md). No emulator implementation,
published assembly listing, ROM, font or commercial bytes were copied.

## Implemented transaction behavior

- Component ports `10xx/11xx/12xx` select B/R/G. Logical index combines the
  low port byte and selected high data nibble; normal writes use the low data
  nibble as component value. Dummy OUT in read mode changes the selector
  without writing RAM. Subsequent IN uses the selector and returns a nibble.
- The first selected bus operation captures address, component, value and
  direction. A denied permission holds WAIT and those fields. Exactly one
  accepted RAM operation occurs when permission is granted; stretched strobes
  do not repeat it. A pending read requires actual backend validity, then
  retains its response until the bus becomes inactive.
- Live address/mode changes cannot redirect an acquired request or release
  its WAIT. Reset flushes the adapter, not palette RAM. After reset, an old
  held strobe cannot replay: the adapter must observe an inactive bus first.
- Disabled, out-of-range and simultaneous read/write inputs do not issue
  new RAM operations. Input strobes must already exclude IACK, DAM and
  unrelated bus owners; this module does not decode raw IORQ alone.

Upstream supplies `external_enabled`, `read_mode` and actual ownership
`permit`. These are **not invented native AEN/APEN/bank or blanking policies**.
No real CPU/DMA/beam arbiter supplies them yet. The selector's reset value,
ignored-access side effects and lifetime across ASIC control changes remain
native qualification gates. CPU input high bits are deliberately not supplied:
the primary read examples do not independently qualify their value. The
interface's four-bit response must not be advertised as complete eight-bit
native palette readback.

## Diagnostic and acceptance scope

```sh
make -C verilator test-z-palette-access
```

The fixture connects the adapter to actual dual-clock palette storage, with
32 MHz bus clock and video half-periods 17,500 / 11,640 / 25,000 ps. It holds
bus strobes for durations scaled by 1/4/7; these are **not real CPU clock-enable
or instruction-execution tests**. No CPU instance or native firmware runs.

Each profile reads all cold entries through selector transactions before
writing RAM, exhausts all 4096 indices × three components × sixteen values,
counts exactly 196,608 normal writes and verifies every resulting entry using
the independent video port after each value pass. Original arithmetic color
expectations distinguish addresses and components. It also checks frozen
permission-held metadata, delayed delivery of a real RAM response, live mode/
address changes during the wait, short-reset no-replay, retained modified
colors and disabled/unmapped/illegal strobes. Display reads during same-address
cross-clock writes are not observable in the fixture: collisions are still
unqualified, not solved by this adapter.

The earlier initial compile rejects fixture integer-width warnings. Those
were corrected without warning suppressions. The subsequent matrix is a
fresh build; earlier logs remain historical. Final execution evidence and the
isolated backend-validity negative control must be recorded separately.

All nine final profiles exit zero under Verilator 5.044; log
`/tmp/x1-z-palette-access-qualified.log`. Runner SHA-256 before/after the
matrix is `7faadce046cf504d2aa9bfae5096dbdc17027ff24f232fdc0da26d21caa1dc54`.
Adapter/fixture SHA-256 respectively:
`896be090f8ea671c3b18322a78f7770e768df003252960cfa65790da8b152694` /
`8211b13d6333b2da9d67fd76ff3e8899c6a6940b3b9d761339a15e97227d0894`.
An isolated one-line mutation bypassing backend validity fails the unchanged
final fixture at its delayed-response assertion, exit one. Production RTL is
not mutated. Logs: `/tmp/x1-z-palette-access-negative-qualified-build.log` and
`/tmp/x1-z-palette-access-negative-qualified-run.log`. Probe-helper/safety
checks and `git diff --check` also pass. The new asset-free target is added to
hosted CI; its source-bound hosted result is not inferred from local execution.

## Integration still required

Native model/control decode, internal/text palettes, full/reduced CPU/display
index/bank policy and eight-bit input-bus behavior; genuine CPU and DMA WAIT/
ownership; video-domain arbitration and synchronous fetch/render integration;
mode-exit/reset/drain and profile-bound snapshot tests; unchanged base/Turbo
acceptance, combined source-bound Quartus fit/CDC and physical Z software/output.

`rtl/x1_z_palette.qip` now lists storage and adapter, but is still outside
`rtl/machine.qip`. No ordinary machine state, runner profile, snapshot version,
board revision or RBF has changed. Z2/Z3 and work groups 1–6 remain open.
