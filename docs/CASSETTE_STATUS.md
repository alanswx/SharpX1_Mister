# Cassette bring-up status

October 10: the shared machine still has no connected cassette playback,
recording, transport or APSS. PPI PB1 remains constant; PC0 has no recorder
consumer. Firmware E9/EA/EB command storage is not a working deck.

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

1. Connect the qualified format-1/old-header parser; retain explicit unsupported
   policies for other formats/rates until their vectors and timing are tested.
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
These hooks and connected acceptance remain work in progress.
