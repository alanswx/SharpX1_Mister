# Tape speed and tape status standard for computer cores

One way to make cassette loading fast and visible in the MiSTer computer
cores (Sharp X1, Sharp MZ, and any other core with a tape deck), so a user
who knows one core's tape knows them all. It covers three features:

- **Turbo** (`5x`): while the tape plays, the machine and the tape both run
  N times faster. Works with any loader, because the loader sees exactly the
  pulses it expects.
- **Quick start**: the core decodes the tape's first program itself and
  boots it at once through a boot path the firmware already has, then hands
  the rest of the tape to the deck.
- **Tape status bar**: a small overlay with elapsed/total time, the speed
  and a progress bar while the tape plays.

The reference implementation is the Sharp X1 core (`rtl/x1_clock_enables.v`,
`rtl/x1_tape_quickload.sv`, `rtl/x1_tape_overlay.sv`,
`rtl/x1_tap_sd_stream.sv`; results in `docs/CASSETTE_STATUS.md`). Machines
differ in how they read tape; each rule says what it needs from the machine,
and the "Other machines" section says what to do when a machine does not
have it.

## The rules

### OSD

1. **One row, Machine page:** `Tape speed`, values in this order:
   `5x + quick start` (default), `5x`, `Normal`. A core without quick
   start offers `5x` (default) and `Normal`. Use the factor the core
   actually runs (`4x`, `5x` ...), the same in the OSD and in the overlay.
   It is a setting like the others: it waits for **Apply and reset** (OSD
   standard rule 1). Give it new status bits; do not reuse a removed
   option's bits without bumping the config version.
2. **Tape overlay, Video page:** `Tape overlay`, `On` (default) / `Off`.
3. **Rewind tape** is a one-press button: Machine page, bottom (OSD
   standard: buttons go in Machine).
4. **The tape slot is not remembered:** `S2,TAP,Tape;`, not `SC2`. A core
   start begins with no tape; disks may stay remembered. A tape that comes
   back by itself at the next start surprises users, and with quick start
   it would boot by itself.
5. **Every mount starts rewound**, and the OSD says so with an info
   message (`"I,Tape ready (rewound),Tape format not supported;"`).

### Turbo

6. **Turbo only while the tape plays.** "Plays" means what the machine's
   deck means: motor on and PLAY. The moment the deck stops, the machine
   is back at its normal speed, so the game never runs fast.
7. **Speed up the loader's timebase and the tape by the same factor, and
   nothing else.** A loader measures pulse widths with something: CPU
   instruction loops, a hardware timer, a video interrupt, a serial chip.
   Whatever it measures with must run N times faster together with the
   tape samples; then it sees the same pulse widths in its own units and
   decodes the same bytes. Find the timebase by reading the firmware's
   tape routine, not by guessing. On the X1 it is CPU instruction loops,
   so the CPU clock enable and the TAP sample rate both go to 5x
   (`x1_clock_enables`: 4 MHz → 20 MHz; transport rate = TAP rate × 5).
   Devices on the same enable (DMA, CTC, FDC) speed up with it; sound
   chips, the sub-CPU and video do not.
8. **Never touch the tape data.** Turbo changes only the rate at which
   samples are played. No filtering, no re-timing, no "cleaning": a loader
   that worked at 1x must see the same sample sequence at Nx.
9. **Choose N from the clocks and timing constraints, not from hope.**
   - The CPU enable must keep its minimum spacing on the master clock
     (X1: at least two 42.95 MHz edges apart at 20 MHz; a test asserts it).
   - If the timing constraints have no multicycle paths for the CPU, every
     path is already timed at the master clock, and a faster enable costs
     no timing. If they do, the faster enable breaks them: either remove
     those constraints and close timing, or keep N lower.
   - The tape source must keep up: N × sample rate × bits per sample must
     fit the SD stream with margin. The X1 plays tapes above 48 kHz at 1x
     (and the overlay then shows no `x5`).
   - Memory and video contention: if the CPU's speed is tied to the video
     chip (wait states, contended memory), speeding the CPU changes those
     relationships; check that the loader does not depend on them.
