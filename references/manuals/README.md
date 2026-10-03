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

## Integrity (SHA-256)

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
