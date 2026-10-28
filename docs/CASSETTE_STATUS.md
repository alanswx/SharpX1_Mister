# Cassette bring-up status

October 20, 2026: the base `sharpx1_cassette` revision was retired. Tape is
in the release core (`sharpx1_turbo_z_font_single`) in both X1 and X1 Turbo
models; see `REVISIONS.md`.

## Running EF clock in the controller (October 27)

Rally-X loaded, but its playfield stayed blank and pressing Space froze the
game. As recorded below ("Native Rally-X time dependency"), it seeds its
generator from the EF time read, and the inherited MR16 firmware never
advanced `time`: the 500-ms ISR only toggled the 1-Hz blink bit, and its
clock branch was commented out with no target. The cassette controller
(`scripts/build_mr16_cassette_firmware.py`) now replaces that ISR's compare
reload (`add r0,#500000/8`, one 4-byte hook site in the ledger) with a JSR
to `cassette_clock`, which does the same add and, once per second, counts
the BCD seconds/minutes/hours that EF returns (hour, minute, second,
starting from 00:00:00 or from an EE time set). MiSTer 126, `x1r`
(`d26f423`) with only `boot1.rom` changed: the previous controller
(`dafb9bef…`) shows the blank, frozen playfield; the new one
(`79442263…`) plays the attract demo, and Space starts a game. The time
is not set from the MiSTer RTC.

## Reading 1Exx maps RAM; BASIC tapes (October 27)

Brain Breaker reached its title, then the IPL boot menu appeared at tape
2:47 and the deck rewound. Trace (`--bus-trace` 77.00-77.44 s, native IPL,
5x): after its custom blocks the game runs `LD BC,1E00 / IN A,(C)` at FC00
to leave the IPL, then jumps to its code below 8000. Only writes switched
the ROM, so the IPL ran instead. CSP decodes the read as well (credited to
Mr. Sato); MAME and XMil do not (XMil cannot load this tape). A read of
1Dxx still does not map the ROM back. `test_turbo_ipl.py` covers both reads
and fails without the change. On MiSTer the game now starts.

Cosmo Cross and Creamy Mami (both "CZ-8CB01") begin with a mode 02 (BASIC)
file: the IPL alone shows "File mode error". With the HuBASIC CZ-8CB01
disk, `LOAD` then `RUN` loads them. Cosmo Cross reaches its title. Creamy
Mami shows its title picture and instructions, then stays at "LOADING
PLEASE WAIT" after its last block, at 5x and at normal speed. Hu-BASIC's
own byte routine reads that block (`0CAA`: edge, about 215 µs delay,
sample). The bytes it stores at B000 match an offline decode exactly (171 of
171 in the 110-s trace window), but over the 18,941-byte body the stored
checksum (16-bit count of 1 bits, `C19B`) is 8 more than the count of
the decoded data (`C193`). Files 1-3 of the same tape and every block of the
other tapes match. So the dump appears to have lost one byte's worth of
1 bits; a tester reports the tape working in an X Millennium build.

## Declared bit count clamped to the payload (October 27)

Cosmo Cross (CZ-8CB01) and Car Chase declare exactly 32 more bits than
their payload holds (the converter apparently counted the 4-byte position
field). The exact-length rule rejected both, which the OSD reported as an
unrecognized format. CSP ignores the declared count and plays the file;
MAME plays the declared count. Both `x1_tap_sd_stream.sv` and
`x1_tap_image.h` now play `min(declared, payload)` bits, so a short
payload plays what it holds and a longer one plays only the declared bits.
`test-tap-image` (356 checks) and `test-tap-sd-stream` (long, short and
empty-payload cases replace the two length rejections) pass. Neither tape
has been loaded on hardware yet.

## Deck FF/REW and APSS (October 26)

Super Mario Bros. Special uses the deck commands beyond STOP/PLAY. Native
IPL trace (simulation, 5x): after the main program (tape 236 s) the game
sends `E9 04` (REW) and polls EA until the deck stops at the start, plays
the first file again, then sends `E9 05` (APSS forward) to skip the main
program and loads the level file at 243.5 s. With REW ignored EA read 1 at
once and the game showed "TAPE ERROR / PLEASE REWIND TAPE" (reproduced at
75 s). X Millennium does the same rewind and skip (tester report). The
transport ignored FF (3), REW (4) and APSS (5/6), and the controller
firmware filtered them out. Now:

- `x1_cassette_transport` winds at 16x the sample rate (CSP
  `DATAREC_FAST_FWD/REW_SPEED` for the X1), one `wind_step` per sample,
  stopping on STOP or at either end (FF's end reads as EOF, sensor 02;
  CSP stops the motor there too). No samples play while winding; PLAY after
  a wind waits for the producer instead of reporting underflow.
- APSS forward (5) / back (6) wind at the same speed but read every sample
  (the producer keeps fetching; a step waits for a valid sample) and stop in
  the first gap after sound: 1.8125 s of tape without a level change, where
  CSP's 2-s APSS window turns 90% one level. A tape end stops it too.
- `x1_tap_sd_stream` moves its cursor per step and fetches no sectors while
  winding; the sector under the cursor is fetched when winding stops.
- The cassette controller extension accepts FF, REW and APSS. EA reads modes 0-6:
  mode bit 2 rides on PORT1 bit 15 (sensor bit 7, which the deck never
  sets); EB keeps sensor bits 6:0. The tester package's `boot1.rom` must be
  rebuilt (`--receive-only --joystick-off --caps-off`).
- Quick start's own passes hold winding off (`busy`).
- `test-cassette-transport`: exact cumulative 16x step intervals, both end
  stops, STOP mid-wind, PLAY refill, APSS gap stops both ways and the end
  stop; three mutants rejected.
  `test-tap-sd-stream`: REW to the start from a mid-sector cursor and FF
  1000 samples then STOP, levels checked against the decoded image after
  the wind. `test-mr16-cassette-firmware` checks the new instructions.
  `test-machine-cassette` (generated IPL, real MR16 controller): FF reads
  EA 3, STOP mid-wind, REW reads EA 4 and stops at the start, PLAY replays
  from the first sample; the ledger checks every wind step at 250 SYS
  edges (16 x 8 kHz at 32 MHz).

