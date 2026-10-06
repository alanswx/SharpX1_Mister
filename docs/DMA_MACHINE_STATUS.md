# Opt-in shared-machine DMA integration

October 5, 2026. `rtl/sharpx1.v`, shared by simulation and MiSTer, now has
an explicit `TURBO_DMA=1` subset requiring `TURBO=1`. Defaults, ordinary
Turbo/X3 and FPGA revisions keep DMA disabled. This is generated-diagnostic
acceptance, **not native Turbo firmware, complete DMA or hardware support**.

## Connected behavior

- Real CPU BUSRQ/BUSACK selects one shared address/data/memory/I/O bus.
  BUSRQ alone never grants ownership. DMA M1 stays inactive, so payload
  cycles cannot acknowledge interrupts or fetch RETI through the IRQ bridge.
- CPU register aliases `1F80..1F8F` select the DMA stream only when the CPU
  owns an ordinary, non-DAM I/O cycle. Reads return the engine's latched data.
- DMA memory/I/O uses the existing IPL/RAM, peripheral and graphics decode.
  FDC DRQ feeds inverted Ready, matching the chosen active-low WR5 setting
  and inspected local MAME connection. No base FDC CPU interrupt was added.
- CPU, DMA and FDC use system-clock enables, not new generated clocks.
- `x1_dma_reset` retains short raw reset requests. CPU execution stops at
  once, but its actual ACK stays held while the started source/destination
  pair drains. DMA and target CE keep running; machine reset follows BUSRQ
  release and holds for four SYS edges. A stalled pair is not forcibly freed.
- Loader `ioctl_wait` blocks IPL/RAM/font writes during drain. Both the
  simulator and MiSTer HPS upload connection honor that signal. The physical
  HPS upload handshake has not been tested. An already-started DMA write may
  commit; reset is not a rollback guarantee.

Serialization advances to **v11**, including default-model instrumentation.
The DMA profile has a distinct identity bit. Never convert historical states;
regenerate native boot. No private software/fonts/states are committed.

## Executed acceptance

Delay-aware runner: SYS 32,000,000 Hz / VID 28,571,428 Hz, Turbo enabled,
X3/single disabled, standard four-MHz CPU/DMA/FDC enables. Initial reset
includes the ordinary ioctl download, then the reset guard's release hold.
`test_machine_dma.py` executes original Z80 diagnostics and generated D88
through real loader/SD paths, with **8,000,000 reference cycles per case**.
No CPU PC/register forcing, fabricated grants or injected game RAM occurs.

| Test | Result |
|---|---|
| Continuous Force-Ready high-RAM copy | 16 read/write pairs, one actual CPU grant, byte-exact RAM and primary address/count readback |
| Subsequent copy to RAM beneath active IPL | Full 8M-cycle fast/delay-aware tests pass: 16 pairs/one grant and exact counters, underlying RAM bytes changed while CPU still reads original IPL |
| DRQ-paced byte-mode drive A read | 256 pairs / 256 real grants, byte-exact sector and readback, zero CPU payload reads |
| DRQ-paced byte-mode drive B read | Same assertions with distinct B payload |
| Drive A write | 256 pairs/grants, fixed-destination two-LOAD workaround, whole-image output matches; B unchanged |
| Drive B normal write over deleted B0-CRC sector | 256 pairs/grants, whole-image payload/mark/CRC repair; A unchanged |
| Drive B D88-protected write | Zero DMA pairs/grants; write-protect status; both whole images unchanged |

Writes use explicit new disposable output copies, never overwrite originals.
Protected setup still enables DMA, but no invented DRQ is supplied.
The fixtures poll **FDC**, not DMA control registers, during byte transfers.
UM0081 Table 13 requires disabling before reading in enabled/inactive state;
this subset's disabling read policy remains documented rather than silently
changed to make the fixture pass. Counter reads occur only after completion.

