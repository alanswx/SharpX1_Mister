# CSP (Takeda) X1 / X1turbo / X1turboZ vs SharpX1_Mister release core: behavioural audit

Read-only audit, 2026-10-20 (source reading only; nothing was run). No files in either repo were edited.

**Superseded ranking:** a second pass checked every item against our RTL and a second source (MAME, xmil, X1-Techknow, x1center); see [CSP_X1_AUDIT_VERIFIED.md](CSP_X1_AUDIT_VERIFIED.md) for the corrected ranks (A 23, A? 1, B 10, C 11, X 2) and the citation fixes. The buckets below are the original, unverified reading.

Follow-up the same day: 1FB0 readback (part of A6) is implemented; Kohakuiro no Yuigon needed it. See `MODEL_SELECT_STATUS.md`.

Sources:
- CSP: `/Users/alans/dev2/common_source_code/src/vm/x1/`. Line numbers are from CR-stripped, SJIS-to-UTF-8 copies; the line count is unchanged.
- Ours: the working tree of `/Users/alans/dev2/SharpX1_Mister` at commit 6aaa7e8 plus an experimental 320x400 palette edit that was later reverted, so `rtl/sharpx1.v` line numbers may be off by about ten lines.
- Release core: `sharpx1_turbo_z_font_single`. The `sharpx1.sv:501-508` instantiation enables:
  - TURBO, X3 single clock, DMA + completion/restart IRQ, FM + FM CTC, cassette, raw 2D
  - the Z video set (palette, multimode, internal8, text CPU) with runtime model
  - TURBO_KANJI/RENDER plus Z_KANJI and EXTERNAL_FONT
- The release core does not enable:
  - RTC_ENABLE, TURBO_SIO or TURBO_Z_EFFECT_CPU
  - wide D88, HD select/media or strict FDC timing

Cross-checks: MAME `refs/mame/src/mame/sharp/x1.cpp`, and our docs that cite X Millennium (xmil) and Techknow.

Buckets:
- **A**: we are probably missing it or wrong.
- **B**: we are probably more correct.
- **C**: unknown.

Each bucket is ordered by likely user impact.

---

## A. Probably missing or wrong in our core

### A1. Kanji ROM I/O ports 0E80-0E82 are not implemented

- **CSP:** `x1.cpp:391-392` maps E80/E81 reads and E80-E82 writes.
  - `display.cpp:1434-1477`: E80/E81 write the address latch, and E82 latches the pointer.
  - Reads of E80/E81 return the left/right glyph bytes and auto-increment after both are read. With a zero high byte, they return the JIS-to-address conversion.
- **Ours:** there is no decode. `rtl/sharpx1.v` di mux (around lines 918-948) has no 0E8x entry, so reads return FF.
  - `docs/KANJI_CG_ACCESS_STATUS.md:9` says "the independent 0E80..83 protocol is not implemented".
  - `rtl/x1_adec.v:168` has a legacy chip select only.
- **Why A:** CSP and MAME (`x1.cpp:1396`) both implement it. MAME's TODO names Might & Magic as a user.
- **Affected:** software that draws Kanji into GRAM through the ports, such as adventure games and Japanese utilities on X1 and Turbo. Exact address/latch semantics are disputed (MAME marks them FIXME), but having nothing at all is certainly wrong.

### A2. Release core will not run at all without a Kanji font upload

- **Ours:** `rtl/x1_z_kanji_machine.sv:57` sets `pause_request = reset_request || ioctl_download || !loaded`, which holds the machine in reset until the font is loaded. `docs/MODEL_SELECT_STATUS.md:143` confirms "without which the release core's screen stays black". This applies in every model, X1 mode included.
- **CSP:** `display.cpp:59-76` simply leaves Kanji blank when no ROM file is present, and everything else runs.
- **Why A:** this is a usability and compatibility gap rather than a hardware question. A missing Kanji ROM should mean blank Kanji, not a dead machine.
- **Affected:** every title, for users without a Kanji dump.

