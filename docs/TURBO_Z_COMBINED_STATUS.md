# Combined experimental Turbo Z video qualification

October 9, 2026. This matches the video capabilities selected by the new
`sharpx1_turbo_z_video` wrapper profile: external palette CPU/video,
multi-mode fetch, internal-eight palette and text/priority together. No
native Z identity, DMA/SIO/FM/Kanji or private ROM/font is enabled.
The source qualified below predates the subsequent
[destination-local ownership reset correction](TURBO_Z_OWNER_RESET_STATUS.md);
its fresh pixel/fit gates are separate. Simulator SYS=32 MHz and
VID=nominal 42.954540 MHz; fitted/physical frequencies are separate evidence.

## Expanded combined diagnostic matrix (started, not yet qualified)

`verilator/tests/test_z_combined_matrix.py` schedules the unchanged CPU/pixel
oracle with all combined runner features required in every returned JSON.
The fast plan check enumerates 120 unique cases, not 120 executed passes:

| Diagnostic group | Cases |
|---|---:|
| Full/reduced single-screen graphics, selected banks, identity/custom, cold/warm | 24 |
| Paired graphics, both front banks and three orders, identity/custom, cold/warm | 24 |
| Paired text with those same front/order/palette/reset combinations | 24 |
| Single text in full/dual64, four priority values, identity/custom, cold/warm | 32 |
| Internal eight-color, identity/custom, cold/warm | 4 |
| Reverse attributes, paired/full/dual64, identity/custom, cold/warm | 12 |

Each actual case retains the original full four/five-second simulation and
exact RGB12/pixel/frame-timing/reset oracle. The wrapper checks actual versus
expected PPM bytes independently, feature selection and pre/post frozen
runner/emitter/helper/font hashes, and records completed cases incrementally.
No stopped, failed or not-yet-run case is reported as complete.

Execution is started under ignored
`verilator/obj_dir_headless/z-owner-combined/complete-matrix-vmlITQ/all-120`
with local log `/tmp/x1-z-combined-all-120.log`.
It reuses the frozen ownership-corrected runner SHA-256
`6c2d657da0821c25bdeeac5ab13ecc0d7817405010592a659d3b336c193e02df`.
Shared machine, simulator top and C++ runner sources are unchanged since
`c05edb0`; recent changes are board-only and reporting/tests. This is not a
newly rebuilt runner or evidence that these tests elaborate the board framework.
Emitter SHA-256 `1e03a9ecd39af3f049ef924db059c5bd5827c10879e479a593181da517009117`;
matrix wrapper at launch `5b6f1b1c222beac6758f107ee60048cea9810851513e657be6f3edecc6775fc2`.
No private ROM/font/game or native Z software is used. Full completion,
native ASIC/firmware and FPGA/physical gates remain separate and open.
The live journal now records ten completed cases (both full-graphics banks
across identity/custom cold/warm, followed by dual64 bank-zero identity cold/
warm). The eleventh, dual64 custom cold, is in flight. This is partial
execution, not 120-case acceptance; `completed.json` and case logs are the
authoritative incremental record.

Example (new output directory only):

```sh
python3 verilator/tests/test_z_combined_matrix.py \
  --frozen-root PATH_WITH_FROZEN_RUNNER_EMITTER_HELPER_AND_CG8 \
  --output NEW_IGNORED_OUTPUT
```

`--group` may select a named group without changing its cases or durations;
`--list` and `make -C verilator test-z-combined-matrix-plan` check enumeration
only. CI selects the plan test; it does not thereby execute all 120 pixel tests.

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
