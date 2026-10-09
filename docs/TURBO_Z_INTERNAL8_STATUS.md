# Opt-in 640x400 internal-palette experiment

`TURBO_Z_INTERNAL8=1` requires the separate multi-mode/X3/palette CPU profile.
`make -C verilator turbo-z-internal8` builds an isolated delay-aware,
non-savable runner in `obj_dir_v13_z_internal8/`. Ordinary runners and board
revisions remain disabled. No fitted Z RBF, native Z program or hardware
result is claimed by this increment.
`make -C verilator test-machine-z-internal8` prepares a unique frozen
runner/oracle/emitter directory for four cold/warm identity/custom cases;
the target is added but that complete target has not yet been executed.

## Connected behavior

Sequential source layout 4 now reaches the real CRTC pipeline: 80 columns,
high scan, 16-raster rows, one source from the bank selected by raster parity.
Printed 124 fig. 4-14 supplies contiguous 80-byte rows. No framebuffer scaling
or injected GRAM is used. The shifter carries an internal-palette tag with its
accepted fetch/load; live mode inputs cannot redirect a buffered character.

Internal storage is a distinct eight-entry, twelve-bit memory, not aliases
overwriting the external 4096-entry RAM. The original RAM primitive's new
`INTERNAL8` parameter leaves ordinary capacity and identity initialization
unchanged. Printed 156 identifies eight entries, printed 160 table 4-24 gives
cold full-intensity colors, and printed 161 identifies QHA0/QHB0/QHC0 as
internal graphics inputs. Physical PA0/4/8 correspond to logical CPU index
bits 3/7/11 after table 4-22's permutation. Other index bits are ignored.

CPU setup is explicitly `AEN=80h`, high scan, 80 columns, no double-raster,
and `APEN/APRD=80h/88h` normal write/selector/read sequences. Store ownership
is captured at transaction acquisition. Existing blank-window ownership and
one-edge RAM responses are reused; upper read bits remain provisional. CPU
reset flushes transactions/responses, not either palette's contents. This is
a functional experiment, not complete ASIC decode or exact WAIT timing. DMA
remains excluded. Text/priority/blackclip and native acceptance remain open.

## Executed verification

- Nine independent-clock/write-spacing unit profiles pass all 4096 address
  aliases, three components and sixteen nibble values: capacity, cold colors,
  CPU forwarding/readback, display, invalid component, reset-held writes,
  retained reset and external isolation. Log `/tmp/x1-z-internal8-unit-fixed.log`.
  The first compile's width warning remains in `/tmp/x1-z-internal8-unit.log`;
  the fixture was corrected, not the warning suppressed.
- Existing external RAM matrix still passes all nine profiles after
  parameterization, as do all-4096 connected palette-pin checks:
  `/tmp/x1-z-internal8-build.log`.
- All-address/five-layout shifter tests explicitly check the palette tag
  during held-request mode/page/parity/address mutation at three clocks:
  `/tmp/x1-z-internal8-shifter-store-tag.log`.
- Actual CPU-written identity/custom palettes each pass every **256,000**
  active 640x400 pixel and measured HS/VS after retained warm reset. Post-reset
  I/O proves CRTC/PPI reinitialization without palette, GRAM or text refill.
  CPU checks all eight entries/components through selector/IN before display.
  Logs `/tmp/x1-z-internal8-{identity,custom}-warm.log`.
  SYS 32 MHz, video 42.954540 MHz, line 1792 master edges, frame 448 lines.
  Frozen runner SHA-256:
  `9001ccfc5447d45e85bb1d0b779cef1092dfec19806e2f067f102cdd86256dbf`.
  Fixture SHA-256:
  `f75c6c7e3ae313a883e210d9c2f519f6a54e23fc43c15ad3a1318aad7ec27e77`.
- Stronger custom cold CPU fixture writes distinct external sentinels, programs
  and reads internal memory, switches back and verifies external preservation.
  All 256,000 pixels also pass: `/tmp/x1-z-internal8-custom-cold-isolation.log`,
  output `verilator/obj_dir_v13_z_internal8/custom-cold-isolation/`.
  Same runner; fixture SHA:
  `8d46fb897bdaccbe2f39e6f9c8c38e852400bb7df89d12e77dcc7bdd5b46b3fd`.

Stronger identity cold and custom warm cases also finish with exit zero:
all 256,000 pixels, CPU external-sentinel preservation and no-refill retained
reset where applicable. Their logs/outputs follow the naming below. The
stronger identity warm case is still running, not qualified.

The stronger cases use directories
`obj_dir_v13_z_internal8/{identity-cold,identity-warm,custom-warm}-isolation/`;
logs `/tmp/x1-z-internal8-{identity-cold,identity-warm,custom-warm}-isolation.log`.
They use the same frozen runner and stronger fixture; do not rebuild that
runner until the remaining identity-warm handle finishes.
Current default-source timing/GRAM/DAM CPU checks and three wrapper lint
profiles finish with exit zero; default runner SHA
`4f4cbf7d2b7c8b68412082f7eea2be86af87d24174ad5d2aa11006491a826e5c`,
build/lint log `/tmp/x1-z-internal8-default-wrapper.log`. That is focused
coverage, not another complete baseline suite or Intel PLL simulation.

Still required: both palettes/cold-warm combinations with the stronger sequence,
connected live switches/reset races, native register/decode/WAIT evidence,
combined fitting/CDC and native software/hardware before closing Z2/Z3.
Text two-bit significance is separate; it is not used by this four-bit store.
