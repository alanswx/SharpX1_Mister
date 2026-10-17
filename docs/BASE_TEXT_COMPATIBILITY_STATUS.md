# External-font base text compatibility

October 16, 2026. Separate default-off `sharpx1_turbo_z_font` qualification;
ordinary profiles and the DMA qualification revision remain unchanged.

The unmodified base IPL writes text and attributes but leaves Kanji metadata
unknown. The external-font cache previously required all three bytes and
blanked those cells. The new path admits committed mask03 packets only in
simple low scan with expansion/underline off. It retains unknown Kanji flags,
requires zero masked payload and never uses a partial packet as a Kanji glyph.
Permission is captured at request, checked at reply, revoked during hold and
checked at actual glyph LOAD. Invalid ink is masked after reverse/blink.
Retained-reset journal rebuild includes partial packets without inventing
native power-on RAM values. Strict standalone adapter default stays mask07.

| Gate | Current evidence |
| --- | --- |
| Strict original adapter | 65,548 positive combinations and 13 matched mutations pass |
| Partial adapter | 778 positive cases and six runtime mutations pass, no warnings |
| Real machine | Six cold/warm positives, 88 CPU reads, twelve exact frames / 1,408,000 pixels; three runtime rejecting controls pass |
| Renderer LOAD | 34 public-port CRTC/color checks and two rejecting mutations pass |
| Existing full metadata | Original five-case machine and four-case exact renderer gates pass |
| Ordinary generated state | Eight original base/Turbo v17 headers/serializers byte-identical; warnings unchanged |
| Ordinary build/regression | Build, 200,000-cycle smoke and full regression pass; 164 PASS reports |
| Wrapper | PLL-interface lint passes; not physical acceptance |
| Quartus | Local 17.0.0 build 595 full flow terminal zero; source-bound RBF 4c0a95f2…; slow setup/recovery fail |
| Native hardware | Unmodified base/Turbo arithmetic cold-repeats; base Main R/T reset and LIST/RUN pass; 21 raw PNGs / 245,760 independently checked pixels |

Pre-change bytes are preserved under `output_files/BASE_TEXT_20261016T1524/`.
Its `focused-audit.json` independently checks current frozen inputs and all
new focused artifacts. Exact live paths/logs are in
[the development handoff](DEVELOPMENT_HANDOFF.md). No timeout or compile
failure counts as a rejecting control. Initial fixture compile failures and
the ordinary isolation-checker failure remain preserved.

The existing renderer oracle is unchanged. Its test enables the new validity
input and retains all 63 normalized warning identities/counts; the refreshed
ledger changes only reviewed source hashes/locations. The new generated IPL
uses actual Z80 I/O and public uploads, initializes no Kanji plane, and checks
retained text/attributes after two traced boots without asset reupload.
Missing text, high scan, underline and expansion must remain black even with
reversed attributes. Ordinary profiles gain no serialized state.

Focused gates run directly from the repository root:

```sh
python3 -B verilator/tests/test_z_partial_ank.py
python3 -B verilator/tests/test_text_packet_load.py
python3 -B verilator/tests/test_z_partial_ank_machine.py
python3 -B verilator/tests/test_z_kanji_video.py --render
python3 -B verilator/tests/test_z_external_font_machine.py
```

Each collector preserves its frozen source, executables and matched runtime
controls in a unique evidence directory. Never restart a live run on timeout
or replace its oracle with a newer source during execution.

The Quartus snapshot is `output_files/quartus-9o5ChatI/`, with 428 original
inputs. The tool rewrites only its copied QPF/QSF. Isolated project queries
prove the same 2,230 assignment multiset and exact non-PLL source/QIP/SDC
order. Only independent global macros and isolated PLL-library ordering move;
neither PLL source defines/undefines macros. Generated build ID is separately
recorded in `build-audit.json`. Full flow completes in 16m11s, with 171 stage
warnings; 25,228 ALMs, 37,234 registers, 534/553 M10Ks, 32 DSPs/four PLLs.
RBF SHA is
`4c0a95f2cc91c91df46eff8e3b22577b809fa6247725bd91294c3db1ce300a23`.
Generated build-ID SHA is
`302c3f62558e7478ec76816125e4f6e37c249c7b7b211ab09a511d9e11f05619`.
Original SDC Slow 1100mV 100C analysis reports setup −15.031 ns, recovery
−8.167 ns, hold +0.251 ns and removal +0.844 ns. This flow does not run the
fast corner; hold requirements are incompletely constrained. Timing acceptance
fails. Fitted SYS/VID are 32/42.954545 MHz, not physical measurements.
No new SDC exceptions are introduced.

The hardware collector uses unmodified 4-KiB base and 32-KiB Turbo IPLs,
synthetic full physical font, ANK16 and disposable protected HuBASIC D88
copies. It requires repeated native arithmetic and missing-Enter rejection,
then Main R/T resets and LIST/RUN without warm core reload/upload/remount.
Actual raw mrext PNGs and hashes are required. Native font conversion, wider
text policies, exact ASIC timing, SAVE/LOAD and general BASIC compatibility
remain open regardless of these bounded results.

Hardware session 61234 is terminal zero in `/tmp/x1-base-text-hardware.log`,
with evidence `output_files/BASE_TEXT_20261016T1524/hardware/`. All four
cold cases reject missing Enter. On the last base cold boot, menu navigation
without selection retains `42`; typing without reset appends `81` and rejects
the fresh-row oracle. Main R then produces fresh `81`, Main T fresh `64`,
followed by stored `10 PRINT 9`, LIST and RUN producing `9`. No warm core
load/upload/remount is requested. Native BASIC may rewrite text at boot;
the separate generated machine fixture establishes retained journal causality.
No physical owned-reset phase is observed here.

`scripts/audit_mister_base_text.py` independently rechecks every pixel,
action sequence, MGL/config/disk, current 428 compiler inputs, frozen helpers,
RBF/Main/remote files and full font DDR. Session 93856 is terminal zero;
`hardware/independent-audit.json` passes. Final owned core is
`X1BTEXT_20261016T155231Z_04`. Ordinary session 21833 is terminal zero in
`/tmp/x1-base-text-regression-v2.log`, with 164 PASS lines and runner SHA
`cb28813e095804f02dfc59cba9e32e7c309bbfb8aabdd9d81af688898eb2408c`.
Regression log SHA is
`9f47acdd12f88de8dfc32f2d485397373e66ff81e5a2df65a77ae7836a917ed6`.

Earlier startup observer counts at `O_VQ=14` are held-packet samples, not
glyph-LOAD samples: that public divider output is inverted. Actual raw-divider
phase 14 corresponds to `O_VQ=2`. The new focused test observes the renderer's
actual `O_GRAPHICS_LOAD`; old evidence and its original labels are preserved.
