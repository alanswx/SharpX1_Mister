# Base IPL and external-font metadata initialization

October 16, 2026. The earlier [base-IPL black frames](BASIC_IPL_MATRIX_STATUS.md)
now have a concrete initialization explanation. The base IPL initializes text
and attributes but does not initialize the Turbo Kanji metadata plane. The
external-font packet adapter deliberately requires all three bytes to be
known. It therefore masks those partially initialized cells, including ANK.

This is a profile/initialization mismatch, not evidence that the base IPL
never executes. No machine RTL, firmware, default power-on value or RBF is
changed. Four hardware controls complete, and the independent terminal audit
passes. Unmodified base-model acceptance remains open.

## Early shared-machine observations

`scripts/observe_native_ipl_startup.py` freezes the source graph, MR16 image,
collector, observer and exact private inputs before building. It instantiates
the same `rtl/sharpx1.v` external-font parameters as the existing board:
Turbo/X3/Kanji/render/Z/external backing, other experiments off. SYS is 32 MHz;
VID has the existing diagnostic's rounded 23,280-ps period. Public ioctl
uploads provide the exact 32-KiB IPL and full synthetic 256-KiB font. Mock DDR
has deterministic backpressure/read latency. There is no disk or key input.

The first collection, `output_files/IPL_STARTUP_20261016T1429/`, completes
200 ms after consumer reset release, base explicit-FF IPL versus native
Turbo IPL, each twice. The base performs the exact original 2,084-OUT prefix:
PPI, fourteen CRTC register pairs, palette/PSG, 1,024 attributes and 1,024
text cells. All 2,048 VRAM commits finish; the CPU reaches its real `0F26`
delay with WAIT released. It makes **no writes to 3800–3FFF**. Turbo also
initializes all 2,048 Kanji cells, for 6,144 total VRAM commits.

The first 4,096 completed M1 samples and every I/O observation are recorded;
the remainder of the completed M1 reads are an address histogram. Pending
terminal reads are not counted as completed. This is not an instruction log
for the whole run, rendered-pixel acceptance or a complete native boot.
Cold repeats match every machine CSV. Raw run logs differ in Verilator host
performance footers and remain unchanged; the initial all-file repeat flags
are false for that reason. Independent audit SHA:
`844588320114388e8486169735dfab6a7cf3ffb5d75c36274438689f79ee64f9`.

The initial observer has one reviewed IF-width diagnostic warning. Its next
revision uses an explicit nonzero comparison; no warning is suppressed and
no machine behavior changes. The next build has exactly the inherited sixty
warnings: PINMISSING 5, MISINDENT 1, WIDTHTRUNC 23, WIDTHEXPAND 26,
CASEINCOMPLETE 1, CASEX 4; none in the new observer.

## Explicit initialization controls

`scripts/mister_basic_metadata_control.py` derives two diagnostic IPLs from
the exact original 4-KiB base bytes, with an explicit FF upper aperture.
Both replace the initial `JP 0006` with `JP 1000`; an original generated
21-byte shim at 1000 returns to native 0006 after its loop. Native bytes
0003–0FFF are unchanged and verified independently.

- Initialize: write zero through the real CPU bus to all 2,048 Kanji cells
  at 3800–3FFF using `OUT (C),H`.
- Skip: replace only that two-byte instruction with two NOPs, retaining the
  loop, addresses, entry and return. It performs no Kanji writes.

These IPLs are explicitly modified diagnostics, not native Turbo firmware,
an accepted replacement ROM or unmodified base-model qualification. NOP and
OUT/WAIT costs differ; this is an initialization control, not a timing oracle.
No state injection or direct RAM/cache/CPU writes are made by the harness.

The corrected shared-machine observer freezes those **same hardware payloads**
in `output_files/IPL_METADATA_SIM_20261016T1438/`. Four 200-ms cases pass an
independent audit of exact prescribed I/O, every recorded M1 byte, all 2,048
descriptor words and exact cold-repeat machine CSVs:

| Diagnostic | CPU OUTs | VRAM commits | Descriptor known masks | Valid packet phase samples |
| --- | ---: | ---: | --- | ---: |
| Skip / repeat | 2,084 each | 2,048 each | 1,024 x 03; 1,024 x 00 | 0 each |
| Initialize / repeat | 4,132 each | 4,096 each | 1,024 x 07; 1,024 x 04 | 71,124 each |

Mask bits are Kanji/attribute/text. The initialized but untouched upper
1,024 cells remain mask 04 and cannot display. Cache `visible` is separately
checked; it does not establish renderer packet validity. Packet counts are
samples at the observer's CE/phase-14 boundary, not visible pixels or frames.
Audit SHA `b5480d33218b2ce7a0caac5da6decbaa3163b4b0b2271f21069ad79063046db5`.

## Actual MiSTer controls (complete)

Availability matched the prior owned Turbo BASIC profile before loading.
`output_files/BASIC_METADATA_20261016T1435/` stages four new MGL/config/disk
cases: skip, initialize, skip repeat, initialize repeat. RBF remains
`fd9a0850…`; all 428 compiler inputs are checked. Same full synthetic font,
no ANK16 upload, zero-config disk protection and disposable D88 copies.
Native originals and other installed cores/config/media are preserved.

The exact previous cold waits/F/Backspace/PRINT6*7/no-Enter/Enter sequence and
frozen public ANK oracle remain unchanged. Each phase requests a fresh raw
mrext PNG. Arithmetic requires complete 80-cell banner and command/result/Ok
rows, including black padding. Process errors cannot qualify a rejecting
control. Both initialize cases pass arithmetic; both skip cases remain black
at all four capture phases. Both initialize no-Enter frames retain the exact
banner and reject the unchanged completion oracle. The same guest performs
the actual interpreter arithmetic; no host result or screenshot is inserted.

Session `64352` is terminal zero, log `/tmp/x1-basic-metadata-control.log`.
`scripts/audit_mister_basic_metadata.py`, terminal session `58953`, separately
checks **16 fresh raw PNGs and 40,960 exact positive pixels**, every action,
MGL/config/disk copy, source/frozen input, prescribed shim bytes, all 428
compiler inputs, remote immutable payloads/Main and full-font DDR.
Audit SHA `59a776ab61805cfbe69f3eee2204deaa8a5f09faa23a89f1210dc16fc645357f`.
This qualifies the bounded generated initialization/skip comparison, not
unmodified native base IPL or full BASIC compatibility.

Restoration to the previously verified native Turbo+ANK16 MGL passes as
session `75034`, log `/tmp/x1-basic-metadata-restore.log`. A fresh raw PNG
matches **10,240 exact banner/Ok pixels** in `restored-native-turbo/`.
All recorded native payloads/Main, compiler inputs, full-font DDR and
ownership recheck unchanged. This is a cold load, with no warm-reset claim.
All jobs are terminal. [Actual raw screenshot gallery](../output_files/BASIC_METADATA_20261016T1435/screenshots.html).

## Remaining policy and acceptance

The strict unknown-byte rule is preserved. Guessing zero for an unwritten
Kanji byte would change source selection and other metadata meaning; this
diagnostic does not authorize that native policy. A future base-compatible
consumer/profile needs an explicit policy and CPU/pixel/reset controls.
Ordinary base profiles do not use this external-font cache. Unmodified base
IPL on this external-font revision remains unaccepted.

No new Quartus build is needed for observer-only changes. The existing
source-bound RBF still fails setup/recovery/hold. Native Kanji fonts, full
Turbo Z, SAVE/LOAD, representative BASIC graphics, wider models and physical
timing remain open. Earlier accepted native Turbo and CSP gates are preserved.
