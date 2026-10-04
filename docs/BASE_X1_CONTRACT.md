# Base X1 bring-up contract

The active machine is `rtl/sharpx1.v`, shared with the headless simulator.
This increment targets the original X1: 4 MHz Z80, 64 KiB main RAM, 4 KiB IPL,
three 16 KiB graphics planes, 2 KiB each of text/attributes and three PCG planes,
HD46505-compatible CRTC, 8255, AY-compatible PSG and base MFM/2D floppy boot.
Generated-media write/readback tests pass with explicit protection controls;
see `DISK_STATUS.md` for the remaining controller/image limitations.
Turbo DMA, CTC, SIO, 400-line modes and cassette transport are not acceptance
claims. A base game running does not establish full machine compatibility.
This file describes the default `TURBO=0` profile. The explicitly opt-in
foundation changes IPL size, GRAM pages and the text/KVRAM aperture; its
separate contract and exclusions are in `TURBO_STATUS.md`.

## CPU and loading

The inherited CPU wrapper exports active-low strobes. Ordinary I/O excludes
interrupt acknowledge. IPL reads cover 0000–7FFF, with populated bytes at
0000–0FFF and FF elsewhere. Writes always reach underlying RAM. Output to
1Dxx enables IPL; 1Exx disables it. Download index 0 loads IPL, index 2 loads
main RAM only while reset is held. Bounds and download/write qualifications
are tested. RAM debug execution uses a high-RAM trampoline at FFF0; it is not
a native IPL/media boot.

## I/O paths currently connected

| Range | Connected device | Important remaining limits |
| --- | --- | --- |
| 0FF8–0FFB | WD1793-family register interface | Generated reads/writes/status tested; exact MB8877 timing/format/metadata incomplete |
| 0FFC/0FFD | Drive/side/motor write; FM/MFM read selection | Drive A/MFM only; motor hold tested; additional density/status ports incomplete |
| 1000–13FF | Graphics palette | Legacy implementation, needs focused coverage |
| 1400–17FF | ANK/PCG beam-addressed access | ROM/three-plane readback and CDC WAIT tested; exact scanline timing/Turbo incomplete |
| 18xx | CRTC registers | Native IPL raster observed; other timings unverified |
| 19xx | MR16 replacement sub-CPU host port | E7/E8, keyboard IM1 make/break and gameplay tested; not full 80C49 equivalence |
| 1A00–1A03 | PPI | Mode-0 directions/latches/BSR tested; printer/cassette and mode 1 need review |
| 1Bxx / 1Cxx | PSG data / address | Three tones, mute, noise, envelopes and joystick inputs tested; full fidelity pending |
| 2xxx / 3xxx | Attribute / text RAM | Low 11 address bits, mirrored |
| 4000–7FFF / 8000–BFFF / C000–FFFF | Blue / red / green GRAM | Individual planes and DAM masks tested; full timing/modes pending |

Port-C bit 6 selects 40-column pixels. Falling bit 5 enters simultaneous
graphics-write mode (DAM); an I/O read clears it. PPI port-B currently exposes
display, host TX-full/RX-empty, overlay selection and sync status. Cassette
and break behavior are incomplete. Same-address dual-clock VRAM collisions
are not specified and must not be treated as a hardware timing guarantee.

Joystick pins at PSG registers 14/15 are active low: bit 0 up, 1 down, 2 left,
3 right, 5 button A, 6 button B; unused bits 4/7 stay high. The board-only
`rtl/x1_joystick_map.v` converts MiSTer bits 0 right, 1 left, 2 down, 3 up,
4 A, 5 B, ignoring higher bits. Simulator `--joya`/`--joyb` take raw X1 pin
bytes (default FF), not MiSTer masks. Snapshot inputs persist unless explicitly
overridden. This does not establish PSG output-port direction compatibility.

## PCG access timing

Base PCG ports 14xx/15xx/16xx/17xx select ANK ROM/blue/red/green. Character
and raster row come from the renderer's `cgaddr`; low port bits do not address
the glyph. `x1_pcg_access` transfers a stable plane/write/data request through
a two-flop toggle synchronizer, captures the current beam address in the
video domain, performs one synchronous memory transaction, and acknowledges
stable read data back through two CPU-domain flops. TV80 now receives WAIT
until that acknowledgement; holding an I/O strobe does not retrigger writes.
ANK writes are ignored. PCG RAM's access and display ports now both use the
video clock, avoiding the previous continuously asserted asynchronous write.

This WAIT covers the integration's CDC/read latency, not a verified native
scanline trap. The inherited `pcg_wait.v` is an optional AUTO_WAIT helper,
not enabled here; its precise hardware equivalence is unconfirmed. Turbo
high-speed PCG is not implemented. The service-time address can lag CPU bus
assertion by synchronizer latency, so exact soft-sync compatibility remains
open. Quartus CDC constraints/placement and reset release need hardware/timing
review; ideal simulation cannot prove metastability safety. Reading and writing
the same location on the display port still requires collision review.

Original fixtures check all planes, mirrors, ROM write protection and Z80
completion using a constant glyph/row; the transaction bench additionally
checks boundary addresses, changing beam while pending and after completion, single writes,
reset cancellation and video half-periods 3/7/17 against CPU half-period 5.
They do not establish PCG raster/scroll/attribute correctness.
CPU bus traces exercise both default video timing and a deliberately slowed
4 MHz video domain; the latter extends PCG read strobes from the ordinary
16 system edges to 40, demonstrating actual TV80 wait-state insertion.

## References and provenance

Address-map reference: existing local MAME `src/mame/sharp/x1.cpp`, especially
the PPI handlers and base I/O mapping. Hardware manuals are indexed under
`references/manuals/README.md`; these take precedence where emulator behavior
is uncertain. The original renderer/font/MR16 firmware are inherited Nise X1
sources with restrictive notices, which remain intact. PSG provenance is in
`references/chip-src/`; the WD1793 and its index RAM were copied from the local
FM-7 candidate snapshot, with an instance/module rename to avoid RAM-name
collisions. See `rtl/vendor/` for retained notices.

The PLL-derived video frequency remains 28,571,428 Hz; intended crystal timing
is not yet verified on hardware. The initial Quartus build generated an RBF
but failed timing; hardware validation has not been established. MiSTer wires these interfaces and lint elaborates with
warnings using an interface-only PLL stand-in. Native read-only D88 boot and
CROSS Chase movement are verified only in simulation; see `PLAYING.md`.
The opt-in one-clock experiment is not the default contract; its short
two-direction gameplay failure is recorded in `CLOCK_EXPERIMENT.md`.
