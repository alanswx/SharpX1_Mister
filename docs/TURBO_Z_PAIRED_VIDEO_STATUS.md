# Experimental Turbo Z paired-screen graphics composition

October 9, 2026. This connects the previously standalone mode-5 fetch/shifter
and ordering decoder to real shared-machine palette lookup. It is **not full
Turbo Z text/priority, native reduced-bank or hardware acceptance**.

## Connected path

`make -C verilator turbo-z-paired` enables Turbo, X3 video, external palette,
multi-mode and text/priority CPU storage together in a separate non-savable
runner. Existing runners and board revisions leave that combination disabled.
In low-scan 40-column mode `90h`, priority bit 4 admits mode-5 fetch: both
banks' base/+400h sources. SCRN display selection does not discard either
screen. Priority is captured at character request, then transferred to the
pixel state at the same character load as the graphics shifter.

The ordering decoder chooses a graphics bank **before** the existing one-edge
external-palette lookup. One selected lookup is enough; it does not merge the
two indices or replicate the palette memory. Bit 3 selects the front bank.
Undefined paired field `11` gets no analog graphics response, rather than an
invented fallback order.

This increment only renders through the existing transparent-text gate.
Opaque text still follows the inherited digital renderer; analog text and
text-between-screens are not connected. Source index zero is provisionally
transparent, while nonzero codes programmed black remain present. For all-zero
graphics, fields `00/10` fall through to graphics palette entry zero; field
`01` ends at fixed text zero (black). This explicitly mirrors the inspected
eX1 policy, **not an established ASIC opacity/blackclip contract**. The existing
provisional reduced effective-pair expansion remains unchanged.

## Verification

`make -C verilator test-machine-z-paired` freezes runner, oracle and emitter
before executing 24 cases: six valid front/order controls (`10/18/11/19/12/1A`),
identity/custom palette, cold/warm reset. Each case checks 64,000 real RGB12
pixels, nominal X3 periods, real CPU completion and unchanged runner hash.
Warm cases require actual CRTC/PPI/priority reprogramming without palette,
GRAM or text refill. SCRN selects screen 1 throughout, including tests with
bank 0 on top, so simultaneous display must override ordinary selection.

The strengthened custom fixture programs nonzero G:R:B index `A:5:F` black,
and its oracle requires front-only/back-only/overlap/all-zero coverage plus
black-front-over-back samples. Palette programming still uses the prior full
mode sequence; native reduced-mode programming after switching remains open.

Current pixel runs are **in progress, not a completed matrix**:

- Initial 24-case matrix: `/tmp/x1-z-paired-machine-matrix.log`, frozen
  `verilator/obj_dir_v13_z_paired/paired-matrix-MxicKs/`. This copy predates the
  additional programmed-black sentinel/coverage assertions; do not claim it
  qualifies those strengthened checks.
  The first bank-0-front identity/cold case passes all 64,000 pixels and
  measured periods, despite SCRN selecting bank 1. Remaining cases are running.
- Separate strengthened custom/front-bank-1 cold probe:
  `/tmp/x1-z-paired-black-front.log`, independently frozen under
  `verilator/obj_dir_v13_z_paired/black-front-2uq5yt/`. It exits zero: all 64,000
  pixels and periods, 2,056 front-only / 2,054 back-only / 59,518 overlap /
  372 all-zero pixels, including 534 black-front/nonzero-back samples.
  Its retained warm-reset follow-up is running on the same frozen runner and
  oracle in `/tmp/x1-z-paired-black-front-warm.log` subsequently exits zero:
  all 64,000 pixels/periods and the same coverage, with real post-reset I/O
  and no palette/GRAM/text refill. This binds the graphics-only checkpoint.
- Both use runner SHA-256
  `ca830ccd225e87fb10a63115d287d833a09154194ebd951720c2ee11f5144178`.

Terminal existing gates exit zero: paired fetch/shifter/full-color pin tests
at all three clocks, ordering truth table/negative and ordinary/X3/DMA wrapper
lint (`/tmp/x1-z-paired-units-wrapper.log`). The actual-CPU priority crossing's
three cold/warm/stopped-clock profiles and disabled negative also pass
(`/tmp/x1-z-paired-build-cdc.log`). Wrapper lint uses a PLL stand-in and retains
inherited warnings. No fitted timing, physical CDC, private firmware, native Z
software or new RBF result follows from these gates.

The enhanced actual-CPU crossing fixture also checks character-bound priority
capture at real request/load phases, and requires live versus captured priority
differences during the 256-byte sweep. All three clock profiles and the same
disabled negative exit zero in `/tmp/x1-z-paired-captured-priority.log`.
The rebuilt default delay-aware runner also passes timing/determinism/FST,
graphics-bus/DAM masks and transaction-bound PPI/DAM CPU checks. Its SHA-256
is `26654e18dd7dbfb40adc628ab130e490788d7e6798c2274482a04bebb6b418c4`;
these are focused default regressions, not a fresh full baseline suite.

Next gates: terminal pixel evidence including the programmed-black cases,
held/live control/reset seams, reduced CPU bank contract, actual analog text
and glyph coverage, blackclip, native firmware and source-bound Quartus/hardware.
The subsequent [analog-text follow-up](TURBO_Z_TEXT_COMPOSITION_STATUS.md)
connects raw glyph color and text palette with provisional intensity; its
pixel acceptance is running. This page's frozen graphics-only results must
not be promoted to acceptance of that newer implementation.
