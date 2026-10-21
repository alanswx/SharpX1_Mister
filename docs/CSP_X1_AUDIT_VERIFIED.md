# CSP X1 audit: verified re-ranking (2026-10-20)

Scope: the 47 items in `docs/CSP_X1_AUDIT.md`. Each was checked against our RTL in the
working tree (uncommitted 1FB0 readback included) and against CSP
(`../common_source_code/src/vm/x1/`), plus at least one second source: MAME
(`../FM-7_MiSTer_alanswx/refs/mame/src/mame/sharp/x1.cpp`, `x1_v.cpp`), xmil-libretro,
neetan, X1-Techknow scans, Sharp manuals, or Mr. Sato's x1center I/O map.

This was source and document reading only. No RTL, test or verilator file was changed;
nothing was built or run, and the CSP binary was not executed. Four parallel
sub-reviews did the per-item checks; their page and line citations are carried over
here. Doc pages are the printed page numbers unless "PDF" is stated.

Follow-up, October 21: A2 is done (the core runs with blank Kanji when no
font is loaded) and A4 is done for 640x200/64 and 320x400/64; 64x2 (90h)
writes are still refused. See `MODEL_SELECT_STATUS.md`.

Ranks:
- **A**: missing in ours, confirmed by a document or a second implementation.
- **A?**: likely missing, but only CSP (or a non-independent source) supports it.
- **B**: ours is more correct, with evidence.
- **C**: still unknown.
- **X**: the audit was wrong, or there is no real difference.
- **Done**: already implemented.

## Rank counts

| Rank | Count | Items |
|---|---:|---|
| A | 23 | A1-A18, A20, A21, C9, C11, C18 |
| A? | 1 | C6 (GRAM part) |
| B | 10 | B2, B4, B5, B6, C2, C3, C4, C5, C14, C17 |
| C | 11 | A19, B1, B3, B7, C1, C7, C8, C10, C12, C13, C15 |
| X | 2 | C16, C19 |
| Done | 0 whole items | Part of A6: 1FB0 readback is done |

Split items are counted under their main rank, with the sub-part ranks given in the
table:
- A5: KSEN sub-part C.
- A6: 1FB0 Done.
- A9: sub/PSG 1-wait A?.
- A11: impact unproven.
- A17: second CZ-8BS1 A?.
- A18: length tolerance A?.
- C3: field 11 C.
- C14: spin-up C.

## Item table

Our di mux is at `rtl/sharpx1.v` ~934-960 in the current working tree. The audit cites
918-948; the forks measured 933-963 as the file changed.