Not done: recording, the deck's mechanical start/stop times, APSS with
more than one program (the firmware command has no count).

## Tape speed: 5x and quick start (October 24)

OSD Machine page, **Tape speed** (`O[12:11]`, replaces Fast tape `O[9]`):
5x + quick start (default), 5x, Normal.

- **5x**: `x1_clock_enables` steps the CPU enable at 20 MHz (was 16) and the
  transport paces samples at five times the TAP rate, both only while the
  tape has pulses: after a quarter second of tape without a rising edge both
  return to real speed together, and the next edge restores 5x. Hyper
  Olympic '84's loader never stops the deck; its set-up ran at 20 MHz during
  the blank tail and its raster-timed PCG writes striped the background
  (MiSTer 126 sweep); with the gate its score screen is clean in
  simulation at 80 s, while Zero Fighter (40 s) and Yellow Cab (26 s) keep
  their times. At 42.95 MHz the
  enables stay two or three SYS edges apart; `test-clock-enables` now
  asserts that. `sharpx1.sdc` has no multicycle paths, so every CPU path was
  already timed at the full 42.95 MHz: the faster enable is not a timing
  change. Tapes above 48 kHz still play at real speed.
- **Quick start** (board-only `rtl/x1_tape_quickload.sv`, machine
  `CART_PORT`): the X1 and Turbo IPLs check a CZ-8RB ROM cartridge (ports
  0E00-0E02 address, 0E03 data) after the floppy and before the tape, read a
  32-byte header with the tape header's layout, copy the program and start it
  (IPL 0x004A/0x0094). The module decodes the TAP's first block in the IPL's
  own tape format from the SD stream (bit = level 175 us after a rising edge;
  N zeros and N ones of sync, N = 40 header / 20 program; bytes MSB first,
  each followed by one edge; a 16-bit count of 1 bits). After a mount or
  rewind it checks the header (attribute 01, non-zero size, ending at or
  below FFA0) and both counts while the deck does not see the tape and port
  reads wait; then it rewinds and decodes again for the boot. The IPL boots
  a 46-byte stub from the ROM (header at 000000 with the tape's name, load
  and exec FFA0): it switches the IPL ROM back on, copies the tape header
  (000100) to FF00 and the program (000120, served byte by byte with CPU
  WAIT as it decodes) with the IPL's own ROM routine 0146, stores 0083 at
  FFFE and jumps to the IPL's tape-boot ending at 0083. A plain ROM boot
  leaves 00BE at FFFE, and Zero Fighter's loader reads FFFE and the CALLs
  before it to find the IPL's tape routines (0564, 0648): it crashed. Both
  IPLs share 0083-00BE and leave FF90-FFEF unused. The tape is handed to the
  deck in STOP just after the program, as the IPL's tape routine stops the
  deck after a program (0x057A); a loader starts it again. A tape that fails
  the check (BASIC, data tape, no sync within 30 s, bad count, ending above
  FFA0) is presented normally and the port reads FF. Above FFA0 are the stub
  and the IPL stack: 3D Bomberman's first program (FFDE + F8, wrapping to
  00D5) overwrites the stack of the IPL's tape routine so that its RET
  starts the game; the ROM routine's stack differs and it ended in the IPL's
  TV timer on MiSTer 126 (sweep, October 24). 10 of the 124 machine-code
  MAME tapes end above FFA0; all have more data after the first block. If the IPL had not read the port during the
  check, the module requests a machine reset (a tape mounted at the IPL menu
  or in BASIC). A user reset boots the tape again; a later drive A mount or
  an eject disarms it.
- Analysis (offline decoder, not in the repo): of the MAME 0.289 list's 163
  TAPs, 124 have an IPL machine-code program and all of them decode at
  175 us; 35 are BASIC and 4 are data tapes (Xanadu tape C, Wingman B/C/D).
  59 are one block (instant), 65 have more data after the first program.
- `make -C verilator test-tape-quickload`: the real `x1_tap_sd_stream` on a
  simulated SD slot, tapes built in the IPL format at 8 and 44.1 kHz. Checks
  the waiting presence read, the stub header and bytes, tape header and
  program bytes, the deck mount position after the program, rearm, the
  reset request, disarm, and the BASIC, bad-count, over-stub, over-stack
  (wrapping past FFFF) and disabled fallbacks. Four mutants are rejected
  (program byte released at the start of the CPU read; no rewind before the
  boot pass; no over-stub check; the stub-only range check).
- Machine simulation (`turbo-x3-single-cassette-quick`, 42.95 MHz single
  clock, native Turbo IPL `212895703175-ipl.x1t`, controller `boot1.rom`,
  tester-package TAPs, 8 kHz), run time from power-on:
  - 5x only (`turbo-x3-single-cassette-fast-tape`): Zero Fighter title and
    attract at 34 s (4x: 40 s); Yellow Cab title at 66 s (4x: instructions
    at 80 s). No underflow; the loader stops the deck.
  - Quick start: Yellow Cab "IPL is loading Yellow_Cab" at 8 s and its title
    at 25 s (one block; the deck stays stopped). Zero Fighter: its 128-byte
    loader boots from the ROM, finds the IPL's tape routine through FFFE,
    loads the rest at 5x, title and attract at 36 s (5x only: 34 s; the
    first program is tiny, so quick start gains nothing). The tape was
    mounted at power-on, the IPL had not looked yet, so no reset was
    requested. Pock-Kun (BASIC) falls back: "File mode error" and the IPL
    menu at 15 s, as without quick start.
  - Found in simulation (fixed before release): serving the program as the
    ROM itself crashed Zero Fighter's loader (FFFE = 00BE); handing the deck
    over in PLAY was wrong (the IPL stops it) and underflowed.

