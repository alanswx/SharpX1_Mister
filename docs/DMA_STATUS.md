# Standalone Z80 DMA first slice

October 5, 2026. `rtl/x1_dma.sv` is an original, standalone functional
implementation. It is **not connected to the shared machine**, included in
`machine.qip`, or accepted as working Turbo/native-IPL DMA. The parent owns
subsequent CPU arbitration, machine/FDC integration and build-list changes.

## Contract and provenance

Primary: local [Zilog UM008101-0601](../references/manuals/Z80_CPU_Peripherals_UM0081.pdf),
SHA-256 `b4efc81540c05990883cf4c7792c2a3d49fb7471bb5502931383ab55b4540886`.
Read Table 11 and the programming/field/readback/loading sections, plus
the timing chapter's standard cycles, grant/release, Ready, WAIT and variable
timing limitations. [Hume's register audit](DMA_REGISTER_CONTRACT.md) is the
review contract, not a test result. Its primary/manual conflicts were
explicitly incorporated before implementation.

The existing sibling MAME `src/devices/machine/z80dma.cpp` and `.h` were
consulted read-only (checkout `f4bfc5a423f48d48e809c01fc70a47c0c00d40a2`).
Those sources credit Couriersud and carry BSD-3-Clause notices. This module
and fixture are newly written from the published interface; no MAME code or
firmware/game bytes were translated or copied. New files carry
GPL-2.0-or-later SPDX identifiers; this does not resolve inherited repository
licensing issues.

## Implemented functional interface

All pins are synchronous to `clk`; `ce` is an active-high advancement enable,
not the physical DMA chip-select pin. `cpu_cs` is active-high decoded selection;
`cpu_rd_n`/`cpu_wr_n` are active-low control transactions with separate input
and latched output data. Hold the transaction through an enabled edge and
provide an enabled inactive edge between transactions. Stretched transactions
are consumed exactly once. Read data is latched on the first enabled read
edge and remains stable through a held read; **physical two-edge CPU read
timing is not modeled**. Control reads disable operation in this functional
profile. Low address aliases belong in the eventual machine decoder, not here.

`busrq_n` is an active-low request and `busak_n` an active-low grant.
Only after two enabled ACK samples does the engine enter an owned pair.
Owned `mreq_n`/`iorq_n`/`rd_n`/`wr_n` are active-low. Integration must use
an owner mux, not electrical tri-state behavior, and retain ACK throughout
the requested ownership. ACK revocation during an active cycle is outside
the host contract. `address` and `data_out` are bundled bus outputs; `data_in`
is sampled at source completion. One host side effect is allowed per completed
strobe, **not once per clk while a strobe is held**.

Memory and I/O cycles hold active strobes for three/four enabled intervals,
respectively, with additional setup/inter-pair states. WR5 D4 selects WAIT
sampling; when enabled, active-low `wait_n` stalls completion. This is a
functional interface with deterministic latencies, **not standard T1/T2/T3
pin waveforms or a half-clock accurate NMOS/CMOS model**. No shortened-cycle
or early-termination timing is claimed.

| Function | First-slice policy |
|---|---|
| Stream grammar | WR0–WR6 identification and ordered associated bytes; nested WR4 pulse/vector bytes; every pending byte is data, including command-shaped values. |
| Transfer | Sequential transfer only, either A/B direction, memory or I/O on either port, increment/decrement/fixed addressing with 16-bit wrap. |
| LOAD | Source counter loads immediately. Variable destination loads on first pair; fixed destination retains its counter and requires temporary-source LOAD then true-source LOAD. LOAD disables and clears Force Ready. |
| Terminal length | Nonzero N transfers N+1 bytes. Primary special zero transfers **65,537**. A 17-bit remaining counter distinguishes this from 65,536. |
| Stopped readback | Byte counter N, variable source start ±(N+1), destination start ±N (last written address). Internal next-destination calculation avoids duplicating that boundary on CONTINUE. |
| CONTINUE | Restart count with current counters, not newly programmed starts. Requires ENABLE; clears Force Ready and end-of-block. |
| Ready | WR5 D3 selects physical active-high/low level. FORCE READY overrides pacing, not bus grant, and clears on LOAD/reset/A3/EOB/release. Byte mode without pin Ready consequently performs only one forced byte. |
| Ownership | Byte releases each pair and waits for ACK high; burst releases after a pair when Ready drops; continuous holds ownership but pauses new pairs until Ready returns. In-flight read/write pairs finish despite Ready loss. |
| Read stream | RR0–RR6, ascending mask order, repeated sequences, single-register repetition, BF/A7/BB. Zero mask deterministically reads RR0. Reserved mask D7 sets a diagnostic fault. |
| Status | Defined D0=request since LOAD; D1=physical Ready active (manual prose, **not MAME inversion or force-ready**); D3/D4=1 because IRQ/search are absent; D5=not EOB. Undefined bits 7/6/2 are zero, not a silicon guarantee. |
| Enables | Configuration, associated bytes, LOAD, CONTINUE, read commands and ordinary reads disable operation. 87 enables valid loaded transfers. WR3 D6 enables only with no associated-byte request and no unsupported configuration. |

## Safety and intentionally unsupported behavior

DISABLE prevents a new pair; an already-started source/destination pair drains
before release. Software RESET does likewise, then partially resets request,
count, timing, global IRQ enable, restart/WAIT and Force Ready; programmed
addresses/length, port/search modes, interrupt-control selection, Ready polarity
and read sequence are retained. For deterministic safety this slice abandons
the loaded block and requires LOAD after software RESET; it does not claim
silicon counter/pipeline retention or ENABLE-only resume after C3. Six C3
writes recover a maximum pending stream, without an out-of-band C3 parser
escape. Hardware `reset` clears the entire module once no pair is pending.
Hardware reset requests are retained on `clk` even when `ce` stops; bus
signals remain stable until CE resumes and any WAIT-stalled pair completes.
**An indefinitely stopped CE or WAIT holds ownership indefinitely**; this is
not an invented successful cancellation. Integration must provide a drain path.

A real CPU cannot program this peripheral while it has granted the bus. For
synthetic safety testing only, the separate register interface accepts 83/C3
while a pair/request is active. Other writes in that interval disable and set
a sticky diagnostic fault without changing the transfer configuration. Do not
wire a second bus master onto the owned bus to exercise this seam on hardware.

`unsupported` is a functional diagnostic, **not a Z80 DMA status bit**. ENABLE
is blocked for search/transfer-search, interrupt enable/control, pulse/vector
options, auto restart, prohibited ownership mode, timing follow-byte options,
B7/unknown commands or reserved read-mask bits. An unprogrammed/reserved WR0
class also asserts this diagnostic; it is not necessarily a sticky fault.
Follow bytes are still parsed
in their real order before that rejection. Timing-reset commands restore
standard timing acceptance. Software/hardware reset clears sticky command
faults; configuration faults must also be removed. AF/A3 can disable IRQ
configuration but no IRQ, daisy chain, IM2 vector, RETI, match or pulse engine
exists. WR3 D6 plus associated bytes is intentionally unsupported as an enable
shortcut: finish programming and issue 87. Timing-byte values are retained
for auditing, not executed approximately.

## Standalone verification

Original fixture: `verilator/tests/dma_tb.sv`, a synthetic bus host and control
stream. No CPU, native firmware, game assets or machine debug injection.
Two final-source standalone runs **pass 32 check groups**: 16 groups each
with CE every master edge and every fourth edge. The generated clock is
100 MHz with 1 ps simulation precision, not a claim about a fitted DMA clock.
It executes 5,955,942 master edges (59.55942 ms). The host delays real ACK,
retains ACK for three edges after release, and commits exactly one side effect
per completed bus strobe. There is a 25-million-edge watchdog.

Executed coverage:

- All 16 WR0 pointer subsets; command-shaped associated data; WR1/2 timing,
  WR3 mask/match, four WR4 nested pulse/vector selections; BB read mask;
  intervening reads do not consume the write queue; six-RESET recovery at
  every position in the maximum five-byte stream.
- Held register writes/reads; RR0–RR6 order/wrap/single-repeat; primary-prose
  Ready status versus Force Ready; LOAD source-only and retained software-reset
  read sequence. Unsupported search, IRQ, restart, mode, RETI and timing
  configurations cannot enable transfers.
- Eighteen direction/address combinations, both source and destination
  address event sequences, payloads, increment/decrement/fixed and 16-bit wrap;
  primary Table 11 stopped count/address readback.
- Both directions and every memory/I/O pairing; memory copy/CONTINUE with
  no duplicate boundary and no implicit reload of changed start registers;
  fixed-I/O destination two-LOAD sequence.
- N=1, 3, 255, 65535 and special zero. Large tests complete 256, 65,536 and
  **65,537** pairs and return the programmed terminal count. Large-count tests
  use fixed addresses; small-address tests independently exercise wrap.
- DRQ-like byte-mode level pacing with FIFO payloads, loss of Ready during
  read/write, active-low/high polarity, burst release, continuous paused
  ownership, loss of Ready before grant, and Force Ready clearing on release.
- No pre-ACK strobe, two enabled ACK samples, minimum three/four enabled
  memory/I/O strobe intervals, stable read/write WAIT and stopped-CE bus,
  hardware/software RESET and DISABLE at both stalled phases: exactly one
  started pair drains, with no restart. This is observable-bus coverage,
  not exhaustive verification of every internal register under CE stop.
- WR3 D6 enable exception, and directed concurrent control-write precedence:
  LOAD wins over a new request; DISABLE wins over a new owned pair.

Verilator 5.044 builds the two files only, with timing runtime and the installed
C++20 compiler. Final build: 158.250 s wall time. First final-source run:
30.784 s wall / 13.557 s CPU; repeat: 24.653 s wall / 13.568 s CPU. Both
return success with identical check-group and master-edge-count output.
Default lint and binary build have **no RTL
warning suppressions and no default warnings**. A separate strict `-Wall`
module-only audit returns 11 UNUSEDSIGNAL warnings for retained identification/
pointer fields, timing/match/pulse/vector bytes and unused helper argument
bits. These are intentional parsed-but-unimplemented fields; they are not
timing/search/IRQ implementations. Full-fixture `-Wall` additionally reports
testbench blocking procedural assignments and declaration initializations.
No warnings were suppressed in source. Whitespace checks include the three
new files explicitly (`git diff --no-index --check /dev/null FILE`).

Source-bound evidence:

| Input/artifact | SHA-256 |
|---|---|
| `rtl/x1_dma.sv` | `f82a77ec37c4183ad6d84be8beb847ca7fe7c082ba99896f6b8486f6a7f16645` |
| `verilator/tests/dma_tb.sv` | `be8c610fb1668a57c833e80910149f8d6372f2495917f5136ee231890937018c` |
| `/tmp/x1-dma-final-unit/Vdma_tb` | `c298fe5873c32a8b48c16c82b37275ef545ca8eab93483f3cb79aa769b7822c7` |
| Consulted Hume contract | `62b3712fc91f2f36efdb62a2671aad7cd6be98298a953b13c07a709c72077aff` |

Local generated logs: `/tmp/x1-dma-final-build.log` and
`/tmp/x1-dma-final-run.log`, plus `/tmp/x1-dma-final-repeat.log`.
Binary hashes are local provenance, not a portable
reproducibility guarantee. Earlier 26/30-group runs predate final assertions
or reset retention; only the source-bound 32-group result describes this slice.

From the repository root:

```sh
verilator --lint-only --timing --top-module dma_tb \
  verilator/tests/dma_tb.sv rtl/x1_dma.sv
verilator --binary --timing -j 2 -CFLAGS -O1 --top-module dma_tb \
  --Mdir /tmp/x1-dma-final-unit \
  verilator/tests/dma_tb.sv rtl/x1_dma.sv
/tmp/x1-dma-final-unit/Vdma_tb
git diff --check
```

## Next acceptance gates (not implemented)

Review this slice against the primary contract, then connect the actual CPU
BUSRQ/BUSACK seam through one shared owner mux with the existing memory/I/O
side effects and waits. Test original CPU programs, transfers under IPL,
RAM/GRAM/DAM/PCG behavior, and real FDC DRQ-paced generated-media transfers
including CRC/protection/abort/SD-ACK drain. Trace unchanged native Turbo IPL
register writes and data before any native DMA acceptance. Interrupt/search,
exact timing, physical arbitration/CDC/reset, Quartus and hardware checks
remain separate. No machine, Turbo, native software, synthesis or hardware
acceptance follows from the standalone fixture.
