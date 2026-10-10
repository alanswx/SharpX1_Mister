# Non-savable RTC/X3/DMA/Kanji/FM coexistence

October 10, 2026. `rtc-x3-dma-kanji-fm` is a separately named delay-aware
simulation profile using the existing shared `rtl/sharpx1.v`. It adds the
already implemented CPU JT51/signed-mixer path to the RTC/X3/DMA/Kanji
combination. Ordinary runners, machine manifests and board revisions are
unchanged. This is neither full Turbo Z nor native sound/hardware acceptance.

## Configuration

SYS is 32 MHz; independent video is nominal 42.954540 MHz. Turbo, RTC,
X3 video, first-level Kanji storage/renderer, DMA and the explicit DMA/Kanji
qualifier are enabled, with `TURBO_FM_CPU=1`. DMA IRQ/restart, SIO and all Z
experiments remain off. FM keeps the existing provisional 4-MHz digital
enable: no new fabric clock, CPU IRQ or CT-to-CTC wire is invented.
The existing RTC compile guard forbids snapshots; v17 defaults are unchanged.
An explicit generated 8192-byte RTC controller is still required.

```sh
make -C verilator rtc-x3-dma-kanji-fm
make -C verilator test-rtc-x3-dma-kanji-fm-runner
make -C verilator test-rtc-x3-dma-kanji-fm-keyboard
make -C verilator test-rtc-x3-dma-kanji-fm-fdc
```

Build completes zero, Verilator 5.044, log
`/tmp/x1-rtc-x3-dma-kanji-fm-build.log`. Existing TV80/MR16 missing-pin,
width/case and inherited CRTC/FDC warnings remain visible; no new suppression
is added. Frozen runner SHA-256:
`79a8dab4f1bd1b920c0710774c9578135b4cd7141b4b6e3abbbb590c8f2b171b`.
Build success alone is not functional acceptance.

## Completed bounded gates

All below use original generated IPLs, actual ioctl/CPU/PS2/FDC/DMA paths,
and frozen inputs, not CPU state or RAM injection. Independent rehashing and
actual RAM/report checks pass in addition to the collectors' own checks.
Output root: ignored `verilator/obj_dir_v17_rtc_x3_dma_kanji_fm/`.

| Gate | Evidence | Limit |
| --- | --- | --- |
| Elapsed calendar, retained-IPL warm reset; four missing/short/save/restore rejections | `qualified-1hz0sv6s/`, 138 frozen inputs; `/tmp/x1-rtc-dma-kanji-fm-runner.log`, terminal zero | FM unprogrammed, DMA idle; native year/power policy unresolved |
| Six actual PS/2 keys with live RTC mailbox polling; absent-key rejection | `keyboard-qualified-chnpfa_3/`, 136 inputs/13 assets; `/tmp/x1-rtc-dma-kanji-fm-keyboard.log`, terminal zero | FM unprogrammed, DMA idle; no rendered glyph/native keyboard-pin qualification |
| Four actual RTC/FDC/DMA sector cases: both observed command shapes, cold/warm | `fdc-qualified-l43n65sh/`, 138 inputs; `/tmp/x1-rtc-dma-kanji-fm-fdc.log`, terminal zero | 1024/2048 actual pairs and all 1024 payload bytes match; FM unprogrammed, glyph display uninitialized |
| Reject FM-disabled executable from explicit FM qualification | `/tmp/x1-rtc-fm-disabled-profile-negative.log`, terminal zero of matched rejecting wrapper | Fails specifically `wrong FM coexistence profile`; no missing-font or timeout substitute |

The generic RTC collectors default to requiring FM **off**; only explicit
`--fm` requests this profile. Calendar/keyboard `--fm` requires
`--dma --kanji --x3`, with six invalid-scope cases rejected before assets.
The disk collector's explicit `--fm` checks the actual JSON feature flag.
These gates do not program or validate FM voices.

## Actual CPU-programmed mixed sound