| Item | Old | New | Evidence (one line) | Sources |
|---|---|---|---|---|
| A1 0E80-0E82 Kanji ports | A | A | We have no decode. `rtl/x1_adec.v:168` is legacy and not instantiated by `rtl/sharpx1.v`. Techknow App.A p275 lists 0E80-0E82 as the **CZ-8KR external Kanji board, machine column X** (E80/E81 R=L/R data, W=addr; E82 00=EPROM/01=Kanji). The Turbo built-in Kanji is read via high-speed CG 14x0 (p276), which we have. So the impact is mostly X1+CZ-8KR software; whether Turbo also decodes 0E80 is unknown. | Techknow A p275-276; CSP `display.cpp:1434-1477`; xmil `io/cgrom.c:7-60`; MAME `x1.cpp:1396` (Turbo map only) |
| A2 font required to run | A | A | `rtl/x1_z_kanji_machine.sv:57,63` holds the reset until loaded, in every model. CSP leaves it blank (`display.cpp:59-76`); MAME uses an ERASEFF region (`x1.cpp:2318`). | RTL, CSP, MAME |
| A3 Kanji eligibility | A | A | `rtl/legacy/x1_vid.v:552-554` requires high scan, R6=25 and R9=15. Techknow p282: 1FD0 bit 2 = Kanji 16 raster/char (12/10 rows). CZ-856C UM PDF 69 (p58): Disk BASIC on a standard monitor starts at 80x12, so default Kanji is blank there. xmil `makeknj8fn` renders 200-line Kanji. Level 2 is an asset limit, not RTL (`x1_vid.v:566` carries the level bit; Techknow p151 says level 2 is optional). | Techknow p151, p282-284; CZ-856C UM; xmil; CSP `display.cpp:1044-1078` |
| A4 Z palette writes in reduced modes | A | A | `rtl/sharpx1.v:448-450` admits only 1FB0=80h with 1FC5 80/88, in low-scan 40-col or 640x400. Other writes fall to the digital palette (`:1306`). CSP, MAME `x1.cpp:969-991` and xmil `palette_o` all accept on AEN&APEN. Techknow p161 (Table 4-25): every mode except 640x400 uses the external palette RAM. The remap target is C1. | Techknow screen p161; MAME; xmil; CSP |
| A5 analog dropped on extra bits / BLACK / SCRN | A | A (KSEN part C) | Gate at `rtl/sharpx1.v:394-404`. Techknow p280 documents 1FB0 bits 0/2/3 (superimpose/capture) as legal, and bit 4 effective only in 320x200, so C64 elsewhere should be ignored rather than forcing digital. CSP (AEN only) and xmil (`crtc.c:84`, bits 7/4) do not drop on 1FE0 or SCRN2. **But xmil also goes digital on KSEN (bit 7)**, as we do. | Techknow A p280; xmil `crtc.c:84,145-180`; CSP `display.cpp:765` |
| A6 Z register readback | A | A (1FB0 Done) | 1FB0 readback is done (`rtl/sharpx1.v:420-433`). Techknow p280-282: 1FC1-1FC5 IN/OUT, 1FD0 "(IN)/OUT", 1FE0 "OUT on turbo, IN also possible on Z". MAME reads only 1FB0, 1FC5 and 1FE0 (`x1.cpp:1407-1417`); xmil reads 1FB0, 1FB9-1FC0, 1FC5, 1FD0 and 1FE0 (`iocore.c:94-131`). | Techknow A p280-282; MAME; xmil; CSP |
| A7 sub-CPU E3 game key | A | A | `x1sub.asm:21` (`;F_GAME_KEY`), fill code `:950-972` assembled out, and `rtl/sub_rom.v` matches the LST. Techknow Ch.5 p177/180/182: E3 returns 3 bytes in mode B. Mode B also prefixes 3 game-key bytes to key events (p179-180), which we also lack. | Techknow Ch.5; MAME `x1.cpp:371-380,607-611`; CSP `psub.cpp:533-560` |
| A8 RTC not running | A | A | `RTC_ENABLE` defaults to 0 (`rtl/sharpx1.v:3`, `rtl/sub_cpu.v:82`) and the release instance does not set it. The firmware EC/EE only store, and the 1 Hz hook is commented out (`x1sub.asm:330-333,739-748`). | Techknow Ch.5 p192; MAME `x1.cpp:2107,2154`; CSP `psub.cpp` |
| A9 GRAM wait / sub-PSG wait | A | A (sub/PSG 1-wait A?) | `machine_wait_n` (`rtl/sharpx1.v:299`) has no GRAM term, and GRAM (`:1255-1257`) never waits. x1center: "GRAMはVRAMサイクルスチールアクセスで…数ピクセルクロック間のウェイト", and text VRAM likewise; Turbo/Z otherwise no-wait. neetan models the Sato tables (`bus/io_wait.rs`). The 1900/1B00/1C00 1-wait appears only in CSP. TODO ref is `docs/SHARP_X1_TODO.md:1766`. | x1center l.114, 287, 5170; neetan; MAME TODO `x1.cpp:1281`; CSP `iobus.cpp` |
| A10 0B00 bank memory | A | A | No decode; RAM is 64 KiB (`rtl/sharpx1.v:856`). Techknow A p274: 0B00 T/Z expansion RAM/ROM bank, bit 4 slot/system, bits 3:0 bank, window 0000-7FFF. x1center: R/W; real boards (CZ-141SF, ZII/Z3) have **2** banks; **CZ-8FB03 (Z-BASIC) uses BML5** as a state latch. The audit's 16x32 KiB is CSP's allocation, not hardware. | Techknow A p274; x1center; xmil `memio.c`; neetan `memory.rs`; MAME (64 KiB banks, differs) |
| A11 DMA "unsupported" refusals | A | A (impact unproven) | `rtl/x1_dma.sv:194-202`. Audit misread: CSP does **not** ignore timing; CSP `z80dma.cpp:87-88` and MAME `z80dma.cpp:505,526` both honour WR1/WR2 cycle length. The inspected native disk streams use no timing bytes (`docs/DMA_REGISTER_CONTRACT.md:210-214`; Techknow Ch.7 p233-234 recipe). | CSP; MAME; Zilog contract doc |
| A12 2HD / FFE-FFF / 4 drives | A | A | 2 drives at `rtl/sharpx1.v:1036/1044`; mounts over 1 MiB rejected (`sharpx1.sv:307`); `x1_disk_control.v:24-25` decodes FFC/FFD only. Techknow A p275 lists 0FFE (2HD) and 0FFF (2D/2DD) as IN; Ch.7 p227 gives 0FFC drive 0-3. Z-BASIC CZ-8FB03 boots from 2HD. | Techknow A p275, Ch.7 p227; x1center; MAME (4 drives, FFE/FFF log only) |
| A13 READ/WRITE TRACK, FM sectors | A | A | Audit misread: `fmt_wp` (`wd1793.sv:1609`) is the write-protect output. WRITE TRACK is at `rtl/vendor/wd1793.sv:1495-1505` (write fault, no DRQ) and READ TRACK at `:1506-1511` (RNF). Techknow Ch.7 p227 Table 7-4 lists Type III; p223: standard 2HD has an FM track 0. | Techknow Ch.7; CSP `mb8877.cpp`; `docs/DISK_STATUS.md:32-33` |
| A14 SIO / mouse | A | A | TURBO_SIO is off, the mouse inputs are tied (`sharpx1.sv:344`), and `ctc_cs` needs turbo (`rtl/sharpx1.v:607`). Techknow A p279: SIO at 1F90 X/T/Z, mouse on channel B at 4800; Ch.9 p267-268: RTSB H→L returns a 3-byte packet. | Techknow A p279, Ch.9; x1center; CSP `mouse.cpp` |
| A15 X1 M1 wait with IPL mapped | A (weak) | A | No M1/IPL term in `machine_wait_n` (`rtl/sharpx1.v:299`). x1center l.114: "X1ではIPL ROM選択時にM1サイクルで１ウエイト挿入される…回路図にはそう書いてある". **Caveat:** same author lineage (Sato) as CSP's policy; MAME and xmil lack it. | x1center; CSP `memory.cpp:77-83`; `docs/CSP_MAC_REFERENCE_STATUS.md:105-111` |
| A16 IN 1E00 disables IPL | A | A | Ours is write-only (`rtl/sharpx1.v:602-603,815-817`; the audit cites 587). x1center l.3717: ROM OFF "書き込む値はなんでもよく、リードでも可". Techknow A p279 lists OUT only, and MAME/xmil are write-only. **Caveat:** Sato lineage again. | x1center; CSP `memory.cpp:129-139`; Techknow; MAME `x1.cpp:1349-1350` |
| A17 expansion devices | A | A (2nd CZ-8BS1 A?) | EMM 0D00-0D03 X/T/Z, BASIC ROM 0E00 X and HDD 0FD0 X/T/Z (Techknow A p274-275); printer on 8255 A/PC7/PB3 (p277-278). We have no decode, PPI `opa` is unconnected, and the SASI DIP is cosmetic (`sharpx1.sv:496`). The 0708 second OPM board is in CSP/xmil only. | Techknow A; x1center (EMM1-9 0D04-0D27) |
| A18 cassette limits | A | A (length tolerance A?) | Record/FF/REW/APSS are documented recorder controls (Techknow A p277, 1900 PB/PC). Audit misread: **old-format TAP is supported** (`rtl/x1_tap_sd_stream.sv:9-10,88,97`; Cannon Ball reaches gameplay, `docs/CASSETTE_STATUS.md:69`). The open "format 0" is a new-header flag. The exact-length rule (`:104`) is real. | Techknow A p277; RTL; CASSETTE_STATUS |
| A19 CRTC reads | A | C (leans X) | The HD46505R chip can read R14-R17 (manual, text extraction). But Techknow A p276 lists 1800/1801 as OUT only, MAME `x1.cpp:1332-1341` is write-only, and xmil has a dummy. Only CSP's generic `hd46505.cpp` reads. Settling it needs board RD routing. | Techknow; MAME; xmil; HD46505R manual |
| A20 NMI reset / monitor DIP | A | A | CZ-880C manual p80: NMI switch → 0066. Techknow A p283: 1FF0 bit 0 = front HIGH(0)/STANDARD(1). Ours is constant 1 (`sharpx1.sv:497`); the audit cites the OSD string at 218-223. **Our comment at `sharpx1.sv:222` calls bit 0 "interlace", which is our own misread.** | CZ-880C p80; Techknow A p283; MAME `x1.cpp:1689-1698` |
| A21 timers share a buffer | A | A (very low) | `x1sub.asm:672-680` shares `tmr_dmy`. Techknow Ch.5 p194 documents 7 independent timers (set D1-D7, read D9-DF). | Techknow Ch.5; CSP `psub.cpp:510-530` |
| B1 palette stall to VBlank | B | C (leans ours) | `rtl/sharpx1.v:478-482`. The only support is a MAME TODO comment (`x1.cpp:981-982`); xmil applies mid-frame. There is no hardware document. | MAME; xmil; CSP |
| B2 live palette | B | B | MAME updates at write (`x1.cpp:997`) and xmil logs mid-frame events, both live like ours. CSP latches at line 0. | MAME; xmil |
| B3 blink from sub-CPU CLK1 | B | C | The blink comes from **our own MR16 firmware** (`x1sub.asm:318-330`; `rtl/sharpx1.v:894-916`), not a proven 80C49 path. MAME (`x1_v.cpp:249-251`) and CSP use frame counters. | MAME; CSP |
| B4 beam-addressed PCG | B | B | Techknow screen p148 Fig 4-22 shows a hardware FPCG-WAIT released about 5 char clocks into retrace. Ours is a real-beam CDC (`rtl/x1_pcg_access.v`); CSP estimates the beam. Neither models the exact release. | Techknow p148; CSP |
| B5 palette readback addressing | B | B (weak) | Techknow p157 Fig 4-29: a separate dummy OUT then IN per component. xmil `palette_i` matches ours. CSP still selects the component by port (minor audit misread). | Techknow p157; xmil |
| B6 scan from 1FD0 bit 0 | B | B | Techknow A p282: bit 0 = 200/400-line monitor select. CSP infers it from the CRTC total; MAME uses the SCRN bits. | Techknow; MAME |
| B7 Z digital mode | B | C | Techknow p156 says only that compatibility mode accesses the palette like earlier models; the display routing is undocumented. Both give the same colours with the identity table. | Techknow p156; CSP |
| C1 reduced-mode index | C | C (doc leans ours) | Techknow p161: "invalid" bits are formed by extending valid bits, which reads as replication like `x1_z_graphics.sv:96-98`. CSP is self-inconsistent (replicates in 400-line, not in 640x200/64x2). MAME replicates when C64 is clear; xmil uses separate 64-entry tables. | Techknow p161; MAME `x1.cpp:986-989`; xmil |
| C2 640x400/8 store | C | B | Techknow p156: separate internal 12-bit x 8 palette, CPU R/W; p161: 640x400 uses it; p160: power-on values. xmil `PAL_HIGHRESO` is separate. CSP's shared table is the outlier. | Techknow p156,160,161; xmil |
| C3 1FC0 field 11 / scope | C | B (scope) / C (field 11) | Techknow A p280: field 11 is "未定義" (undefined); 1FC0 is meaningful only in multicolour 320x200, and bit 4=0 forces bit 1=0. That supports our 320x200-only scope (`rtl/sharpx1.v:510`). Neither fallback for field 11 is documented. | Techknow A p280 |
| C4 16-row paired PCG | C | B | Techknow p151 Fig 4-25: address {TX7..TX1, AB3..AB0}, so the even code is lines 0-7 and the odd code lines 8-15, i.e. top/bottom like ours and xmil. CSP interleave is wrong. Low-scan behaviour is still open (all three differ). | Techknow p151, p284; xmil |
| C5 high-speed PCG fallback | C | B | Audit misread: it cites `x1_pcg_selector.sv`, but the release uses `x1_z_pcg_selector.sv` (`rtl/sharpx1.v:1119-1127`) with exactly the 37FF/3FFF/27FF selectors and no fallback, which is what Techknow p148 describes. The CSP/MAME 3FF and xmil 7FF four-cell search is the X1EMU convention. | Techknow p148; CSP `display.cpp:653-713`; MAME `x1.cpp:815-830` |
| C6 SCRN bit 2 | C | A? (GRAM) / C (ANK font) | Techknow A p282: bit 2 = 16 raster/char (12/10 rows), set with the CRTC. CZ-856C UM p59: graphics are "200/192 dots" in those modes. Ours uses `raster[2:0]` (`rtl/x1_gram_address.sv:14-17`), so rasters 8-15 repeat 0-7. CSP uses a 0x400 stride; xmil doubles lines. The ANK glyph source (8x16 CG vs doubled 8x8) is undocumented. | Techknow; CZ-856C UM PDF 70; CSP; xmil |
| C7 KSEN in analog | C | C | CSP is "uninvestigated" (`display.cpp:1211`); xmil goes digital, as we do. No document. | CSP; xmil |
| C8 DMA to Z regs/FM | C | C | Ours is CPU-only (`rtl/sharpx1.v:323-324`, FM `:305`). CSP and MAME route DMA I/O generically. There is no Z-specific evidence, though on generic Z80 bus grounds it is close to A?. | CSP `iobus.cpp:215-222`; MAME |
| C9 FM CTC on Z | C | A | Techknow A p274: "turboZにはCTCは付いていない。ただし、0704H番地はFM音源機能のソフトウェアチェックに使う". x1center: Z has no CTC at 0704-0707, only an FM-detect latch. Ours `fm_ctc_cs` (`rtl/sharpx1.v:672`) is ungated by model. The audit framed it as unknown when Techknow states it. | Techknow A p274, Ch.8 p260; x1center; CSP `x1.cpp:372-378` |
| C10 0700 read | C | C | Techknow A p274: 0700 OUT, 0701 IN/OUT, so a 0700 read is undocumented. CSP, xmil and neetan return 00 for 0700; MAME returns status. Ours returns status on both (`x1_fm_decode.sv:13`). Low impact. | Techknow; x1center; xmil; neetan |
| C11 digital palette reset | C | A | Techknow screen p156: digital palette initial values B=AAh, R=CCh, G=F0h. Ours clears to 00 on every reset (`rtl/legacy/x1_vid.v:600-617`). IPL-reset behaviour is not stated, but power-on should be identity. | Techknow p156; CSP `display.cpp:104-109` |
| C12 X1 IPL mirror | C | C (leans ours) | Ours returns FF above 1000 (`rtl/sharpx1.v:933-935`). MAME (`x1.cpp:2305-2306,1284-1286`) and xmil also do not mirror; Techknow Ch.2 p86-87 only places the IPL at 0000-0FFF. Only CSP mirrors. The CZ-800C ROM CS was not traced. | MAME; xmil; Techknow Ch.2 |
| C13 1FF0 upper bits | C | C (narrowed) | Techknow A p283: bit 4 = SW1 (ON=0), bits 5-6 unused, bit 7 = "FD DATA". Neither our F nibble nor CSP's 0 is documented. CZ-880C p79 numbers the switches differently. | Techknow A p283; CZ-880C p79 |
| C14 motor/READY | C | B (motor-off) / C (spin-up) | x1center: MON 1→0 gives motor off after "約1.2秒" (l.2554), the same as ours (`rtl/sharpx1.v:1036`) and MAME (`x1.cpp:770`); CSP uses 1.5 s. Spin-up delay is undocumented (Techknow Ch.7 p233 says to poll READY). | x1center; MAME |
| C15 1FA8 CTC alias | C | C | Ours ignores a3 (`rtl/sharpx1.v:607`), matching MAME and xmil. Techknow A p279 and x1center put the CZ-8BM2 CTC at 1FA8, a different address from the built-in one, which leans toward a3 being decoded. The schematic was not traced. | Techknow A p279; x1center; MAME; xmil; neetan |
| C16 1700 read | C | X | Techknow A p276: 17xx IN/OUT = PCG green. Ours, CSP and MAME all return green. | Techknow; MAME |
| C17 ANK16 patch | C | B (weak) | CSP overwrites even a complete user file; xmil loads defaults and lets the file override (`font/font.c:108-123`), as we use the file. | xmil; CSP |
| C18 AEN=1, APEN=0 writes | C | A (low) | CSP, MAME (`x1.cpp:971-1001`) and xmil (`palette_o`) all drop the write; ours goes to the digital palette (`rtl/sharpx1.v:1306`). There is no hardware document; this is three implementations. | CSP; MAME; xmil |
| C19 daisy chain | C | X | Techknow Ch.6 p204: Turbo order is slots > SIO > DMA > CTC > key. Ours (`rtl/sharpx1.v:707-729`) matches apart from the absent SIO (A14). | Techknow Ch.6 |

