# Committed-cache packet to real CRTC/RGB

October 14 continuation. `rtl/x1_z_kanji_video.sv` is an original GPL-2.0-only
adapter between the qualified cache and the existing `x1_vid` renderer.
It remains outside `machine.qip` and every board/machine profile. The renderer,
CRTC, CPU, writer, cache, frontend/backend and VRAM sources are unchanged.
This connects real components in a diagnostic; it does not yet wire an
external-font profile into `rtl/sharpx1.v` or the MiSTer wrapper.

## Packet and timing contract

An actual `O_GRAPHICS_START` at phase 0 requests the current cell and four-bit
raster from the cache. Cache half selection remains descriptor bit 22. The
cache registers its response on the second sampling edge; the adapter samples
it on the third edge, two VID edges after request admission. Metadata is ready
before the renderer's actual phase-10 capture and held through phase-14 LOAD.
At the fixture's 11,640-ps half-period, admission to adapter capture is 46.560
ns; this is functional scheduling, not a physically constrained path result.

Only the exact response slot may populate a packet. Cell, row, half and glyph
tag must match the held intent/descriptor; the full high descriptor byte must
be `07` (all three writer known bits, reserved bits zero). Missing/invalid
responses produce zero metadata and zero data. There is no live VRAM fallback.
Capture closes an unfinished request, and later responses cannot replace its
bytes. A new prefetch clears the old packet and supersedes pending ownership,
including consecutive same-address requests. Video-local reset clears both
the packet and expected-slot state. No raw SYS reset is used by this adapter.

The existing renderer still captures its raster eligibility at phase 10 and
applies the Kanji blank mask at LOAD, after reverse/blink in the color path.
Known packet attributes/data travel together. Invalid metadata is never
exposed as a partial old/new character. Normal high scan, R6=25/R9=15 and
normal-size text remain the bounded renderer policy. The adapter does not
resolve ANK/PCG fonts, broader rasters, native KACE/WAIT timing or reset/upload
ownership around a writer that is still draining.

## Unit gate

`make -C verilator test-z-kanji-video` finishes zero in session `18918`,
folder `x1-z-kanji-video-n4o8gsl6`, log `/tmp/x1-z-video-unit-final.log`:
one positive run and thirteen exact RTL mutants, fourteen strict warning-free
Verilator 5.044 timing/assertion builds/runs. The positive covers 65,548
scenarios: all 2,048 cells, sixteen rows and both halves, plus nine invalid
reply cases and capture/supersession/reset boundaries. Each valid packet has
an aligned early response and a different aligned late response; neither may
replace its exact-slot byte. Inputs are poisoned after request admission.

Controls reject live cell/row selection, ignored half/tag/valid/hit, permissive
known/reserved metadata, out-of-slot replies, capture left open, superseded
replies and stale start/reset metadata. Compiler failures and the global
timeout are refused. The earlier attempt `x1-z-kanji-video-8udp_4td` is
preserved: a live-cell mutant made its held register unused and failed strict
compilation. Refined fault variants retain that register's use while selecting
the live bus at response time; the packet assertions remain unchanged.

## Real renderer and independent RGB oracle

`make -C verilator test-z-kanji-render` connects actual TV80, three real VRAMs,
the qualified writer/cache/font service, this adapter, and the unchanged real
CRTC/RGB shifter. Generated assets and delayed/BUSY mock DDR are used.
Diagnostic code is preinitialized RAM, not a native IPL upload/mapping test.
CRTC programming uses its actual separate bus under caller-held video reset;
it is host-driven here, not real CPU CRTC writes or Main/OSD dispatch.

Each positive uploads all 262,144 generated font bytes once, writes all 2,048
cells through the writer, and runs two complete CPU OUT/IN diagnostic boots
around an interrupted tenth owned write. Independent Python emission checks
the full program image, all 58 CPU write intents/descriptor expectations and
57 sampled IN values. Retained font and VRAM require no asset reupload.

A targeted collision freezes VID just after a real phase-0 cell-zero request.
SYS refills and offers a new glyph before VID resumes. At SYS100, raw VRAM
commits before phase-10 capture while the prefetched packet still describes
the old version. The positive must observe this mismatch and retain the older
coherent packet. A counterfactual wiring control feeds the real raw VRAM bytes
to the renderer and must fail the unchanged capture oracle at that boundary.
A second control changes the actual renderer glyph input and must fail its
unchanged RGB oracle. No DUT state, forced CRTC fields or injected CPU results
are used.

Every cache reply is checked against admitted write intent and the generated
font. A compositional per-VID-edge oracle checks the real RGB registers through
CPU writes, blink, blanking and resets. Separately, five whole frames per
positive are compared pixel-for-pixel with a static Python oracle derived
from the programmed cells and CPU program, not returned DUT addresses/data:

1. Initial filled VRAM.
2. CPU-written cells after interrupted/repeated boots.
3. Blink asserted, including reversed text.
4. Same blink state after video-local reset, with retained CRTC/VRAM/font.
5. All-black frame after cache invalidation with stale VRAM still retained.