10. **Stop cleanly.** If the stream underflows, the deck stops (it must not
    stretch or invent samples). Report underflows in simulation.

### Quick start

11. **Boot through a path the firmware already has.** Look for an entry
    the firmware checks at reset before the tape: a ROM cartridge, an
    expansion ROM, an autoboot hook. The core then *is* that cartridge,
    serving the decoded program as cartridge bytes. The X1 IPL checks a
    CZ-8RB ROM cartridge (ports 0E00–0E03) before floppy and tape. Do not
    write the program into RAM behind the firmware's back: the firmware
    would not have set up what the program expects.
12. **Decode exactly what the firmware decodes.** Same sample point, same
    sync rules, same checksum. Not a "better" decoder: a tape the firmware
    would reject must be rejected. Before building it, write a throwaway
    software decoder with the same algorithm, run it over the whole tape
    corpus and measure: which tapes decode, which fail and why (X1: a fixed
    175 µs sample point decodes all 124 machine-code tapes of MAME's list
    at 8–48 kHz; 150 µs missed 4).
13. **Check, then boot.** First pass: decode the first program completely
    and verify its checksums while the deck does not see the tape and any
    firmware read of the cartridge waits (CPU WAIT). Only if it passes:
    rewind, decode again and serve the bytes as the firmware reads them.
    Nothing is half-booted; anything that fails falls back to rule 16.
14. **End in the state a real tape boot leaves.** Loaders inspect the
    firmware. Compare, at the moment the program starts, a native tape
    boot with the quick start: memory, stack contents (return addresses),
    firmware variables, the deck (stopped or playing, and its position),
    registers that matter. The X1 serves a 46-byte stub as the cartridge
    program; it copies the real program with the firmware's own ROM copy
    routine, writes the tape boot's return address (0083) at FFFE and jumps
    into the firmware's own tape-boot ending. Without it, Zero Fighter's
    copy-protected loader read FFFE to find the IPL's tape routine and
    crashed. The deck is handed over **stopped, just after the program**,
    because the IPL's tape routine stops it there.
15. **Exclude programs that touch the firmware's workspace or stack.**
    Programs that load over the stub, the firmware variables or the stack
    often do it on purpose (3D Bomberman overwrites the tape routine's
    stack so its `RET` starts the game). Those play normally (X1: programs
    must end at or below FFA0; 10 of 124 tapes).
16. **Fall back transparently.** BASIC programs, data tapes, bad
    checksums, no sync within a time limit, excluded load ranges: the tape
    is presented to the deck exactly as without quick start, and the
    cartridge reads as absent (FF).
17. **Mount, reset, disarm.**
    - A tape mounted after the firmware passed its cartridge check (at a
      menu, in BASIC) requests a machine reset, so it boots.
    - A user reset boots an eligible tape again.
    - Mounting a boot disk afterwards, or ejecting the tape, disarms quick
      start: the newest medium boots.
18. **Default on only after a corpus sweep on hardware.** Load every
    machine-code tape of the corpus on a MiSTer with quick start, take
    screenshots after the first program and after the rest has loaded,
    and compare the failures with turbo only. Fix or exclude every
    difference before making quick start the default.

### Tape status bar

19. **What it shows:** `TAPE ▶ m:ss/ m:ss x5` and a progress bar, in the
    bottom-left corner of the picture:
    - elapsed time from the stream cursor (samples played ÷ sample rate),
      total time from the image length, both saturating at 99:59;
    - `x5` only while turbo is actually active (not for a tape played at
      1x because its rate is too high);
    - a 64-step bar, 128 pixels wide, filled in proportion to the position.
20. **When:** only while a tape is loaded and the deck plays. It disappears
    when the deck stops, so it never covers the game.
