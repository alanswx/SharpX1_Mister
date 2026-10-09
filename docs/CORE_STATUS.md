# Sharp X1 hardware implementation survey

Survey date: 2026-10-02. The original source/wiring audit below had no functional
boot evidence. Subsequent bring-up now verifies native CROSS Chase boot and
gameplay in simulation. Subsequent bounded base-video/native-input and optional
DMA hardware checks are recorded in [the hardware matrix](HARDWARE_VIDEO_MATRIX_STATUS.md)
and [DMA qualification](DMA_BOARD_BUILD_STATUS.md); they are not full hardware
signoff. Use the updated chip table
for current status, not the historical defect descriptions below.

The original audit below predates the first implementation increment. See
[bring-up progress](BRINGUP_PROGRESS.md): simulation now uses the MiSTer machine,
timing advances, the shared divider/reset polarities are corrected, and the
source manifest and secondary-clock/pixel-enable connections are repaired.
The table and confirmed-defect list below are retained as a **historical
pre-implementation audit**, not the current status. Bus polarity, overlay,
loader qualification, main RAM and sub-CPU work RAM have since been repaired
and tested. The renderer, VRAM/font, PPI, PSG and WD1793-family controller are
now connected. See the [updated chip table](CHIP_IMPLEMENTATION_TABLE.md) and
[base-machine contract](BASE_X1_CONTRACT.md) for current implementation status;
historical `sim.v` SRAM defects describe the removed legacy wrapper.

## Which machine are we surveying?

The FPGA wrapper `sharpx1.sv` instantiates `rtl/sharpx1.v` (the **MiSTer path**).
The simulation wrapper `verilator/sim.v` now instantiates the same machine.
`rtl/sharpx1_legacy.v` remains the **legacy reference path**. A module present in the legacy
machine is not thereby implemented in the machine built for MiSTer.

**Present** means RTL is instantiated; **partial** means recognizable behavior
exists but has gaps or disconnected interfaces; **absent** means no functional
instance exists in that path. These categories describe implementation, not
compatibility certification. Chip names cover the base X1 and selected Turbo
hardware; exact packages and memory sizes vary by model.

## Chips and major subsystems

