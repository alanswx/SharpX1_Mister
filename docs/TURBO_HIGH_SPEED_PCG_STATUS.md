# Bounded Turbo high-speed PCG / CPU ANK16 increment

October 5, 2026. Original functional implementation of the proposed
[PCG contract](TURBO_PCG_CONTRACT.md), not ASIC truth-table or native WAIT
validation. No native software probes, hardware access, Quartus build, tool
installation, private font embedding or Kanji backend were performed here.
Parent owns snapshot v07 and shared Makefile registration; this increment
changes saved model state and must not consume older snapshots.

## Implemented policy and limits

Only `TURBO && SCRN[5]` enables the new CPU path. Base and compatible access
retain beam capture in the video domain, the original RAM stages and WAIT
behavior. Display font selection/rendering was not changed.

- Select candidate cells in order `7FF, 3FF, 5FF, 1FF`, independently for
  PCG (attribute b5 set) and character ROM (b5 clear). If none qualifies,
  use **7FF**, the explicitly provisional X Millennium fallback, not MAME's
  3FF. Twelve metadata bytes shadow the same accepted/aliased text, attribute
  and KVRAM writes as the real RAM; no third RAM ports or VRAM replicas.
- Ordinary per-plane PCG address is `{T,n[3:1]}`. If `K & 90h != 0`, use
  `{T[7:1],n[3:0]}`: even/odd glyph pairing, with all 16 nibble values distinct.
  This paired condition and symmetric high-speed reads/writes follow the
  approved provisional X Millennium policy, not proven hardware behavior.
- Plane zero dispatches K b7 to **unsupported Kanji**, returning FF; it never
  substitutes ANK or claims a font bank/half mapping. Otherwise SCRN b6 selects
  CPU ANK16 `{T,n}` versus ANK8 `{T,n[3:1]}`, independently of SCRN b0 scan rate.
  Plane-zero writes do not change fonts or any PCG plane.
- Require all four attribute shadows and the selected cell's text/KVRAM
  shadows to be valid. Until initialized by writes, reads return FF and PCG
  writes are suppressed. There is no invented power-up VRAM value. Validity
  and metadata survive warm reset, matching retained VRAM. This conservative
  validity policy is a functional limitation, not a real ASIC initialization
  requirement. Future DMA writes must update these same shadows.
- Capture selection/address/type/payload at the CPU acceptance edge and hold
  the bundled request until ACK. Subsequent mode/metadata/beam changes do not
  retarget it. A synchronized request waits for **asserted video HSYNC**;
  an already-active window qualifies. The opportunity is consumed once, and
  the RAM/response stages finish even if HSYNC has fallen. One-edge windows
  therefore work; a whole CDC roundtrip need not fit inside HSYNC.
- With no HSYNC, high-speed WAIT remains asserted until a window or reset.
  This is not a fabricated fixed-cycle timeout. Recurring windows give bounded
  completion in the tested profiles, not a native hardware timing guarantee.
  HBlank/display-end are not silently treated as equivalent to HSYNC.

## CPU response, font storage and reset

`x1_font16` reuses its existing CPU RAM port, multiplexing upload versus a
frozen CPU read address. Only upload can assert WE; both RAM reads remain
unconditional registered reads, with readiness gated after RAM. No 4096-byte
font replica or new memory port was added. Actual Quartus BRAM inference and
resource/timing closure still require a separate fit.

Missing, partial, out-of-order and invalid loads remain blank ANK16. Upload
has CPU-port priority and the established loader holds the machine reset.
Concurrent live CPU reads during upload are not a supported ownership model;
the port's visible CPU output is blank while loading. Font storage/readiness
survive warm reset. CPU font data remains entirely in the system domain:
the video transaction supplies the window/ACK; its return handshake allows
the registered system-domain font value to be latched as the CPU response.

The original CPU integration fixture exposed a long-WAIT seam: TV80's
inherited I/O auto-wait phase can repeat T2 after RD/IORQ have gone inactive,
sampling the bus again. An isolated monitor showed correct PCG RAM data and
the first CPU sampling edge, followed by an FF fixture result without the
hold. The fix retains a completed **high-speed read only** on the inactive
bus CG-address tail. It cannot override memory, interrupt ACK or active I/O;
new request acceptance/reset clears the qualifier. TV80 and base-mode data
selection were not modified. The CPU fixture passes with this response hold.

