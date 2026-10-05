# CPU-executed standalone DMA bus diagnostic

October 5, 2026. Only `verilator/tests/dma_cpu_tb.sv` and this document belong
to this increment. **No shared machine, QIP, Makefile, CPU or DMA RTL edits.**
This is a functional unit harness, not a stub wired into the X1 machine or
acceptance of native IPL, FDC, Turbo, timing, Quartus or hardware behavior.

## Design and acceptance plan

The plan was stated before implementation: use the actual `rtl/cpu.v` wrapper
and active TV80 dependencies, the frozen `rtl/x1_dma.sv`, one ACK-selected
owner mux, clocked RAM and a functional I/O target. An original CPU-executed
ROM programs the stream and verifies memory/I/O payloads, primary counter
readback and continuation. Run CE=1/4/7 with WAIT-stretched transactions;
verify no pre-grant DMA strobes or CPU side effects while granted, then
exercise reset during both pending read and write and let the real CPU restart.

The eighteen acceptance-gated/raw-register-CS × CE=1/4/7 × normal/read-reset/
write-reset cases pass on the final fixture. Parent reproduced them through
`make -C verilator test-dma-cpu HEADLESS_DIR=obj_dir_v06_units`;
`/tmp/x1-v06-dma-cpu-final.log` records all terminal results. The raw variant
holds selection throughout the real CPU's WAIT-stretched OUT and deliberately
requests ownership before that OUT finishes; grant still waits for completion.

The wrapper's historical `mreq`, `iorq`, `rd`, `wr`, `m1` outputs are all
active-low. `.cep(cpu_ce)` advances TV80; `.cen(1'b0)` deliberately does not.
Request and grant are active-low, directly wired between the actual CPU and
DMA. No forced ACK or internal register/PC assignment is used. TV80 Mode=0,
T2Write=1, IOWait=1; refresh is not enabled. The original ROM begins at reset
address zero, disables interrupts and sets SP=C000. The fixture protects its
ROM aperture against bus writes.

## CPU program and target contract

The ROM is emitted by small original instruction helpers, not copied IPL
tables or game bytes. It initializes its RAM source and destination sentinels
through Z80 writes. The testbench initializes only the original ROM and empty
synthetic RAM before cold reset, not game state or debug execution. Read-only
hierarchical observations support assertion diagnostics, never stimulus.

| Address / target | Functional fixture role |
|---|---|
| `1F80..1F8F` | One DMA stream; the ROM alternates `1F80`/`1F8F` for writes. Low address bits do not select a register. |
| `8000..8007` | CPU-written memory source: original byte pattern `31 + 13*i`. |
| `8200..8207` | CPU-initialized destination; DMA receives original FIFO pattern `B0 + 7*i`. |
| `9000..9035` | CPU-stored six-byte count/A/B readback after each of four blocks. |
| `8FF0` | CPU-written retained warm-reset marker, not a testbench patch. |
| `9040..9045` | CPU-stored all-zero DMA counter readback after hardware reset. |
| I/O low byte `20` | CPU arms a target stage/Ready gap. |
| I/O `21` | CPU result: A5 success, E1 assertion failure, followed by HALT. |
| I/O `22` / `23` | Target event count / CPU readback of captured transmit FIFO. |
| I/O `24` | Reset scenario selector, read by the original CPU program. |
| I/O `25` / `26` | CPU observes drained reset-pair count and payload. |
| I/O `0040` / `0041` | DMA FIFO source / sink, respectively. Other target low-byte decodes are fixture aliases, **not X1 port-map claims**. |

Each normal run performs four four-byte blocks:

1. A=incrementing memory source, B=fixed I/O sink. Program nonzero N=3,
   active-high Ready and WAIT, temporarily declare B source and LOAD, then
   true A source and LOAD. ENABLE is last. The real CPU polls the separate
   functional target count, not DMA control/status while a block is running.
2. CPU reads count/A/B, issues CONTINUE and ENABLE, and transfers the next
   four memory bytes to the same fixed sink. It reads all eight captured bytes
   back through I/O and compares each, detecting duplicate/lost boundary data.
3. B=fixed I/O source, A=incrementing memory destination, active-low Ready.
   LOAD/ENABLE transfer four FIFO bytes; the CPU verifies count and addresses.
4. CONTINUE transfers the next four into consecutive memory. The CPU checks
   all eight received RAM bytes and masked EOB status.

The CPU verifies primary stopped count=3, source-next A=8004 then 8008,
fixed B=0041, and opposite-direction destination-last A=8203 then 8207,
fixed B=0040. A7/RR1..RR6 results must match; register reads remain stable
through a held CPU transaction. Undefined status bits are masked by 3B; final
defined status is 19 because the functional target holds pin Ready inactive
after its quota. CONTINUE must preserve live addresses and not duplicate the
last destination. No special-zero/search/IRQ/timing test is newly claimed here;
see the [separate standalone DMA slice](DMA_STATUS.md).