| Chip / part | MiSTer path | Legacy path | Evidence and remaining work |
| --- | --- | --- | --- |
| Z80A main CPU | Present, bus integration broken | Present, FZ80 selected | `rtl/cpu.v` instantiates TV80; legacy instantiates FZ80. Reset polarity is corrected; newer logic still treats active-low bus outputs as positive strobes. |
| IPL ROM and ROM/RAM overlay | Partial | Partial, external memory plus monitor ROM | Newer IPL is an 8 KiB DPRAM despite the 4 KiB comment; ioctl writes are not qualified by image index/download. Mode input to decoder is open, and RAM wins the read mux over IPL. Legacy uses external IPL bus and `noicez80`/`bootrom`. |
| 64 KiB main RAM (DRAM equivalent) | Present, bus writes incomplete | External interface present, sim model broken | Newer write enables have no idle defaults. Legacy delegates memory to its external CPU bus. `sim.v` SRAM signals have implicit one-bit widths and its RAM write enable is connected to an address bus. |
| Address decode / bus glue | Partial | Present | `rtl/x1_adec.v` has many device selects. Newer RD/WR, IPL-select and simultaneous-access inputs are open; three RGB-plane select outputs drive the same `gram_cs` net. Decode alone is not a device implementation. |
| 80C49 sub-CPU and keyboard MCU functions | Partial MR16 replacement | Partial MR16 replacement | `rtl/sub_cpu.v` uses `mr16_x1`/`mr16core`, not an 8049 CPU implementation. Firmware includes keyboard and host commands. Newer PS/2, handshake, interrupts and several DMA/FDC inputs are disconnected. Separate original keyboard MCU execution is absent. |
| Sub-CPU work RAM | Present, incorrect width/wiring | Same broken shared module | `rtl/sub_cpu.v:353` replaces 16-bit RAM with `dpram #(8,10)`, truncates word data and feeds `h_wram_rd` back as host write data rather than `h_wram_wd`. This can corrupt firmware-visible communication in both paths. |
| 8255 PPI, system ports | Absent | Partial | `PIA8255` is instantiated only in the legacy machine. It has port direction/control/bit operations; the source explicitly says handshake modes are unsupported. Printer and cassette inputs are constants. |
| Host/sub-CPU PPI handshake functions | Partial | Present in replacement logic | Busy flags and mailboxes are implemented by `x1_sub`; they are not a second general-purpose 8255 instance. Much of their newer integration is open. |
| HD46505 / MC6845-family CRTC | Absent | Present, unverified | `rtl/legacy/x1_vid.v:187` instantiates `crtc6845s`; no video controller instance exists in `rtl/sharpx1.v`. |
| Text and attribute VRAM | Allocation only; not functional | Present | Newer single VRAM block has no working CPU/video wiring. Legacy `text_ram` and `att_ram` are separate dual-port 2 KiB blocks. |
| ANK character generator ROM | Absent from machine | Present | Legacy instantiates the 2 KiB `x1_cg8` font table attributed to X Millennium. No instance in newer machine. |
| PCG RAM (three color planes, 6 KiB) | Absent as PCG behavior | Present, unverified | Legacy has three 2 KiB PCG RAMs plus `pcg_wait`. The newer block named `PSGRAM` is selected by PSG ports and is not a programmable character generator implementation. |
| GRAM, RGB planes and palette/mixing glue | Allocation only; not functional | Partial | Newer GRAM is one 64 KiB block, with no video read path or plane semantics. Legacy combines external plane data with text/PCG and palette logic in `x1_vid`; external backing storage must work first. |
| X1 simultaneous multi-plane writes | Absent from connected logic | Present mode/decode logic | Legacy `x1_mode` controls DAM from PPI; newer decoder DAM input is open. Verify write/read-clear transitions and memory arbitration. |
| AY-3-8910 / YM2149-compatible PSG functions | Absent | Present, output integration incomplete | Legacy instantiates `ay8910`, mixes channels and seek PCM into `PCM_L/R`. Newer maps PSG accesses to RAM. Simulation AUDIO outputs are not wired to the legacy PCM output. |
| Joystick ports | Absent | Partial | Legacy PSG input ports use firmware joystick emulation and an external-input mux. Physical and PS/2 inputs in `sim.v` are undriven implicit nets; MiSTer input delivery is absent. |
| Z80 CTC (Turbo) | Absent | Present, unverified | Legacy instantiates `z80ctc` and connects interrupt/RETI logic. Newer decoder definitions do not connect a CTC. |
| Z80 DMA (Turbo) | Partial disconnected replacement | Partial firmware replacement | DMA operations are implemented through MR16 GPIO and `z80dma.asm`, not a standalone DMA chip. Legacy connects bus request/acknowledge and refresh arbitration; newer leaves bus-request/ack inputs and `dma_sel` integration incomplete. |
| Z80 SIO (Turbo) | Absent | Stub | Legacy forces SIO IRQ inactive and `sio_doe=0`; `sio_rd=0` is not serial-controller behavior. Debug UART is a different device. |
| MB8877A floppy controller | Partial firmware scaffolding | Partial firmware emulation | `mb8877a.asm`, `fdd_emu.asm` and `x1_sub` expose FDC registers/status/DRQ. No standalone MB8877 RTL. Existing source notes identify command limitations. No MiSTer disk-image backend is connected. |
| Floppy drives / media backend | Absent | Original platform support only | Firmware references original disk-image mechanisms, but current MiSTer and simulation wrappers do not supply working media. A DSK OSD entry does not implement a disk interface. |
| uPD1990 RTC functions | Partial firmware command state | Partial firmware command state | Firmware has calendar/time storage and EC–EF commands, plus timer code. No uPD1990 serial device RTL or MiSTer clock synchronization; do not claim battery-backed clock or full calendar compatibility. |
| Cassette deck and tape signal path | Absent | Stub/partial command state | Firmware stores transport commands and status; legacy `cmt_read=0`. There is no connected tape decoder, recorder, transport or APSS implementation. |
| TV control / remote | Absent | Command-state stub | Firmware E7/E8 state is present; no functional tuner/remote model or connected output. |
| Printer / Centronics | Absent | Partial PPI outputs | Legacy has data/strobe signals, but ready input is constant and no printer endpoint exists. |
| Kanji ROM and Turbo Kanji VRAM | Absent | Stub | `FAKE_KANJI_VRAM` is enabled; writes update one fake register. Kanji-ROM select exists without a ROM/readback implementation; video Kanji data is not supplied by a real font path. |
| Turbo 400-line / display mode registers | Absent | Partial | `x1t_mode` and `x1_vid` accept mode flags. Their presence is not verified 400-line or full Turbo video compatibility. |
| Turbo Z analog/4096-color extensions | Absent | Absent as a complete implementation | `X1TURBOZ` is disabled and labelled future in the legacy top. Existing conditional code must be audited before enabling it. |
| Optional YM2151 FM board | Absent | Disabled stub | `FM_BOARD` is disabled; conditional implementation only returns dummy status `8'h03`. No FM synthesizer instance. |
| EMM / expansion RAM, SASI HDD, 8-inch floppy | Absent | Decode only | Decoder chip selects do not terminate in working expansion devices/backends. Optional features, not prerequisites for a base X1 target. |
| SPI/MMC / configuration-ROM interface | Absent | Present original-platform glue | Legacy shift-register SPI signals are implemented at the external-ROM port. The simulation ties MMC input low; this is not a MiSTer storage adapter or an original X1 chipset feature. |
| Video scan doubler / NTSC encoder | Absent from newer machine | Scan doubler present; NTSC conditional | Legacy uses `dbl_scan`; `NTSC_S2` is disabled. MiSTer should receive correct pixel enable, sync, blanking and RGB first. |
| MiSTer board framework / HPS / PLL | Present, core integration incomplete | Not the legacy platform | Secondary machine clock and pixel-enable are connected; template OSD remains. PLL video frequency is 28.571428 MHz, not the commented 28.636 MHz; hardware validation remains open. |

