# TV80 BUSRQ/BUSACK dependency audit

This is a focused CPU unit audit, not an implemented X1 DMA path. Only the new
`verilator/tests/cpu_busreq_tb.sv` and this document are part of this increment.
Verified October 5, 2026 through the actual `cpu.v` wrapper with standalone
Verilator 5.044 `--timing`: all 18 ownership cases and three no-request controls
pass. A second execution gives the identical 19-line PASS trace; both also
match the original direct-TV80 unit's trace. Build/run exit codes are zero; the only
reported build warning is the inherited PINMISSING described below.

## Active path and polarity

`rtl/cpu.v` instantiates `tv80e`, which instantiates `tv80_core`, `tv80_mcode`,
`tv80_alu` and `tv80_reg`. These are the same files listed in `rtl/machine.qip`.
The wrapper drives `tv80e.cen` from **`cep`**, not its separate `cen` input.
The parent has now added `busrq_n`, `busak_n` and `rfsh_n` ports to `cpu.v`.
The actual `rtl/sharpx1.v` instance still ties request to `1'b1` and leaves
acknowledge/refresh unused: the machine does not implement DMA ownership.

Both `busrq_n` and `busak_n` are active-low: request=0, grant=0. The wrapper's
plain-named `mreq`, `iorq`, `rd`, `wr`, `m1` also carry active-low TV80 signals.
Default parameters are Mode=0 (Z80), T2Write=1, IOWait=1; TV80_REFRESH is not
defined in this unit. `rfsh_n` therefore stays inactive here.

The core samples BUSRQ on enabled rising edges into `BusReq_s`, asserts grant
at `T_Res` after the current machine cycle, and does not advance that cycle
while T3 is held by WAIT. Architectural execution uses `cen && !BusAck`.
Release also requires enabled sampling; asynchronously asserted reset clears
grant independently of CE. These are implementation observations, not exact
physical-Z80 pin timing or metastability guarantees.

## Original regression

The inline, original 32-byte ROM starts at reset address zero and performs
memory write/read, increment, OUT/IN, sentinel writes, external-owner RAM
readback and HALT. There are no game/BIOS bytes, PC/register injection or
internal force operations. The input port returns `5C`; OUT must emit `36`.
The target model accepts each completed write once per asserted strobe, with
WAIT released and CE enabled, and verifies four memory writes plus one OUT.

Three deterministic enable periods (1, 4, 7 master edges) each run a no-request
control plus BUSRQ during WAIT-stretched opcode fetch, memory read/write and
I/O read/write. An additional memory-write case resets the granted CPU with
CE stopped: 18 ownership cases and three controls in total.

The unit now instantiates **the actual `cpu` wrapper** with `.clock(clk)`,
`.cep(cen)` and `.cen(1'b0)`, mapping its historical active-low output names.
Read-only observations use `dut.Z80CPU.*`. Only the DUT port mapping, hierarchy
and introductory comment changed; reversing these substitutions recovers the
original unit SHA exactly, proving all assertions, stimulus and periods remain
unchanged. The constant-zero secondary `cen` also catches an accidental swap
of the wrapper's real enable input.

Checks cover no grant or cycle/side-effect change while WAIT holds the cycle;
grant only at an enabled cycle boundary; completion of an in-flight write
exactly once before grant; inactive M1/MREQ/IORQ/RD/WR/refresh while granted;
no PC progress or target writes while an external owner holds the bus;
enable-stopped interface/PC/SP/ACC/F/machine-cycle/T-state/data-latch stability
and unsampled request/release; bounded release and normal ROM continuation;
and asynchronous reset/restart while granted. Read-only internal observations
support the boundary/stability assertions; the continuation and transfer
checks independently use external bus effects. A synthetic owner writes `C7`
to ordinary RAM only after grant; native CPU code later reads and stores it.
This is not a Z80 DMA implementation or a shared-machine bus-mux test.

Run from the repository root, without the shared Makefile:

```sh
cpu_busreq_build=$(mktemp -d /tmp/x1-cpu-busreq.XXXXXX)
verilator --binary --timing --top-module cpu_busreq_tb \
  --Mdir "$cpu_busreq_build" -Wno-fatal \
  verilator/tests/cpu_busreq_tb.sv rtl/cpu.v rtl/tv80/tv80e.v \
  rtl/tv80/tv80_core.v rtl/tv80/tv80_mcode.v \
  rtl/tv80/tv80_alu.v rtl/tv80/tv80_reg.v
"$cpu_busreq_build/Vcpu_busreq_tb"
```

Keep `--timing`: the test uses timed stimulus and retains the CPU's inherited
1ps assignment delays. The master clock is 100MHz solely for this unit;
cadences are functional CE checks, not X1 rate/fractional-divider validation.
The existing `tv80_core` omits `tv80_reg.DIRSET`; Verilator reports PINMISSING.
That register-module input is unused in the inspected source. `-Wno-fatal`
keeps the warning visible; no source suppression or TV80 dependency edit is made.

## Source identity and remaining gates

Parent's new wrapper seam is included; the five TV80 sources are unchanged.
SHA-256:

```text
rtl/cpu.v          1c29db19f60006dab1f2c947e920d16b3ae4cb5fb0c6e90e80753b0b70b74879
tv80e.v           d5efecac70701951fea6bf9a60bfba48f44b8fc05c51fd96b8718923995c9c02
tv80_core.v       fe7f95b061b2750121477dcb46154b7cc73b03b35d521007f67ad4e222a7d830
tv80_mcode.v      7d17d36ae8748c090621f0e46b570f1d0f1f30cd48096c482bb41a08965b75b5
tv80_alu.v        6e89303814fea0d6e7fd9a5388c9485322dd11879ac4c34e319ad1e5b6ce93c5
tv80_reg.v        3e1d2bd99693e397a87cf4d63aab244763d1990880ab82324672bc2833930e53
```

Test SHA-256: `31749d662b10f7244947669627c1859f80d02805e63e4fb30f942d671e7a266d`.
Original ROM SHA-256: `a9c7174067f5b18310897fb3d6daef2655b5eba845504766433bc0c6f35aa9dd`.
Executed binary: `/tmp/x1-cpu-wrapper-busreq-unit/Vcpu_busreq_tb`, SHA-256
`b56a42f890c3007d40de72df7b61bcf3d420c7c584c005294c0ff0117abd9960`.
Temporary build/run/repeat logs are
`/tmp/x1-cpu-wrapper-busreq-{build,run,repeat}.log`.
Only this unit/doc were edited by the sidecar; the parent owns the wrapper
and shared Makefile changes. Verilator's
two-state unit behavior is not an exhaustive uninitialized-state/X audit.

Machine arbitration wiring, shared-memory/I/O ownership muxes, peripheral
strobe gating, an actual DMA engine and FDC DRQ transfer tests remain required.
Address/data remain driven logic values in TV80 rather than physical tri-state
pins; an FPGA owner mux must use BUSACK explicitly. IRQ/NMI/HALT arbitration,
refresh-enabled behavior, request glitches/sub-cycle synchronizers, exhaustive
instruction timing, CDC, Quartus and physical hardware are outside this test.

The parent also added `make -C verilator test-cpu-busreq`, using the same
wrapper fixture and dependencies. The standalone command above remains useful
for an isolated build; neither command implements machine DMA arbitration.
