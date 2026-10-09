# Reverse-attribute analog text acceptance increment

October 9, 2026. Original CPU-programmed fixture/oracle extension, with no RTL
behavior change. This qualifies one bounded reverse/priority/reset case on the
current experimental text compositor; it does not close the full attribute,
native opacity/intensity, blackclip or hardware matrix.

`--text --reverse` alternates native attribute bit 3 across eight-cell groups,
while keeping all eight source colors and the existing ANK A glyph. The oracle
reverses the **masked raw three-bit glyph color** (`color XOR 7`), not analog
palette RGB. Consequently absent glyph pixels can become nonzero opaque text,
and some ink can become transparent. Raw color 7 is deliberately programmed
black, so the test also distinguishes presence from output brightness.

## Terminal machine result

The actual shared CPU custom `1Ah` bank-1-front/text-between warm test exits
zero in `/tmp/x1-z-reverse-middle.log`. It checks all 64,000 RGB12 pixels and
nominal X3 line/frame periods, real CPU HALT/completion, warm reset at 4,500 ms
for 10 us, real CRTC/PPI/priority reinitialization and no palette/VRAM refill.
The invocation lasts five seconds at SYS 32 MHz / VID 42,954,540 Hz.
Alternate-order and missing-reverse images must differ from the actual capture,
not merely compile. The full text/graphics acceptance matrices remain separate.
The actual frame differs by 37,028 pixels from the alternate text order and
1,314 pixels from the missing-reverse counterfactual.

Frozen outputs under
`verilator/obj_dir_v13_z_paired/reverse-middle-YRbvhb/` are ignored. Runner:
`6420d29945b4958ee8509334fb8e774f7191ab490babd2172f00b65e0ed634e0`.
Program:
`38a3c6ed88eebd16348cb10158b9f51af9d1c7e7b58cc0e3800231138e53ce1b`.
The copied checked-in ANK source is a reference to existing repository glyphs,
not a new private font or a cleared/authentic machine ROM claim.
Its source SHA-256 is
`68aa689abd81c1a620980b5318b669b292a72d4877916ec43dc2461d713c831b`.

`test-machine-z-text-reverse` reproduces this bounded case using frozen
runner/oracle/emitter/ANK source. The recipe is dry-run inspected, not executed
again as a separate matrix. Subsequent text invocations now report the ANK
source SHA-256 and reject changes during a test; that metadata extension was
added after the completed probe was frozen, so do not attribute that new
assertion to its historical execution.

The subsequent distinct-entry/window fixture also terminates with exit zero
in `/tmp/x1-z-distinct-text-warm.log`, under
`verilator/obj_dir_v13_z_paired/distinct-text-1Zu1ji/`. See the
[coverage follow-up](TURBO_Z_TEXT_OPACITY_COVERAGE.md#distinct-text-entry-follow-up)
for identities and scope. It checks all 64,000 pixels through retained reset,
with seven distinct writable text RGB entries, font/runner hash checks and
selected counts `85/86/87/87/85/86/1481`. Alternate order differs at 36,434
pixels and missing reverse at 1,804. This is a stronger bounded fixture,
not full attributes, native opacity/intensity or hardware acceptance.

The primary text-palette page (Techknow printed 162 / PDF page 58) was visually
rechecked at `/tmp/x1-text-level-primary.png`: CPU field pairing and replication
are visible, but the output diagram still does not identify the DAC pin
significance needed to settle `01 -> 5` versus `01 -> A`. The explicit
experimental intensity policy is therefore unchanged, not newly native-qualified.