Whole-machine `dma_machine_reset_tb.sv` also passes four independent runs:
request during source read, during destination write, a 2 ns pulse while SYS
is physically stopped, and a reload write held through a real blocked SYS
edge. Every case drains exactly one pair, retains CPU ACK, restarts from the
original loaded diagnostic in retained RAM, then finishes all 16 pairs with
exact total 17/17 counts and two grants. HALT alone is not completion: the
fixture also waits for all pairs and actual grant return.

Existing standalone DMA 32 groups, actual CPU/DMA 18 cases plus direct-read,
and standalone reset-guard tests pass unchanged. Baseline delay-aware timing,
reset/divider/FST/repeatability and v11 base snapshot/SDL checks also pass.
Build warnings remain inherited; compilation does not establish synthesis.

Commands from the repository root:

```sh
make -C verilator test-machine-dma HEADLESS_DIR=obj_dir_v11_units
make -C verilator turbo-dma DMA_DIR=obj_dir_v11_dma_fast DMA_TIMING=--no-timing
python3 verilator/tests/test_machine_dma.py verilator/obj_dir_v11_dma_fast/Vtop
```

Both complete delay-aware and fast matrices pass all six cases with the same
counts/payload/counter/whole-image assertions and original per-case duration.
Fast ignores inherited intra-assignment delays; it is not the scheduling
reference. Base wrapper lint passes with the PLL stand-in, not an Intel fit.
The subsequent full seven-case fast matrix also passes after adding the
RAM-under-IPL case; its separate full-duration delay-aware case passes too.
Logs: `/tmp/x1-v11-dma-seven-fast.log`, `/tmp/x1-v11-dma-overlay-delay.log`.

| Tested executable | SHA-256 |
|---|---|
| Delay-aware Turbo DMA | `3e1a686362076cf1282c7153fbd61735ca1c4aa9eb3e1abfc75c78786d8f56ff` |
| Fast Turbo DMA | `c9b48d27f87487609e846bba439d060c7658606ed163113ce3cee884ab2d3a33` |

These identify the generated-diagnostic checkpoint, not a native game boot.
Local logs: `/tmp/x1-v11-machine-dma-expanded.log`,
`/tmp/x1-v11-machine-dma-reset.log`, `/tmp/x1-v11-dma-units.log`,
`/tmp/x1-v11-base-timing.log`, `/tmp/x1-v11-base-snapshot.log`.

## Remaining gates

1. Broaden the pending-SD reset cases below to partial CPU payload,
   lost-data/CRC failure and no-ready/Ready-loss continuity. Single-block
   payload/header held and short reset cases now pass.
2. Broaden the video-target cases below to further PCG reset/phases,
   DAM/mixed side-effect targets and native raster traffic; preserve single
   peripheral transaction semantics.
3. X3/single combinations and programmable Ready polarity; current generated
   machine fixtures exercise active-low Ready only.
4. Unchanged native Turbo IPL disk streams, authentic counter continuation
   and Turbo FDC aliases; native Arcus/Bastard remain unqualified.
5. DMA IRQ/daisy/service, search and variable pin timing remain unsupported.
   [Automatic restart](DMA_AUTO_RESTART_STATUS.md) now passes standalone and
   actual shared-CPU diagnostics, not native/pin-timing or IRQ combinations.
   Do not fake missing capabilities or enable the default profile.
6. Source-bound Quartus reset/CDC/bus fit and physical hardware validation.
   The frozen `15a0655` artifact predates this work and fails timing.

## October 6 pending-SD reset and video-target qualification

No machine RTL changes were needed for this increment. The shared machine is
still the opt-in v11 subset, with SYS 32 MHz / VID 28.571428 MHz, ordinary
4 MHz CPU/DMA/FDC enables and X3/single disabled. These are original generated
programs/media, not unchanged native Turbo IPL or physical hardware evidence.

