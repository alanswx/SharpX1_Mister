# Turbo Z palette storage foundation

October 8, 2026. This is a standalone, original storage primitive, **not a
connected Turbo Z palette device or a hardware-qualified feature**.

`rtl/x1_z_palette_ram.sv` provides three 4096 × 4-bit component memories.
The physical capacity follows IC68/69/70 and PA0–PA11 on sheet 46 of the
existing CZ-880 service manual. See the [contract audit](TURBO_Z_PALETTE_CONTRACT.md)
for primary scan provenance and unresolved ASIC behavior. No emulator code,
private fonts or native software bytes are copied into this implementation.

CPU component order is B=0, R=1, G=2; display packing is RGB12 R:G:B.
Both ports have one local-clock edge of read latency. CPU writes forward the
new selected nibble. Registered response metadata does not follow subsequent
live address/component changes. Component 3 rejects access without aliasing.
Independent resets flush/mask responses but do not clear RAM. Unwritten data
and cross-clock same-address read/write collisions are deliberately unspecified.
The future palette arbiter must prevent or qualify those collisions.

CPU access inputs represent already accepted local-clock operations, **not
raw Z80 strobes**. Native register decode, AEN/APEN/APRD, selector lifetime,
reduced-color banking, WAIT, DMA ownership and display arbitration remain
outside this module. The separate `rtl/x1_z_palette.qip` is not included in
`rtl/machine.qip`; ordinary machine profiles and fitted RBFs are unchanged.

## Executed verification

```sh
make -C verilator test-z-palette-ram
```

All nine delay-aware profiles pass with a 32 MHz CPU clock, video half-periods
17,500 / 11,640 / 25,000 ps and accepted-operation spacing 1 / 4 / 7 CPU
edges. Each profile programs all 4096 addresses and all three components with
all sixteen nibble values (196,608 writes), checks CPU and independent display
readback, then checks concurrent disjoint-address reads/writes and retained
warm/short resets with either clock stopped. RGB12 component isolation and
inactive/invalid writes are covered. Observable same-address cross-clock
collisions are excluded, not claimed deterministic. Log:
`/tmp/x1-z-palette-ram.log`. This does not qualify exact chip pin timing.

An isolated temporary mutation dropping CPU address bit 11 fails the unchanged
test at the first readback (address 0/component B). Production RTL was not
mutated. Logs: `/tmp/x1-z-palette-negative-build.log` and
`/tmp/x1-z-palette-negative-run.log`. The positive nine-profile target and
asset-free hardware-runner safety checks are added to hosted diagnostics;
hosted execution is a separate gate, not inferred from local success.

## Required next gates

- Quartus RAM inference/resource check; no storage fit has yet been executed.
- Resolve the ASIC differences recorded in the contract audit before decoding
  native registers or exposing a Z detection signature.
- Accepted-transaction adapter, held strobe deduplication, CPU/DMA/beam
  arbitration and an explicit collision/WAIT policy.
- Reduced-mode and CPU/display bank selection, independent renderer/pixel
  expectations and complete mode-exit/reset cases.
- Profile-bound snapshots, unchanged base/Turbo regressions, source-bound
  full FPGA fit and actual native/physical Turbo Z acceptance.

Do not mark Z2, Turbo Z or a TODO work group complete from this RAM test.