Reset cancels pending window/handshake stages and clears response ownership;
completed PCG writes are not rolled back. Selector metadata and loaded font
persist. This is functional asynchronous-reset testing, not reset-release
metastability or placed CDC verification.

## Verification and isolated outputs

Installed Verilator 5.044; all build outputs are under
`/tmp/x1-pcg-increment-Iwfl7y`. No shared `obj_dir_fast`, `obj_dir_headless`
or savable executable was rebuilt. Tests use original CPU programs and an
original generated 4096-byte font pattern, not native IPL/game injection.

Final confirmed results (all processes terminal, successful exit) are:

| Test | Evidence |
|---|---|
| `pcg_selector_tb` | 49,216 counted checks: all 16 attribute patterns/independent selectors, 7FF fallback, every glyph/nibble, three planes and K=00/10/80/90; ANK8/16 and unsupported dispatch assertions |
| `font16_tb` | Original display assertions unchanged; all 4096 CPU reads added; missing/partial/order/overflow readiness checks |
| `pcg_access_tb` | Original base assertions unchanged; CPU/video half periods 5 versus 3/7/31 time units pass |
| `turbo_pcg_access_tb` | 16,395 transactions per run; six combinations of video half-period 3/7/31 and window width 1/3 edges pass. Exhaustive PCG/font bytes, frozen inputs, ROM protection, unsupported writes, held strobes/read tails, stopped/resumed destination clock and reset at window/RAM/ACK stages |
| CPU `test_turbo_pcg.py` | All twelve loaded/unloaded × cold/warm × model cases pass: synthesis-style Turbo, delay-aware Turbo (32 MHz sys / 28,571,428 Hz video), and delay-aware X3 (32 MHz sys / 42,954,540 Hz video). All selector patterns, independent ROM selection, paired aliases, both scan bits, ROM protection and unsupported Kanji |
| Original base CPU/pixel checks | Final isolated delay-aware build passes PCG at 28,571,428 and 4,000,000 Hz video; PCG 40-column RGB fixture retains frame hash `df7438caf137ff25`, 320×200, 15 frames, HS period 62,718,750 ps and VS period 16,181,750,000 ps |

`git diff --check` passes. Focused builds report missing-timescale warnings
in modules without delay statements; no new width/latch/pin warnings remain
in the selector/font/high-speed fixture build. Full machine builds still
report inherited CPU/MR16/video/FDC warnings: successful tests do not certify
those unrelated warnings. The concurrent parent's FDC work is
outside this increment; these asset-free PCG checks do not qualify it or
establish current native game compatibility.

Terminal logs: `selector-result.log`, `font-result.log`, `base-{3,7,31}.log`,
`async-{3,7,31}-w{1,3}.log`, `cpu-fast.log`, `cpu-turbo.log`, `cpu-x3.log`,
`cpu-base.log`, `base-pixels.log` beneath the isolated output directory above.
No PCG test/build job remains live at handoff.

Parent independently reproduced selector/font/base and all six asynchronous
high-speed runs via `make test-turbo-pcg-access` in
`/tmp/x1-v06-other-units.log`. Rebuilt combined-controller Turbo and X3
delay-aware runners pass all eight loaded/unloaded × cold/warm CPU cases in
`/tmp/x1-v06-{turbo,x3}-pcg-cpu.log`. Their unchanged nominal rates are
32 MHz system / 28,571,428 or 42,954,540 Hz video. This does not qualify the
pending full D88 matrix or native Turbo software.

### Stable implementation fingerprints

These bind the scoped sources, not a frozen archive of unrelated concurrent
parent changes. All final machine runners were compiled after the scoped RTL
stable point; no savable model was built.

| Source | SHA-256 |
|---|---|
| `rtl/x1_pcg_access.v` | `29e57f92edb0fe54c16db8ce3be617d7097c6c5603f96fb317ad6e6d2bdd30ca` |
| `rtl/x1_pcg_selector.sv` | `313fe6040be462074d0ec0b1babc17392677ecd5fe856e84db2a83b819f48d4a` |
| `rtl/x1_font16.sv` | `44c2466751b7f5e8f4e1a4f053cb4c2dd684e6cdc62dbed44e43d3b52edfe7b7` |
| `rtl/sharpx1.v` | `ff044394beb2f190c7fb6d1aa96d1dc66e160f7d6b60b43b97a7c2f0951f36e5` |
| `rtl/machine.qip` | `5d39c5598c6f6f0dbcaefda46821bc0f011a1668b590bf2f9df45f3152832a98` |