Private-output `audio-qualified-BH1IYt/` freezes runner, generated IPL,
controller, SV emitter and signed-WAV checker before two 800-ms cold runs.
Five frozen inputs rehash unchanged; reports and all seven RAM/CPU/sub-RAM/
text/attribute/DMA/WAV artifacts match exactly across cold/repeat.
Actual CPU status bytes are `00/01/00/FF`, completion AA and four real DMA
pairs copy `31..34` exactly. No disk requests/writes occur.

Both actual C++ captures contain 38,400 signed stereo frames at 48 kHz.
Independent waveform checks and the frozen checker find centered PSG
1000.000 Hz and isolated left FM 491.639 Hz, no clipping, and bounded PSG
DC. This pitch follows the **provisional 4-MHz** FM clock, not a resolved
native YM2151 oscillator/DAC contract. The same current-source SV emitter
is freshly built/executed in `audio-emitter-check/`; its complete 8192-byte
IPL matches the uploaded program byte-for-byte. Its original sample-aligned
stereo/mono and reset-repeat gates also finish zero:
`/tmp/x1-combined-fm-audio-current-emitter.log`.

Generated IPL SHA-256:
`06de8f3feb6a5974cf1306eeb11e100778ea3efa6168c921d8a35cf1315e6b61`.
Frozen/current SV emitter SHA-256:
`349a0a7965520e18bcb41cc03670e2a3713eac63bdf68f5cdd845e5e2796f724`.
Five-input list: `/tmp/x1-combined-fm-audio-before.sha256`. Its first check
used the wrong working directory and failed path resolution; the corrected
root-directory check passes all five unchanged files, without rewriting them.

`test_signed_audio_capture.py` keeps its original ordinary-FM requirements.
Only `--rtc-dma-kanji-fm --ram ACTUAL_DUMP` admits this separate exact profile,
requiring X3/RTC/Kanji/DMA flags, controller/upload count, four pairs, real
status/payload RAM and the unchanged waveform assertions. The actual combined
report is rejected by ordinary acceptance, and missing `--ram` rejects before
assets. The ordinary-FM recheck now completes zero using the unchanged
default acceptance: PSG 1000.000 Hz, FM 491.617 Hz, 38,400 frames. Its first
nested build improperly borrows a parent profile's object and rejects before
execution; the corrected local-object build is separate and accepted only
after the actual waveform check. See
[build isolation](RUNNER_BUILD_ISOLATION_STATUS.md), not a waived profile gate.

The forced-local nested combined rebuild produces exactly the same executable
SHA-256 as the frozen tested runner above. The existing multi-case collectors
were independently audited before the subsequent Makefile isolation repair;
their copied Makefile hashes are historical, not mislabeled as the newer file.
No RTL/C++/firmware or runner output changes are inferred from that recipe fix.

The audio fixture runs the RTC device but does **not** query its calendar;
it does not initialize Kanji video. DMA/status setup precedes voice programming,
so this is not ongoing FM-tone/FDC-DMA/glyph contention or owned-reset audio
acceptance. Do not merge these separate bounded gates into that broader claim.

## Remaining coexistence and native gates

1. Repeat exact Kanji pixels/active CG DMA with this FM-enabled profile.
2. Program/observe FM while querying RTC and performing ongoing FDC/CG DMA;
   retain exact payload, calendar, glyph and audio assertions through reset.
3. Qualify busy writes/status tails, voice/mix and retained assets during
   actual owned reset drain, including stopped clocks and SD acknowledgement.
4. Execute native Arcus/Bastard and broader software with protected original
   assets; neither prior non-FM probe was accepted gameplay. FM addition is
   a capability/coexistence step, not an asserted diagnosis or game fix.
5. Resolve native oscillator/IRQ/CT routing, analog gain/DAC/panning, current
   source resources/timing/CDC and physical sound/input separately. No RBF
   or board capability is added by this simulation profile.