## Highest-priority confirmed integration defects

1. **Main CPU bus polarity:** `rtl/cpu.v` exports TV80's `*_n` signals
   without inversion, but `rtl/sharpx1.v` negates them for decode and tests them
   as asserted-high read/write strobes. CPU/sub-CPU reset polarities have been
   corrected; bus integration still needs repair and functional tests.
2. **IPL unreachable through the read mux:** `O_RAM_CS=~I_MREQ_n` and
   `di = ram_cs ? ramDo : ipl_cs ? ...` prioritize RAM on ROM accesses.
   Decoder read/overlay inputs are also floating.
3. **Sub-CPU memory corruption:** the 16-bit work-RAM interface has been
   replaced by an 8-bit RAM with the wrong host write-data connection.
4. **No newer video device:** `HBlank`, `HSync`, `VBlank`, `VSync`, and `video`
   have no output-generating logic in the newer machine. MiSTer pixel-enable
   and secondary-clock pins are now connected, but not a working renderer.
5. **FPGA build unverified:** shared machine and PLL dependencies are now
   included. Quartus compilation, timing closure, and hardware boot remain open.
6. **Simulator has only timing/reset coverage:** it now tests the same top and
   advances time, but bus/peripheral wiring remains broken and no ROM is loaded.

## Validation and next decision

Verilator 5.044 successfully lint-elaborated the newer hierarchy when its
dependencies were explicitly supplied. Warnings confirmed sub-CPU RAM
truncation, IPL/address-width mismatches and multiple `gram_cs` drivers.
This survey does not modify RTL or fix the reported defects.

The initial target is base X1 and simulation now exercises the same machine
path as synthesis. Repair bus polarity, ROM overlay, RAM write strobes
and sub-CPU memory first; prove instruction fetch and host communication.
Then integrate the inherited CRTC/text/PCG/PSG implementations or suitable
replacements with behavioral tests. Storage and Turbo extensions follow once
the base machine is dependable.

For chip diagrams and model differences, start with the original X1 schematic,
then compare the Turbo and Turbo Z documents in the
[downloaded-document index](../references/manuals/README.md).