## Items the original audit got wrong or overstated

- **A1:** It cites `x1_adec.v:168` as if it were in our machine, but it is legacy and not instantiated. 0E80 is documented as the X1 CZ-8KR external board; the Turbo reaches its built-in Kanji through 14xx high-speed CG, which we have. MAME maps 0E80 only in its Turbo map.
- **A3:** "!underline" is SCRN bit 7, not a cell attribute. "Level 2 blank" is an asset limit, not RTL.
- **A4:** The 320x400 path it cites was reverted. The real gate is `rtl/sharpx1.v:448-450`.
- **A5:** The KSEN sub-claim is not clearly wrong: xmil also drops analog on KSEN.
- **A6:** "CSP and MAME agree" holds only for 1FB0/1FC5/1FE0. MAME keeps 1FC1-1FC4 write-only and has its 1FD0 read commented out.
- **A7:** The key list follows CSP/MAME; Techknow bit 18 is keypad "/". It also missed the mode-B 3-byte prefix on key events.
- **A10:** "16 x 32 KiB" is CSP's allocation. Real boards have 2 banks, and the port is an expansion-slot bank per Techknow, not a "Turbo built-in".
- **A11:** CSP does not ignore timing bytes; both CSP and MAME honour cycle length.
- **A13:** `fmt_wp` is the write-protect output. The real READ/WRITE TRACK handling is at `wd1793.sv:1495-1511`.
- **A18:** Old-format TAP is supported (Cannon Ball plays). "Format 0" is a different case.
- **A20:** It cites the OSD string, not the DIP constant (`sharpx1.sv:497`).
- **B3:** The "hardware signal path" claim is unproven: our blink comes from our replacement firmware.
- **B5:** CSP still selects the component by IN port.
- **C1:** CSP is self-inconsistent, not a single convention.
- **C4:** "The schematic allows either" is wrong: Techknow p151 settles the high-scan layout.
- **C5:** It cites a selector module the release core does not use.
- **C6:** The xmil `updatemask` is dirty tracking, not a GRAM stride.
- **C9:** Framed as unknown, but Techknow App. A states that Z has no CTC at 0704.
- **C11:** Framed as unknown, but Techknow gives the power-on identity values.
- **C16 / C19:** There is no actual difference.
- **Line references:**

  | Reference | Audit | Actual |
  |---|---|---|
  | di mux | 918-948 | ~934-960 |
  | IPL disable | 587 | 602-603 / 815-817 |
  | FM `cpu_allowed` | 303 | 305 |
  | Z CPU decode | 321-322 | 323-324 |
  | palette owner | 465 | 478-482 |
  | `ctc_cs` | 591 | 607 |
  | GRAM | 1250-1252 | 1255-1257 |
  | RAM | 837 | 856 |
  | drives | 1019/1028 | 1036/1044 |
  | TODO | 1743 | `docs/SHARP_X1_TODO.md:1766` |
  | analog gate | 395-402 | 394-404 |

