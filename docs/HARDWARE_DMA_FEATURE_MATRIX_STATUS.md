# DMA-candidate hardware feature matrix

October 8, 2026 (captures dated October 9 UTC). The user released mister126
and mister14 and reserved mister192. Only **mister126 / 10.0.2.126** is used;
mister192 is not contacted and mister14 remains available.

## Exact tested machine

Separate opt-in `sharpx1_turbo_dma_single`, source
`818b0de28e6a3331e3894fd0313369bad618e534`, RBF SHA-256
`c1d83e6bc7218a5736d3c8cf4505cc3eb69d4c75c4ca958a5106f3c698bc8ca3`.
SYS/video share the fitted PLL's 28,571,428 Hz clock with enables. The Turbo
foundation, DMA completion/restart IRQ and F1 boot DIP are enabled; X3, Kanji
rendering, SIO, FM and Z palettes are not. Fit and exact earlier DMA acceptance
are in [DMA_BOARD_BUILD_STATUS.md](DMA_BOARD_BUILD_STATUS.md).

All MGLs use unique setnames/configs and disposable protected media. Installed
cores, existing media and services are preserved. RBF identity is checked
before loading. Tests send explicit keyboard events through a temporary
uinput device; this is not physical-keyboard/controller acceptance.

## Executed base-video and retained-reset MGLs

On the MiSTer browse `_Computer/X1Matrix_20261009T005305Z/`:

| MGL | Dimensions | Matching pixels per capture | Cold + retained reset |
|---|---|---:|---|
| `graphics-40.mgl` | 320 × 200 | 64,000 | Pass |
| `text-40.mgl` | 320 × 200 | 64,000 | Pass |
| `pcg-40.mgl` | 320 × 200 | 64,000 | Pass |
| `graphics-80.mgl` | 640 × 200 | 128,000 | Pass |
| `text-80.mgl` | 640 × 200 | 128,000 | Pass |
| `pcg-80.mgl` | 640 × 200 | 128,000 | Pass |

Each IPL is an original real-CPU diagnostic, not injected RAM or game bytes.
It programs CRTC/PPI and relevant VRAM/attributes/GRAM/PCG/palettes. Captured
MiSTer PNGs are decoded and compared against the already qualified CPU-IPL
simulation images with exact dimensions/RGB, no scaling or color tolerance.

The twelve captures above match **1,152,000 pixels, zero mismatches**.
Reset uses Main's Ctrl+Left Alt+Right Alt chord; no load_core, IPL upload or
disk remount command is sent between captures. Active core/setname and IPL
hash remain unchanged. This is bounded retained-reset acceptance, not all OSD
menu commands, reset during writes, power cycling or exact bus timing.

An earlier cold-only batch at `_Computer/X1Matrix_20261009T005058Z/` also
matches all six references (576,000 additional pixels). Comparing its
80-column graphics against the wrong text reference intentionally fails with
112,000 mismatches. Both pass and negative evidence are preserved.

Local ignored manifests, MGLs and actual PNGs are in the matching
`output_files/X1Matrix_*` directories. Logs:
`/tmp/x1-dma-video-hardware-current.log` and
`/tmp/x1-dma-video-warm-hardware.log`.

## Native-software batch

Six protected native-title trials completed, with actual PNGs visually
inspected and copied media hashes unchanged:

| Title | MGL directory under `_Computer/` | Visually inspected observation |
|---|---|---|
| CROSS Chase | `X1Matrix_20261009T005633Z` | Populated playfield; reset returns title, new input reaches Press key |
| Galaga | `X1Matrix_20261009T005633Z` | GAME START; reset returns title, new input reaches level selection; not live-play qualified |
| Druaga | `X1Matrix_20261009T005633Z` | Populated maze/player/timer; reset returns title, new input reaches GET READY FLOOR 1 |
| Mappy | `X1Matrix_20261009T021501Z` | ROUND 1 with largely blank field in this capture; reset returns title, new input changes screen; not live-play qualified |
| Xevious | `X1Matrix_20261009T021829Z` | Initial AREA 1 transition; reset returns title, new input reaches populated scrolling terrain/aircraft |
| Shanghai | `X1Matrix_20261009T022713Z` | 144-tile board/pointer; reset returns title, new input returns board; tile removal untested |

The first batch exits nonzero on a 55-second SSH timeout during Mappy's
**post-reset input**, after completing the preceding three trials. Its partial
manifest and four Mappy captures are preserved; final media checks were not
reached for that interrupted case. Read-only recovery checks found our Mappy
MGL still active and no surviving uinput helper. Separate fresh Mappy/Xevious/
Shanghai trials then exit zero. The original interruption is not relabeled
success or diagnosed as a core defect from a transport timeout.

No media/IPL/core reload is sent between each warm reset and its subsequent
input. All six completed cases retain core/setname and unchanged protected
assets. Timing of these captures and screen progression does not establish
five playable commercial games, input-specific movement/fire, native Turbo,
sound fidelity or physical controllers. Galaga/Mappy need additional settled
gameplay checks; do not promote earlier RBF observations to this candidate.
Logs: `/tmp/x1-dma-native-warm-hardware.log` (interrupted) and
`/tmp/x1-dma-native-warm-hardware-resume.log` (three fresh completed trials).

