# Sharp X1 chip implementation summary

Updated: 2026-10-05. Native IPL/D88 boot and playable CROSS Chase are verified
in simulation, together with focused CPU, memory, graphics, keyboard/IRQ and
PSG tests. MiSTer and simulation both use `rtl/sharpx1.v`; the board wrapper
wires the exposed interfaces and passes lint with warnings, not hardware validation.
The legacy column describes reference RTL only.
See [bring-up progress](BRINGUP_PROGRESS.md) for the timing/reset and shared-source
changes and runtime evidence.

| Chip / subsystem | Shared MiSTer/simulator path | Legacy reference path |
| --- | --- | --- |
| Z80 CPU | TV80; fetch/memory diagnostic passes | FZ80 present |
| IPL and main RAM | Base 4 KiB/64 KiB; experimental Turbo 32 KiB IPL; overlay, patterns and loader bounds tested | External interfaces; broken historical simulation memory |
| 80C49 functions | MR16; E7/E8, PS/2 ASCII, cold/steady IM1 IRQ and game movement tested; receive-only profile fixes cold command turnaround; one-clock timer compensated, instruction rate differs; full command set incomplete | Partial MR16 replacement |
| 8255 PPI | Mode-0 reset/directions/latches/split C/BSR tested; other modes/printer/cassette incomplete | Partial; handshake limitations |
| 6845-family CRTC | Base 40/80 text and 320/640×200 pixel/period fixtures verified; exact native waits/ROM/hardware pending | Present |
| Text/attribute RAM | Two connected 2 KiB dual-clock banks | Present |
| Character ROM and PCG | Base font/PCG and CDC WAIT tested; optional 16-row ANK loader/pixels and ordinary/paired high-scan PCG address unit added; CPU font selection/high-speed PCG and physical timing pending | Present |
| Graphics RAM/palette | Base three 16 KiB planes; opt-in Turbo two pages/plane (96 KiB); CPU/DAM and actual page/blackclip RGB tested; full-RA low/repeated/even-odd address mapper added; authentic high-scan clocks pending | Partial |
| AY/YM PSG | JT49; three tones/mute, deterministic noise, all envelope shapes/period scaling tested; full fidelity/hardware pending | Present; audio output incomplete |
| Joystick ports | Both PSG inputs tested; MiSTer bit order corrected and 64 combinations verified; hardware pending | Partial |
| Z80 CTC | Opt-in Turbo: CE-based four-channel timers/counters, vectors, priority/service and RETI connected; CPU IM2/keyboard coexistence and stretched ACK tested; exact pin timing/ASIC aliases/hardware pending | Present |
| Z80 DMA | Standalone 32 groups and actual CPU/DMA 18 cases pass; separate opt-in shared-machine CPU ownership/FDC DRQ, generated A/B reads/writes/protection/CRC and owned reset now pass; native IRQ/search/exact timing and hardware remain open | Partial, opt-in shared-machine subset |
| Z80 SIO | Shared-machine device still missing; standalone two-channel 108-format/FIFO/collision tests and separate RX/TX IRQ nested service/held ACK/actual-CPU IM2 pass at CE=1/4/7; first-character/external IRQs, x1/break/WAIT/Ready/full arbitration/integration pending | Stub |
| MB8877 floppy controller | WD1793-family D88 engine; A/B read/write/protection and owner-drain tests. ID/data CRC, C/S and 75 deleted/CRC metadata/reset-drain groups pass directly. Full-machine metadata matrix, exact mechanics/format/errors and hardware remain open; see [metadata status](D88_WRITE_METADATA_STATUS.md) | Partial firmware emulation |
| Disk-image backend | D88 host preflight plus shared-RTL bounds/invalid not-ready and pending-read replacement/eject/reset quarantine tested; copy-only writes verified; physical faults/permanent stalls pending | Missing from historical harness |
| RTC | Partial firmware state | Partial firmware state |
| Cassette/APSS | Missing | Command-state stub |
| Kanji | Experimental 2 KiB KVRAM storage tested; glyph ROM/readback/rendering missing | Fake register |
| Turbo display modes | SCRN pages/blackclip/raster and nominal X3/ANK tested; bounded high-speed PCG/CPU ANK selection passes original unit/CPU tests. Kanji, expansion/underline, exact ASIC/WAIT/switching and hardware remain open; see [PCG status](TURBO_HIGH_SPEED_PCG_STATUS.md) | Partial |
| Turbo Z / YM2151 / expansion devices | Unimplemented; manual-based [Turbo Z roadmap](TURBO_Z_PLAN.md) covers model identification, analog graphics, FM/HD disks and capture peripherals | Missing or stubbed |

See [the detailed survey](CORE_STATUS.md) for evidence and
[replacement chip candidates](CHIP_REUSE.md) for sources pulled from other
cores. Downloading replacement RTL does not change the implementation status
above until it is connected and tested.
See [Turbo foundation evidence and exclusions](TURBO_STATUS.md) and
[disk safety coverage](DISK_STATUS.md). The opt-in profile is not complete
Turbo support, and historic game/hardware checkpoints do not validate new RTL.
