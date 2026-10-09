# Turbo Z external palette: CPU-only experiment

The shared `rtl/sharpx1.v` Z80 now accesses external palette RAM when
`TURBO_Z_PALETTE_CPU=1`. This is an original, asset-free implementation of the
explicit sequence in the [primary programming audit](TURBO_Z_PALETTE_CONTRACT.md),
not full Turbo Z support or native firmware acceptance.

## Implemented scope

- Requires `TURBO=1`; DMA combinations are rejected. Ordinary profiles default
  to zero. MiSTer wrapper and board revisions remain disabled.
- Edge-qualified CPU OUTs latch `1FB0` and `1FC5`. The experiment accepts only
  `1FB0=80h`, `1FC5=80h/88h`, low scan and 40 columns. IACK/DAM are excluded.
  No control readback, Z identification or reduced/internal/text palettes.
- The actual CPU WAIT input includes the adapter WAIT. Normal component
  writes, dummy selector OUTs and subsequent INs access real palette RAM.
  Analog-selected writes do not also update the legacy digital palette.
- CPU reads return the verified low nibble; the upper nibble is provisionally
  zero, **not qualified native pin behavior**. Tests explicitly mask it.
- Warm reset clears experimental controls/selector, not palette contents.
  Zeroed ASIC controls/selector are provisional, not proven native defaults.
- Display reads are disabled. Permission is constant only because there is
  no competing display consumer and DMA is prohibited. Before rendering is
  enabled, implement real arbitration and prevent/qualify dual-clock collisions.
- This timing-aware runner is non-savable. Combining its compile macro with
  `X1_SAVABLE` is rejected; no old state is converted or accepted as a Z state.

## Executed CPU acceptance

```sh
make -C verilator test-machine-z-palette-cpu
make -C verilator test-machine-z-palette-disabled
```

Verilator 5.044, 32 MHz system / 28,571,428 Hz video, inherited delays enabled.
The original generated Z80 program initializes genuine PPI/DAM/scan controls,
checks cold identity, writes and rereads all three components at 19 boundary
indices (including 0, 255/256, 2047/2048 and 4095). Dummy selector low nibbles
must not overwrite colors. Mode exit, unsupported palette control, high scan
and 80-column settings each attempt three wrong-component writes; all
programmed colors must remain unchanged after re-entry. These protection
checks qualify this experiment's gates, not native inactive-mode semantics.
Each invocation runs 6,400,000 reference cycles
(200 ms); the warm test asserts reset at 100 ms for 10 us without asset reload.
Retained RAM flag selects the warm path and all programmed colors are checked
again. Both invocations reach the expected halted `ZPAL`/`ZWAR` markers.

The unchanged program on an ordinary Turbo build reaches the genuine `EE`
failure marker. Both target invocations exit zero in
`/tmp/x1-z-palette-machine-final.log`; the added mode protection/profile checks
are separately tracked in `/tmp/x1-z-palette-machine-mode-qualified.log`.
Frozen enabled runner SHA-256:
`b62461dc035dbc1feddffda52064569f0d75a7e2a9f2c19483c2f3aec7e21eb5`;
disabled runner:
`b47d71bd93d81248144e7e58cd456ea00775c994f71b9719b075866822e318a3`.
Executable hashes are checked before/after each qualification.
The final generated diagnostic SHA-256 is
`cee5a375d3ac08882537c8eaef42046bd00f56c96387989fe58ae314c756c250`.
Its extended cold, warm and disabled runs all exit zero. Both targets are
added to asset-free hosted CI with separate 900-second limits; no hosted pass
is inferred from these local runs.

The CPU test covers boundary entries, not every address/value. Exhaustive
RAM/adapter matrices remain separately documented; they cannot establish
native CPU/beam timing. No native ROM, commercial game, font or emulator code
is copied into this diagnostic.

An earlier moved generated build failed because its precompiled-header paths
still named its original directory. That output is retained under
`/tmp/x1-z-palette-prior-w6t5aSvb/relocated-build`; a fresh build passed. This
build-path failure is not a palette functional result.

## Remaining acceptance

Baseline regression is tracked in `/tmp/x1-z-palette-machine-baseline.log`;
do not infer overall completion from individual passing cases. Bus fault
injection and upload/reset overlap still need explicit CPU fixtures.
Mode-exit/unsupported-mode write protection is now covered;
general control policy, upper read bits, selector lifetime,
text/internal palettes, five native graphics formats, synchronous rendering,
DMA/display ownership, snapshots and native software remain open. No combined
Quartus fit, timing/CDC acceptance, new RBF or physical Z test exists for this
CPU checkpoint. Z2/Z3 and the full goal remain incomplete.
