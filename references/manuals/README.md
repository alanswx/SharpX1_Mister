# Downloaded Sharp X1 documentation

Retrieved 2026-10-02 from Philip Smart's
[Sharp X1 manuals archive](https://eaw.app/sharpx1-manuals/).
These are original machine manuals and published circuit diagrams hosted by
an archival site. Most manual prose is Japanese; schematics remain useful
without translation. The PDF files are retained locally and ignored by Git
to avoid adding roughly 210 MiB of scanned material to source history.

| Local file | Pages | Use in core development | Original download |
| --- | ---: | --- | --- |
| [CZ800C_Schematic.pdf](CZ800C_Schematic.pdf) | 7 | Base X1 circuit diagram; first reference for chips, buses, memory, video and sub-CPU connections. | [Source](https://eaw.app/Downloads/Manuals/Sharp/CZ800C_Schematic.pdf) |
| [CZ851_2C_Schematic.pdf](CZ851_2C_Schematic.pdf) | 7 | X1 Turbo model 20/30 circuit diagram; compare DMA, CTC, SIO and expanded display wiring with base X1. | [Source](https://eaw.app/Downloads/Manuals/Sharp/CZ851_2C_Schematic.pdf) |
| [CZ-880_Service_Manual.pdf](CZ-880_Service_Manual.pdf) | 73 | Turbo Z service information and schematics; useful for later model-specific hardware work. | [Source](https://eaw.app/Downloads/Manuals/Sharp/CZ-880_Service_Manual.pdf) |
| [cz8rl1_schematic.pdf](cz8rl1_schematic.pdf) | 1 | CZ-8RL1 data-recorder circuit diagram; cassette signal and transport circuitry. | [Source](https://eaw.app/Downloads/Manuals/Sharp/cz8rl1_schematic.pdf) |
| [CZ-856C_UsersManual.pdf](CZ-856C_UsersManual.pdf) | 252 | Turbo II operation and feature reference; helps define observable machine behavior. | [Source](https://eaw.app/Downloads/Manuals/Sharp/CZ-856C_UsersManual.pdf) |
| [CZ-856C_BasicReferenceManual.pdf](CZ-856C_BasicReferenceManual.pdf) | 444 | Turbo II BASIC reference; useful for designing software-driven graphics, sound and device tests. | [Source](https://eaw.app/Downloads/Manuals/Sharp/CZ-856C_BasicReferenceManual.pdf) |
| [CZ-856C_ApplicationManual.pdf](CZ-856C_ApplicationManual.pdf) | 88 | Turbo II application manual; reference for bundled applications and their expected use. | [Source](https://eaw.app/Downloads/Manuals/Sharp/CZ-856C_ApplicationManual.pdf) |

All seven downloads returned successfully and were recognized as PDFs by
`file` and `pdfinfo`. Page counts were checked with `pdfinfo`. These are largely
scanned images: text extraction from the service-manual sample returned no
searchable content. OCR and a detailed page-by-page circuit audit remain to be
done. `pdfinfo` emitted a form-fields warning for the base schematic but could
read its page count. Metadata validation does not certify every scanned page.

These documents describe different models. Do not apply Turbo Z-specific
registers or memory sizes to the base X1 without checking the model schematic.
The archive identifies the base and Turbo diagrams as magazine-published
schematics. It does not provide a dedicated Turbo II schematic in this set.

October 5 follow-up: CZ-880 service-manual pages 1–6, 9, 30 and 43–48 were
visually inspected for the [Turbo Z roadmap](../../docs/TURBO_Z_PLAN.md).
Specs, multi-mode matrix and chip/control labels were recorded; this was not
OCR, a complete foldout netlist/ASIC audit, or verified register timing.
The existing local scan was reused, not downloaded again. The Fujitsu
datasheet's printed page 4-33 also informed concrete remaining status/CRC/
deleted-data contracts in [disk status](../../docs/DISK_STATUS.md).

October 6 Kanji follow-up: CZ-851/852 PDF pages 2/3 and page-3 ROM/decoder
detail crops were rendered from the existing hashed scan and visually read.
IC92 LS139 and IC106/105/104/103 ROM pin wiring now define an exhaustively
tested first-level address component; see the [contract audit](../../docs/KANJI_CONTRACT_STATUS.md).
CPU-port semantics, Turbo Z level-2/ASIC behavior and native ROM filename
ordering were not established by this circuit trace.

## Integrity (SHA-256)

October 6 DMA-service follow-up: retrieved Zilog's February 1980
[Z80 DMA Product Specification](https://bitsavers.trailing-edge.com/components/zilog/z80/Z80_DMA_Product_Specification_Feb80.pdf)
as ignored `Z80_DMA_Product_Specification_Feb80.pdf` (19 pages), SHA-256
`5941201bddb9ce1edb1ad0d130b73076129d66b402761f4d41461b567dd1f05c`.
The original www.bitsavers.org host returned 403 and the web screenshot cache
missed; the mirror download, pdfinfo and local rendering succeeded. PDF page 9,
Figure 8b was visually inspected to corroborate the cause-modified vector
bits missing from the later UM008101 scan. This is not a complete audit of
its counters, IRQ timing or commands; see [DMA service](../../docs/DMA_SERVICE_STATUS.md).

October 6 FM follow-up: retrieved two Yamaha primary documents for the
[standalone FM foundation](../../docs/TURBO_Z_FM_STATUS.md). PDFs remain ignored.

| Local file | Pages | SHA-256 | Retrieval / actual inspection |
|---|---:|---|---|
| `Yamaha_YM2151_199112.pdf` | 10 | `9c15c4be47cc1b4dbcc61d81d4275248fab604b52ec4b687889096a00c873216` | [Bitsavers mirror](https://ftpmirror.your.org/pub/misc/bitsavers/components/yamaha/YM2151_199112.pdf); original Bitsavers host returned 403. Visually read pages 3–5, 8–10. |
| `Yamaha_YM2151_Application_Manual.pdf` | 31 | `ec3d9b0f1934873b49e1f3820b7cde9aa1bfff6d917fb2a8a09be609fcee8640` | [Application manual scan](https://map.grauw.nl/resources/sound/yamaha_ym2151_synthesis.pdf); visually read PDF 1, 7, 13–15, 23. The web viewer timed out; local download/render worked. |

`pdfinfo`, hashes and local rendering succeeded. Text extraction of the
selected material was not usable. No claim of a complete electrical/net audit
or silicon equivalence follows from these downloads.

October 5 Turbo II follow-up: selected CZ-856C user-manual pages were rendered
and visually read, without Japanese OCR. PDF 69–70 (printed 58–59) cover the
scan/text/graphics mode table; PDF 86–91 (printed 75–80) cover text attributes,
expansion, ROM/RAM CG and underline restrictions. Introductory and contents
pages were also sampled, not the complete 252-page manual. The resulting
[software-visible acceptance matrix](../../docs/TURBO_IMPLEMENTATION_PLAN.md#primary-turbo-ii-textvideo-acceptance-contract)
does not settle ASIC bit encodings or earlier-model equivalence.
Later the BASIC reference's PDF 200–202 (printed 2-163–165) and PDF 214
(2-177) were visually read for WIDTH and KSEN. They clarify graphics
suppression, the high-scan 10-row exclusion and separate underline color;
the provisional renderer policy and uncompleted verification gates are in
[text-raster status](../../docs/TURBO_TEXT_RASTER_STATUS.md).

```text
183e1e9e2d356ab7cba0491ab1784894bae7c4ec7ca82a2bf7421fe517168b3e  CZ-856C_ApplicationManual.pdf
e45eb7ce77f2a1c0d16f4030be3dddaea011473702bb3728913e84e43cf246e6  CZ-856C_BasicReferenceManual.pdf
ae2f807aaeefcf9993cc705b7ea24015b121d976048ed9f65e2f0f15b37228ac  CZ-856C_UsersManual.pdf
70a5f8da327ed25710e76d60117c4f82a655e6a7b29a34cb3239c75f0bd65a81  CZ-880_Service_Manual.pdf
9b9567a9ddace4cce8db7b2c22581827ac0b6ab554dc6cd9071e00b2536331fc  CZ800C_Schematic.pdf
8784414a3aaa25e15b4afb3662967c395c3abd6b4204ab818c7b18ed07c33f5c  CZ851_2C_Schematic.pdf
dc00c3ae4dbf1ef7ce2bcc6e3aa3e1cec2126521014c5e34ddc4314668e12d5c  cz8rl1_schematic.pdf
```

Retain original attribution and treat these archival documents separately
from the repository's code license.

## Floppy controller datasheet

Retrieved 2026-10-03: [Fujitsu MB8876A/MB8877A datasheet](https://knetonator.de/dashboard/PPG/Manuals/WT-A%20MB8876A_FujitsuMediaDevices.pdf),
saved locally as `MB8876A_MB8877A_Datasheet.pdf` (ignored, 17 pages).
SHA-256: `3358e0cefabb858261177d3f658c63db3f4142f9bfb826339135d5c19ab1b91b`.
This is Fujitsu's original document hosted by an archive, not a new emulator
description. PDF pages 5-6 cover status-read interrupt acknowledgement and
Type IV ready/index/immediate condition bits; compare local MAME's
`src/devices/machine/wd_fdc.cpp` for immediate-mask persistence and re-arming.
Physical pin timing and exact Fujitsu silicon equivalence remain unvalidated.

Retrieved 2026-10-05: Western Digital's October 1979
[FD179X-01 datasheet](https://bitsavers.trailing-edge.com/components/westernDigital/FD179X-01_Data_Sheet_Oct1979.pdf),
saved as `FD179X-01_Data_Sheet_Oct1979.pdf` (ignored, 20 pages).
SHA-256: `e51aef0933d88e7705f6f774ffb3238e8e8096bd9b9d774a985d95ef5766e3ce`.
PDF 11 (printed 11) explicitly specifies Type-II C/S comparison against the
least significant ID-side bit; PDF 12–13 describe write data marks, lost-data
zero filling and CRC generation. These are manufacturer interface references,
not proof the X1's Fujitsu part has identical timing or all error behavior.
In particular its PDF 12 says data-CRC terminates a multi-record read, whereas
the current bounded adapter follows MAME's sticky-CRC continuation policy.
That discrepancy remains a chip-exact acceptance gate; do not advertise the
adapter as a complete FD179X or MB8877 replica.

## Z80 peripherals manual

Retrieved 2026-10-04 directly from [Zilog](https://www.zilog.com/docs/z80/um0081.pdf):
`Z80_CPU_Peripherals_UM0081.pdf`, 330 pages, 2,401,861 bytes, ignored locally.
SHA-256: `b4efc81540c05990883cf4c7792c2a3d49fb7471bb5502931383ab55b4540886`.
UM008101-0601 includes CTC, DMA, SIO and PIO programming/timing. Printed CTC
pages 15/30/31 describe deferred running time-constant reload; pages 21/29 cover
software reset and interrupt service. It informed the original enable-based
CTC and focused tests; it is not evidence of authentic X1 ASIC alias decode.
October 5: official-host retrieval matches the existing file byte-for-byte;
the redundant retrieval was moved to a temporary audit file. DMA printed
pages 75–78 and 89–92 were checked for terminal counts, bus request and
programming contracts; see the implementation plan. DMA/SIO remain absent
from the shared machine; a separately tested standalone DMA slice is now
documented in `docs/DMA_STATUS.md`.
SIO printed 225–231 and 272–301 were inspected for the original
[SIO contract](../../docs/SIO_REGISTER_CONTRACT.md); programming/FIFO/IRQ
research is not device implementation, physical timing or native acceptance.
## Additional DMA primary reference (October 6, 2026)

Downloaded Zilog **1982/83 Data Book** to ignored
`Zilog_1982_Data_Book.pdf` from the
[publisher scan](https://bitsavers.trailing-edge.com/components/zilog/_dataBooks/1982_Zilog_Data_Book.pdf).
SHA-256 `f95c54fc8ff0e5524434132340e644b94ae7dc9ad861b0976114b6ba8a37bf84`.
Inspected text at printed 59–60: default/variable bus timing, two-sample
grant, orderly Ready release and next-operation Burst/continuous match
release. This older prose does not resolve the later UM0081 truncated
counter table; see [search contract](../../docs/DMA_SEARCH_CONTRACT.md).
No binary redistribution or hardware equivalence is implied.
