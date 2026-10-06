# DMA sequential masked-comparison status

October 6, 2026. Ordered search-plan increment: WR0 sequential transfer/search
now compares actual transferred bytes and reports a real sticky match flag.
This is a source-bound historical comparison checkpoint. The subsequent
[Byte stop increment](DMA_BYTE_STOP_STATUS.md) supports bounded Byte-mode
Stop on Match. **Pure search, non-Byte stop and DMA IRQ/service remain unimplemented.**
The full search classes remain part of the active goal, not replaced by this
non-stopping increment. [Remaining pipeline contract](DMA_SEARCH_CONTRACT.md).

## Behavior and provenance

Original changes in `rtl/x1_dma.sv`, no copied emulator code or private assets.
Primary [Zilog UM008101-0601](https://www.zilog.com/docs/z80/um0081.pdf),
printed 50/Figure 20, 58, 99 and 110: ignored mask bits, sequential operation
order, genuine match status and explicit status reinitialization. Existing
local MAME's `do_search`, LOAD/CONTINUE/reset routines were inspected, not run.
Its search helper only conditionally triggers an interrupt; it is not a
reference acceptance test for this sticky status implementation.

The comparator runs at completed destination-write time on the latched
source byte. A held or WAIT-stalled write does not prematurely set the flag.
RR0 D4 is inverted match state; ordinary reads/DISABLE preserve it.
8B clears match/EOB without changing request/physical Ready. Hardware/software
reset clears it. LOAD, CONTINUE and automatic reload clear the new latch;
these reset/load policies are explicitly tested candidate behavior, not
claimed silicon pipeline equivalence. Parsed mask/match bytes do not make
ordinary WR0 transfer mode compare. Stop/IRQ/unsupported timing and pure
search still fail closed; comparison acceptance cannot fake those capabilities.

Both shared builds use the same machine DMA engine when `TURBO_DMA=1`.
Defaults/ordinary Turbo/X3/board profiles still disable DMA. No IRQ pin, new
clock, synthetic bus grant or private ROM was added. Serialized DMA state
now includes a match latch: the simulator reserves **DMA revision 1**, an
additional profile bit 53, rejecting the previous DMA profile before restore.
The non-DMA v12 identity is unchanged. No supported DMA-savable target is
introduced or native DMA snapshot acceptance claimed; fresh affected states
must be generated, never patched/converted.

## Executed verification

Verilator 5.044 on macOS, timing/assertions enabled:

```sh
make -C verilator test-dma-compare HEADLESS_DIR=obj_dir_v12_dma_compare
make -C verilator test-dma test-dma-cpu test-sio-dma test-sio-dma-cpu \
    HEADLESS_DIR=obj_dir_v12_dma_compare DMA_TEST_CFLAGS=-O0
make -C verilator test-machine-dma-compare \
    DMA_DIR=obj_dir_v12_dma_compare_machine
```

All exit zero. The comparison unit runs **3072 cases at each CE=1/4**:
all 256 masks × two sources × three ownership modes × matching/nonmatching
data. Fully masked FF correctly has no possible nonmatch. Additional tests
cover first/middle/last sticky matches, plain-transfer exclusion, WAIT timing,
LOAD/CONTINUE/8B, actual matched-latch resets and automatic reload/retained
mask programming. Payload writes and held status/bus outputs are checked.
The final build has no default Verilator warnings or warning suppression.
The first fixture failure is retained: its 8B assertion expected inactive
physical Ready despite driving active-low Ready low. The assertion now
expects the actual active pin; RTL was not altered to satisfy it.

The actual shared CPU executes **12 original generated-ROM cases**:
both sources × all three ownership modes × match/no-match. Each runs eight
million 32 MHz reference cycles, uses CPU FORCE READY rather than forced
FDC pins, verifies actual payload/adjacent guards, status, all six counter
bytes and 8B, then halts after four real byte pairs. Byte mode has four grants;
continuous/Burst have one. All 12 also pass on the isolated `--no-timing`
runner, not an instruction-trap or RAM bootstrap.

The original 40-group automatic-restart suite, CPU/DMA and SIO/DMA/CPU
ownership/error/IM2/reset tests pass. Delay-aware restart, seven original
shared-machine disk/RAM cases, four reset cases and GRAM/PCG targets pass;
fast restart and GRAM/PCG targets pass separately. Native firmware and
physical timing are not inferred from generated diagnostics.

| Tested artifact | SHA-256 |
|---|---|
| `rtl/x1_dma.sv` | `d6704409bc10e9a1f7935b0de0b2ab42845bc6f2522a9a5cd884b42c30a7cdfe` |
| Comparison unit | `476ecc45efad1127407fae83bc3cb1379a722e8cb90ace0750320463a40dec22` |
| Delay-aware shared DMA runner | `4af8a5dfe6d95b5eeed9c69bb0d5b3a72216f70b1e7c589c694a45c3ac5de4a1` |
| Fast shared DMA runner | `8f8daf88ca68b526de91ced5a0049fdd96258ba59266b4a420ea81dd832bbf2b` |

Logs `/tmp/x1-dma-compare-3.log`, `/tmp/x1-dma-compare-regression.log`,
`/tmp/x1-dma-compare-machine.log`, `/tmp/x1-dma-compare-machine-positive.log`,
`/tmp/x1-dma-compare-machine-fast.log`. The fresh base savable build is
byte-identical to the five-game-qualified v12 base executable, SHA-256
`159062a12920cb398d1bd348b8e901a7b6139d31cfcadd8d038b73235d962a8a`;
fresh snapshot/negative-header/clock/joystick tests pass in
`/tmp/x1-dma-compare-base-snapshot.log`. This does not qualify Turbo DMA games.

The prior full base delay-aware rerun subsequently exited zero (session 4266,
`/tmp/x1-dma-autorestart-base.log`); hosted automatic-restart
run [37529441225](https://github.com/alanswx/SharpX1_Mister/actions/runs/37529441225)
subsequently passed on `d203dd5`. The
[24-target run](https://github.com/alanswx/SharpX1_Mister/actions/runs/37531002075)
also passes on `b893582`, including comparison. Later Byte-stop/pure-search
commits require their own terminal hosted results.