`dma_machine_sd_reset_tb.sv` runs eight delay-aware cases: drive A/B × read/write
× unacknowledged/mid-ACK request. Each case loads an original program through
ioctl and serves two distinct generated 960-byte D88 images through SD.
The reset is held through an 80-SYS-edge host stall and the eventual ACK drain;
CPU/FDC enables remain stopped, while the host uses SYS without their enables.
During that stall the old LBA, drive owner and request/ACK remain stable and
no DMA pair advances. The transport clears while reset is still held.

For reads, no old pair has started; for writes, 256 genuine byte-mode pairs
have already filled the published payload buffer. Accepted writes may commit
during reset, not roll back. Both whole images, including headers, padding
and the untouched drive, are checked **before reboot**, so a later identical
write cannot conceal old-buffer corruption. After releasing reset, the same
loaded program re-enters from IPL without asset reload, records its second
entry in retained RAM and completes another 256 exact pairs/grants. The CPU
checks status/address/count readback; read cases also compare every byte.
The images are checked again, and CPU FDC payload accesses must remain zero.
This requests reset while DMA is waiting for a disk/host transaction, not an
owned pair; owned read/write drain is covered by the earlier separate fixture.
It does not cover metadata writes, released-short-reset retry or physical HPS.

`test_machine_dma_video.py` also passes on both frozen fast and delay-aware v11
runners above, at the original **8,000,000 reference cycles per case**:

| Target | Executed checks |
|---|---|
| GRAM | 576 read/write pairs / 36 genuine continuous grants; both CPU-access pages, all three planes, starts at 0/1FFF/3FF0, 16-byte spans, opposite-page guards and source-counter wrap at FFFF |
| Selected PCG | 96 pairs / 6 genuine continuous grants; three independent paired sixteen-row planes, real synchronized WAIT/HSYNC-window transactions and post-transfer plane isolation |

CPU-generated Force Ready paces these continuous video transfers. The CPU
checks each transfer's terminal/address/count registers and every returned
RAM byte; a stale destination sentinel cannot satisfy the checks. Exact native
ASIC/scanline timing, PCG reset/CDC signoff, DAM and hardware bandwidth remain
open. Pin-level single-write semantics remain qualified by the existing PCG
fixtures, not by a duplicate-side-effect counter in this new runner.

```sh
make -C verilator test-machine-dma-sd-reset HEADLESS_DIR=obj_dir_v11_units
python3 verilator/tests/test_machine_dma_video.py verilator/obj_dir_turbo_dma/Vtop
python3 verilator/tests/test_machine_dma_video.py verilator/obj_dir_v11_dma_fast/Vtop
```

Logs: `/tmp/x1-machine-dma-sd-reset4.log`,
`/tmp/x1-machine-dma-video-delay.log`, `/tmp/x1-machine-dma-video-fast2.log`.
Earlier failed fixture-construction logs are retained: the initial SD fixture
exceeded its mistakenly chosen 4 KiB ROM buffer, then sampled combinational
reset before settling; the first video emitter failed to mask the wrapped
16-bit counter's high byte. Correcting those fixture errors did not change
machine behavior or relax the runtime payload/count/transport assertions.
Inherited machine warnings remain; the new SD fixture adds no suppressions.
These whole-machine checks are not part of the standalone asset-free CI gate.

## October 6 reset-extension checkpoint

The full delay-aware base `make test` completes with exit 0 in
`/tmp/x1-oct6-base-regression.log`, including the video matrix, peripherals,
complete generated disk/metadata matrix and final motor/index units. The
baseline runner SHA-256 is
`17d3dcff8d9cf523084ea2f0e196a8e48668fbb07e49fa1a53f15fd50025352e`.
SYS is 32 MHz, video 28.571428 MHz; this is not X3/Turbo or hardware evidence.

The reset extension passes **64 cases** on the shared opt-in v11 machine:
eight held payload requests, eight 2 ns raw pulses, sixteen single-block
first-header-read/published-metadata-write cases, and thirty-two split-header
cases (A/B, before/mid-ACK, held/pulsed, first/second read/write).
Generated write media now starts deleted with
data-CRC B0. Whole-image checks distinguish an aborted header read retaining
those fields from a published metadata write committing their repair.
After drain, the same CPU program reboots without loader/debug injection and
completes 256 fresh pairs with native status/count/readback assertions.