RGB CSVs and actual PNGs are retained. Frame 1 must differ from 0, frame 2 from
1, reset frame 3 must equal 2, and frame 4 must be entirely black. Frame
collection waits for complete VS boundaries and checks exact width/height;
it does not independently qualify native frame frequency or PLL timing.
Graphics/PCG/ANK inputs and graphics palette are zero in this fixture: these
frames qualify the Kanji path, not native ANK/PCG or multi-device composition.

The full frozen connected session `21336` finishes zero in
`x1-z-kanji-render-870corcr`, log `/tmp/x1-z-render-first-full.log`: both
positives and both exact controls pass. All jobs are terminal.

| Positive | Columns / frame | SYS / CPU | VID half-period | Completed writes / DDR reads | Captured pixels | Stale-VRAM witnesses |
|---|---|---|---:|---:|---:|---:|
| render80 | 80 / 640x400 | 32 / 4 MHz | 11,640 ps | 6,206 / 198,592 | 1,280,000 | 1 |
| render40-sys100 | 40 / 320x400 | 100 / 4 MHz | 11,640 ps | 6,206 / 198,592 | 640,000 | 2 |

Each positive requires 262,144 external font writes, three CPU attempts and
two complete boots. SYS enable periods are eight and twenty-five edges;
SYS100 is component stress, not an X3 machine rate. Simulated durations are
490.364 / 409.703 ms. Per-edge RGB assertions check 15,941,639 / 15,941,579
registered outputs respectively, separately from the independent static frames.
The unit and connected gates together contain eighteen builds/runs: fourteen
strict warning-free unit builds and four connected builds with the exact
inventory below. The ten full frames contain 1,920,000 checked RGB pixels;
four complete boots plus two interrupted attempts give 116 actual CPU write
intents and 114 sampled IN values.

Final read-only review in `x1-z-render-final-review-bxeblzfa` rehashes all
current/frozen inputs, compiled executables, logs, programs, traces, frame
CSVs and PNGs; checks exact compiler inventories and rejecting assertions;
and repeats the frozen CPU/pixel audits. PNGs are regenerated in the review
directory and must match the original bytes, without rewriting originals.
Review SHA-256:
`695f10458766beee23ebbdae3be1f37cd586863ee1e519e4346c94606dfde23f`.
Unit/connected terminal report SHA-256 respectively:
`847e14360410c8d279146e50910800e22815917d33fafe169cb5165caaa1eb37`,
`382a928708824b9bc8d7b95b217b079e0cb4249d4dcf40e1c4947219c793f6d7`.

The earlier frozen review in `x1-z-render-review-dh8l0pr2` already passes its
five 640x400 frames and independent CPU/pixel audits; it is not substituted
for the full current gate.

Connected builds preserve exactly 63 reviewed warning headers: 32 unchanged
CPU/TV80, 30 unchanged legacy VID/CRTC, one fixture video-reset observation.
They use `-Wall -Wno-fatal` with an exact source-bound warning inventory;
additions/changes fail. New adapter/writer/cache/frontend/backend/RAM code has
no warnings. This is neither warning suppression nor physical CDC acceptance.
Both checker modes refuse optimized Python before allocating evidence and
freeze sources, executable/log hashes and all final frame/trace artifacts.
CI schedules both targets, with 900 seconds for the renderer; no hosted
acceptance result is claimed.

## Inputs and remaining integration

| Input | SHA-256 |
|---|---|
| Adapter | `8016d1553bccf66a45e1641b63d5d085b23ce862e61e25a5578c768143a352ab` |
| Unit fixture | `1ce28c3e7f17d5bee165bf39a45735be23d76bc779ee5f38c9200ab3686e7079` |
| Render fixture | `1da913002cf093c792406a3e0683abc2d7d689286ad09a08aed0e6cd95681aee` |
| Checker/emitter/oracle | `f03a4c24a41c0e6e0b7a55e08fe965a7f4d5a8fee4928170c57f36137be81dd9` |
| Warning inventory | `4419faa671dd2af6848cfd1c1bc7749a02c2b1db1847e8e59942796e824db6fd` |
| Generated CPU program | `cebb4c0a626836732aac0af901c863d183fc84392bc9287d592ab9accce41c08` |
| Generated full font | `985d0a287503c3823bd267ef00253238e0f97d22298052575b96274479399486` |

Wire machine CPU decode/WAIT/readback, selectors, renderer and actual DDR
ports in a separate non-savable profile. Resolve writer drain before lifecycle
invalidation, retained-cell reconstruction, missing-font boot and real upload/
reset dispatch. Then qualify actual whole-machine CPU/pixels, concurrent font
reads/devices, wider modes and ordinary-profile identity. Native fonts/ASIC
behavior and combined FPGA fit/timing/CDC remain open. Earlier 138-M10K cache
fits do not bind this combined diagnostic. No Quartus/MiSTer action occurred.