### A3. Kanji text display limited to high-scan, 25-row, 16-raster, normal-size cells; level 2 is blank

- **CSP:** `display.cpp:1044-1050` renders any KVRAM bit-7 cell through `adr2knj_x1t` (`display.cpp:1521-1564`, which covers both levels).
  - This works in every scan and row mode.
  - In 200-line mode, `display.cpp:1061-1078` uses shift -1, i.e. even rows (also xmil makechr), and vertical double follows the attribute.
- **Ours:** `rtl/legacy/x1_vid.v:552-554` latches eligibility only when all of these hold: high scan, `!text_y2`, `!underline`, not attribute 6/7, R9=15 and R6=25. Ineligible cells are blank.
  - The release core uses the Z_KANJI path, so the older low-scan TURBO_KANJI_RENDER path is not used.
  - Our docs say level 1 only (`scripts/prepare_z_kanji.py`; AGENTS.md).
- **Why A:** CSP and xmil both display 200-line Kanji and level 2.
- **Affected:** Japanese text in 15 kHz mode, in 20-row or 12-row layouts, double-size Kanji, and level-2 characters.

### A4. Turbo Z CPU palette writes ignored or misrouted in 640x200/64 and 320x200 64x2 (C64) modes

- **CSP:** `display.cpp:163-180` accepts writes whenever AEN && APEN && !APRD. `get_zpal_num` (`display.cpp:1335-1373`) remaps the index per mode:
  - hireso 80 columns: `&0x888`, replicated
  - hireso 40 columns: `&0xccc | >>2`
  - low-res 80 columns or C64: `&0xccc`, and `>>2` when C64 and 1FD0 bit 4 is set (the second bank)
- **Ours:** `rtl/sharpx1.v:433-434` admits palette RAM access only when **1FB0 == 80h exactly** and the mode is low-scan 40-column, internal8 or reduced (the new 320x400 path).
  - With 1FB0 = 90h (C64), writes are not admitted.
  - In low-scan 80 columns (640x200), the write falls through to the *digital* palette (`I_PAL_CS && !z_palette_selected`, around `rtl/sharpx1.v:1295`), corrupting 1000-1200 digital colours.
  - Fixtures work around this by programming in 40-column mode first (AGENTS.md).
- **Why A:** native software is free to program the palette while in these modes. MAME (`x1.cpp:983-990`) also remaps the index.
- An experimental 320x400/64 remap (`(i&CCC)|(i&CCC)>>2`) was tried and reverted: Kohakuiro turned out to use 640x400/8, and no software exercises 320x400 CPU writes yet. All three reduced modes remain open; which display-index convention to remap to is item C1.
- **Affected:** Z titles using 64-colour modes. Ys III is a Z title (MAME notes); others are unknown.

### A5. Z analog video switched off whenever BLACK (1FE0) is non-zero, or SCRN bit 2 or bit 7 is set, or 1FB0/1FC5 hold any bits beyond 80/90 and 80/88

- **Ours:**
  - `rtl/sharpx1.v:395-402`: `z_video_enabled` requires `turbo_black_video==0`, `controls[7:1]==0`, `!scrn[2] && !scrn[7]`, and analog_mode exactly 80h or 90h.
  - The 90h case is also limited to low-scan 40-column.
  - When any of these fail, the screen silently reverts to digital 8-colour.
- **CSP:** analog rendering depends only on AEN (`display.cpp:765, 775`), plus C64 for 64x2.
  - Text blackclip is applied in analog mode (`get_zpriority`, `display.cpp:1390-1395`).
  - KSEN underline is drawn in analog mode (`display.cpp:1212-1235`).
  - C64 in hireso or 80 columns is simply ignored, so analog rendering continues.
- **Why A:** whatever the exact native blackclip semantics are, dropping to digital colour is very unlikely to be right.
- **Affected:** Z software that also uses Turbo blackclip, underline or 12/20-row modes, or writes extra bits to 1FB0.

### A6. Turbo Z register readback missing

