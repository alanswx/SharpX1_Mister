# Cached VRAM write transaction boundary

October 14, 2026. Original GPL-2.0-only `rtl/x1_z_kanji_vram_write.sv`
connects a held CPU write to three synchronous `x1_video_ram` CPU ports and
the qualified external glyph cache. It is standalone, outside `machine.qip`
and all machine/board profiles. Existing machine RTL, cache/frontend/backend,
TV80 and VRAM sources are unchanged. This implements the write boundary for
later integration, not native ASIC write visibility or actual machine RGB.

## Provisional transaction contract

`write_select[2:0]` is one-hot `{kan,attr,text}`. `write_accepted` identifies
one admission while enabled and armed. Address, data and select are held;
the following SYS edge captures the other two bytes from the synchronous
VRAM CPU ports. Live bus changes cannot redirect a pending write or refill.
No other writer may modify these cells during ownership.

One complete 32-byte glyph and descriptor is sent to the cache. Only after
its VID publication and returned SYS completion does the component issue
one VRAM write strobe, consume completion and release CPU WAIT. It keeps
the reply until `write_valid` is observed low, preventing held-level replay.
A write that retires early still drains and commits once. Dropping admission
permission never revokes an admitted transaction. Stopped VID deliberately
holds the write and WAIT; BUSY DDR retains the corresponding font request.
After early retirement, wait for idle before starting another request; there
is no queue for overlapping CPU transactions.

The 32-bit descriptor is `{5'b0,known[kan,attr,text],kan,attr,text}`; the
physical glyph tag is `{kan[4:0],text}`, and committed half is descriptor
bit 22. Per-cell known masks start zero at launch and retain subsequent
committed writes. Unknown bytes are masked zero in the packet; consumers
must require all three known bits before interpreting text. This does not
define cold native RAM values. Every write, including partial/ANK/PCG entries,
currently refills a glyph. Refill-before-write WAIT and that bandwidth cost
are experimental policies, not an ordinary machine timing change.

There is intentionally no raw reset. Before cache invalidation, upload,
font replacement or resetting its service, the caller must block new writer
admission and wait for `idle`, with SYS/VID/font service continuing. Only then
may the existing lifecycle coordinator invalidate/drain the cache. Its present
pause input invalidates immediately, so it cannot be wired directly ahead of
an owned writer without this additional ordering. Admission must guarantee
a loaded, stable font and a serviceable cache completion. The component does
not itself implement missing-font boot, upload permissions or reset dispatch.

## Connected diagnostic

`make -C verilator test-z-kanji-vram` freezes all RTL, fixture, checker and
warning inventory before building. The fixture instantiates actual TV80,
three actual VRAMs, cache/frontend/backend and a delayed/BUSY mock DDR.
It programs every font byte through the real ordered upload interface once.
Public VRAM ports first seed a nonzero pattern while the writer is idle;
rotating first-written planes then expose any reliance on unknown old bytes.
This is diagnostic initialization, not injected CPU results or private state.

For each cell, three host-driven writes fill all metadata planes. Inputs are
poisoned after admission, completions are held, and every published version
must return all sixteen rows with coherent descriptor/glyph/bank/half/data.
Public-intent ledgers require exact font addresses, word/lane/data and counts.
Further cases block admission, revoke permission with an owned BUSY request,
stop VID during publication and retire a raw request before completion.

The real Z80 then executes a generated OUT/IN/self-check diagnostic with 24
writes per complete boot, including attribute-port aliases and the highest
three cells. It writes its own success/failure marker and HALTs. Two complete
boots surround an attempt reset with its tenth write already owned; that
write still drains once. Font and VRAM/cache metadata are retained without
asset reupload. This reset does **not** invalidate the cache or exercise the
service lifecycle/Main/OSD path.
CPU is held reset during upload and host writes; each program boot holds
reset for 32 SYS edges before release. Clocks, phases and memory delays are
deterministic in the frozen fixture.

A separate Python emitter must reproduce the complete 64-KiB program image.
Independent audits check all 58 actual CPU OUT intents and resulting expected
descriptors/glyphs, plus 57 sampled IN values per positive. CPU self-checks
establish those IN results reach the executing diagnostic. Cache scans are
synthetic, not the machine renderer or displayed RGB. One CPU-read corruption
control must reach the unchanged program's `EE` failure-handler HALT, with a
recorded wrong first IN value; deadline expiry cannot qualify that control.

| Positive | Cells | SYS / CPU | VID half-period | Admissions / commits | DDR reads |
|---|---:|---|---:|---:|---:|
| full32 | 2,048 | 32 / 4 MHz | 11,640 ps | 6,205 | 198,560 |
| full100 | 2,048 | 100 / 4 MHz | 11,640 ps | 6,205 | 198,560 |
| cpu2m-slow-vid | 8 | 32 / 2 MHz | 20,000 ps | 85 | 2,720 |

