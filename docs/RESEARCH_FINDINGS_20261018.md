# Reference findings, October 18, 2026

A read-only research pass (subagent) over the user's `~/Downloads` and public
sources. **No third-party bytes are committed.** At the user's request the
extracted material (manual scans, Techknow chapters, Neo Kobe selections and
text specifications, 2HD dumps, inventory `inv.tsv`, `d88info.py`) is kept
locally in the git-ignored `references/local/research_20261018/` (457 files,
hash-verified copy). Private ROM dumps were not kept; they remain only in
the original Neo Kobe archive. This file records citations, hashes and the
facts taken from them. Confidence: *documented* (Sharp or a published technical book),
*emulator* (one implementation's choice), or *inferred*.

## Sources

| Source | Where | SHA-256 | Notes |
| --- | --- | --- | --- |
| Neo Kobe – Sharp X1 (2016-02-25).zip | `~/Downloads` | `e7c44e3b…bead84` | Third-party collection; no redistribution permission. Member `[Miscellaneous] [technical].7z` holds the manuals below. |
| CZ-880C (X1turboZ) Instruction Manual, 95 pp. | inside Neo Kobe | `394ee15b…25c1cbefcc` | Sharp copyright; cite pages only. |
| "X1turboZ CZ-850C" Instruction Manual | inside Neo Kobe | `e7649b13…` | Cover shows plain X1turbo CZ-850C, not turboZ. |
| CZ-880CB/CE Service Manual | inside Neo Kobe | `70a5f8da…` | Identical to `references/manuals/CZ-880_Service_Manual.pdf`. |
| X1-Techknow Ch.5 Sub CPU / Ch.6 Interrupts / Ch.7 Floppy / Ch.8 Sound | [Sharp-X1-Fun](https://github.com/UnsatisfactoryResult/Sharp-X1-Fun/tree/main/Documents/X1-Techknow) | `4a6881fe…`, `3bee4e5b…`, `9a7615f5…`, `a1111fd4…` | Book scans, no stated license; reference only. |
| "new TAP format specification" | inside Neo Kobe | — | Text spec (SJIS). |
| MAME `hash/x1_flop.xml`, `x1_cass.xml` (mame0283) | `~/Downloads/mame0283-arm64/hash` | — | CC0 metadata. |
| Common Source Code Project (CSP) x1 VM | `../common_source_code` (local) | — | GPLv2; cited only. |

## Disk

- **Boot DIP** (CZ-880C manual p.79, *documented*). The disk type is SW3,SW2,SW1, with OFF = 1:

  | Type | Medium | Size | Format |
  | --- | --- | --- | --- |
  | 0 | 2D | 320K | X1 |
  | 1 | 2DD | 640K | X1 |
  | 2 | 5" 2HD | 1M | X1 |
  | 3 | 5" 2HD | 1M | standard |
  | 4 | 8" 2D-256 | 1M | X1 |
  | 5 | 8" 2D-256 | 1M | standard |
  | 6 | 8" 1S-128 | 240K | standard |
  | 7 | hard disk | 10M | — |

  - The table applies when SW5 is OFF; for types 0/1, SW6 must also be ON/OFF respectively.
  - SW5 ON gives priority to the front-panel 2HD/2D boot switch (p.52). In that case SW6 ON offers 2HD/2D and SW6 OFF offers 2HD/2DD.
  - SW4 is factory ON. The factory default is SW2 OFF with all others ON.
  - The physical bit/polarity mapping to port 1FF0 is still *inferred* (it agrees with MAME's F1/F3/F5/FF if ON reads as 0).
- Two built-in dual-mode 2HD/2D 5.25" drives (p.86).
- The external FDD connector carries DISK TYPE SELECT (pin 1), MFM (pin 19) and LOW CURRENT (pin 37) (p.76). This is a signal list only, with no timing.
- **X1-format 2HD** (Techknow Ch.7 p.223, *documented*): MFM throughout, all 256-byte sectors, including track 0. The "standard" 2HD format instead has cylinder 0 head 0 as 128-byte FM.
- Real dumps (CZ-8FB02/FB03, Fast S-OS turbo) measure 77 × 2 × 26 × 256, D88 media byte 0x20, 1,089,776 bytes. This agrees with xmil `fdd_2d.c`.
  - That is above the default 20-bit selected-volume limit, so it requires the `turbo-wide-d88` profile.
- Turbo BASIC (Techknow App. B pp.319/325, *documented*): DKIOSW at FC61 holds FF for 2DD and FE for 2HD. FD5DRT drive types 1–3 use DMA, so turbo BASIC always uses DMA for 2HD/2DD.
- **Selector behaviour (CSP `floppy.cpp`, *emulator*):**
  - IN 0FFE selects 2HD at 360 rpm.
  - IN 0FFF selects 2D/2DD at 300 rpm.
  - All drives change together.
- **Not found in any Sharp source:** drive RPM and FDCCLK per density.
- `.dsk` in CSP is an Amstrad CPC (MV-CPC / EXTENDED) image converted to D88, not an X1 format. The `.dsk` files in Downloads are Apple II images.
- Raw formats: `.2d` = 327,680 B (implemented); xmil `.2hd` / CSP `.hdb` = 77 × 2 × 26 × 256 = 1,025,024 B.

## Cassette

**TAP formats**
- New format, magic `TAPE`:
  - 0x04: name, 17 bytes
  - 0x1A: write protect
  - 0x1B: format (0x01 = constant-rate sampling)
  - 0x1C: sample rate in Hz (u32)
  - 0x20: data length in bits (u32)
  - 0x24: play position (u32)
  - 0x28: data
- Old format: u32 sample rate, then data.
- Both store 1 bit per sample, MSB first, as the signal level (spec text; CSP `datarec.cpp` `load_tap_image()`).
- Downloads tapes are mostly new format at 8000 Hz. One is 176,400 Hz (Car Chase), and one is old format (Cannon Ball).

**Physical encoding** (Techknow Ch.5 p.190, *documented*)
- A bit-0 cycle is 250 µs and a bit-1 cycle is 500 µs, sampled 185 µs after the rising edge.
- Each byte is start bit 1, then D7..D0.
- Tape layout: an 8 s gap, then an information block, then a data block, each with a 2-byte sum.

## Interrupts, FM, RTC

- Turbo daisy-chain priority (Techknow Ch.6 p.204, *documented*): I/O slot 1 > slot 2 > SIO > DMA > CTC > key (sub-CPU). Base X1: slots 1–4, then key.
  - The repo's SIO → DMA → CTC → sub order matches.
  - MAME's `x1turbo_daisy` differs and is marked TODO there.
- **FM** (Techknow Ch.8 p.260, *documented*):
  - The YM2151's internal timers cannot be used. Tempo comes from a CTC (turbo internal at 1FA0, X1 CZ-8BS1 at 0704).
  - ch0 runs as a timer and ch3 as a counter, T = TC0 × 250 ns × prescaler × TC3, which implies ZC0 → TRG3.
  - The OPM runs at 4 MHz.
  - This supports leaving OPM IRQ unconnected to the CPU.
- **RTC** via the sub-CPU (Techknow Ch.5 pp.191–193, *documented*): EC/ED set/read date, EE/EF set/read time, each with a 3-byte payload.
  - Date: year as BCD; month 1–12 in binary in bits 7:4; weekday 0–6 (Sunday = 0) in bits 2:0; day as BCD.
  - Time: hour, minute, second as BCD.
  - **The year is counted by the sub-CPU, not the µPD1990, and is lost at main power off.**
- IPL reset scope (CZ-880C p.80): CPU, 8255, PSG, CTC, SIO, CRTC, FDC and 1FDx, plus the ROM bank. DMA and OPM are not listed.

## Kanji, fonts, firmware

- CZ-880C spec (p.84): BIOS ROM 32 KB (IPL 4 KB), CG 8 KB, Kanji levels 1+2 = 256 KB, PCG RAM 6 KB, text 4 KB, attribute 2 KB, GVRAM 96 KB.
- CSP file conventions (`display.cpp`, *emulator*): ANK8 2 KB, ANK16 4 KB, `KANJI.ROM` / `FNT1616.X1` = 306,176 B, an X Millennium "virtual" JIS-ordered layout converted LRLR → LL..RR. MAME uses `kanji1–4.rom`, 4 × 32 KB raw chips.
- The Neo Kobe turboZ BIOS set's IPL equals the turbo IPL (`21289570…`), so **no separate Z IPL dump exists there**.

## Turbo Z ASIC

No register-level documentation beyond MAME/xmil/CSP was found. The CZ-880C manual pp.85–86 gives only feature-level descriptions: multi-mode, 4096 colours, priority/palette/background/black control, and video capture.

## Still open

- Native 2HD drive RPM and FDCCLK routing.
- CZ-8BS1 schematic.
- Turbo Z ASIC registers.
- A genuine Z IPL dump.
