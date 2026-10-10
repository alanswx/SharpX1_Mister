# Cassette bring-up status

October 10: the shared machine still has no connected cassette playback,
recording, transport or APSS. PPI PB1 remains constant; PC0 has no recorder
consumer. Firmware E9/EA/EB command storage is not a working deck.

## Bounded TAP prerequisite

`verilator/x1_tap_image.h` is original C++20 code. The format layout reference
is the existing local MAME `src/lib/formats/x1_tap.cpp` (BSD-3-Clause, Barry
Rodewald); no implementation was copied. It accepts old four-byte sampling-rate
headers and new forty-byte `TAPE` headers, retaining title/reserved/flag bytes.
Ordinary 8,000-Hz waveform samples are MSB first. Samples are not decoded tape
bytes and the sampling rate is not the native baud rate.

Admission is bounded to 8 MiB, with exact declared-bit/payload length, checked
position/index access, partial-last-byte exclusion and an owned immutable
source copy. Zero-length images and position-at-EOF are representable.
Unsupported rates and unknown flags are rejected explicitly. Reserved bytes
and fixed-width titles are retained without guessing their encoding.

Format bit 0 is documented by MAME as “speed limit sampling method.” Metadata
with this bit is accepted, but waveform access explicitly rejects its unresolved
semantics. MAME ignores this flag; that is not enough to establish compatibility.
Read-only archive inspection found this flag in all eight sampled new headers,
including seven 8-kHz tapes and one 44.1-kHz tape. Therefore this prerequisite
does **not** establish that those local commercial tapes can be played.
Private archives were not extracted, modified or committed for these tests.

`make -C verilator test-tap-image` passes 324 synthetic checks with C++20,
`-Wall -Wextra -Werror`. An independent AddressSanitizer/UndefinedBehaviorSanitizer
build also completes zero without diagnostics. Coverage includes old/new
headers, lengths/counts, truncation, counts 0–17, sample order, excluded padding,
EOF/reset/seek, immutable input, flags/rates and maximum capacity. This target
is scheduled in CI; no hosted result is claimed here.

Checked source SHA-256:

- Parser: `7846bdb47ece393325ee320b7d784f75ab8c54b787e797532bd70a693585e6ed`
- Fixture: `5001bb038a5ad86344cd795b534b6dfc89c2294767957ad4153174938f17dddc`

## Connected implementation and acceptance still required

1. Resolve format-1 waveform semantics using a second implementation or original
   format documentation; qualify explicit vectors before admitting these files.
2. Implement SYS-timed sampling independent of CPU/MR16 enables, bounded host
   buffering, pause/resume/EOF and reset policy. Connect actual waveform levels
   to PPI PB1; do not deliver decoded bytes directly to CPU memory.
3. Make the real MR16 firmware execute transport setters at startup, E9 and
   BREAK, and serve live EA/EB responses through its existing mailbox. Preserve
   host flag/clear semantics. The proposed cassette-only OP5 allocation conflicts
   with RTC; reject that combination until a proper shared interface exists.
4. Reuse extended firmware upload without changing ordinary/RTC behavior; index
   6 currently belongs to RTC firmware and index 7 must remain RTC-only. New
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
