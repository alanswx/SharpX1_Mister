# Original MB4107 clock-selection evidence

October 10, 2026. Primary-source research and correction, not new RTL,
native disk timing, or hardware acceptance.

## Retrieved and inspected

Downloaded the [Fujitsu 1988 Linear Products Data Book scan](https://ftpmirror.your.org/pub/misc/bitsavers/components/fujitsu/_dataBooks/1988_Fujitsu_Linear_Products_Data_Book.pdf)
to ignored `references/manuals/Fujitsu_1988_Linear_Products_Data_Book.pdf`:
23,951,016 bytes, 600 pages, SHA-256
`081d4cb0d9031b1a87137b122d0be86d30e162a3eb108c135069d4cb8f9f50d8`.
Text extraction locates the original **MB4107**, October 1984 Edition 1.0,
on PDF 272 onward. PDF 273 / printed 6-2 is rendered and visually inspected;
this is not an audit of all device pages or the whole book.

The original table establishes MIN pin 1 high for mini-floppy operation,
low for standard operation. With the MB8877A controller selection, CK pin 8
is respectively 1 MHz or 2 MHz. FM pin 2 is a separate density input; DW
pin 4 supplies the read-data window, not the controller master clock.

The already-local 1990 Fujitsu book (SHA-256
`8360ba1bd0e9fc408f385daee32faa12cf52e35aad843b5561bd5f73e6c34268`)
contains the later MB4107A, February 1989 Edition 2.0. PDF 404 / printed
6-5 is also visually inspected. It retains these four pin identities and
explicitly associates 2D/2DD with MIN high and 2HD with MIN low. That later
description is corroboration, not a substitute for the original Sharp route.

## Schematic correction and implementation consequence

Re-read CZ-880 service sheets 47/48 from the existing ignored scan, SHA-256
`70a5f8da327ed25710e76d60117c4f82a655e6a7b29a34cb3239c75f0bd65a81`.
The previous byte-timing note incorrectly called DW pin 1. The drawing and
original manufacturer table establish **DW pin 4**; pin 1 is MIN. The
earlier blanket claim that the relevant MB4107A pin assignment differs is
withdrawn, without claiming whole-device electrical equivalence.

| Sharp connection | Confirmed role | Still missing |
| --- | --- | --- |
| IC416 CK 8 → IC417 CLK 24 | Controller master clock | Source-bound enable integration |
| IC416 DW 4 → IC417 RCLK 26 | Recovered read-data window | Native VFO/flux timing |
| IC420 MIN 6 → IC416 MIN 1 | ASIC-controlled rate selection | Exact IN-latch truth table and BUSY policy |
| Separate ASIC 1.6M and drive-class route | Capacity/mechanical signal | RPM, low-current and installed-drive behavior |

Implementing the chip's known MIN polarity is now better supported than
choosing a rate from a capacity name. But tracing a wire does not prove the
ASIC's internal latch/control function. Keep the strict-D88 experiment's
explicit diagnostic 1/2-MHz enables until that function is independently
qualified. Do not silently change ordinary board clocks, index rate, seek
timing or snapshots, or mark native 2HD support complete.

The standalone MB4107A download URL returned HTTP 404; it was not retrieved.
The original 1988 book retrieval succeeded through the mirror. PDFs and
rendered reference images remain ignored/temporary, with no redistribution
permission inferred. No private firmware/media was touched.
