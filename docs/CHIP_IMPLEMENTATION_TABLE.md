# Sharp X1 chip implementation summary

Updated: 2026-10-09. Native IPL/D88 boot and playable CROSS Chase are verified
in simulation, together with focused CPU, memory, graphics, keyboard/IRQ and
PSG tests. MiSTer and simulation both use `rtl/sharpx1.v`; the board wrapper
wires the exposed interfaces and passes lint with warnings. Bounded base video/
native input checks and a separate eighteen-case DMA restart hardware matrix
now pass on mister126; this is not full hardware validation.
The [fresh ordinary v15 baseline](BASELINE_V15_STATUS.md) passes the complete
delay-aware suite, and [five commercial games](COMMERCIAL_COMPATIBILITY.md)
pass fresh native fast-model gameplay/control tests. Neither qualification
enables or certifies the optional Z/serial/FM/Kanji profiles below.
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
| Z80 DMA | Opt-in shared completion/restart IRQ, CPU/FDC/video/reset/search and buffered-handler snapshots pass simulation; separate [single-clock hardware revision](DMA_BOARD_BUILD_STATUS.md) passes all-corner constrained fit, six memory and twelve A/B restart CPU diagnostics; mixed Ready/restart, broader concurrent/reset/savable, sequential non-Byte stop, variable timing, native/exact pin timing remain open; existing board defaults disabled | Partial MR16 firmware replacement, not the new standalone engine |
| Z80 SIO | Default-off [shared-machine functional increment](SIO_MACHINE_STATUS.md): generated IPL CPU/RX/WAIT/nested IM2/retained reset pass with DMA present/absent at ×16 and externally synchronized [×1](SIO_X1_STATUS.md), including partial-frame/blocked-IN reset; standalone formats/FIFO/IRQ/error/flow/idle Send Break, disable/resume, WR3 automatic modem gating, asynchronous RTS drain and 7,908 short/long/malformed TX cases remain qualified separately; ×1 fractional stop, native clock width/phase/pin CDC, remaining serial modes, mouse/native software, enabled snapshots and FPGA integration pending; board/C++ profiles off | Stub |
| MB8877 floppy controller | WD1793-family D88 engine; A/B read/write/protection and owner-drain tests. ID/data CRC, C/S and 75 metadata/reset-drain groups plus frozen fast/delay-aware CPU matrices pass. Protected native A/B boot and generated DMA reads pass hardware; native metadata, physical writes/mechanics/format and exact errors remain open; see [metadata status](D88_WRITE_METADATA_STATUS.md) | Partial firmware emulation |
| Disk-image backend | D88 host preflight plus shared-RTL bounds/invalid not-ready and pending-read replacement/eject/reset quarantine tested; copy-only writes verified; physical faults/permanent stalls pending | Missing from historical harness |
| RTC | Ordinary profiles retain static firmware state. Opt-in shared machine and non-savable runner pass actual Z80 EC..EF elapsed time and retained-IPL reset; bounded real memory-DMA drain/blocked-upload/stopped-SYS tests also pass. Native year/power, other targets/devices, enabled snapshots and hardware remain open. [Current evidence](RTC_MACHINE_STATUS.md) | Partial, opt-in running clock |
| Cassette/APSS | Default-off read-only SYS waveform/MR16/PPI diagnostic; separate TAP runner passes 25 checks including exact base pixels, actual PS/2 STOP and retained-media/phase warm reset; native loading, recording and APSS open; boards disabled | Command-state stub |
| Kanji | Default-disabled first-level ROM/address/CG WAIT backend, loader and CPU INI pass; [opt-in renderer/mixed-source pixels and snapshots](KANJI_RENDER_STATUS.md) pass synthetic and bounded private-candidate tests. Full ASIC attributes/native glyph/CPU protocol, Z level-2 and FPGA acceptance remain open | Partial conditional legacy path, unqualified |
| Turbo display modes | SCRN pages/blackclip/raster, nominal X3/ANK, bounded high-speed PCG/CPU ANK and sixteen global expansion/underline row/mode-exit fixtures pass. Exact ASIC/WAIT/switching, full Kanji attributes/native software and X3 timing/hardware remain open; see [PCG status](TURBO_HIGH_SPEED_PCG_STATUS.md) | Partial |
| Turbo Z analog palette/graphics | Default-disabled shared experiments connect RGB12, external palette/CPU ownership and full 320x200/4096. [Reduced-mode matrix](TURBO_Z_MULTIMODE_STATUS.md) passes sixteen identity/custom cold/warm wide/tall/selected-screen cases with provisional index expansion; [640x400 internal8](TURBO_Z_INTERNAL8_STATUS.md) passes four cold/warm isolation cases. Both paired indices and captured priority now reach composition; original/strengthened matrices are separately tracked. Native reduced CPU bank/opacity/ASIC timing and Z board integration remain unqualified | Conditional subset; disabled by default |
| Turbo Z text palette/priority | Opt-in CPU text storage and 1FC0 controls, exact decode/DAM/cold/warm/stopped-clock crossing tests pass. Analog text now connects actual post-attribute glyph color to retained text RGB and priority in 320x200 full/selected/paired layouts. [Distinct-entry reverse/warm fixture](TURBO_Z_TEXT_OPACITY_COVERAGE.md) passes all 64,000 pixels; stronger full ordering matrices are running. Old zero-visible-text/aliased-color fixtures do not establish stronger coverage. Native intensity/opacity/blackclip, broader attributes/live switches, firmware and hardware remain open; ordinary board defaults stay disabled | Partial (opt-in) |
| Turbo Z YM2151 / expansion devices | [Standalone JT51 FM](TURBO_Z_FM_STATUS.md) bus/timers/stereo/mixer pass at three master frequencies; [conservative decoder](FM_DECODE_STATUS.md) passes exhaustive controls and actual CPU neighboring-port/reset/WAIT tests; default-off [shared CPU bus](FM_MACHINE_STATUS.md) passes generated IPL status/busy/WAIT/PPI DAM/real DMA/reset. [Shared signed audio](FM_MACHINE_AUDIO_STATUS.md) adds CPU-programmed cold/warm mixed captures at three clocks and stereo C++ WAV checks. Native IRQ/software/analog/hardware, DMA-owned FM, capture/HD/level-2 Kanji and other Z devices remain open; [roadmap](TURBO_Z_PLAN.md) | Partial, opt-in JT51 CPU/audio; ordinary profiles off |
| Turbo Z video input / capture effects | Default-off [CPU effect storage](TURBO_Z_EFFECT_CPU_STATUS.md) passes actual Z80 1FC1..1FC4 byte/read/AEN/DAM/reset tests under provisional policies; decoder and digital ADC-pin units pass separately. No connected ADC/line-FIFO/digitizer or rendered capture/mosaic/chroma/scroll device exists. Source clocks/GRAM arbitration, native access/pixels and physical input remain open | Partial CPU prototype; effects not implemented |
| Turbo Z 2HD / second-level Kanji | Base D88/first-level optional glyph work does not implement complete 2HD rate/media/format behavior or authentic level-2 addressing/storage. Native HD media and concurrent level-2 CPU/video loading, fit and hardware gates remain open | Not qualified |

See [the detailed survey](CORE_STATUS.md) for evidence and
[replacement chip candidates](CHIP_REUSE.md) for sources pulled from other
cores. Downloading replacement RTL does not change the implementation status
above until it is connected and tested.
See [Turbo foundation evidence and exclusions](TURBO_STATUS.md) and
[disk safety coverage](DISK_STATUS.md). The opt-in profile is not complete
Turbo support, and historic game/hardware checkpoints do not validate new RTL.
