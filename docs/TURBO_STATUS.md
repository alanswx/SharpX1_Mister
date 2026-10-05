# Experimental X1 Turbo foundation

October 5, 2026. Active path is `rtl/sharpx1.v` beneath both wrappers.
`TURBO=0` remains the default base-X1 machine. `TURBO=1` is a partial feature
profile, **not a complete Turbo/Turbo II/Turbo Z model**. Legacy source macros
are reference-only, not verification evidence.

## Implemented increments

| Feature | Behavior and coverage |
|---|---|
| Graphics pages | 96 KiB total: two 16 KiB pages per B/R/G plane. SCRN bit 4 selects CPU reads/writes; bit 3 independently selects display in low/repeated modes. Mode 01 instead uses fixed even/odd display pages. CPU tests cover both pages/planes, boundaries, display/access combinations, DAM isolation and warm-reset selector clearing with storage retained. Actual 320/640 RGB fixtures show independently selected access/display pages. |
| SCRN | Non-DAM writes to `1FD0..1FDF` latch mode bits. Bits 0/1 select graphics raster addressing; bits 3/4 select display/CPU pages (mode 01 uses fixed even/odd display pages). The separate X3 profile uses bit 0 for nominal high/low-scan enables. Text expansion/underline, CPU font selection and high-speed PCG remain missing. Reset is zero. Reads remain unmapped (`FF`); see reference disagreements below and [raster contract](TURBO_RASTER_STATUS.md). |
| X3 clock / ANK | Optional `TURBO_VIDEO_MASTER=1`: nominal 42.954540 MHz video, unchanged 32 MHz system, enabled CRTC; exact dot/character cadence unit and focused pixel tests pass. Index-4 4096-byte font loader publishes only complete ANK, retained over machine reset. Ordinary/paired PCG address unit passes. Hardware phase/PLL/CDC, complete text/Kanji/high-speed PCG and native gameplay remain open. See [clock/font evidence](TURBO_VIDEO_CLOCK_STATUS.md). |
| Kanji attribute VRAM | Separate 2 KiB at `3800..3FFF`, independently readable/writable from text at `3000..37FF`. Base retains its text mirror. CPU tests cover boundaries/reset retention. **Kanji glyph rendering/ROM access is not implemented**. |
| Blackclip | Write-only `1FE0`: graphics raw indices 0/1, selected text color and blanking clip. Registered mixer fixture exhausts all 128 masks and nonzero text/all graphics colors before palette mapping. CPU-written RGB fixtures verify graphics/text clipping at both widths. |
| IPL aperture | 32 KiB in Turbo versus 4 KiB in base. Bounds, no 4 KiB mirroring, writes under ROM and overlay off/on verified with an original synthetic IPL/RAM diagnostic; oversize CLI loads rejected. Authentic local Turbo archives inventoried, **not installed/booted**. |
| CTC/IRQ | Enable-driven four-channel timers/counters, channel-0/3 cascade, vectors/service and RETI integrated. Schematic-based CTC-before-keyboard priority; both CPU clock profiles pass repeated IM2 and concurrent cold input. Stable stretched ACKs verified with connected CTC and real MR16 firmware. Exact phase/pin timing, ASIC aliases and hardware remain open. See [CTC evidence](CTC_STATUS.md). |
| Two mounted disks | Shared one-controller A/B path, independent physical heads/motor hold, protected copies and ACK-stable ownership pass generated CPU/transport tests. Selection rescans temporarily deassert ready; exact mechanics/HPS replacement and native disk-set compatibility remain open. Included in the latest experimental RBF, not hardware-tested. See [disk evidence](DUAL_DISK_STATUS.md). |

Provenance: mode/bank and loader changes are local original integration code
based on the documented map and inspected references; blackclip modifies the
inherited Satoh renderer. Existing notices/restrictions remain. No emulator,
BIOS or commercial media bytes were copied into tracked RTL/tests. Media,
snapshots and downloaded emulators remain ignored.

## Commands and configurations

From repository root, then `verilator/`:

