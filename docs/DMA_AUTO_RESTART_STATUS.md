# DMA automatic restart qualification

October 6, 2026. `rtl/x1_dma.sv` now implements WR5 D5 automatic restart
for its sequential-transfer engine, including the opt-in shared machine.
Default base/Turbo/X3/board profiles still keep DMA disabled. This is not
complete DMA, native firmware or hardware acceptance.

## Primary contract and implementation

Reread the existing local [Zilog UM008101-0601](https://www.zilog.com/docs/z80/um0081.pdf),
printed 60 (automatic repeat), 79–80 (interrupt/restart interaction),
103–105 (WR5 and reset), and 106–107 (LOAD/CONTINUE). The local MAME
`z80dma.cpp` automatic-restart completion was also inspected read-only;
no code or media was copied. [Existing source/manual provenance](DMA_STATUS.md).

At a completed terminal destination write, automatic restart reloads **both**
address counters from their programmed buffers, clears the byte counter,
reloads the block length and clears EOB. A variable destination's first write
uses its starting address again. A fixed destination also autoreloads its
buffer, unlike explicit LOAD's immediate-source-only workaround.
Programming new buffers between Byte-mode pairs does not change active
counters; the next restart uses the new buffers. These tests keep the
programmed terminal count unchanged during such buffer updates.

Byte ownership releases each pair. Burst releases on inactive Ready;
continuous holds ownership but pauses new pairs while Ready is inactive.
The existing Force Ready release policy is unchanged. DISABLE or a pending
software/hardware reset drains a started terminal pair but prevents restart.
No new clock, pin, module state field, CPU interrupt connection or artificial
host Ready/grant was added. Only the existing optional DMA engine changes;
snapshot layout remains v12. Regenerate affected diagnostic/native states
from boot; earlier source-bound evidence is not promoted to this profile.

IRQ/search/pulse/variable-cycle configurations remain explicitly rejected.
In particular, auto-restart plus interrupt programming is not an accepted
combination until genuine IP/IUS/vector/service behavior exists. Do not
claim Zilog pin-timing equivalence from functional bus latencies.

## Executed local checks

The first standalone run exits zero for 38 groups at CE=1/4, retaining all
original supported transfer/reset cases and replacing only the obsolete
auto-restart rejection assertion with positive restart tests.
Log `/tmp/x1-dma-autorestart.log`. An extended 40-group run additionally
checks large block boundaries and also exits zero: **40 groups, 11,942,192
master edges**, 119.42192 ms at the fixture's 100 MHz SYS clock, CE=1/4.
Verilator 5.044, host `-O0`; this is not physical DMA clock/timing acceptance.

- All 54 combinations of A/B source, increment/decrement/fixed addresses
  and Byte/continuous/Burst modes: three real two-byte blocks each, wrapped
  addresses, counter readback, cleared EOB and paused ownership.
- New source/destination buffers programmed between pairs without LOAD;
  active block uses old counters, next block uses new buffers. Fixed
  destination buffer updates are independently exercised.
- Terminal write stalls under WAIT; DISABLE, software RESET and stopped-CE
  hardware RESET each drain exactly the started pair without restarting.
- Extended fixtures complete 256, 65,536 and the primary special-zero
  **65,537** byte blocks, check automatic count/length reload and execute
  one genuine pair of the next block with correct address/count readback.

`test-machine-dma-restart` generates original ROM through the normal ioctl
loader and executes the actual shared Z80 with `TURBO=1,TURBO_DMA=1`.
CPU Force Ready permits one Byte-mode pair per real grant; the FDC Ready
pin stays inactive. Both directions execute three four-byte blocks, changing
buffers before the first terminal byte without LOAD. The CPU reads all six
counter bytes after every pair, verifies cleared EOB and actual RAM payloads,
then halts successfully after exactly twelve reads/writes/grants per direction.
No forced PC, bus grant or patched private firmware. Every invocation runs
the original eight million reference cycles (250 ms at SYS32 MHz).

The delay-aware shared-machine restart, seven original RAM/overlay/A/B
read/write/CRC/protection cases, four owned-reset cases and GRAM/PCG targets
all exit zero. `test-dma-cpu`, `test-sio-dma`, and `test-sio-dma-cpu` also
exit zero, including original grant/serial/error/IM2/reset cases.
The fast shared-machine restart, seven original machine cases and GRAM/PCG
targets also exit zero on the isolated `--no-timing` runner. Their functional
results agree with the delay-aware profile; fast ignores inherited delays.
The full base delay-aware regression remains running and is not inferred
from these focused DMA results.

| Evidence | SHA-256 |
|---|---|
| `rtl/x1_dma.sv` tested source | `34054eb6fe43a54497cc74ca6df369518d814ff5f849f4373338920a35c6fd41` |
| Delay-aware `obj_dir_v12_dma_restart_machine/Vtop` | `775a91c7c22c636895d73cb3fde148d1aebeab9711edc8af2c58e9b8632efd7d` |
| Extended `obj_dir_v12_dma_restart/dma/Vdma_tb` | `4865841360fadd210c6366dce329a7ddae7816e4eaf692215ab76e097f94e456` |
| Fast `obj_dir_v12_dma_restart_fast/Vtop` | `82f7b25cdf13764c0c10beb1e820a2bbe80280059e73b2c8335f78ea17cc6e3e` |

Logs: `/tmp/x1-dma-autorestart-2.log` (extended standalone),
`/tmp/x1-dma-autorestart-machine-2.log` (delay-aware machine),
`/tmp/x1-dma-autorestart-cpu-sio.log`,
`/tmp/x1-dma-autorestart-machine-fast.log`, `/tmp/x1-dma-autorestart-base.log`.
The first new CPU/machine test failure is preserved in
`/tmp/x1-dma-autorestart-machine.log`: it read RR1 after a six-register
sequence instead of selecting RR0 for the next status check. The program now
executes BF before each status read; no RTL behavior or assertion was weakened.

## Remaining acceptance

Native Turbo IPL/software continuity, physical Ready/bus phases, X3/single
profiles and current-source Quartus/CDC/reset/resource fit remain open.
This feature does not close work group 2 or imply working Turbo Z.
