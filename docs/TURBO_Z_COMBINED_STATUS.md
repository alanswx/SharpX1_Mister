# Combined experimental Turbo Z video qualification

October 9, 2026. This matches the video capabilities selected by the new
`sharpx1_turbo_z_video` wrapper profile: external palette CPU/video,
multi-mode fetch, internal-eight palette and text/priority together. No
native Z identity, DMA/SIO/FM/Kanji or private ROM/font is enabled.
The source qualified below predates the subsequent
[destination-local ownership reset correction](TURBO_Z_OWNER_RESET_STATUS.md);
its fresh pixel/fit gates are separate. Simulator SYS=32 MHz and
VID=nominal 42.954540 MHz; fitted/physical frequencies are separate evidence.

## Completed coherent-control checks

`test-machine-z-combined-control-reset` selects `INTERNAL8=1` in the original
actual-CPU priority/reset fixture. At VID half-periods 17,500/11,640/25,000 ps,
all three runs finish zero: 256 cold/warm priority values, real mode exit and
return, captured character eligibility/priority, both stopped clocks and reset
while an actual CPU-written 5A payload is pending with VID stopped. The same
internal-eight combination with priority disabled fails specifically at
`CPU sweep incomplete`, not a watchdog. No fabricated bus or shifter state.

Final log `/tmp/x1-z-combined-control-qualified.log`. Existing three-clock
CDC and disabled-priority regression also finishes zero in
`/tmp/x1-z-combined-control-final.log`. New fixture wiring adds no warnings
or suppressions. Source/executable were hashed before qualification and match
afterward:

| Artifact | SHA-256 |
|---|---|
| Control fixture | `1b26af7a81eab59013f36bb6191105d27db285387d7fb2de5cc9cddffc0d79bc` |
| Shared machine | `ddb49969b0c4e3cb0000c0aaac434c175e841e4dfa8c99f14b8c2f568e333b67` |
| Combined control executable | `6ff1911c35fe50338d20b9012c35f5922b1b75b213a7e7d4b7df95f21c052c08` |

## Source-frozen pixel checks

Delay-aware C++ runner and original emitter/oracle/checked-in ANK source are
frozen under `verilator/obj_dir_headless/z-board-combined/qualification-CBgbK8/`.
Each test runs its unchanged full five-second duration, programs custom colors
through CPU instructions, resets at 4.5 seconds for 10 microseconds, then
requires control reinitialization without palette/GRAM/text refill. The final
frame is actual RGB12, compared against the independent oracle and checked
line/frame periods, not an emulator screenshot or fabricated framebuffer.

| Format / selected case | Current result |
|---|---|
| 640x400 / internal 8 | Passed all 256,000 pixels and retained-reset/no-refill checks |
| 640x200 / 64 | Passed all 128,000 pixels and retained-reset/no-refill checks |
| 320x400 / 64 | Passed all 128,000 pixels and retained-reset/no-refill checks |
| 320x200 / 64 | Paired text-between/front-bank-0 and selected-bank-1 cases each pass 64,000 pixels |
| 320x200 / 4096 | Graphics-on-top/text case passes all 64,000 pixels and retained-reset/no-refill checks |

All six processes exit zero: 704,000 exact pixels in total. Independent `cmp`
of all six actual/expected PPMs passes. Paired text selects all seven writable colors (86–87 pixels each)
and differs from the alternate text order at 15,132 pixels. Its auxiliary raw
graphics coverage metadata retains the previously documented window omission;
do not promote that metadata to an exact source distribution. These are bounded
custom warm cases, not the complete cold/identity/custom/front/order matrix.

Logs `/tmp/x1-z-board-combined-{internal8,paired-text,wide64,tall64,dual64,full-text}.log`.
Frozen executable SHA-256
`fd41ee4c1f6b4950d31d712be11a6c4afc356ef3654a5a69d159a29c8eabf0c8`,
pixel fixture `1e03a9ecd39af3f049ef924db059c5bd5827c10879e479a593181da517009117`,
ANK source `68aa689abd81c1a620980b5318b669b292a72d4877916ec43dc2461d713c831b`.
Final pre/post executable/emitter/helper/ANK hashes match after all six runs.
Generated programs/captures stay ignored.

The [source-bound FPGA flow](TURBO_Z_BOARD_BUILD_STATUS.md) completes, but fails
reported timing. No timing closure, physical scaler/CDC, native ASIC opacity/
intensity, firmware/software or full Turbo Z/work-groups 1–6 completion follows.