- **Our own docs/RTL comment error found on the way:** `sharpx1.sv:222` calls DIP bit 0 "interlace off". Techknow says it is the HIGH/STANDARD monitor switch.

## Documents found or downloaded

Downloaded on 2026-10-20 into the ignored `references/local/docs_20261020/`. Hashes are recorded in `references/README.md` under "October 20 CSP-audit reference retrieval".

| File | What was actually read |
|---|---|
| `01 X1-Techknow Table of Contents.pdf` | Rendered only. |
| `06 X1-Techknow Part 2 Chapter 1 System Overview.pdf` | Not read. |
| `07 X1-Techknow Part 2 Chapter 2 Memory Configuration.pdf` | p86-87 read (IPL placement). |
| `08 X1-Techknow Part 2 Chapter 3 HuBASIC Structure.pdf` | Not read. |
| `14 X1-Techknow Part 2 Chapter 9 Various Interfaces.pdf` | p268 read; p263-271 OCR used only to locate text. |
| `17 X1-Techknow Index.pdf` | Not read. |
| `CZ-856C_InstructionManual.pdf` | Not read. |
| `HLN014_HD46505R_CRT_Controller_Users_Manual.pdf` | Text extraction only: register R/W table. |
| `Motorola_6845.pdf` | Text extraction only. |
| `x1center_sdx1_0_IO_map.html` | Mr. Sato's "試験に出ないX1" chapter 0 I/O map, Ver.2018.7.18. Read for FM, 0B00, 0D00, FDC, 1D/1E, wait, CZ-8BM2 and SASI. |