The owner mux selects DMA only on actual CPU ACK=0. RAM/I/O responses latch
on clocked request capture. Target acceptance waits four enabled intervals;
one accepted edge per held strobe performs the memory write or FIFO side
effect. A read response remains stable even when that accepted edge advances
the FIFO. Ready is level-paced, with 12-enabled-edge startup and 22-edge
inter-byte gaps. CPU and DMA WAIT are routed separately to the selected owner.
This deliberately exercises stretches; it is not an FDC or exact Z80 pin
timing model. Normal byte transfers release real CPU ACK after every pair.

## Interface dependencies and reset policy

No change to `x1_dma.sv` was needed for the first CPU-connected cases.
The fixture makes integration assumptions explicit:

- A clocked RAM response must be valid before either master samples it;
  WAIT is required for this fixture's request/response latency. Feeding stale
  synchronous RAM data as if it were an asynchronous read is invalid.
- DMA register read data is latched on its first enabled selected edge. The
  bridge selects reads **during CPU WAIT**, then allows CPU sampling once
  that response settles. Gating read selection until the very sampling edge
  cannot be assumed safe. A separate CE=1 normal case with raw read CS,
  direct DMA output and no added register-read WAIT also passes: this TV80
  configuration gives the output time to settle before its sample. An
  unfinished negative test had incorrectly expected that case to fail; its
  observed A5 result/count=3 was used to correct the fixture, not invent a
  stale-read defect. This does not qualify arbitrary latencies or profiles.
  Writes are tested both at the
  accepted edge and with raw held CS; neither allows CPU grant before its
  WAIT-stalled machine cycle finishes.
- A FIFO must retain the completed read value until DMA has sampled it.
  The functional target latches it; immediately exposing the next FIFO item
  on a consume edge would violate the data interface.
- Target side effects occur once, not on every enabled edge while strobes
  remain low. A shared-machine owner mux must also preserve real memory/I/O
  decode, overlays, banking, RAM-under-ROM and PCG/DAM side effects.
- **Immediate CPU reset while DMA owns a pending cycle is unsafe with direct
  ACK wiring.** TV80 reset asynchronously revokes ACK independently of CE;
  the DMA requires ACK throughout its pair and gates strobes with it. A
  machine reset sequencer must keep grant intact until DMA drains, or implement
  an explicitly reviewed retained-owner/ACK bridge while holding CPU reset.
  Simply connecting simultaneous CPU/DMA reset is not qualified by this test.

For read-reset and write-reset cases, the real CPU first completes and checks
all four normal blocks, writes its retained marker, programs another block
and enters a real grant. The controller holds DMA WAIT and stops both enables
for 20 master edges. It requests DMA reset while keeping the CPU's real ACK
intact; eight stopped edges and twelve DMA-only edges must retain bus, counts
and ownership. DMA counter/phase state is additionally checked during CE stop
(excluding the independently sampled reset-pending flag).

Then WAIT is released and DMA alone advances to drain the one started pair.
Only after request/strobes release does the controller reset the CPU. RAM and
target logs remain retained. The restarted ROM observes one committed sink
write and its first source byte, reads reset DMA counters as zero, emits A5
and HALTs. Reset may therefore commit an already-started write; it is **not
rollback**. Permanently stopped CE/WAIT retains ownership indefinitely. This
fixture supplies a drain-enable override; real machine reset that stops DMA CE
must provide equivalent progress or a separately designed cancellation policy.

## Reproduce and remaining gates

Use the installed Verilator timing runtime and C++20 compiler, from repo root:

```sh
verilator --binary --timing -j 2 -CFLAGS -O1 \
  --top-module dma_cpu_tb --Mdir /tmp/x1-dma-cpu-unit -Wno-fatal \
  verilator/tests/dma_cpu_tb.sv rtl/x1_dma.sv rtl/cpu.v \
  rtl/tv80/tv80e.v rtl/tv80/tv80_core.v rtl/tv80/tv80_mcode.v \
  rtl/tv80/tv80_alu.v rtl/tv80/tv80_reg.v
/tmp/x1-dma-cpu-unit/Vdma_cpu_tb
```

Keep `--timing` to retain inherited TV80 1ps assignments. The generated master
is 100 MHz solely for this unit; CE=1/4/7 checks are not fitted X1 clock rates
or a fractional divider. The existing missing `tv80_reg.DIRSET` pin remains
visible as PINMISSING; that input is unused in the inspected dependency.
`-Wno-fatal` accommodates the inherited warning, not a source suppression or
dependency fix. No new warning is intended to be hidden by it.

Real FDC DRQ/WAIT integration, generated D88 reads/writes, CRC/protection,
SD ACK/drive/eject ownership, IPL-overlay/shared memory decoding, authentic
Turbo firmware, interrupts and physical reset/CDC/timing remain separate
acceptance gates. No game/private asset, machine integration, Quartus or
hardware run belongs to this increment.

The registered target additionally runs `+direct-register-read` with the
same real CPU and original ROM; it is a positive bounded latency check,
not a silicon-negative test. Both paths retain payload/counter/ownership
assertions. No DMA RTL change was needed.