21. **How it looks:** 8×8 font, one line of 21 characters and the bar below
    it in a black box, 4 pixels from the left and bottom edges of the
    active picture. White text, green fill, dark grey track. Doubled
    horizontally on pictures at least 512 pixels wide and vertically on
    pictures with at least 300 lines, so it has the same size on screen in
    every mode.
22. **It never changes the machine.** It is mixed into the core's RGB after
    the machine and before the framework's scaler. The machine, its video
    timing and its memory are untouched.
23. **Measure the picture, don't assume it.** Find the active width and
    height by counting pixels between blanking edges each frame, so the bar
    follows mode changes (X1: 320/640 wide, 200/400 lines).
24. **One word across clock domains.** Compute the times and the fill in
    the system clock, pack them into one word (loaded, playing, turbo,
    fill, elapsed, total) and hand it to the video clock with a toggle
    handshake; the renderer holds the last word it took.

## Other machines

The rules hold everywhere; what changes is where the machine keeps its
timebase, its motor and its boot paths.

| If the machine ... | then |
|---|---|
| times bits with CPU loops (X1, MZ, Spectrum, CPC, MSX BIOS) | speed up the CPU enable and the samples (rule 7). |
| times bits with a hardware timer (C64 CIA timers + FLAG, VIA timers) | the timer's clock must run N times faster together with the CPU; check every other user of that timer while the tape plays. |
| decodes the tape in a chip with its own clock (BBC serial ULA, Atari POKEY) | speed up that chip's clock and the samples. If its clock is shared with something that must not change (a video-derived clock), keep turbo off. |
| times bits with video interrupts | speeding them changes the display; either accept a fast, unsynced picture while loading or keep turbo off. |
| has no motor control (Spectrum) | there is no "deck plays" signal: turbo while the stream is consuming samples and the CPU is in the firmware's tape routine (a PC range), or offer turbo as a manual button. Say which in the README. |
| has a cartridge or expansion-ROM boot checked before the tape (X1, MSX, C64) | quick start through it (rule 11). |
| has no such path | no quick start; turbo only. Patching the firmware or trapping its routines is a different feature with different risks; do not call it quick start. |
| has real audio tapes (WAV) | decode the waveform to levels exactly as the machine's input circuit would (comparator, threshold, polarity) before both turbo and quick start; turbo still plays the same levels faster. |
| has tapes without a known length (a live audio input) | show elapsed time only, no total and no bar. |

## Testing

- **Unit tests** for each module with a real stream on a simulated SD
  slot: rates, fill, the clock-domain handoff, the quick-start check, boot,
  rewind, reset request, disarm and every fallback. Keep a few deliberate
  mutants (a guard removed, a byte released too early) that the test must
  reject.
- **Machine simulation** with the native firmware and real tapes: time to
  the game's title at Normal, turbo and quick start; no underflow; the deck
  state afterwards. Trace the I/O when something stops: a loader that
  sends no deck commands and never reads the tape port has crashed.
- **Corpus decode statistics** from the throwaway decoder (rule 12): how
  many tapes quick start can take and why the rest cannot.
- **Hardware:** the corpus sweep (rule 18), plus mounting a tape at the
  firmware's menu (reset request) and a BASIC tape (fallback).

## X1 results (October 24, 2026)

| Tape | Normal | 5x | 5x + quick start |
|---|---|---|---|
| Yellow Cab (one 52 KB block, 8 kHz) | instructions at about 260 s | title 66 s | title 25 s, instructions 40 s |
| Zero Fighter (128-byte loader, then its own loader) | demo at about 70 s | title 34 s | title 36–42 s (first program is tiny) |
| Pock-Kun (BASIC) | "File mode error" | same | same (fallback) |

Of the 163 tapes in MAME's X1 list, 124 have a machine-code first program
(59 single-block: loaded at once; 65 with more data after it: the rest at
5x), 35 are BASIC and 4 are data tapes. 10 of the 124 load above FFA0 and
are excluded from quick start (rule 15).
