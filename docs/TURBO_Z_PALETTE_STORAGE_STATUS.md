# Turbo Z palette storage foundation

October 8, 2026 storage checkpoint, with subsequent CPU-integration update.
This original storage primitive now has an opt-in
[shared-Z80 consumer](TURBO_Z_PALETTE_CPU_STATUS.md), but is **not a complete
Turbo Z palette device or a hardware-qualified feature**.

`rtl/x1_z_palette_ram.sv` provides three 4096 × 4-bit component memories.
The physical capacity follows IC68/69/70 and PA0–PA11 on sheet 46 of the
existing CZ-880 service manual. See the [contract audit](TURBO_Z_PALETTE_CONTRACT.md)
for primary scan provenance and unresolved ASIC behavior. No emulator code,
private fonts or native software bytes are copied into this implementation.

CPU component order is B=0, R=1, G=2; display packing is RGB12 R:G:B.
Both ports have one local-clock edge of read latency. CPU writes forward the
new selected nibble. Registered response metadata does not follow subsequent
live address/component changes. Component 3 rejects access without aliasing.
Independent resets flush/mask responses but do not clear RAM. Configuration
now initializes logical index G:R:B to the corresponding component nibbles,
using constant RAM initialization rather than a reset clearing loop. This is
the external palette's documented power-on identity image, not ASIC-register
defaults or a claim about power-on initialization time. Cross-clock same-address
read/write collisions are deliberately unspecified.
The future palette arbiter must prevent or qualify those collisions.

The later screen-display chapter now specifies native power-on palette
initialization, separately from retained IPL reset; see the contract audit.
This primitive now implements the external RAM image at FPGA configuration;
ordinary CPU/video resets never rerun it. It does not implement the internal
eight-entry palette, text palette or cold-versus-warm machine reset dispatch.

CPU access inputs represent already accepted local-clock operations, **not
raw Z80 strobes**. Native register decode, AEN/APEN/APRD, selector lifetime,
reduced-color banking, WAIT, DMA ownership and display arbitration remain
outside this module. Storage and adapter are now listed in `rtl/machine.qip`
for the default-disabled CPU experiment. The separate `rtl/x1_z_palette.qip`
remains available for isolated synthesis probes; ordinary profiles and fitted
RBFs are unchanged. The probe results below do not qualify combined integration.

## Executed verification

The cold-image extension checks every address/component through CPU reads and
every RGB12 entry through the independent video port **before any CPU write**.
An independent division/modulo oracle checks the image and a second full read
checks retention after a pre-write warm reset. All nine original clock/enable
profiles then execute the unchanged exhaustive write, independent readback,
concurrent-other-address and programmed-data reset checks, exit zero.
Log: `/tmp/x1-z-palette-cold.log`. The generated model is Verilator 5.044.

An isolated mutation using the red-index nibble for the initial green bank
fails the unchanged cold test at logical index `010h`, component G, before
normal writes begin. Production RTL remains unchanged by the control. Logs:
`/tmp/x1-z-palette-cold-negative-build.log` and
`/tmp/x1-z-palette-cold-negative-run.log`. This specifically detects missing
or incorrect cold initialization rather than relying on later writes to hide it.

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

The counts and manifests below bind the **earlier uninitialized** storage RTL.
They must not be attributed to the new configuration image without a fresh
source-hashed inference/fit and initialization-image audit.

### October 9 cold-image refit

The fresh Apple Quartus **17.0.0 Build 595** probe completes synthesis and
fitting, exit zero, retaining **three dual-clock 4096×4 banks, six M10Ks,
39 ALMs, four registers and 49,152 logical memory bits**. All four staged
inputs hash-match after fitting. The inherited collision/virtual-pin/clock-pin
warnings remain; no suppressions, board assembly or timing acceptance were added.

Quartus binds each bank to its generated `db/*.hdl.mif`. An independent
division/modulo audit reads every explicit address/value in all three MIFs,
rejects missing/duplicate entries and verifies all **12,288 initialization
nibbles** against the logical identity image. This checks actual inferred RAM
initialization files, not just behavioral Verilator initial statements.
It does not verify an assembled board bitstream or physical configuration.

Evidence: ignored `output_files/z-palette-apple-JzvX2pUK/`, log
`/tmp/x1-z-palette-cold-quartus.log`, image audit
`/tmp/x1-z-palette-cold-mif-audit.log`. Snapshot parent is `7c66efb` with the
separately hashed then-uncommitted cold-image RTL; RTL SHA-256 is
`23f43871a644b7770d6b180f7c03842802190fb96e97d3a4b12da8adc466e557`,
input-manifest SHA-256
`2e7edaf3eed012ac221576ab421eb98485bdad7888fe2b31cdd4a5cb90c02f8a`.
Generated blue/red/green MIF SHA-256 respectively:

- `385af4b595863d11cc8c0e30286514de815eedde0a105be18695f3d3181883d1`
- `81f667ba8d87524eaf36dfeb21e34a28db433600e3826602fa3555c2b088e8d4`
- `91d8f557d6a2102250736dad2a4811256372e6eeba8e35004e58d8c215c15935`

The earlier native Linux 17.0.2 probe below does **not** bind this extension.
Native refit, combined-machine integration, internal/text palettes, accepted
register/ownership behavior, native cold boot and hardware acceptance remain open.

### Earlier uninitialized-storage probes

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
