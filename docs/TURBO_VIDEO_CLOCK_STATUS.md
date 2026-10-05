# Experimental Turbo X3 clock and 16-row ANK

October 5, 2026. Shared machine: `rtl/sharpx1.v`. This is a partial video
increment, not completed Turbo support or native commercial-game acceptance.
The default base and existing single-clock profiles remain unchanged.

## Clock contract

`TURBO_VIDEO_MASTER=1` uses nominal X3 = 42,954,540 Hz, as printed on
CZ-851/852 schematic page 3. CPU/sub-CPU/PSG/CTC stay on the existing 32 MHz
system domain. `rtl/x1_video_timing.sv` derives renderer and CRTC enables,
without a new fabric clock: high-scan dots occur every two X3 edges and
low-scan dots every three. Characters take 16/24 edges in 80-column mode,
32/48 in 40-column mode. Low mode therefore averages 28.636360 MHz renderer
half-dot steps; high mode steps on every X3 edge.

Sampled scan/width changes restart the enable divider phase, not the CRTC.
This is an explicit experimental policy, not a transcribed live-switch
hardware contract. Two-stage mode/width sampling does not establish bundled
multi-bit CDC safety. Exact oscillator/divider phase, switching behavior,
reset release and physical output still need schematic and hardware review.
The simulator enforces the nominal X3 rate for this profile. The FPGA's
requested PLL rate must not be confused with its fitted rate.

## Font and PCG contract

Turbo ioctl index 4 loads exactly 4096 bytes, character-major 256x16 ANK.
Address zero starts a new load; only contiguous addresses through 4095 publish
the font. Partial, out-of-order or oversized loads invalidate availability.
High-scan ANK stays blank until a complete load; warm machine reset retains
the font. Low-scan ANK and base CPU font reads retain the existing 8-row ROM.
The optional MiSTer OSD loader is not physically tested.

High-scan ordinary PCG repeats eight rows; paired PCG uses attribute-selected
even/odd glyph pairs and all sixteen rows. Address arithmetic is exhaustively
unit-tested, but native PCG pixel acceptance is still open. SCRN text expansion,
CPU 16-row font selection, underline, high-speed PCG, Kanji ROM/readback and
Kanji rendering remain unimplemented. KVRAM allocation is not glyph support.

`scripts/stage_turbo_font.py` stages an unchanged font from the user's existing
private archive. No font bytes or commercial assets are tracked. The selected
FNT0816.X1 hash is
`e356dd1992708d2bdf03d4029ba07a8177158e1cb0eac145f881ed8dcdae35d8`;
its model/hardware provenance remains to be qualified.

## Reproduction

From the repository root:

```sh
make -C verilator turbo-video turbo-video-fast test-video-timing test-font16
python3 scripts/stage_turbo_font.py
cd verilator
python3 tests/test_video_modes.py ./obj_dir_turbo_video/Vtop --kind text --turbo-raster 1 --ank16 --output obj_dir_turbo_video/ank16
python3 tests/test_video_modes.py ./obj_dir_turbo_video/Vtop --kind text --turbo-raster 3 --ank16 --ank16-warm-reset --output obj_dir_turbo_video/ank16-reset
```

The synthetic pixel test generates its own 4096-byte font and checks every
active pixel, not just a screenshot. Native probes can use `--font16 PATH`;
it requires an exact 4096-byte file and a Turbo model. Runner snapshot format
was v03 at the recorded X3 checkpoint; the later deleted-data index increment
uses v04. Regenerate live native-boot snapshots instead of restoring older
model states. Never patch states to bypass that check.

## Recorded evidence