Existing local documents used:
- `references/manuals/X1_Techknow_Appendix_A_IO_Map.pdf`: all of printed p274-284 read.
- `references/manuals/X1_Techknow_Screen_Display.pdf`: printed p148, 151, 155-157, 159-161.
- `references/local/research_20261018/techknow/` Ch.5: p176-182, 192, 194.
- Ch.6: p204-205.
- Ch.7: p223 (via the findings doc), 227, 233-234.
- Ch.8: p259-260.
- CZ-880C instruction manual: p79-80.
- CZ-856C User's Manual: PDF 69, 70, 90, 91.

Not used: the CZ-880 service manual and the CZ800C/CZ851 schematics. No decode net was traced.

Searches that found nothing retrievable:
- a Turbo Z ASIC register manual;
- Oh!X / Oh!MZ register articles;
- a CZ-8KR port document beyond Techknow;
- X1EMU source (eX1 is the CSP fork already local).

## Docs still missing that would settle the remaining C items

| Item(s) | Document that would settle it |
|---|---|
| A19, C12, C15 | A careful trace of the existing CZ-800C / CZ-851 / CZ-880 schematics: CRTC RD routing, IPL ROM chip-select (mirror), CTC CS a3 decode. These are local but untraced; this is work, not a download. |
| C1, C7, B7, B1 | A Turbo Z ASIC (IX0900-series video/palette) register and timing specification, or the CZ-880 service manual's ASIC pages with internal description. None was found publicly. Otherwise, hardware captures. |
| C6 (ANK part), C13 | A CZ-880C/851 technical manual describing the SCRN bit 2 CG fetch, and the 1FF0 bit 4-7 physical wiring. CZ-880C p79 vs Techknow p283 switch numbering needs the schematic DIP net. |
| C8 | Any Z native software using DMA to I/O at 1000-12FF/1FBx, or the ASIC's IORQ/BUSAK gating in the service schematic. |
| C10 | CZ-8BS1 schematic (YM2151 A0 / RD decode) and the Z built-in FM decode. |
| C14 (spin-up), A9 (exact tables) | The Sato "x1_vwait_20120507" measurement data itself (cited by CSP but not retrieved here), plus a drive (FD-55/YD-380 class) datasheet for READY after motor-on. |
| A15/A16 independence | The CZ-800C schematic sheet with the M1 WAIT gate and the 1E** decode. x1center says the schematic shows it; we have not traced it ourselves. |