## Full feature coverage and remaining gates

Both actual Main OSD menu reset entries also pass on this exact DMA RBF.
`scripts/mister_reset_check.py` defaults to read-only qualification checks;
explicit execution loads the completed protected CROSS Chase MGL, advances
away from the title, then selects Reset (F12, Up ×3, Enter; close F12) and
Reset-and-close (F12, Up ×2, Enter). Each returns the exact qualified native
title PNG, SHA-256
`b9e2d2e38fb1e486fa130401aa3688284098a9625a5cda1b102070f2d2572ec5`.
New input reaches Press key. Core/setname and protected ROM/disk hashes remain
unchanged; no load_core/upload/remount is sent between reset and its follow-up
input. All six actual PNGs were visually inspected. Evidence:
`output_files/X1OSD_20261009T025416Z/`, log `/tmp/x1-dma-osd-hardware.log`.
This bounds the reported OSD reset concern, not every condition behind the
original report, physical buttons, power cycles or reset during disk writes.

| Feature | Hardware evidence / next gate |
|---|---|
| CPU/IPL/RAM, CRTC/PPI basic video | CPU diagnostics and native software; not exhaustive CPU/BASIC/PPI compatibility |
| 40/80-column graphics, text/ANK, PCG, digital palette | Exact cold/warm pixels above; broaden native attributes, beam traps and live bandwidth |
| DMA RAM, A/B FDC sector restart, IM2 handlers/RETI | Eighteen green CPU-driven MGLs on this exact RBF; see linked build status; precise grants/pins, Ready/mixed IRQ and resets during owned SD remain |
| Native protected A disks/keyboard | Current six-title batch; full movement/fire/pair-removal qualification remains separate |
| Native B boot | Earlier DMA-disabled-RBF acceptance; do not promote it to this RBF |
| Warm reset | Exact six static-video cases, six native reset/input observations and both bounded OSD reset entries above; broader loading/write/physical-button conditions remain |
| D88 writable media, eject/change, format/density/HD | Local synthetic coverage only for implemented subsets; physical transport/native multi-disk acceptance still needed |
| Keyboard/sub-CPU and joystick | Temporary-keyboard native checks and local mapping tests; physical devices, remaining sub-CPU functions and joystick gameplay remain |
| PSG audio | Local waveform regression; listening/physical capture and fidelity remain unverified here |
| Cassette/native BASIC | Incomplete; require implemented contracts and authorized software diagnostics |
| Turbo raster/X3/400-line/16-row text | Not enabled by this fitted RBF; separate timing-qualified build/native/hardware gates needed |
| Kanji CPU/glyph/attributes | Opt-in local diagnostics only; not enabled in this RBF; native and physical acceptance remain |
| SIO | Standalone local diagnostics; shared-machine/native/hardware integration incomplete |
| FM/OPM | Standalone local diagnostics; machine integration/audio/native/hardware acceptance incomplete |
| Turbo Z palette/multi-mode/capture/HD/level-2 Kanji | Incomplete; standalone RGB12/storage tests do not establish a working Z machine |
| HDMI/VGA/clocks/CDC/external timing | Positive constrained fit is recorded separately; physical measurement/external constraints remain |

No work group or full-machine compatibility is declared complete.

## Local follow-up verification

The complete delay-aware `make -C verilator test` exits zero. Its runner
SHA-256 before/after qualification is
`8886ca0529f99ac000ee4344d256427f4d874655d7dc8755c3b90a9b840f677a`;
log `/tmp/x1-hardware-followup-baseline.log`. Separate `test-sio-async`,
`test-fm`, `test-fm-cpu`, `test-rgb12` and `test-kanji-rom` also exit zero;
log `/tmp/x1-hardware-followup-optional-local.log`. These standalone optional
tests add no physical acceptance for devices absent from this RBF.
The [new palette RAM test](TURBO_Z_PALETTE_STORAGE_STATUS.md) remains standalone.

## Reproduction

Coordinate availability first. Native games are local authorized/private
assets already staged on mister126; neither scripts nor git redistribute them.

```sh
python3 scripts/mister_matrix.py --host mister126 --execute --warm-reset \
  --rbf-path /media/fat/_Computer/X1DMA_20261009T003346Z/dma.rbf \
  --rbf-sha256 c1d83e6bc7218a5736d3c8cf4505cc3eb69d4c75c4ca958a5106f3c698bc8ca3 \
  --video-ipl output_files/hardware-video-ipl
# Omit --video-ipl for six native-title observations.
make -C verilator test-mister-matrix-safety
python3 scripts/mister_reset_check.py \
  --manifest output_files/X1Matrix_20261009T005633Z/manifest.json --execute
```

The runner defaults to stage-only. `--warm-reset` requires explicit execution.
Synthetic video references are required and failing PNGs/comparison counts
are saved before assertions. Five asset-free CLI safety checks pass, including
rejection of mister192, unsafe RBF location/identity and invalid test selection.