Runner hashes (each path ends in `/Vtop` below the isolated output root):

| Subdirectory | SHA-256 |
|---|---|
| `base-machine` | `c35dd121e90acb084b8b30102c5f7895b95a38b44b72507137ff11b31270cad2` |
| `turbo` | `f6b961e1b1c35e817e18e68798ecbaa7d626dd27b0d77966db779c1eb4f78017` |
| `x3` | `ca220d6a0d7432eb64f1a96126dc2d61d82c14f902ba9948c09c96c5199f1cca` |
| `turbo-fast-isolated` | `4a30c8a2968db1052ebadc190976065cd174c6fa397972889a35f141846ad974` |

### Commands for parent registration

From the repository root, create a fresh isolated directory (do not target
parent-owned live build directories):

```sh
pcg_test_root=$(mktemp -d /tmp/x1-pcg-check-XXXXXX)
verilator --binary --timing --assert -j 2 -Wno-fatal \
  --top-module pcg_selector_tb --Mdir "$pcg_test_root/selector" \
  rtl/x1_pcg_selector.sv verilator/tests/pcg_selector_tb.sv
"$pcg_test_root/selector/Vpcg_selector_tb"
verilator --binary --timing --assert -j 2 -Wno-fatal \
  --top-module turbo_pcg_access_tb --Mdir "$pcg_test_root/async" \
  rtl/x1_pcg_access.v rtl/x1_video_ram.v rtl/x1_font16.sv \
  verilator/tests/turbo_pcg_access_tb.sv
for half in 3 7 31; do
  for width in 1 3; do
    "$pcg_test_root/async/Vturbo_pcg_access_tb" \
      +VIDEO_HALF=$half +WINDOW_WIDTH=$width || exit 1
  done
done
```

Keep the existing base bridge and font test commands/expectations, supplying
an isolated Mdir. From `verilator`, build an isolated non-savable runner using
the current machine manifest; adding `-GTURBO_VIDEO_MASTER=1` and
`-DX1_TURBO_VIDEO_MASTER` selects the separate X3 profile:

```sh
cd verilator
verilator -cc --timing --assert --trace-fst --exe --build -j 4 \
  --Mdir "$pcg_test_root/turbo" --top-module top -GTURBO=1 \
  -CFLAGS '-std=c++20 -DX1_TURBO_FOUNDATION' -MAKEFLAGS 'OPT_FAST=-O3' \
  sim.v $(awk '/^set_global_assignment -name (SYSTEMVERILOG_FILE|VERILOG_FILE) / { print "../" $4 }' ../rtl/machine.qip) \
  sim_headless.cpp -Wno-fatal -o Vtop
python3 tests/test_turbo_pcg.py "$pcg_test_root/turbo/Vtop"
```

Each CPU case lasts 50 ms in 32 MHz reference units; warm reset occurs at
25 ms for 10 us, without reloading text/attributes/KVRAM/font. Failure JSON
retains actual byte, port and expected byte in the diagnostic peek.

## Remaining gates and separate CDC proposal

Fallback, ASIC paired condition and HSYNC service phase remain provisional.
Kanji bank/half layout/assets/backend, DMA shadow integration, native Turbo
software, hardware WAIT, physical CDC placement/reset and FPGA resource/timing
acceptance remain open. No complete Turbo or 400-line compatibility claim.

Separately, parent reports an X3 timing failure through direct video VSYNC
to PPI B2 / CPU data, with VDISP also direct. A reviewed follow-up can add
X3-only two-flop single-bit synchronization of VSYNC and VDISP into `clk_sys`,
resetting the synchronizers deterministically and leaving the base connection
exactly unchanged. Tests should prove two-stage latency at asynchronous
phases, level persistence, reset and real CPU PPI polling; then STA/CDC must
confirm the constrained paths and identify any remaining direct crossings.
Neither this proposal nor a timing-closure claim is implemented here.
