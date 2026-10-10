# Cassette bring-up status

October 10: the default-off `CASSETTE_ENABLE` shared-machine profile now connects
a read-only SYS-timed waveform transport, executed MR16 setters/live E9/EA/EB
responses and PPI PB1. Six generated-IPL machine cases pass an independent
rerun. Ordinary runners and all board revisions remain cassette-disabled;
the TAP parser is not yet connected to a native runner. Native tape loading,
recording, speed control and APSS remain open. PC0 has no recorder consumer.

## Connected read-only diagnostic checkpoint

Run `make -C verilator test-machine-cassette` for all six cases and three
controls; the standalone prerequisites are `test-cassette-transport` and
`test-mr16-cassette-firmware`. CI scheduling is not a hosted acceptance result.

`rtl/x1_cassette_transport.sv` consumes prebuffered, SYS-synchronous held samples,
not decoded tape bytes. Eleven standalone cases cover nominal/actual clock
frequencies, pause/resume, final-sample duration, underflow, reset and command
priority, with exact rejecting controls. A missing sample stops playback with
sticky underflow; it never silently stretches time. Only EJECT/STOP/PLAY are
implemented; other requests leave the running transport unchanged.

The source-derived 8-KiB controller is uploaded through index 6 during drained
reset. Its extension commits low/high OP5 stores at startup, E9 and BREAK;
the machine edge detector accepts each once despite held stores. EA/EB read
the applied deck state through the real firmware/mailbox. Index 7 remains
RTC-only, and RTC+cassette is explicitly rejected because OP5 conflicts.
The inherited firmware/ordinary profile is not replaced.

The restricted builder also repairs the packed-ASCII comparison only in this
extension: the caller supplies ASCII in the upper byte, while the inherited
BREAK comparison expects an unpacked `03`. Static checks cover all 65,536
packed words. Actual PS/2 Ctrl+C subsequently stops the deck; plain C does not.
F12 make/release first disables the inherited joystick mode, which otherwise
consumes C/A before ASCII processing. The tested PB0 route is held BREAK,
**not** a qualified native read-cleared cassette-STOP pulse.

Independent delay-aware execution of `test_machine_cassette.py --run` finishes
zero in frozen folder `x1-machine-cassette-e0b0j0oo`. Its six original CPU cases
cover transport/PPI low and high levels, Ctrl+C/release/subsequent A, plain C,
retained-media warm reset, empty media and an actual mount/PLAY commit tie.
The independent slot ledger checks 4,000 physical 32-MHz SYS edges per sample;
the complete-waveform cases accept exactly 256 samples. Executed commits are
exactly 8/3/3/5/4/9. Timer ACK rising edges are execution witnesses, not inferred
handler counts. No hierarchy writes, forced state, private IPL or host mailbox
responses are used. Three controls reject missing ASCII normalization, a
disabled deck and RTC+cassette. Synthetic diagnostics do not prove native loading.

Qualified sources SHA-256:

- Transport: `1767eba3eee4a4b06f148733afdfe57c624c669ef0215944afaf2cd9f64266b2`
- Builder: `34b1d68ba0fb44034d9215d4bc6e343ec33afe27fbda4508324fdeb5d17e5361`
- Machine fixture: `30784d00420cc3d23b1735cb9f10843a89cf93e7aa9c689545512e5869bca750`
- Collector: `78aa3908b7d56ddcd3d6d2949e7d1a81f915781c83bbbbbbe73e4340c645544d`

All eight actual ordinary base/Turbo generated headers/serializers compare
byte-identical to `d2c2d5f`, with no added warnings. The existing RTC elapsed,
retained-reset, transport and DMA-reset diagnostics finish their immutable
evidence checks after integration. Wrapper DMA lint passes an interface check,
not Quartus or hardware acceptance. No existing RBF enables cassette.

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
2. Qualify native use of the implemented SYS-timed sampling, bounded host
   buffering, pause/resume/EOF and reset policy. Connect actual waveform levels
   to PPI PB1; do not deliver decoded bytes directly to CPU memory.
3. Extend qualification of the implemented real MR16 setters at startup, E9 and
   BREAK, and serve live EA/EB responses through its existing mailbox. Preserve
   host flag/clear semantics. The proposed cassette-only OP5 allocation conflicts
   with RTC; reject that combination until a proper shared interface exists.
4. Connect a separate non-savable native runner using the qualified extended
   upload without changing ordinary/RTC behavior; index 7 remains RTC-only. New
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
The connected diagnostic above qualifies these hooks only in its stated scope;
native loading and broader coexistence acceptance remain work in progress.
