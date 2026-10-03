# Sharp X1 chip implementation summary

Updated: 2026-10-03. Native IPL/D88 boot and playable CROSS Chase are verified
in simulation, together with focused CPU, memory, graphics, keyboard/IRQ and
PSG tests. MiSTer and simulation both use `rtl/sharpx1.v`; the board wrapper
wires the exposed interfaces and passes lint with warnings, not hardware validation.
The legacy column describes reference RTL only.
See [bring-up progress](BRINGUP_PROGRESS.md) for the timing/reset and shared-source
changes and runtime evidence.

| Chip / subsystem | Shared MiSTer/simulator path | Legacy reference path |
| --- | --- | --- |
| Z80 CPU | TV80; fetch/memory diagnostic passes | FZ80 present |
| IPL and main RAM | 4 KiB/64 KiB; overlay, patterns and loader bounds tested | External interfaces; broken historical simulation memory |
| 80C49 functions | MR16; E7/E8, PS/2 ASCII, IM1 make/break IRQ and game movement tested; full command set incomplete | Partial MR16 replacement |
| 8255 PPI | Mode-0 reset/directions/latches/split C/BSR tested; other modes/printer/cassette incomplete | Partial; handshake limitations |
| 6845-family CRTC | Native IPL/game 320×200 raster verified; other modes/timings pending | Present |
| Text/attribute RAM | Two connected 2 KiB dual-clock banks | Present |
| Character ROM and PCG | Font renders IPL/game; ANK/three-plane PCG reads/writes and CDC WAIT tested; exact scanline/Turbo timing pending | Present |
| Graphics RAM/palette | Three 16 KiB planes; individual/DAM-mask writes tested, game colors observed; full modes pending | Partial |
| AY/YM PSG | JT49; three tones/mute, deterministic noise, all envelope shapes/period scaling tested; full fidelity/hardware pending | Present; audio output incomplete |
| Joystick ports | Both PSG inputs tested; MiSTer bit order corrected and 64 combinations verified; hardware pending | Partial |
| Z80 CTC | Missing | Present |
| Z80 DMA | Disconnected scaffolding | Partial firmware emulation |
| Z80 SIO | Missing | Stub |
| MB8877 floppy controller | WD1793-family replacement boots one native D88 game; exact MB8877 timing/errors/writes pending | Partial firmware emulation |
| Disk-image backend | Read-only D88/512-byte simulator host verified; MiSTer HPS host wired/linted, hardware pending | Missing from historical harness |
| RTC | Partial firmware state | Partial firmware state |
| Cassette/APSS | Missing | Command-state stub |
| Kanji | Missing | Fake register |
| Turbo display modes | Missing | Partial |
| Turbo Z / YM2151 / expansion devices | Missing | Missing or stubbed |

See [the detailed survey](CORE_STATUS.md) for evidence and
[replacement chip candidates](CHIP_REUSE.md) for sources pulled from other
cores. Downloading replacement RTL does not change the implementation status
above until it is connected and tested.