```sh
make -C verilator test-d88-scanner test-turbo turbo-single
cd verilator
python3 tests/test_turbo_banks.py ./obj_dir_turbo_single/Vtop
python3 tests/test_turbo_ipl.py ./obj_dir_turbo_single/Vtop
python3 tests/test_video_modes.py ./obj_dir_turbo/Vtop --kind graphics --turbo-bank 1
python3 tests/test_video_modes.py ./obj_dir_turbo_single/Vtop --kind graphics --turbo-bank 1
python3 tests/test_video_modes.py ./obj_dir_turbo/Vtop --kind graphics --turbo-bank 0 --blackclip 0x30
python3 tests/test_video_modes.py ./obj_dir_turbo/Vtop --kind text --blackclip 0x0f
```

Delay-aware models: baseline sys=32,000,000 / video=28,571,428 Hz; single
sys=video=28,636,364 Hz with compensated MR16 timer. Graphics runs 1 second,
text 200 ms; every active pixel and settled HS/VS period is checked, not just
hashes. CPU bank tests run 31.25 ms including reset/download; warm variant
pulses reset at 20 ms for 10 us without reloading storage. IPL uses a full
32 KiB original fixture, not downloaded firmware. JSON reports
`turbo_foundation=true`; Turbo pixel flags require the matching model.

Display controls cross through two video-clock sampling stages. This defines
simulation latency, not hardware safety for simultaneous multi-bit changes.
Mid-scan phase, bundled-control CDC placement and reset release require review.
Pixel fixtures switch before settled captures, not exact live-write timing.

Optional FPGA revision `sharpx1_turbo_single` sources the single-clock project
and enables `X1_TURBO_FOUNDATION`; neither default revision changes model.
MiSTer IPL upload bounds follow the same 32/4 KiB choice. No OSD label promises
Turbo compatibility. The [latest source-bound two-image build](DUAL_DISK_QUARTUS_BUILD.md)
fits at 48% ALMs / 54% memory bits (69% RAM blocks), with positive constrained
timing at all eight analyzed corners. External I/O, CDC/reset and hardware
remain unverified. Hardware is unavailable while travelling; earlier RBFs
predate this increment. The earlier [foundation build](TURBO_QUARTUS_BUILD.md)
remains historical; the CTC checkpoint binds 333 inputs to `0115a38`, while
the latest two-image RBF binds all 334 inputs to `ffc1c1c`.

## Reference disagreements and next gates

The [implementation plan](TURBO_IMPLEMENTATION_PLAN.md) records schematic
pages, MAME functions, dependencies and feature acceptance. X Millennium was
cloned and inspected at revision `b07506c0cae31d260db28cb079148857d6ca2e93`,
not built/run. Its `io/crtc.h` and `crtc_bankupdate` agree on independent
display/access bits `08/10`. Its `io/iocore.c` limits blackclip readback to
Turbo Z, consistent with the chosen original-Turbo behavior. It exposes SCRN
readback at exact `1FD0`, whereas MAME leaves reads unmapped and mirrors
writes over sixteen ports. This remains a schematic/manual/software review
gate; tests document our chosen contract, not authentic hardware readback.

X Millennium also estimates high-resolution dots at 21.0526 MHz and clamps
CRTC geometry, versus the schematic's 42.95454 MHz oscillator and inherited
21.47727 MHz divider annotation. It is not a line-timing oracle. SCRN bit 1
is raster expansion/200-line selection in these references; distinct 400-line
behavior needs a clock/address contract, not PPM row duplication.

The new [graphics raster increment](TURBO_RASTER_STATUS.md) separates full CRTC
RA from text MA and implements low, repeated-raster and even/odd-page address
paths. It does not change clocks/fonts or establish authentic high scan.
The previous published RBF predates this increment. A subsequent opt-in
[X3 clock/font increment](TURBO_VIDEO_CLOCK_STATUS.md) provides nominal high
scan and 16-row ANK simulation checks, not full physical video acceptance.

Next: finish divider/mux phase/switching audit and physical 15/24 kHz
qualification, text expansion/underline, CPU font selection, high-speed PCG
and Kanji glyph access. CTC/daisy-chain/RETI now
has focused simulation acceptance, not exact hardware equivalence. Continue
DMA BUSRQ/BUSACK/FDC DRQ pacing, SIO, and explicitly selected optional FM,
expansion/Turbo Z features. Authentic Turbo IPL/native software, disk changes,
synthesis/CDC and physical video/input/audio are separate gates. Arcus loading
and Bastard Special title probes are not gameplay acceptance; see
[software results](COMMERCIAL_COMPATIBILITY.md).
