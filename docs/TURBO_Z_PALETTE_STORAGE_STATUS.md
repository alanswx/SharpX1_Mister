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

The later screen-display chapter now specifies native power-on palette
initialization, separately from retained IPL reset; see the contract audit.
This primitive intentionally does not implement that sequencer or initial
image. Its unspecified unwritten entries are a storage-layer limitation,
not a proposed native Turbo Z cold-start policy.

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

## Executed standalone Quartus inference/fit

Quartus **17.0.0 Build 595**, the existing Apple amd64 runtime, completes
Analysis & Synthesis and Fitter on the original storage RTL from `99eb141`.
No board assembly, TimeQuest acceptance or MiSTer deployment is run. Synthetic
32 MHz CPU / approximately 42.955 MHz video clocks and 53 virtual pins are
not board constraints; the two automatically placed clock pins are not a
MiSTer pinout. Existing main-project and RBF defaults remain unchanged.

| Fitted standalone resource | Result |
|---|---:|
| ALMs | 39 |
| Logic registers | 4 |
| Logical palette memory bits | 49,152 |
| M10K blocks | 6 (two per component) |
| PLLs / DSPs | 0 / 0 |

The fitter RAM summary retains three 4096×4 true-dual-port, dual-clock
`altsyncram` instances, not duplicated CPU/video stores or RAM-sized flip-flop
arrays. Local-port read-during-write is New data; mixed-port is Don't care.
The three synthesis warnings `276027` explicitly retain undefined cross-clock
collisions. Do not suppress them or claim collision arbitration from this fit.
Other warnings concern processor settings, unavailable LogicLock and incomplete
clock-pin assignments (`169085` critical warning); no board signoff follows.

Evidence: ignored `output_files/z-palette-apple-DeLmblfn/`, log
`/tmp/x1-z-palette-apple-probe-retry.log`, exit zero. All four input files
hash-match after fitting; manifest SHA-256 is
`db2d67b39d756090ba469b9e2c630254df203e452493d48a6a34182997de9fdc`.
RTL SHA-256 is `754249117650a94d93391bb9fd6822b9f578a72fccc2fc2c11afb206919d528b`.
Templates/helper were then-untracked, separately hashed inputs; the RTL is
unchanged from `99eb141`. Container identity and helper hash are preserved.

The original `z-palette-apple-fYuRqrM6` probe exits 3 before RTL synthesis
because Quartus's QSF reader rejects a foreach loop. That failed snapshot/log
is preserved. The fresh successful probe uses explicit virtual-pin assignments.
Native Linux helper preflight passes while misterubuntu has an unrelated
active Sharp MZ fit. After rechecking that its Quartus processes have ended,
the isolated native **17.0.2 Build 602** probe also completes synthesis/fit,
exit zero, with the same six M10Ks, 39 ALMs, 49,152 bits and three retained
dual-clock RAM banks. All four input hashes remain unchanged and its manifest
hash equals the Apple probe's. The clock-pin/collision scope remains unchanged.
No competing job was killed or restarted, and no board binary was assembled.

Native evidence is retained on misterubuntu at
`/home/alans/mister/SharpX1_Mister/output_files/z-palette-driver-cQXbIS1q/output_files/z-palette-probe-wpMWbLIp/`.
Copied reports/manifests are local under ignored
`output_files/z-palette-native-wpMWbLIp/`; log
`/tmp/x1-z-palette-native-probe.log`. The isolated driver avoids production
checkout edits; the clean host checkout was fast-forwarded to the verified
`99eb141` checkpoint before staging.

```sh
# Coordinate/inspect running containers or Quartus jobs before --build.
bash scripts/probe_z_palette_quartus_apple.sh --check
bash scripts/probe_z_palette_quartus_apple.sh --build
# On the native Linux build host, once available:
bash scripts/probe_z_palette_quartus.sh --check
bash scripts/probe_z_palette_quartus.sh --build
```

Adding six blocks to the prior 394-block DMA fit would estimate 400/553;
that arithmetic is not a combined-device fit or timing acceptance. Kanji,
capture buffers, FM and the renderer still need their own actual integration
and resource accounting.

## Required next gates

- Integrate storage under an established ASIC/ownership contract and refit the
  combined machine; the standalone resource gate alone is now demonstrated.
- Resolve the ASIC differences recorded in the contract audit before decoding
  native registers or exposing a Z detection signature.
- Accepted-transaction adapter, held strobe deduplication, CPU/DMA/beam
  arbitration and an explicit collision/WAIT policy.
- Reduced-mode and CPU/display bank selection, independent renderer/pixel
  expectations and complete mode-exit/reset cases.
- Profile-bound snapshots, unchanged base/Turbo regressions, source-bound
  full FPGA fit and actual native/physical Turbo Z acceptance.

Do not mark Z2, Turbo Z or a TODO work group complete from this RAM test.