## Fast tape and tape overlay (October 23)

- **Fast tape** (OSD Machine page, default on; `fast_tape` machine input):
  while the deck is in PLAY, `x1_clock_enables` steps the CPU enable at
  16 MHz instead of 4 MHz and the transport paces samples at four times the
  TAP rate. The Z80 loaders time PB1 pulses with instruction loops, so they
  see the same pulse widths. Everything on the CPU enable (DMA, CTC, SIO,
  FDC) speeds up with it; the PSG, FM and the sub-CPU do not. Only in the
  single-clock 42.95 MHz build (enables stay two or three SYS edges apart,
  `test-clock-enables`) and only for tapes up to 48 kHz (the two-sector SD
  stream must keep up).
- Simulation, `turbo-x3-single-cassette-fast-tape`, native Turbo IPL and the
  joystick-off controller: Zero Fighter is fully read by 25 s and at its
  title at 40 s (real speed: still loading at 55 s, demo at 70 s); Yellow Cab
  (240 s at 8 kHz) shows its instructions by 80 s (real speed: 260 s on
  MiSTer 126). No underflow; the loader stops the deck in both.
- **Tape overlay** (OSD Video page, default on; board-only
  `rtl/x1_tape_overlay.sv`): while the deck plays, the bottom-left corner
  shows `TAPE > m:ss/m:ss x4` and a 64-step progress bar. Elapsed time and
  fill follow the stream cursor; the total is the TAP length divided by its
  rate. One packed word crosses to the video clock by a toggle handshake.
  `test-tape-overlay` checks the times, the fill, the handoff and pixels.
- MiSTer 126 (`592196b`, `releases/SharpX1_20261023.rbf`): Zero Fighter
  shows the overlay (`TAPE > 0:19/ 0:41 x4` at 15 s) and its title by 45 s;
  Yellow Cab's instructions at 85 s (260 s at real speed). See
  `DMA_BOARD_BUILD_STATUS.md`.
- A drive mounted by an earlier MGL stays mounted (`SC`), and the IPL boots
  a disk before the tape: clear Drive A first for a tape-only MGL.

## Board revision `sharpx1_cassette` (October 18)

Base X1 (two-clock: SYS 32 MHz, VID 28.571428 MHz) with the existing
`CASSETTE_ENABLE` machine profile and a new board-only SD producer:

