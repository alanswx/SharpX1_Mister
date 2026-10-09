# Turbo Z text-palette CPU increment

`TURBO_Z_TEXT_CPU=1` is a separate, default-disabled experiment requiring
`TURBO_Z_PALETTE_CPU=1`. It implements CPU storage/access, not analog text
rendering, priority or a native Z model. No board revision enables it.

The original GPLv2-only `rtl/x1_z_text_palette.sv` stores eight six-bit words.
Cold initialization duplicates each digital color bit into its two-bit field;
entry zero stays black and is inaccessible to CPU writes. Ports `1FB9..1FBF`
access the seven other entries. Warm reset flushes transaction/read-response
flags, disarms a stale held OUT until idle, and retains palette contents.
Memory writes are synchronous and have no reset-time assignments.

The shared Z80 path gates accesses to explicit experimental modes `80h/90h`
and excludes DAM transactions. Completed IN responses survive the CPU's late
sampling tail but not subsequent memory/I/O/interrupt-acknowledge transactions.
Inactive/entry-zero reads return `FF`; selected reads return zero upper bits.
These response and AEN policies are provisional, not measured ASIC behavior.

A 48-bit held snapshot transfers the raw palette to the video domain, with a
separate destination-reset mask. Unit tests inspect all indices; the machine
currently leaves this output disconnected from the glyph renderer. No RGB
intensity ordering is inferred. The [primary-source pin audit](TURBO_Z_PALETTE_CONTRACT.md)
does not resolve text-bit-to-DAC significance. Physical CDC payload bounds,
placement and exact native access/WAIT behavior still need qualification.

## Executed checks, October 9, 2026

```sh
make -C verilator test-z-text-palette test-machine-z-text-cpu
```

The final matrix exits zero: nine unit profiles plus five actual-CPU controls.
Log: `/tmp/x1-z-text-final-memory-matrix.log`. Frozen executable, Python oracle
and Z80 emitter: `verilator/obj_dir_v13_z_text_cpu/cpu-matrix-VNvLuq/` (ignored).
Runner SHA-256:
`3de0214e005bc05aea94b7ca122f44bcb4be676ab7be1b495e89399bb88287ec`.

- Units: video half-periods 17,500 / 11,640 / 25,000 ps, each with held OUT
  lengths 1 / 4 / 7 CPU edges. Every writable entry exercises all 64 values,
  poisoned held address/data, raw snapshot, fixed zero, inactive gates, late
  reads and held/pulsed reset retention.
- Actual shared Z80: modes `80h` and `90h`, each cold and warm reset; all seven
  entries and all 64 values, upper-write-bit masking, inaccessible zero,
  inactive AEN and DAM isolation. Warm reset at 100 ms lasts 10 us; the trace
  requires mode reinitialization but no text-palette refill. Each run lasts
  125 ms, with 32 MHz system / actual 28,571,428 Hz video and delays enabled.
- The unchanged CPU probe fails as expected with the capability disabled.
  No private IPL, font or game bytes are used. No frame/game claim is made.

Mode-80 fixture SHA-256:
`35d2e19da594b74111095402242c371955cd70e2ffcb933436a17ff9aaee9549`;
mode-90:
`ef3686163517e86d97cd27bfc7b7574270469523c4a59ac8f586d59bb4537172`.

Current default timing/GRAM/DAM CPU checks pass on runner
`55629eaeb20d3436a83bb3008a6702d6dc371a6e47c1cdf4071fbf754204b993`.
The isolated default fast snapshot tests pass on runner
`c61868850a76cf9d059407aa63dce142a17f4423f12ed5f19023049d2e50fa9e`.
Ordinary/X3/DMA wrapper lint passes with a PLL stand-in. These are focused
default checks, not a second full baseline or Quartus/hardware signoff.

## Remaining acceptance

Resolve text intensity wire order from primary pin evidence or hardware;
connect actual glyph color selection and RGB expansion; implement `1FC0`
priority/transparency, blackclip and overlap rules; exercise native Z firmware,
live controls/reset races and physical access timing. Combine with graphics,
Kanji/PCG and both-screen composition before claiming Z2/Z4 completion.
The profile is non-savable; ordinary v13 snapshot models remain unchanged.

The subsequent [paired analog-text experiment](TURBO_Z_TEXT_COMPOSITION_STATUS.md)
connects this palette when video/multi-mode are also enabled. Its intensity and
opacity policies remain provisional; native/hardware gates are not closed.
The raw-glyph interface advances current snapshots to v14. Above CPU-storage
and snapshot evidence remains historical/source-bound, not text-renderer acceptance.
