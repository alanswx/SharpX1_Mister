# User-local X Millennium 0.26 source inspection

October 15, 2026. The user identified `~/Downloads/xmil026s`. Its extracted
Windows source and `~/Downloads/xmil026s.zip` were inspected read-only.
No emulator code, ROM/font bytes or build products were copied into RTL.
This version was **not compiled or executed**. It is useful additional source
history, not an independent hardware measurement or a second independent vote
alongside the existing X Millennium libretro descendant.

Archive: 167,299 bytes, SHA-256
`b314af2d381a92e41186d0f69797842ff1646b15210817acbf29339792e1be28`.
Thirteen inspected files match their original archive members byte-for-byte;
the hash inventory is `output_files/xmil026-reference-20261015/inputs.json`.
The project uses Windows/MSVC, DirectDraw and x86 inline assembly. No toolchain
or compatibility layer was installed. The archive's `OTHERFNT/README.TXT`
discusses unchecked personal font-conversion tools; it is not a general source
or ROM redistribution license. Overall licensing remains unaudited.

## Relevant comparisons

| Inspected source | Finding and limit |
| --- | --- |
| `X1_PCG.CPP:40–72` | PCG/Kanji selector helpers search cells 7FF/3FF/5FF/1FF using attribute bit 5. This is the historical fallback, not evidence for changing the separate CZ-880 physical highest-cell selectors. |
| `X1_PCG.CPP:233–265` | High-speed font reads use the port nibble as row, Kanji bit 7 as selection and bit 6 as byte half. The non-16-row ANK path doubles rows with `l >> 1`. This corroborates functional policy, not CPU WAIT latency. |
| `X1_PCG.CPP:78–179,319–397` | Font lookup converts addresses/JIS and selects ranges of the emulator's combined font store. That store is not a verified physical IC65/IC66 dump or a conversion recipe for the current 256-KiB board loader. |
| `X1_CRTC.H` / `X1_CRTC.CPP:566–587` | SCRN access/display bank control and stored-byte readback are explicit. Stored readback is an emulator policy, not proof of native ASIC unused bits/reset behavior. |
| `X1_SCPU.CPP:18–20,33–75,107–124` | Command tables and E3/E6/ED handling are useful mailbox/keyboard/calendar references. Keyboard interrupts are host-emulated with command/interrupt gating; this does not resolve the FPGA's native sub-CPU/IRQ timing or justify bypassing its real MR16 path. |
| `X1_VRAM.H`, `DRAWTXTB.CPP`, `DRAWTXT6.CPP`, `DRAWTXT8.CPP` | Attribute definitions distinguish color/reverse/blink/PCG/double-size and underline. Renderer source is available for future policy comparisons; no new full raster/priority acceptance follows from this inspection. |

The PCG fallback and virtual font conversions are specifically kept separate
from the current physical-Z decoder and native-font open gates. The earlier
[Kanji contract audit](KANJI_CONTRACT_STATUS.md) and
[current external-font hardware limits](TURBO_Z_EXTERNAL_HARDWARE_STATUS.md)
remain authoritative for implemented/verified scope.