The pulse ends before the next SYS edge; the guard must retain it. Following a
drive-B pulse, the reset drive latch returns to A and its queued scanner may
legitimately publish a new request. The fixture checks the **old falling ACK**
clears busy, and old owner/LBA remain stable throughout the held ACK, before
accepting only that explicit A rescan. It does not require indefinite global
idle after the original request drains. The overbroad prior assertion failed
in `/tmp/x1-machine-dma-sd-expanded.log`; no machine fix or bypass was needed.
The corrected 32-case run completes in `/tmp/x1-machine-dma-sd-expanded2.log`.
The isolated final **64-case** run completes with exit 0 in
`/tmp/x1-machine-dma-sd-final.log`. Its executable SHA-256 is
`3fc214c1271d133b6e6ccf80bbb88993253c20e7da43ddbfb7693ecadf59c2aa`.
The split fixture places the header at byte 1016, so deleted mark byte 1023
and CRC status byte 1024 occupy different 512-byte blocks. Reset after a
published first metadata write or during the second read must preserve the
committed normal mark while retaining B0. An accepted second metadata write
may commit the CRC repair. Both full generated images, padding and neighboring
bytes are checked before fresh retry and after completion; later retry cannot
hide a wrong intermediate image. This checks publication bytes, not physical
HPS epochs or every cached-index/remount/command-retry behavior.

Five actual-machine PCG reset profiles also pass: source read, destination
write, physically stopped SYS, blocked asset reload, and a granted PCG write
with video physically stopped for **80 running SYS edges**. A retained 2 ns
request keeps the real CPU ACK/address/data stable and CPU execution stopped.
Video restart drains exactly one write; only then does machine reset occur.
After the original program reboots, it completes the sixteen-row plane with
**17 actual video-domain write edges**, matching the first drained pair plus
16 fresh DMA pairs and two grants. No substituted grant, PCG RAM patch or
WAIT forcing is used. The earlier four RAM reset profiles pass unchanged.
Log: `/tmp/x1-machine-dma-pcg-reset2.log`.

```sh
make -C verilator test-machine-dma-sd-reset test-machine-dma-sd-short-reset \
  test-machine-dma-metadata-reset test-machine-dma-split-metadata-reset \
  HEADLESS_DIR=obj_dir_v11_reset_qualification
make -C verilator test-machine-dma-reset test-machine-dma-pcg-reset \
  HEADLESS_DIR=obj_dir_v11_units
```

These are bounded functional reset tests, not exact ASIC/CDC or fitted timing.
Partial CPU payload/Ready loss, further PCG phases, DAM and native firmware still
need further acceptance; remote Quartus/MiSTer remain unavailable.

### Expanded CI compiler qualification

The earlier 16-target hosted gate passed on `0e4e021` and `7e2015f`.
Adding the original DMA register/CPU units and idle Send Break expands the
configured gate to 19 targets; its hosted terminal pass is still pending.
The two unbounded expanded runs were canceled, not counted as failures of RTL
or passes. Their final logs show Ubuntu GCC 13.3 / Verilator 5.020 still
compiling the large DMA fixture coroutine at `-O1`, rather than executing it.
The superseding workflow bounds targets, with extra time for the full-length
DMA unit, and uses `DMA_TEST_CFLAGS=-O0` there. The local default remains `-O1`.
No assertion, emulated clock, reference duration or large/wrap case is removed.
The local O0 build/run also passes all **32 groups / 5,955,942 clock edges**,
including 256/65,536/65,537 transfers at CE=1/4; log
`/tmp/x1-dma-ci-o0-local.log`. This does not by itself establish hosted compiler
acceptance; inspect the new CI result before promoting all 19 targets.