- **OSD:** `S2,TAP` mounts a tape; `F6` loads the deck controller. Every mount
  starts rewound at sample 0 (the TAP's stored position is ignored). The OSD
  reports "Tape ready (rewound)" or "Tape format not supported".
- **Producer:** `rtl/x1_tap_sd_stream.sv` reads the image through the hps_io
  SD block interface (VDNUM 3), parses the header and holds one MSB-first
  sample for `x1_cassette_transport`. Admission mirrors `x1_tap_image.h`:
  old header with rate 8000, or new `TAPE` header with format 1, rate 8000,
  write-protect flags limited to bit 4 (the declared bit count is clamped to
  the payload since October 27). Anything
  else mounts as no tape. Two 512-byte slots keep the current and next sector
  resident (0.512 s of tape each). It mounts the deck only after the first
  sample is held, so PLAY never starts without data.
- **Controller:** not embedded. Build it with
  `python3 scripts/build_mr16_cassette_firmware.py --receive-only --joystick-off --output-dir DIR`
  and load it as index 6 (OSD `F6` or an MGL `f` item) or as `boot1.rom`
  (Main sends index 0x40, mapped to 6). An MGL `f` item only applies when
  CONF_STR has a matching `F` option. `--joystick-off` changes exactly one
  low-ROM byte (offset 376, `03`→`02`) so the inherited PS/2 joystick
  emulation starts disabled; otherwise it eats A/Z/X/C and the keypad,
  including the IPL's `C` (CMT) key, and F12 (its toggle) opens the MiSTer
  OSD. The default builder outputs are unchanged.
- **Memory fix:** the cassette branch of `rtl/sub_cpu.v` now stores the 8-KiB
  controller as two byte-wide dual-port arrays. The previous 16-bit,
  byte-written, two-read-port array synthesized to registers (the fitter
  needed 7,812 LABs of 4,191). `test-machine-cassette` passes again on the
  new memory: six CPU cases plus three rejecting controls.

Checks:

- `make -C verilator test-tap-sd-stream`: 18 checks against the real transport.
  They cover old and new headers, a sector-exact payload, a partial last byte,
  write-protect metadata, empty media, eight rejections (44.1/176.4 kHz,
  format 0, unknown flags, long/short payload, old-header rate 0, truncated
  header), remount rewind, a 20,000-cycle SD latency, exact 32-MHz cadence
  and a bit-order mutant, which is rejected.
- `make -C verilator lint-wrapper-cassette`. Default `lint-wrapper` warnings
  are identical to before.
- Quartus 17.0 build `quartus-linux-YHBWKu6Z` (commit `6a9b41e`), RBF
  `4572260f…`: 50% ALMs, 38% block memory. The eight-corner inventory has
  failing paths in 23 of 32 reports. Every one is a SYS↔VID crossing between
  the two PLL outputs, inherited from the two-clock base design (PCG bus,
  hps_io status/reset into video, MR16 blink). None is same-clock, and none
  is in the tape streamer or the controller memory. This is not a timing
  closure claim for the base two-clock revision.
- Simulation (frozen cassette runner, base IPL `0513077c…`, joystick-on
  controller `5463d65d…`): the Zero Fighter TAP loads without input. The IPL
  falls back to CMT and starts PLAY at 5.85 s, and the loader stops the deck
  at 47.0 s. The title/instructions frame appears, with zero underflow.

MiSTer 192 hardware: same RBF, MGL with base IPL (index 0), joystick-off
controller `439a3863…` (index 6), TAP on S2. Raw mrext captures are in
`output_files/CASSETTE_20261018/hw/`, and media hashes in `media.sha256`.

| ID | Tape | Header | Result |
| --- | --- | --- | --- |
| K01 | Zero Fighter | new, 8 kHz | Auto CMT load, "IPL is loading ZERO", attract demo; Space starts stage 1 ✓ |
| K02 | Pock-Kun | new, 8 kHz | IPL "File mode error"; MAME 0.283 `x1 -cass` shows the same (not a machine-code file) |
| K03 | Bomber Man | new, 8 kHz | Title, then maze gameplay after Space ✓ |
| K04 | Cannon Ball | old, 8 kHz | Title, then gameplay after Space ✓ |
| K05 | Slalom | new, 8 kHz | Instructions, then stage 1 after Space ✓ |
| K06 | Sea Bomber | new, 8 kHz | Title/instructions ✓ |

Earlier hardware attempts on this date are preserved as evidence. Without
the F6 entry, Main skipped the MGL's index-6 item, and the IPL reported
"Please turn on the Power SW slowly again !". With the joystick-on
controller, `C` was swallowed.

### Follow-up: runtime rates, X3 core, controller fallback (commit `930a57d`)

- **Runtime sample rate.** `x1_cassette_transport` has a default-off
  `RUNTIME_RATE` parameter that paces at a held `sample_hz`. The fixed-rate
  expression, and the existing transport mutant that edits it, are
  unchanged. `x1_tap_sd_stream` admits `MIN_HZ..MAX_HZ` and reports
  `sample_hz`; boards accept 4–192 kHz. The MAME 0.289 software list has 163
  TAPs: 141 at 8 kHz, 14 at 44.1 kHz, 4 at 48 kHz, 2 at 24 kHz, 1 at 32 kHz
  and 1 at 22.05 kHz. MAME's own loader rejects every rate except 8 kHz.
  `test-tap-sd-stream` now has 28 checks. The new ones cover
  4/8/22.05/44.1/48/176.4 kHz cadence and drift, out-of-range rejections, and
  a transport mutant that ignores the runtime rate (rejected on cadence).
- **Controller fallback.** Until an index-6 upload arrives, the cassette
  branch of `rtl/sub_cpu.v` serves low-bank program reads from the ordinary
  embedded `sub_rom`. A missing controller therefore behaves like the ordinary
  core (no deck control) instead of an empty program. On hardware the X3 core
  without a controller reaches "IPL is looking for a program from CMT", which
  requires a running sub-CPU; the empty program gave "Please turn on the
  Power SW slowly again !". No new firmware is embedded.
- **X3 main core.** The external-font profile now admits cassette, and
  `sharpx1_turbo_z_font_single` defines `X1_CASSETTE`.
- **Simulation runner.** With `+define+X1_CASSETTE`, `verilator/sim.v`
  instantiates the board streamer on its own hps_io-style channel.
  `sim_headless.cpp` adds `--tape` and `--tape-controller`. Targets:
  `turbo-x3-single-cassette`, `base-cassette` (and `-fast`). They are
  non-savable, and the default generated state audits are unchanged.

Runner checks (fast `--no-timing` builds, joystick-off controller
`439a3863…`, no input):

- `turbo-x3-single-cassette`, native Turbo IPL `21289570…`, Zero Fighter:
  at 70 s the attract demo is running. The whole tape is read (81 SD sector
  requests), the deck is stopped by the loader, and there is no underflow.
  At 55 s the screen still read "IPL is loading ZERO".
- `base-cassette`, base IPL `0513077c…`: Zero Fighter shows the same 70-s
  attract demo. 3D Bomberman (44.1 kHz) plays to the tape end (sensor `02`,
  1,337 requests, no underflow), and at 135 s the title art is being drawn.

Builds (Quartus 17.0, commit `930a57d`):

| Revision | Build | RBF | Fit | Eight-corner inventory |
| --- | --- | --- | --- | --- |
| `sharpx1_turbo_z_font_single` (+cassette) | `AJf4dzRg` | `31b499ca…` | 70% ALMs, 79% BRAM | 0 failing paths in 32 reports |
| `sharpx1_cassette` | `oyUG0tPv` | `0b035d1f…` | 51% ALMs, 38% BRAM | Base two-clock crossings only, as above |

MiSTer 192, raw mrext captures in `output_files/CASSETTE_20261018/hw/`:

| Core | Media | Result |
| --- | --- | --- |
| X3 font single | Native Turbo IPL, ANK16, controller, Zero Fighter TAP | "IPL is loading ZERO", attract demo; Space starts stage 1 ✓ |
| X3 font single | Same without controller | Sub-CPU runs; IPL waits at "looking for a program from CMT" (ordinary behaviour) |
| X3 font single | Galaga raw .2d | Title; Space gives the level menu ✓ (disk path intact) |
| `sharpx1_cassette` | Base IPL, controller, 3D Bomberman (44.1 kHz, software list `3dbomb`) | Loads; title art, then instructions after Space ✓ |

### Software-list tape sweep (MiSTer 192, X3 core `31b499ca…`)

All 163 MAME 0.289 software-list TAPs pass the board's admission rules.
Ten were run with the native Turbo IPL and the joystick-off controller. Each
got one capture at `min(length, 200 s) + 25 s` and another after Space;
the list and hashes are in `output_files/CASSETTE_20261018/softlist/`.

| ID | Title | Rate | Result |
| --- | --- | --- | --- |
| KS01 | Space Burger | 8 kHz | Game, then GAME OVER/Push space ✓ |
| KS02 | Star World II | 8 kHz | Title ✓ |
| KS03 | Barricade | 8 kHz | IPL "File mode error": software list says "In BASIC, type LOAD and then RUN" |
| KS04 | Atama no Taisou | 8 kHz | Same; a BASIC tape |
| KS05 | Star Stream | 44.1 kHz | Still "WAIT A MOMENT PLEASE." at 109 s (inconclusive; MAME marks it unsupported) |
| KS06 | Maharito | 44.1 kHz | Title, HIT SPACE KEY ✓ |
| KS07 | Yakyūkyō | 24 kHz | Title ✓ |
| KS08 | Wingman | 48 kHz | Still loading at 225 s of a 650 s tape (inconclusive) |
| KS09 | Z Gundam | 22.05 kHz | Title ✓ |
| KS10 | Wakusei Mephius | 32 kHz | IPL "File mode error" (no reference; MAME marks it unsupported) |

Six of the eight non-BASIC tapes reach a title or game, at four different
non-8-kHz rates. The non-8 kHz titles have no emulator reference here,
because MAME only plays 8 kHz tapes.

Still open on the board: Car Chase, the only 176.4 kHz tape (its payload is
4 bytes shorter than the declared bit count; admitted since October 27, not
yet loaded); format 0; recording (FF/REW/APSS since October 26);
BASIC tapes through HuBASIC (Cosmo Cross, Makaio load since October 27); EF clock running since October 27, not set from the MiSTer RTC. The external-font
X3 core is the only Turbo revision with tape.

October 10: the default-off `CASSETTE_ENABLE` shared-machine profile now connects
a read-only SYS-timed waveform transport, executed MR16 setters/live E9/EA/EB
responses and PPI PB1. Six generated-IPL machine cases pass an independent
rerun. Ordinary runners and all board revisions remain cassette-disabled;
the separate non-savable TAP runner now passes generated-asset checks. Native tape loading,
recording, speed control and APSS remain open. PC0 has no recorder consumer.

## Connected read-only diagnostic checkpoint

Run `make -C verilator test-machine-cassette` for all six cases and three
controls; the standalone prerequisites are `test-cassette-transport` and
`test-mr16-cassette-firmware`. CI scheduling is not a hosted acceptance result.

`rtl/x1_cassette_transport.sv` consumes prebuffered, SYS-synchronous held samples,
not decoded tape bytes. Eleven standalone cases cover nominal/actual clock
frequencies, pause/resume, final-sample duration, underflow, reset and command
priority, with exact rejecting controls. A missing sample stops playback with
sticky underflow; it never silently stretches time. Only EJECT/STOP/PLAY are
implemented; other requests leave the running transport unchanged.

The source-derived 8-KiB controller is uploaded through index 6 during drained
reset. Its extension commits low/high OP5 stores at startup, E9 and BREAK;
the machine edge detector accepts each once despite held stores. EA/EB read
the applied deck state through the real firmware/mailbox. Index 7 remains
RTC-only, and RTC+cassette is explicitly rejected because OP5 conflicts.
The inherited firmware/ordinary profile is not replaced.

The restricted builder also repairs the packed-ASCII comparison only in this
extension: the caller supplies ASCII in the upper byte, while the inherited
BREAK comparison expects an unpacked `03`. Static checks cover all 65,536
packed words. Actual PS/2 Ctrl+C subsequently stops the deck; plain C does not.
F12 make/release first disables the inherited joystick mode, which otherwise
consumes C/A before ASCII processing. The tested PB0 route is held BREAK,
**not** a qualified native read-cleared cassette-STOP pulse.

Independent delay-aware execution of `test_machine_cassette.py --run` finishes
zero in frozen folder `x1-machine-cassette-e0b0j0oo`. Its six original CPU cases
cover transport/PPI low and high levels, Ctrl+C/release/subsequent A, plain C,
retained-media warm reset, empty media and an actual mount/PLAY commit tie.
The independent slot ledger checks 4,000 physical 32-MHz SYS edges per sample;
the complete-waveform cases accept exactly 256 samples. Executed commits are
exactly 8/3/3/5/4/9. Timer ACK rising edges are execution witnesses, not inferred
handler counts. No hierarchy writes, forced state, private IPL or host mailbox
responses are used. Three controls reject missing ASCII normalization, a
disabled deck and RTC+cassette. Synthetic diagnostics do not prove native loading.

Qualified sources SHA-256:

- Transport: `1767eba3eee4a4b06f148733afdfe57c624c669ef0215944afaf2cd9f64266b2`
- Builder: `34b1d68ba0fb44034d9215d4bc6e343ec33afe27fbda4508324fdeb5d17e5361`
- Machine fixture: `30784d00420cc3d23b1735cb9f10843a89cf93e7aa9c689545512e5869bca750`
- Collector: `78aa3908b7d56ddcd3d6d2949e7d1a81f915781c83bbbbbbe73e4340c645544d`

All eight actual ordinary base/Turbo generated headers/serializers compare
byte-identical to `d2c2d5f`, with no added warnings. The existing RTC elapsed,
retained-reset, transport and DMA-reset diagnostics finish their immutable
evidence checks after integration. Wrapper DMA lint passes an interface check,
not Quartus or hardware acceptance. (At this October 10 checkpoint no RBF enabled cassette.)

## Separate waveform-fed runner

`verilator/sim_cassette.v` and `verilator/cassette_main.cpp` instantiate the same
shared machine with only cassette enabled. It accepts binary 4/8-KiB IPL
assets (explicitly uploads/maps only the lower 4 KiB), an explicit 8-KiB
controller and the bounded TAP parser. It mounts STOP state and holds the
next sample stable until pre-edge SYS `valid && ready`. No decoded tape data
is injected into RAM and no mailbox responses are supplied. Debug ports read
only. Snapshots, disk services and deck-command injection are unavailable.

```sh
python3 -B verilator/tests/test_cassette_runner.py --run
```

`make -C verilator test-cassette-runner` wraps these generated-asset checks;
CI scheduling is not a hosted acceptance result.

The collector prints its disposable `EVIDENCE` folder, including a frozen
`obj/cassette_runner`, source-derived `generated/controller.bin` and builder
report. `--build-only` does not execute tests. Use a new disposable output:

```sh
PATH_TO_FROZEN/cassette_runner --ipl LOCAL_IPL --controller LOCAL_CONTROLLER \
  --tape LOCAL_TAP --cycles 32000000 --output NEW_DISPOSABLE_DIRECTORY
```

`--keys` accepts decimal millisecond / hex PS/2-byte rows. `--cycles` measures
physical 32-MHz units including 12,352 startup/upload cycles; JSON separately
records reset release. SYS=32 MHz, VID=28,571,428 Hz, delay-aware execution.
Declared TAP position is honored; accepted-final-sample and completed playback
EOF are distinct. Actual RGB frames, RAM/text/attribute observations and input/
executable hashes are saved, not loading-success claims. Outputs can contain
private bytes and must remain ignored/disposable.

Fresh execution in `x1-cassette-runner-ol445t4d` finishes zero: twelve checks,
including eight exact admission/option rejections, 4/8-KiB IPL equivalence,
declared position 3, ten actual samples/cursor 13, STOP and empty media.
Public waveform transitions match every held input level; final EOF occurs
exactly 125 microseconds after final acceptance. Inputs and executable remain
unchanged. There are 60 inherited Verilator warnings, none in the new top/
transport, and no C++ warnings. The first collector failure on macOS `/var`
versus `/private/var` aliases is retained; normalizing the temporary path fixes
generation, not RTL.

Native local IPL/Rally-X probes at one/four physical seconds exit zero with
assets unchanged, but show only preparing / floppy-search screens and accept
zero tape samples. This establishes native IPL initialization, not tape loading.
The IPL menu dispatches ASCII C to cassette loading; the real-PS/2 follow-up
first disables joystick emulation with F12, which otherwise consumes C.
The ten-second follow-up now exits zero on an actual CMT-search frame and
accepts 33,227 samples, with no underflow and all assets unchanged. Independent
read-only auditing compares every accepted level against the original private
TAP and requires consecutive cursors and exact 125-microsecond intervals.
PLAY begins at 5.846650859375 seconds, before the first scheduled PS/2 byte at
6.5 seconds: the initial transition is native floppy-search fallback, not
evidence that the later C key caused it. Six real PS/2 bytes finish transmission;
their native action is not otherwise qualified by this capture.

Evidence: `/tmp/x1-native-rallyx-cassette-iFzAfm/run10-cmt/`. The mounted private
TAP hash is `ca83e1a5b9e9443c20399e187373b8b5796f939e10b419740701cebafb7998b5`.
The actual PNG says `IPL is looking for a program from CMT`, not a game screen.
A fresh no-key 130-second probe is running under the same frozen executable
in sibling `run130-autoload/`, covering the complete 119.964-second tape plus
IPL startup. It is not yet terminal or a loading/gameplay qualification.

Runner source / collector / executable SHA-256, respectively:

- `34b1d2257a398649a815e87c1a075a3e65acce9e31d2b71641dd7dc79853a355`
- `3d111bff9201224e403ef412f13ada28addae36c09569a9a92bfc512df761dc4`
- `0eb97d7b1c52802d844d58dca625522f456aab8dcdb1c17dd32b7b4f77e385c2`

The subsequent current-source runner qualification completes zero with **25
checks** in `x1-cassette-runner-vw9jbd_r`; observation log
`/tmp/x1-cassette-reset-video-main.log`. It retains the original twelve checks
and adds two CPU-written base-video cases, Ctrl+C/plain-C video/input cases,
three playback/reset cases and six exact reset-admission rejections.
All four captured rasters match independently constructed glyph/color/reverse
pixels: 320,000 RGB pixels across 40/80-column and input cases. The checked-in
ANK source is frozen before compilation, not taken from a private font export.
Both physical clock frequencies and frame/line periods are asserted.

Nine actual PS/2 packets (F12 then Ctrl+C make/release) stop playback at
124.057953125 ms, after 524 of 4,096 samples and before EOF. The plain-C control
transmits six packets and continues playback. Public waveform transitions are
checked against the accepted source ledger; this is not native PB0 pulse or
keyboard-release-state acceptance.

`--reset-at MS` is repeatable; `--reset-for-us US` defaults to 10 us. Events
must fit strictly after startup and before the requested end; overlapping or
touching pulses and orphan/zero widths are rejected before output creation.
The generated 128-sample test resets at 4 and 8 ms for 100 us each. Every
cursor/level remains ordered, no samples advance during asserted reset, and
uploads remain exactly 12,288. Partial slot phases of 55.125 and 21.28125 us
survive reboot; actual next arrivals match the independent active-edge oracle.
EOF differs from the no-reset control only by measured inactive/command edges.
These integer-ms assertions occur at SYS falling edges; an acceptance-edge tie
is not qualified. JSON now explicitly records intra-assignment-delay handling
and warm-reset scheduling/counters.

Source manifests compare unchanged before/after and independently against the
current tree. The build has the same 60 inherited Verilator warnings and no
C++ warnings. New runner / collector / executable SHA-256:

- `e4c29630ed92f4d61679f6547a719e3ed241550b7f38ad95a6ccc9198b5fba83`
- `5163beef13d96eef07954a39fe1ba2fdbf431fb456588bb86a71d65572f58643`
- `494812a481f6e4951f4115943a522ae92e24b8aceddb44f0c628a7aba6a6ac84`

An independent read-only audit in `/tmp/x1-cassette-independent-Q4tA6i/`
rechecks eleven positive reports, all 320,000 pixels, three warm runs, two
PS/2 scripts and fourteen admission-negative logs. It verifies 137 frozen
source hashes, 306 evidence hashes and all 363 original files unchanged.
Four disposable evidence mutations reject at the exact pixel, retained-phase,
held-waveform and plain-C-false-stop assertions. This strengthens artifact/
oracle integrity; it is not a second simulator execution or native acceptance.

The older frozen 130-second native probe finishes with exit zero and has progressed beyond the
`IPL is loading RALLY-X` display to score/map/car graphics. The observed PNG is
private ignored evidence, not a controls/gameplay pass. It accepts 524,717
samples with zero underflow and enters STOP at 71.436165578125 seconds, before
EOF. The terminal image still lacks a full playfield; do not treat its score/map
as playable-game acceptance. Independent native auditing verifies all 524,717
accepted bits and 313,598 waveform transitions against the actual TAP payload,
all four assets/executable and 137 historical frozen-source hashes, terminal
RGB/FNV and unchanged artifacts. Of the 524,716 sample intervals, 524,715 are
125 us and one is 125.03125 us (one extra SYS tick). Supported-command priority
is a plausible cause, not witnessed by this runner's log; preserve the
exception rather than claiming uniformly exact cadence. Evidence:
`/tmp/x1-rallyx-native-audit-5d22VJ/summary.json`.
Same-executable 83-second exploratory keyboard and no-input cold probes both
finish zero with unchanged assets, identical accepted-waveform logs and zero
underflow. Main inspected their actual PNGs: exploratory F12/Space/Enter/arrows
reach `PUSH START BUTTON`, `CREDIT 02` and program credits; the no-input frame
still shows the partial blue map block. Both retain a zero word at RAM 1577h;
its apparent random-generator role is a hypothesis, not a diagnosed fault.
Neither establishes release-correct controls or gameplay.

The local MAME no-input reference reaches a fuller, changing playfield at
83/130 seconds. Its read-only observer records repeated PLAY and STOP/REWIND,
with a read-cleared PB0 STOP pulse unlike the current held-BREAK policy.
These differences are leads, not a proven cause; MAME uses a replacement MCU
and warns about its font dump. Protected evidence is
`output_files/mame-rallyx-reference-siRvI2/`. Never equate the RTL bus address
with MAME's instruction PC.

The passive physical-plane dump extension passes all 25 generated checks in
`x1-cassette-runner-2rjkcn2t`. Terminal inspection adds six files: 2-KiB
`pcg-{b,r,g}.bin` and 16-KiB `gram-{b,r,g}.bin`. Inspection advances no clocks
and supplies no CPU bus data. Four video fixtures execute eighteen GRAM
sentinel writes each, spanning 0000h/0007h/0008h/1FFFh/2000h/3FFFh in every
plane. Main's separate read-only check verifies all 72 sentinels, rejects
28 in-memory width/boundary/plane-swap controls, and preserves all 431 original
files and bound sources. Only PCG dump sizes are checked, not PCG contents.
The executable SHA-256 is
`299858dc515aed48f9bb6ec1b09cf6747dea59f27f03fd494af4f54728d1442a`;
sixty inherited HDL warnings remain, with no C++ warnings. The new native
83-second no-input plane-dump probe was interrupted at the user's stop request
(session 26507, exit 130), before terminal dumps/report. Partial evidence is
preserved; it is not a result.

The older binary and assets are unchanged by this runner extension. Native cold repeats,
loading/game input, recording/APSS and hardware remain separate gates. No
existing RBF enables cassette.

## Native Rally-X time dependency: investigation, not a gameplay fix

Read-only inspection of the immutable 83-second no-input RAM identifies the
actual seed initialization at 157Bh: `LD A,EFh; CALL 320Bh; CALL 321Ch` sends
the time-read command and discards the first returned hour byte. Two subsequent
calls to 321Ch store minute/second bytes at 1577h/1578h. The routine at
1547h..1576h updates that word using shifts and carry; a zero starting word is
therefore a concrete lead for its non-progressing generator, not permission
to overwrite game RAM. The input and no-input observations both have zero
there. The full disassembly can lose synchronization at embedded data; the
initialization and mailbox routines were also checked directly as raw bytes.

The inherited MR16 command table maps EF to `host_w3,time`, but its 500-ms
ISR's elapsed-clock branch is commented out in
`bios/reference/fw_subcpu/x1sub.asm`. The cassette-only extension leaves that
clock behavior unchanged. Local MAME returns hour/minute/second from a running
RTC initialized from host wall time. Its exact returned values must be recorded
before comparing native seeds; differing wall time prevents assuming identical
game state. This identifies the source of static time, not proof that it is the
only cause of the missing playfield.

The completed read-only MAME memory follow-up is
`output_files/mame-rallyx-memory-mStnwi/`: terminal exit zero, protected media
and frozen inputs unchanged. Main independently checks the 64-KiB program
captures against underlying saved RAM and confirms exact code agreement at
1540h..1576h. The 83/130-second reference words are FC1Ah/70F7h, unlike RTL's
0000h. The observed EF transactions at 71.43582175/73.97396975 seconds return
`12 03 47` / `12 03 49`; reference time is BCD and wall-clock-dependent.
This strengthens the running-clock lead, not a causal gameplay qualification.
Saved PCG/text/attribute dumps are present; that observer did not capture GRAM.

Next implementation contract: qualify real RTC/cassette coexistence through
executed controller firmware, preserving ordinary profiles. Both existing
experiments use OP5 incompatibly and deliberately reject their combination.
A new explicit profile needs non-overlapping GPIO ownership, retained/readable
clock initialization, exact firmware redirection/allocation bounds, independent
CPU time/deck/keyboard tests and pending-reset controls. Reading PORT5 to obtain
its output latch is unsafe because it clears the host-data flag. An invalid
power-on RTC does not advance until valid time is programmed; host/battery
initialization must be an explicit contract, not an invented nonzero game seed.
Only then rerun protected native cold/repeat/game-input checks.

## Bounded TAP prerequisite

`verilator/x1_tap_image.h` is original C++20 code. The format layout reference
is the existing local MAME `src/lib/formats/x1_tap.cpp` (BSD-3-Clause, Barry
Rodewald) and Common Source Project `src/vm/datarec.cpp`; no implementation was
copied. It accepts old four-byte sampling-rate
headers and new forty-byte `TAPE` headers, retaining title/reserved/flag bytes.
Ordinary 8,000-Hz waveform samples are MSB first. Samples are not decoded tape
bytes and the sampling rate is not the native baud rate.

Admission is bounded to 8 MiB, with exact declared-bit/payload length, checked
position/index access, partial-last-byte exclusion and an owned immutable
source copy. Zero-length images and position-at-EOF are representable.
Unsupported rates and unknown flags are rejected explicitly. Reserved bytes
and fixed-width titles are retained without guessing their encoding.

The initial parser rejected format-1 waveform access because MAME calls it
“speed limit sampling method.” Follow-up inspection resolves this discrepancy:
Common Source Project `datarec.cpp:1172` quotes the t-tune format as
`01H=定速サンプリング方法` (constant-rate sampling), explicitly accepts format
`01` and decodes MSB-first samples at the stored frequency. Its loader at
lines 1178–1227 was read, not built. The parser now accepts format-1 8-kHz
waveforms; new-header format zero remains metadata-only/explicitly unsupported.
Read-only archive inspection found format 1 in all eight sampled new headers,
including seven 8-kHz tapes and one still-unsupported 44.1-kHz tape. This
prerequisite does **not** establish that those commercial tapes can be played.
Private archives were not extracted, modified or committed for these tests.

`make -C verilator test-tap-image` passes 356 synthetic checks with C++20,
`-Wall -Wextra -Werror`. An independent AddressSanitizer/UndefinedBehaviorSanitizer
build also completes zero without diagnostics. Coverage includes old/new
headers, lengths/counts, truncation, counts 0–17, sample order, excluded padding,
EOF/reset/seek, immutable input, flags/rates and maximum capacity. This target
is scheduled in CI; no hosted result is claimed here.

Checked source SHA-256:

- Parser: `765cfb59718e96fdf53dfa0334edca78e1cc67995ec97d738b1eabcb2df3c8f1`
- Fixture: `fc74f3c1bc7a627fd4288695b0767646c902e89a1af857c0d3492542e6ec1f67`

Second implementation inspected SHA-256:
`6c7167cc7bb9ff529b91481bb5ea0c80b6355b836e55c205b443a093d4049636`.
The original 324-check checkpoint is historical; the fixed-rate follow-up adds
an independent modern-header waveform vector and unsupported-format-zero check.

## Connected implementation and acceptance still required

1. Qualify native loading through the connected format-1/old-header parser; retain explicit unsupported
   policies for other formats/rates until their vectors and timing are tested.
2. Qualify native use of the implemented SYS-timed sampling, bounded host
   buffering, pause/resume/EOF and reset policy. Connect actual waveform levels
   to PPI PB1; do not deliver decoded bytes directly to CPU memory.
3. Extend qualification of the implemented real MR16 setters at startup, E9 and
   BREAK, and serve live EA/EB responses through its existing mailbox. Preserve
   host flag/clear semantics. The proposed cassette-only OP5 allocation conflicts
   with RTC; reject that combination until a proper shared interface exists.
4. Qualify the separate non-savable native runner using the qualified extended
   upload without changing ordinary/RTC behavior; index 7 remains RTC-only. New
   interfaces need explicit snapshot identity/compatibility design, not state
   byte conversion. Initial playback experiments should be non-savable.
5. Corroborate sensor encoding and command policies. Local MAME describes EB
   bit 0 as not-at-end, bit 1 as insertion and bit 2 as recording permitted, but
   its constant `05`/`07` response does not model live EOF/write protection.
   The CZ-8RL1 schematic establishes physical sensors and command/status paths,
   not their software upper-bit mask or exact timing. Unsupported operations
   must not silently succeed or invent native error codes.
6. Run real CPU E9/EA/EB and PPI waveform diagnostics with stopped enables,
   retained-asset reset, EOF and unsupported commands. Then qualify native IPL
   loading of authorized tape software, cold repeats and protected-copy save/
   readback. APSS, recording, speed control and physical deck timing stay open
   until separately implemented and tested.

Parser checks alone do not close the cassette TODO or base-X1 compatibility.

## Connected-path research follow-up

Common Source Project `src/vm/x1/psub.cpp:692–696` normalizes EB as insertion,
not-at-end and recording permission; `play_tape()` at lines 466–475 attaches
playback media in STOP state. Its actual read-only values are `00` without
media, `03` inserted before EOF (including stopped), and `02` at EOF. Lines
243–250 make EA STOP when the transport remote drops. These third-party
behaviors support an explicit first read-only policy, **not measured Sharp
upper-bit/timing semantics**. Do not confuse this pseudo-controller response
with the separate physical-pin model's ROM-dependent input inversion.
Inspected file SHA-256:
`d6d44e11086bb20a3d0cde6e6a490d6171997303da816368c2502005ff022115`.

The planned real path is parser → SYS-timed held-sample handshake → transport
→ PPI PB1 → real Z80 loader. Transport/sensors must return via executed MR16
firmware and the existing mailbox, not host-generated EA/EB replies. Startup,
E9 and BREAK need setters; normal key IRQ processing also needs live status
refresh because inherited PLAY/REC keyboard-IRQ suppression otherwise remains
stale after autonomous EOF.

There is a verified polarity trap in the current code: `rtl/sub_cpu.v:445`
assigns `O_KEY_BRK_n` directly from OP1[2], while firmware asserts BREAK by
setting `PIO_BRK=04h`. A future cassette PB0 connection therefore needs its
inverse, despite the signal's name. Preserve the existing IP1 feedback and
qualify actual PS/2 BREAK execution rather than changing ordinary wiring by
inspection alone.

The initial integration plan uses a separate non-savable simulator top and
constant-disabled machine generate branches. This only preserves ordinary
snapshot v17 if generated declarations/checksums/serializer order compare
unchanged. Neither new ports nor a new profile bit alone prove compatibility.
RTC+cassette remains unsupported until the conflicting OP5 interface is resolved;
index-6 uploaded-controller factoring must leave RTC/index-7 behavior intact.
The connected diagnostic above qualifies these hooks only in its stated scope;
native loading and broader coexistence acceptance remain work in progress.