- **CSP:**
  - `display.cpp:410-460`: 1FB0 (zmode1), 1FC1-1FC4 (adjust, mosaic, chroma key, scroll), 1FC5 (zmode2), 1FD0 and 1FE0 (mode1, mode2) are all readable on Z.
  - `display.cpp:288-312`: 1FC1-1FC4 writes are stored, gated by AEN.
- **Ours:** none of these are in the di mux (`rtl/sharpx1.v:918-948`), so they read FF.
  - `x1_z_effect_registers` exists only behind TURBO_Z_EFFECT_CPU, which the release core leaves off.
  - 1FC0 and 1FB9-1FBF reads are implemented.
- **Why A:** CSP and MAME (`x1.cpp:1407`: 1FB0 r/w, "Z only") agree.
- **Affected:** Z-detection routines that write 1FB0 and read it back would conclude "not Z". Effect rendering is absent in both emulators, so only the readback matters.

### A7. Sub-CPU E3 "game key" command always returns zeros

- **Ours:** the MR16 firmware command table has E3 → `host_w3, game_key` (`bios/reference/fw_subcpu/x1sub.asm:700`). But `F_GAME_KEY` is commented out (`x1sub.asm:21`), and the LST shows the update code assembled out (`x1sub.LST:1134`). So `game_key` is never written.
- **CSP:** `psub.cpp:533-560` fills 3 bytes from the matrix (QWEADZXC, keypad, ESC/1/-/+/*/TAB/SPACE/RET) in keyboard mode B. The real 80C49 firmware path in `sub.cpp` does the same in ROM.
- **MAME:** `x1.cpp:607-611` implements it too.
- **Affected:** Turbo games that read simultaneous keys through E3 lose keyboard control. Specific titles were not verified.

### A8. RTC/calendar does not run in the release core

- **Ours:** RTC_ENABLE is off. `docs/RTC_MACHINE_STATUS.md:6-7` says "The default machine still has the static-clock defect". `docs/CASSETTE_STATUS.md:159` lists "a running RTC (Rally-X seed)" as open.
- **CSP:**
  - The real-sub path uses a uPD1990A, and the ROM is patched with the host year (`x1.cpp:472-479`).
  - The pseudo-sub path seeds from host time and ticks every second (`psub.cpp:185, 280-287`).
- **Affected:** BASIC TIME$/DATE$, and games that seed their RNG from the clock (Rally-X noted).

### A9. No GRAM/VRAM access wait states, and no 1-wait on sub-CPU/PSG I/O

- **CSP:**
  - `iobus.cpp:106-200, 254-283, 317-331`: every GRAM read or write takes a position-dependent wait from Mr.Sato's hardware-measured tables (`io_wait.h:16-17`, "based on x1_vwait_20120507 by Mr.Sato"; `io_wait_hireso.h` for 24 kHz). Separate 40 and 80 column tables, with a 2112-clock period.
  - `iobus.cpp:243-247, 305-309`: I/O to 1900/1B00/1C00 takes 1 wait.
- **Ours:** GRAM is dual-port with no WAIT (`rtl/sharpx1.v:1250-1252`), and there is no I/O wait for sub/PSG. `docs/SHARP_X1_TODO.md:1743` lists wait-state validation as open.
- **Why A:** CSP's tables are measurement-derived. Ours has no evidence for zero waits.
- **Affected:** graphics-heavy games and demos run faster than real hardware; raster or beam-timed code may desync.

### A10. Turbo bank memory (0B00) is absent

- **CSP:**
  - `x1.cpp:387` maps the port.
  - `memory.cpp:90-96, 141-142, 148-161`: bit 4 = 0 maps one of 16 × 32 KiB banks (`extram[0x90000]`, `memory.h:34`) over 0000-7FFF, and the register is readable.
  - `memory.cpp:57-58`: resets to 10h.
- **Ours:** not decoded, and RAM is 64 KiB (`rtl/sharpx1.v:837`). `docs/TURBO_IMPLEMENTATION_PLAN.md:141` treats it as an optional expansion.
- **Why A:** MAME also implements it (`x1.cpp:1393`).
- **Affected:** software or OSes that probe and use bank RAM (RAM disks, larger programs). Whether every Turbo model has it is unclear.

### A11. Z80 DMA refuses to run when the program uses features our engine marks unsupported

- **Ours:** `rtl/x1_dma.sv:194-202`. The `unsupported` flag blocks ENABLE for:
  - WR1/WR2 timing bytes (`timing_a_set || timing_b_set`)
  - some interrupt-control combinations
  - non-byte transfer/search with match stop
  - mode 11
- **CSP:** `z80dma.cpp` accepts these. It uses a generic Z80 DMA with timing ignored and full search, interrupt and restart support.
- **Note:** our hardware sweep booted all DMA disk titles tested, so the common paths are covered.
- **Affected:** any title that programs a variable-timing byte (a common Zilog idiom) or interrupt-on-match. The DMA would silently never start.

### A12. 2HD media, 4 drives and FDC density switching absent

- **CSP:**
  - `floppy.cpp:57-95`: IN 0FFE switches to 2HD/360 rpm (or 1.44M) and IN 0FFF to 2D/2DD.
  - `x1.cpp:773-795`: drive type follows media type at mount.
  - `x1.h:52` and `x1.cpp:481-494`: MAX_DRIVE 4.
- **Ours:**
  - 2 physical drives (`rtl/sharpx1.v:1019,1028`).
  - Mounts over 1 MiB are rejected (`sharpx1.sv:307`).
  - FFE/FFF are no-ops, and HD select/wide-D88 are off in the release core (`docs/WIDE_D88_STATUS.md`, `docs/TURBO_HD_DISK_PLAN.md`).
- **Affected:** 2HD-distributed Turbo software, such as the Fast S-OS turbo dumps in `docs/RESEARCH_FINDINGS_20261018.md`, and 3- or 4-drive setups.

### A13. FDC READ TRACK, WRITE TRACK and FM-density sectors unsupported

- **CSP:** `mb8877.cpp` supports Type III read/write track and FM/MFM per sector, using D88 density flags. Selection is in `floppy.cpp:61-70`.
- **Ours:**
  - `docs/D88_WRITE_METADATA_STATUS.md:47`: READ TRACK returns RNF.
  - WRITE TRACK is unsupported (`fmt_wp`, `rtl/vendor/wd1793.sv:1609`).
  - `docs/DISK_STATUS.md:32-33`: FM selection is rejected.
- **Affected:** disk formatting (BASIC FORMAT, game save disks), copy protection that reads tracks or uses FM tracks.

### A14. Mouse (SIO channel B) and SIO absent in the release core

- **CSP:**
  - `mouse.cpp:20-38`: on an SIO channel B RTS H→L, the mouse injects a 3-byte packet.
  - The Turbo SIO is at 1F90 (`x1.cpp:421`); the X1 uses the CZ-8BM2 at 1F98/1FA8 (`x1.cpp:436-437`).
  - SIO is first in the Turbo daisy chain (`x1.cpp:359`).
- **Ours:** TURBO_SIO is off and there is no mouse. The CZ-8BM2 CTC at 1FA8 is not decoded in X1 mode.
- **Affected:** mouse-driven Turbo tools and games, and serial/MIDI software.

### A15. X1 mode: 1-wait M1 while the IPL is mapped

- **CSP:** `memory.cpp:77-83` (`fetch_op` wait = `m1_cycle`, X1 build only), and `memory.cpp:61,105,116`.
- **Ours:** no M1 wait. `docs/CSP_MAC_REFERENCE_STATUS.md:105-111` measured 16.5 µs in CSP against 14.75 µs in ours.
- **Why A, weakly:** CSP's choice is deliberate and Sato-derived. It is still unverified on hardware.
- **Affected:** IPL timing only; low impact.

### A16. Reading 1E00 also disables the IPL ROM

- **CSP:** `memory.cpp:129-139` ("thanks Mr.Sato", i.e. hardware-observed).
- **Ours:** writes only (`rtl/sharpx1.v:587`).
- **Affected:** loaders that use IN to bank out the ROM; low impact.

### A17. Expansion devices absent

| Device | CSP | Ours | Impact |
|---|---|---|---|
| EMM | 0D00-0D03, 24-bit auto-increment address, 16 MiB (`x1.cpp:389`, `emm.cpp:57-94`, `emm.h:20-26`) | Absent (`docs/CORE_STATUS.md:69`) | Software using EMM as a RAM disk |
| CZ-8RB ROM BASIC | 0E00-0E03 (`cz8rb.cpp`) | Absent | Low |
| SASI HDD | 0FD0-0FD3 with DMA DRQ (`sasi.cpp`, `x1.cpp:393`) | Absent; the DIP "SASI" boot setting is cosmetic | Hard-disk users |
| Second CZ-8BS1 | 0708/0709 + CTC 070C (`x1.cpp:380-385`) | Absent | Two-OPM music |
| Printer | PPI port A/strobe (`x1.cpp:211-215`) | Absent | Low |

### A18. Cassette transport limits

- **CSP:** `datarec.cpp` plus sub-CPU control (`sub.cpp:110-133`, `psub.cpp` E9) support record, FF/REW, APSS, the old TAP format and CAS/WAV, and tolerate length errors.
- **Ours:** read-only new-format TAP, no FF/REW except by remount, no APSS, no record. Old "format 0" TAP is unsupported, and the exact-length rule rejects Car Chase (`docs/CASSETTE_STATUS.md:156-167`).
- **Affected:** Car Chase, Cannon Ball (old format), and tape saves.

### A19. CRTC register reads return FF

- **CSP:** `hd46505.cpp` `read_io8` returns R12-R17 on odd addresses and the index on even addresses.
- **Ours:** CRTC is write-only (no 18xx in the di mux).
- **Affected:** rare; light-pen or cursor-address readers.

### A20. No NMI reset and no "high-reso monitor" DIP option

- **CSP:**
  - `x1.cpp:548-552`: `special_reset` raises NMI (front-panel style reset).
  - `x1.cpp:1035-1040`: DIP bit 0 is monitor type, selectable by the user.
- **Ours:** only a full reset. DIP bit 0 is fixed at 1 (standard monitor), with only the boot device selectable (`sharpx1.sv:218-223`).
- **Affected:** booting into 24 kHz mode (Turbo BASIC high-res start), and software that hooks NMI.
- **Status (October 22, 2026):** the monitor DIP is now the OSD `Monitor` option (`93a72ce`); NMI reset is still open.

### A21. Timer commands D0-DF share a single buffer in our firmware

- **CSP:** `psub.cpp:510-530` keeps 8 separate timer buffers.
- **Ours:** `x1sub.asm:671-680` writes and reads `tmr_dmy` for all 8 timers.
- **Affected:** TV-timer utilities only; very low impact.

---

## B. We are probably more correct

### B1. Palette writes stall until vertical blank (lease), not horizontal blank

- **Ours:** `rtl/sharpx1.v:465`: `x1_z_palette_owner` with `video_blank(VBlank)`.
- **CSP:** `display.cpp:166-170, 539, 598-604` waits only to the next horizontal blank plus 24 clocks.
- **Why B:** MAME's comment (`x1.cpp:980-981`) reads "cannot do mid-frame scanline update (-> bus request signal when accessing this on non-vblank time)", which supports ours. Our docs still call the policy provisional.
- **Risk:** palette uploads during active display are much slower in ours.

### B2. Z palette changes take effect immediately

- **Ours:** the palette RAM is read live by the display.
- **CSP:** applies 4096 palette changes only at the start of a frame (`display.cpp:589-592`, `update_zpalette`). That is an emulator simplification.

### B3. Text blink derived from the sub-CPU CLK1 signal

- **Ours:** `rtl/sharpx1.v` `display_blink` comes from the sub-CPU's `O_clk1`.
- **CSP:** a frame counter `cblink & 0x20` (`display.cpp:547, 997`).
- **Why B:** ours follows the hardware signal path.

### B4. Character PCG/CG reads and writes are beam-addressed through a real CRTC/video pipeline

- **CSP:** `display.cpp:724-755` estimates the beam position from clocks since VBLANK, with a "cpu detects vblank" hack in `iobus.cpp:285-291`.
- **Ours:** `x1_pcg_access`.
- **Why B:** ours uses the real pipeline rather than an estimate. Native WAIT phase is still open on both sides.

### B5. Turbo Z palette readback addressing

- **Ours:** `x1_z_palette_access.sv`: the IN port's address low byte plus the selector from the last OUT, following Techknow printed 157-159.
- **CSP:** `display.cpp:177-178, 380-393` latches the index only from an OUT to 1000 in read mode. 1100/1200 OUTs are ignored, and every IN returns that entry regardless of its port address.
- **Why B:** ours is documentation-based. CSP's version is a shortcut.

### B6. Scan mode taken from the 1FD0 bit 0 hardware signal

- **Ours:** `x1_gram_address.sv`, `x1_vid` `I_TURBO_HIGH_SCAN` use 1FD0 bit 0.
- **CSP:** `display.cpp:557-559` and `iobus.cpp:211-214` infer hireso from CRTC vt_total > 400.
- **Why B:** they agree for sane software, but ours uses the actual mode bit rather than an inference.

### B7. Z digital mode (AEN = 0) keeps pure digital colours

- **CSP:** in the Z build, digital colours still pass through `zpalette_pc` (`display.cpp:834, 863, 910, 945`; `update_zpalette` `display.cpp:1375-1386`). Text goes through the text palette and graphics through 4096-palette entries 000/00F/0F0…
- **Ours:** digital output stays digital.
- **Caveat:** this is listed under B only weakly; it could equally be C. No document says Z compatibility mode routes through the analog palette.

---

## C. Unknown (with the evidence needed to settle each)

### C1. Reduced-mode palette index convention

- **CSP:** `display.cpp:1188-1201, 1247-1275, 1352-1358`. Bank-only indices:
  - 640x200/64 displays at `&0xCCC` with no replication.
  - 64x2 mode puts screen 0 at `&0xCCC` and screen 1 at `>>2` (the 333 positions).
- **Ours:** `rtl/x1_z_graphics.sv:73-90`. Replicated effective pairs `{G3G2G3G2…}` for modes 1, 2, 3 and 5, citing Techknow printed 161.
- **Consequence:** the two give different colours for the same palette RAM contents.
- **To settle:** a Z hardware capture of a known palette in 64x2 and 640x200, or native Z software screenshots.
- **Note:** this decides how A4 should remap writes.

### C2. 640x400/8 palette store

- **Ours:** a separate internal 8-entry store (`docs/TURBO_Z_INTERNAL8_STATUS.md`).
- **CSP:** `get_zpal_num` writes into the shared 4096 table at the replicated `&0x888` index (`display.cpp:1340-1346`).
- **To settle:** Z hardware. Write in 640x400, switch to 4096 mode, and see whether the 4096 entries changed.

### C3. 1FC0 priority field 11 (paired)

- **CSP:** default case is text > front > back (`display.cpp:1418-1420`).
- **Ours:** undefined, which shows as backdrop or black (`x1_z_layer_order.sv:32`).
- **Ours also:** 1FC0 is ignored outside 320x200 layouts (`sharpx1.v` composition), while CSP applies zpriority in every AEN mode.
- **To settle:** Techknow Appendix A plus hardware.

### C4. 16-row paired PCG (KVRAM & 90h) layout

- **CSP:** gaiji rows interleave even/odd codes: row r = pcg[(T&~1)|(r&1)][r>>1] (`display.cpp:243, 1029-1034, 715-718`). It is displayed in any scan mode.
- **Ours:** top/bottom halves: `{T[7:1], row[3]}` (`x1_vid.v:486`, `x1_pcg_selector.sv:58`, following xmil). It is displayed only in high scan.
- **Schematic:** `{DCHA[7:1], C4Y..C1Y}` (`docs/TURBO_PCG_CONTRACT.md:45`) allows either.
- **To settle:** a hardware test or IX0522CE behaviour.

### C5. High-speed PCG fallback cell when no candidate matches

- **CSP:** 3FF (`display.cpp:669-670, 709-710`), as MAME does.
- **Ours:** 7FF, following xmil (`x1_pcg_selector.sv:43-50`).
- **Ours also:** returns 0 until all four selector attribute cells have been written once since power-on.
- **To settle:** hardware.

### C6. SCRN (1FD0) bit 2

- **CSP:** bit 2 selects the 16-raster ANK font (FONT16_EN = mode1 & 5) and a 0x400-stride, 16-raster GRAM layout (`display.cpp:22, 1051-1062, 1164-1168`).
- **Ours:** global vertical text expansion, following xmil, with GRAM unchanged (`x1_text_raster.sv`, `x1_gram_address.sv`; `docs/TURBO_TEXT_RASTER_STATUS.md`).
- MAME has yet another interpretation.
- **To settle:** a hardware capture of BASIC WIDTH 40,12 / 80,20.

### C7. KSEN (1FD0 bit 7) underline in analog Z mode

- **CSP:** assumes B = 1111 (`display.cpp:1212`, explicitly "uninvestigated").
- **Ours:** disables Z video (part of A5).
- **To settle:** hardware.

### C8. DMA access to Z registers, palette and FM

- **CSP:** DMA I/O reaches everything. `iobus.cpp:216-222` updates zmode1 and zmode2 even on DMA writes, and display's default `write_dma_io8` calls `write_io8`.
- **Ours:** CPU-only decode (`rtl/sharpx1.v:321-322`); FM excludes DMA (`:303`).
- **To settle:** native Z software that uses DMA palette uploads, or a hardware test. `docs/MODEL_SELECT_STATUS.md` already calls our choice provisional.

### C9. FM CTC presence on Turbo Z

- **CSP Z build:** 0704 is a read-back flip-flop and the CZ-8BS1 CTC is not mapped (`x1.cpp:374-378`). It is still in the daisy chain.
- **Ours:** FM CTC at 0704-0707 in all models.
- **Techknow Ch.8:** Turbo FM tempo uses the internal CTC at 1FA0, and the X1 uses 0704 (`docs/RESEARCH_FINDINGS_20261018.md`).
- **To settle:** a Z schematic or software probe behaviour, i.e. how FM-detection on Z decides board versus built-in.

### C10. FM status read at 0700

- **CSP:** returns 00 (`x1.cpp:372`).
- **Ours:** returns the YM status on 0700 and 0701 (`x1_fm_decode.sv` decodes 0700-0701 as one slice).
- **Note:** the real YM2151 ignores A0 on reads, but the board decode is unknown.

### C11. Digital palette and priority reset values

- **CSP:** initialises 1000/1100/1200 = AA/CC/F0 (identity) once, and never resets them (`display.cpp:104-109`; the reset at `display.cpp:131-155` omits pal).
- **Ours:** clears palette and priority to 0 on every reset (`x1_vid.v:600-608`).
- **Consequence:** graphics are black until software programs the palette. The IPL or BASIC normally does this.
- **To settle:** a hardware power-on/reset read of the graphics colours.

### C12. X1 IPL mirroring

- **CSP X1:** 4 KiB IPL mirrored through 0000-7FFF (`memory.cpp:45-49`).
- **Ours X1 mode:** 1000-7FFF reads FF while the IPL is enabled (`rtl/sharpx1.v:918`; `docs/BASE_X1_CONTRACT.md`).
- **To settle:** an X1 hardware read.

### C13. Turbo DIP 1FF0 upper nibble

- **CSP:** `(monitor & 1) | drive << 1`, so bits 4-7 are 0 (`x1.cpp:1037-1039`).
- **Ours:** MAME's F1/F3/F5/FF, so bits 4-7 are 1.
- **Docs:** the CZ-880C manual p.79 lists SW4-SW6 meanings, but the polarity is inferred.
- **To settle:** hardware.

### C14. FDC motor and READY timing

- **CSP:** 560 ms spin-up before READY and a 1.5 s motor-off delay, with one motor for all drives (`floppy.cpp:30-53`).
- **Ours:** READY is immediate, with a 1.2 s hold per drive (`x1_disk_control.v`).
- **To settle:** a drive datasheet or hardware trace.

### C15. Turbo main CTC mirror at 1FA8-1FAB

- **Ours:** `rtl/sharpx1.v:591` ignores a3, so the CTC appears at 1FA8-1FAB too.
- **CSP Turbo:** decodes only 1FA0-1FA3.
- **To settle:** a schematic decode check.

### C16. Reading 1700

- **CSP:** returns PCG green. Its own comment (`display.cpp:405`) says real 1400 and 1700 are the same function (CG ROM).
- **Ours:** also returns green.
- Both match each other; hardware may differ.

### C17. ANK16 0x7F-0x9F and 0xE0-0xFF glyphs

- **CSP:** patches the xmil built-in glyphs over the loaded ANK16 (`display.cpp:56-57`, `x1.h` tables).
- **Ours:** uses the user's file as is.
- Ours is correct only if the dump is complete; the patch exists because common dumps lack those glyphs.

### C18. Z 1000-1200 writes with AEN = 1 but APEN = 0

- **CSP:** the write is dropped (`display.cpp:165-180`).
- **Ours:** goes to the digital palette.
- **To settle:** hardware.

### C19. Interrupt daisy chain

- **Order:** CSP Turbo is FM CTC > SIO > DMA > CTC > sub (`x1.cpp:352-367`). Ours is FM CTC > DMA > CTC > keyboard. They are the same apart from the absent SIO, and both match Techknow Ch.6.
- **X1:** CSP is SIO > CTC (CZ-8BM2) > FM CTC > sub. Ours is FM CTC > keyboard.
- No action is needed beyond A14.

---

## Equivalent (checked; no meaningful difference found)

| Area | Detail |
|---|---|
| DAM | Arm on PC5 H→L; any IN clears it; DAM writes 0000/4000/8000/C000 hit the documented plane sets. Ours: `x1_dam_control.sv`, `sharpx1.v:1250-1252`. CSP: `iobus.cpp:58-67, 106-200, 257` |
| VRAM map | Text/attribute/KVRAM, with 3800 mirroring text in X1 mode |
| Digital palette | Priority 1300 and Turbo blackclip bits 3/4/5 (ours adds bit 6 border) |
| Text rendering | Reverse/colour masking and horizontal/vertical double |
| GRAM layout | Turbo GRAM page bits 3/4; high-scan interleave (`x1_gram_address.sv` vs `display.cpp:1161-1168` without bit 2) |
| Z 4096 mode | Index bit order: G3 = page 0 @ offset, G2 = page 0 @ +400h, G1/G0 = page 1 (`x1_z_graphics.sv:85-87` vs `display.cpp:1248-1255, 899`) |
| Z text palette | 1FB9-1FBF format (GG RR BB in bits 5:0) |
| Z priority | Fields 00/01/10 |
| Main CTC wiring | Ch1/ch2 at 2 MHz; ZC0 cascades to TRG3 |
| FM CTC wiring | ZC0 → TRG3 |
| PSG and joystick | PSG clock 2 MHz; joystick bit map (button 1 → bit 5, button 2 → bit 6) |
| FDC | FM/MFM select via FFC/FFD reads; INTRQ not connected to the CPU; FDC DRQ → DMA RDY |
| Sub-CPU interrupt | Vector equals the sub output byte |
| Turbo IPL | 32 KiB IPL; PPI PB4 = ROM-disabled flag |
