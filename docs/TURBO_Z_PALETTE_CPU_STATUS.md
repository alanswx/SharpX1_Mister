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
- Display reads are still disabled. CPU permission now comes from the
  [functional blank-window ownership handshake](TURBO_Z_PALETTE_OWNER_STATUS.md),
  not a constant grant. Before rendering is enabled, its display consumer must
  honor that handshake and carry correct response/blanking validity. DMA remains
  prohibited; native ASIC BUSRQ/WAIT timing is not established.
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

### Width correction and active-video follow-up

The original `fe734f1` fixture and guard used C6=0 while calling it 40 columns.
The actual shared renderer's `I_W40` and established base pixel fixtures use
C6=1 for 40 columns. The guard and fixture now use C6=1, with C6=0 as the
unsupported 80-column protection case. Earlier runner/fixture hashes above
are historical and must not be promoted to a correct-width qualification.
The corrected-width pre-ownership test passes in
`/tmp/x1-z-palette-width-corrected.log`; its ROM hash is
`674d9e6ca44357bbe48e932d1094959eab66f6d9cffb4bcc68125c6bb415d54b`.

Final connected ownership/tail qualification is in
`/tmp/x1-z-palette-owner-machine-qualified.log`: corrected-width ordinary
cold/warm and disabled-control checks pass. The new
`make -C verilator test-machine-z-palette-video` also programs the actual CRTC,
requires nonzero HS/VS and completed frames, and checks contiguous real CPU
palette I/O holds exceed 1 ms. Its unchanged original program passes cold and
warm with maximum hold 12,541,218,750 ps (12.54 ms). This is CPU/ownership
acceptance, not analog pixels or native ASIC electrical timing.
Final enabled / disabled runner hashes are
`da56cb3b0ce7d98a36ba8602811dc5ea1db979f2128b8f14aa2026748ac3778d` /
`f5a77bd8c8fc07947bf8954d8b749f7ac411c0f22a3253fb163be015d3bd1b4a`.
The original CRTC-enabled ROM hash is
`c1a3acf48979ff4f7d62a8fbe6e9067f8dcf12f602bf9e95fa7a89a6e3899e90`.

Before the retained-read-tail fix, that exact program reaches `EE` on runner
`e192188240b1007d5e8ee927ea4896a56ba958a75b26cd858a3d3095ec963ad0`;
the log is `/tmp/x1-z-palette-owner-video-original-failure.log`, and original
ROM/CPU CSV are retained under ignored
`verilator/obj_dir_v12_z_palette_cpu/before-tail-original/`.
Its last active red-component IN samples mapped data zero, but the CPU still
fails the comparison: this matches the known TV80 inactive I/O sampling seam
already handled by PCG. The adapter now retains only a completed RAM response;
the machine uses it on the palette's inactive I/O tail, clearing eligibility
on memory, ACK or other I/O. No early RAM validity or fake grant is introduced.
Adding extra diagnostic stores happened to pass on the old runner, but changes
instruction phase: that result is kept separately, not substituted for the
original failure. `--diagnostic` is not used by the acceptance targets.
`--output NEW_DIRECTORY` retains diagnostic assets and rejects existing paths.

The nine exhaustive adapter profiles also pass after adding inactive-response
retention/new-OUT clearing checks; see the ownership report. A fresh full
baseline regression is tracked in `/tmp/x1-z-palette-owner-baseline-final.log`;
its final status must be recorded separately from the earlier pass below.

The full `make -C verilator test` baseline regression now exits zero in
`/tmp/x1-z-palette-machine-baseline.log`. Its ordinary-profile runner SHA-256
is `420fac723265e953dfa367d2332814e63d86d28134439a38f307c792266d3329`,
unchanged at the final check, with shared machine RTL from `fe734f1`. This
establishes the unchanged baseline diagnostic gate, not optional Z display
or native/hardware acceptance. Bus fault
injection and upload/reset overlap still need explicit CPU fixtures.
Mode-exit/unsupported-mode write protection is now covered;
general control policy, upper read bits, selector lifetime,
text/internal palettes, five native graphics formats, synchronous rendering,
DMA/display ownership, snapshots and native software remain open. No combined
Quartus fit, timing/CDC acceptance, new RBF or physical Z test exists for this
CPU checkpoint. Z2/Z3 and the full goal remain incomplete.