Each positive requires exactly 262,144 external font writes, three CPU attempts
and two complete boots. Simulated durations are approximately 134.555,
55.194 and 36.805 ms. The SYS100 case is a component clock stress profile,
not an X3 machine frequency change.

## Qualification evidence

Full frozen session `18539` finishes zero in `x1-z-kanji-vram-ccu5g0xa`, log
`/tmp/x1-z-kanji-vram-first-full.log`: three positives, fourteen exact RTL
mutants and one actual-CPU bad-readback control, eighteen builds/runs. All jobs
are terminal. The three positives give six complete boots, three interrupted
attempts, 174 CPU writes and 171 independently checked read samples. An earlier
small review with all strengthened observations passes in
`x1-z-kanji-vram-u0hca2ip`; it is not substituted for the full gate.

Controls reject live address/commit data/merge data, each unmasked unknown
plane, lost known-mask retention, wrong glyph level, early or repeated VRAM
strobes, early WAIT, disabled admission, held-reply replay and a queued offer
lost when admission falls. Each must fail its exact local ownership/data/
progress assertion. The bad-readback control must fail the unchanged CPU
completion oracle with marker `EE`, precisely one first write and an observed
wrong first IN. No assertion or completion deadline was relaxed.

Read-only final review `x1-z-vram-final-review-0qzvqiq0` rehashes current/frozen
sources, all executables/compiler/run logs, program images and traces, checks
the exact compiler inventory and re-emits/audits the complete CPU intent and
read sequence. It preserves a final artifact roster. Review SHA-256:
`ad0dcb73626abb2ca3d57a60240243cc12d5197e4e3203e7ad95905f15d7f39c`.
Its roster covers 112 final files. Terminal report SHA-256:
`76eecba0f6e6a0e6e83cb897be2d91575a8fe5d911994badad6a099587323ca7`.

The writer passes separate strict `--lint-only --timing -Wall`. Connected
CPU builds use `--binary --timing --assert -Wall -Wno-fatal` and require
exactly the 32 inherited CPU/TV80 warnings from the earlier reviewed inventory,
with only the fixture hierarchy renamed. New writer/fixture/VRAM code has no
warnings; the checker refuses additions or changes. This is an exact inventory,
not warning suppression or physical CDC acceptance. Optimized Python refuses
before evidence allocation. All failed attempts/control artifacts are kept;
compiler errors and the whole-test timeout cannot count as matched negatives.
The target is scheduled in CI with a 900-second limit; no hosted result exists.

| Input | SHA-256 |
|---|---|
| Writer RTL | `229bfa92bec64878a078cf8f92ef998f57ce6bf6f219d6f28d4195adbd28418c` |
| Connected fixture | `0ee97598cee6780d30eeb04f9876b3e131ecece11254c0d63a02147083191d2f` |
| Checker/emitter | `4040f322b687bed350cb9d8d38104d37a54df0c2de1f616ec06bbe6e820a0131` |
| Warning inventory | `26655f72b5e4f9de30ed0bc2ae254aee8760d8ac4779e10633ad0fbf23d1ab15` |
| Full-profile generated program | `733fbfe6fe3eb82c2534b459c010aea3686e1886b175e65464eb3dd2f6607266` |
| Eight-cell generated program | `38a44616e055fa5201f3e02d763a9f21508b8a86c9429eaa7bd65a49a0fb9eed` |
| Generated full font | `985d0a287503c3823bd267ef00253238e0f97d22298052575b96274479399486` |

The unchanged cache remains at `e9671fb7…`, with its separate
[half-selection qualification](TURBO_Z_CACHE_HALF_STATUS.md). No Quartus map,
fit or STA has run for this new writer/known-mask/VRAM combination. Earlier
138-M10K cache fits do not establish its combined resources or timing.

## Remaining integration

The later [cache-renderer gate](TURBO_Z_CACHE_RENDER_STATUS.md) now connects
the real CRTC/RGB path in a separate CPU/VRAM/cache fixture and checks ten full
frames. Wire both components to actual machine CPU decode/WAIT/readback,
selectors and DDR ports. Resolve admission while fonts are absent and
cache reconstruction after invalidating retained VRAM. Add writer-drain ordering
before lifecycle pause, actual Main/OSD dispatch and competing CPU font reads.
Qualify actual CRTC RGB, ANK/PCG/mode changes, simultaneous devices, stopped
clocks and resets before combined source-bound fitting/physical CDC and board
work. Native font conversion and ASIC visibility/timing remain open. No MiSTer
load/reset/input or remote Quartus action occurred for this continuation.