| Check | Result / scope |
|---|---|
| Enable unit | Exact low/high dot and character intervals at both widths, live mode transitions and reset phase pass. |
| Loader unit | All 4096 addresses, blank-before-ready, partial/overflow rejection and asynchronous clocks pass. |
| Renderer unit | Existing exhaustive blackclip plus all ANK/ordinary/paired PCG address combinations pass. |
| Delay-aware synthetic ANK mode 01 | Both widths pass every pixel of all sixteen distinct rows; 200 ms runs, eight completed frames, 4521 reset edges. Frame hashes `8ec9d6393e3dde65` / `3eab7f8f2c08d9a5`. |
| Delay-aware ANK mode 11 warm reset | Both widths retain the font and pass every pixel after a 10 us reset at 120 ms; 200 ms runs, 4841 reset edges, six complete frames, same font frame hashes. |
| Fast graphics mode 11, page 1 | Both widths pass the existing pixel oracle at nominal X3; 1.8-second runs, 29 complete frames. |
| Delay-aware low live-width transitions | Both directions preserve expected pixels; HS approximately 62.56 us, VS 16.145 ms. |
| CPU CTC/keyboard | Focused IM2 and cold input polling pass in the new clock profile. Not pin-timing or hardware acceptance. |
| Native Arcus, supplied 16-row ANK | Two fresh eight-second boots repeat byte-for-byte with unchanged assets; 468 complete 640x400 frames; HS 40.218750 us, VS 18.022406250 ms. Screen remains garbled: **not playable**. |

Initial X3/font checkpoint executable hashes (`cd2695e`, before BRAM refactor):

- Delay-aware X3: `1df05fe01d03970641c6df89ee30f5606933159f6105dea2e55a73e02b3a84c5`.
- Fast X3: `ccaa8ce89b8712773271b9ce8e80aa892f6065bd5e7630380aaeabdea1ae5a49`.
- Base regression: `c346711bfce43a1347e6a798526eccd1220d82d7b966f9439fba33a64a95a120`.

The complete `make -C verilator test` suite passed against a frozen copy of
that base executable; log `/tmp/x1-x3-final-base-regression.log`. It includes
timing/reset/FST, CPU/memory, cold keyboard, base video, PSG, PCG, storage,
malformed scanner, abort/ACK drain and disk index checks. Savable-model
snapshots require their separate fast-model regression. This
does not turn those base checks into complete Turbo acceptance.

Arcus uses Disk 1 in A / Disk 2 in B as an explicitly exploratory setup;
release instructions have not established intended disk ordering. Font-loaded
probe: `verilator/obj_dir_turbo_video_fast/special-probes/arcus-x3-font16/`,
including actual `cold.png`, original asset hashes and both cold reports.
It issued 2752 disk requests and zero writes per run, with 8255 reset edges,
8191 ioctl bytes and six scripted PS/2 bytes. Frame hash
`57153e3223bf20ad` is repeatability evidence, not correct rendering/gameplay.
Missing Kanji/high-speed PCG are known gaps, not yet proven causes of this
particular screen. Arcus and Bastard gameplay and the historical five-title
requalification remain open.

The new FPGA revision `sharpx1_turbo_video` requests a separate X3 PLL and
retains the old 32 MHz system PLL. Its first
[source-bound Quartus build](TURBO_VIDEO_QUARTUS_BUILD.md) assembled, but
**fails timing at every analyzed corner**. The font became 32K flip-flops
rather than block RAM; total ALM utilization reached 94%. Other failures
include HPS video-counter CDC and system-to-video reset recovery. Positive
same-clock setup slack is not overall timing closure. The fitted video PLL
is 42,954,545.4545 Hz, not precisely the simulator's nominal rate.

The subsequent font refactor uses the existing dual-clock `x1_video_ram`
primitive with an unconditional synchronous read, gating availability after
the RAM. Loader unit and delay-aware mode-11 warm-reset pixel tests pass;
both widths retain the same hashes above (six complete frames, 4841 reset
edges). Tested executable SHA-256:
`9200ba1211b4fba8bc826f868d4ada8ac22db151388c13debc804dd43a46f63b`.
This is a RAM-inference correction candidate, **not proof of inference or
timing closure** until a new fit is audited. No timing exceptions were added.
Wrapper lint uses a stand-in PLL and is not synthesis evidence.
Physical MiSTer testing is unavailable while travelling. Older published
RBFs do not contain these clock/font changes.
