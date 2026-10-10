# Turbo Z Kanji physical storage contract

October 10, 2026. The physical decoder and full-size selector/store components
are implemented/tested. Default-off second-level machine storage and normal-size
glyph rendering now have an early synthetic CPU/pixel pass; full-matrix,
native-font and FPGA backing-storage acceptance remain open. This does not
complete work group 3 or Z7.

## Primary pin trace

Re-rendered and visually read existing CZ-880 service-manual PDF/printed sheet
46, IC65/66 and their labeled address/CE pins. Source SHA-256:
`70a5f8da327ed25710e76d60117c4f82a655e6a7b29a34cb3239c75f0bd65a81`.
The local render is `/tmp/x1-z-line-sheet46.png`; original reference:
[Sharp service manual](https://eaw.app/Downloads/Manuals/Sharp/CZ-880_Service_Manual.pdf).

| ROM input | Board net |
|---|---|
| A16..A13 | DKAN3..DKAN0 |
| A12..A5 | DCHA7..DCHA0 |
| A4..A1 | K4Y..K1Y |
| A0 | L/R |
| IC65 CE | KACE1, first level |
| IC66 CE | KACE2, second level |

Each chip has a 17-bit address. Its local byte is
`bank*8192 + character*32 + row*2 + half`. Declared flattened storage is
IC65 followed by IC66, 131,072 bytes each. This is **not** the earlier Turbo
four-chip half-major physical loader layout. Native archive member names,
the user-supplied 306,176-byte glyph exports and ASIC select/row timing are
not qualified by these pin labels. No private bytes are embedded or converted.

## Executed standalone decoder acceptance

Original GPL-2.0-only `rtl/x1_z_kanji_address.sv` takes caller-qualified level
enables and explicit bank/character/row/half. It preserves both raw active-low
CE outputs; its flattened consumer validity requires exactly one selected
chip. It does not manufacture KACE1/2 from DKAN4 or infer a missing ASIC.

`make -C verilator test-z-kanji-address` completes zero using Verilator 5.044,
strict warnings without suppressions. The independent integer/pin oracle
visits all **262,144** physical bytes exactly once, plus all disabled and
dual-selected cases. A matched earlier-model half-major negative fails the
unchanged pin assertion. Log `/tmp/x1-z-kanji-physical-address-first.log`;
negative log `verilator/obj_dir_headless/z-kanji-address/negative.log`.
CI now schedules the asset-free target; its hosted result is not yet known.
The adjacent earlier-model 131,072-byte decoder repeats successfully with
the new target in `/tmp/x1-z-kanji-physical-adjacent.log`, without warnings.
New decoder SHA-256:
`38a61f776e3a8d91920853815be7fb7456d9dfa7b1d641de13eb566ea4f5d104`;
original fixture SHA-256:
`1323a9f2ba11f3d57cfbbd1dd9e540ad5e2c82c2c98c42f12377aaf493b6f68a`.

## Remaining integration gates

The decoder is not in `machine.qip`, instantiated by a board/runner or connected
to a font memory. Existing first-level profiles, snapshots and manifests stay
unchanged. Do not claim level-2 machine support from this combinational check.

1. Qualify the documented functional source/level/half selection below in the
   shared CPU/display machine. Exact electrical KACE timing remains separate.
2. Resolve storage architecture: the earlier X3 fit has only 164 spare M10Ks;
   a naive 256-block ROM addition cannot satisfy the full Z requirement.
   Plan external memory/cache arbitration for concurrent glyph/CPU/DMA/capture
   requests rather than dropping second level to fit current BRAM.
3. Define explicit model-bound native conversion with complete original hashes;
   do not truncate exports or reuse the earlier physical format silently.
4. Qualify ordered loader, actual CPU/WAIT, pixels/attributes, pending-operation
   reset and source-bound Quartus resources/timing before physical acceptance.

## Functional controls resolved from primary documentation

Main and a read-only research agent independently visually inspected Techknow
*Screen Display*, printed pages 139–141 and 147–148/151 (PDF 35–37, 43–44/47).
PDF SHA-256: `70b6f88f7d775ab5ee7a9c289958eb7ef09e4b86e4ca0a02eed3e231b0804a78`.
Table 4-13 establishes PCG priority: attribute bit 5 selects PCG rather than
ROM; only with ROM selected does Kanji attribute bit 7 select Kanji. Bit 4
then selects first/second level, bit 6 selects left/right and bits 3:0 carry
the upper glyph address. Thus the functional Z address is
`{kanji_attribute[4], kanji_attribute[3:0], text_byte, row[3:0], kanji_attribute[6]}`.
This uses the Z physical pin order above; it is not earlier half-major layout.

The high-speed CPU interface explicitly uses selector cells 37FF/3FFF/27FF,
screen-control bit 5 and 14*0–14*F reads, with address bits 3:0 supplying row.
The text states that normal-speed access cannot access Kanji. Figure 4-22
shows horizontal-blank preparation before WAIT release, not immediate service.
These pages do not justify the existing emulator-derived four-cell fallback.
For display, figure 4-17 supplies RA4:RA1 in high-resolution 12-line mode and
RA3:RA0 in other supported modes; low-resolution 25/20-line Kanji is explicitly
warned incorrect. Native double-height and exact Z ASIC phases remain open.

The next implementation is a separate default-off, non-savable full-256-KiB
shared-machine profile with highest-cell CPU selection, actual WAIT/readback
and normal-size high-resolution 25-line pixels. A behavioral simulation store
does not solve the FPGA resource gate: external backing storage and deadline-
aware display/CPU arbitration remain required, not a truncated BRAM substitute.
Ordered public upload, both levels/halves/all rows and bank boundaries, missing
response handling, pending-reset cancellation and ordinary v17 state identity
must be tested before declaring machine support. No native font conversion is
implied by a synthetic physical-byte diagnostic.

## Full-size selector/store checkpoint, not machine acceptance

Run `python3 -B verilator/tests/test_z_kanji_components.py`. The independent
Main rerun completes zero in `x1-z-kanji-components-fxxyzae0`, log
`/tmp/x1-z-kanji-components-main.log`; the initial agent run also completes
zero in `x1-z-kanji-components-btwne303`. Both freeze source/fixtures before
compilation and preserve the monitored ordinary modules.

The highest-cell selector visits all 262,144 physical addresses exactly once
and 524,288 attribute/Kanji/plane/font-mode combinations. Lower fallback cells
cannot qualify or replace it; PCG priority and unaccepted-write exclusion are
checked. The separate 262,144-byte simulation store scans every byte on both
ports three times at each of two unrelated video half-periods (17,500/11,640 ps).
Ordered publication, first-byte/start ties, gaps/repeats/overflows, trailing and
orphan strobes, live uploads, lost reset permission, short resets and stopped
CPU/video clocks are covered. Warm reset retains image/readiness but cancels
response validity. Half-major, swapped level/bank and stale-reset-valid mutants
reject at matched assertions. Raw build warnings are retained; only the
reviewed synchronous/asynchronous reset-use diagnostics are permitted.

Qualified selector/store SHA-256:

- `690d71fcf8fdbaaaece7738d28d2ac7dd34a5b8f561a738152690fa3ce126bf8`
- `d8e70cba447b0e3ed6096eeab8546cc032d260720e7cd2962db3fa3c70087335`

## Shared-machine synthetic acceptance; native and FPGA gates open

The separate `TURBO_Z_KANJI` integration uses the full simulation store and
highest-cell selector. It freezes an 18-bit CPU address through the existing
WAIT/response protocol and captures display character/control/attribute/raster
at request. Unsupported Kanji and invalid responses suppress text ink after
reverse/blink, without forcing underlying graphics to black. Initial supported
display scope is high-scan R6=25/R9=15, normal-size text; broader modes,
double-width ANK/PCG, underline and native ASIC phases are not qualified.

The frozen `x1-machine-z-kanji-zgfae1jf` probe/render80 collector completes
zero. Independent Main audit with `audit_z_kanji_machine.py` confirms 32 real
CPU read payloads, three complete 640x400 frames (768,000 exact pixels), physical
frame periods and unchanged evidence/current inputs. Bound input-manifest hash:
`b05977f68aab2207e48a0b8a5c2624f5f4b841b140ab02ceccc142a0d94ad857`.
No native ROM bytes are used. These are generated physical-font diagnostics,
not native software or hardware acceptance.

The `hhofb8uy` matrix now completes all fifteen CPU/pixel/loader/reset cases,
including the exhaustive 262,144-address real-CPU scan. Main's strengthened
independent audit confirms 262,688 CPU reads, fifteen complete frames and
3,072,000 exact pixels, physical periods and unchanged evidence/current inputs.
Log: `/tmp/x1-z-kanji-full-main-audit.log`. Separate disabled, half-major and
missing-display-response controls reject at matched assertions. These do not
establish native fonts, wider raster support or an FPGA memory implementation.
The machine build retains 61 warnings: the ordinary 60 plus source-order-
exposed `TIMESCALEMOD` on existing `x1_z_effect_registers.sv`. No warning-clean
claim is made; this is not an additional new-fixture or Kanji-module warning.
Ordinary base/Turbo generated state
is unchanged, and ordinary fast/snapshot checks complete zero. Final-current
delay-aware regression now completes zero with 164 PASS reports. See `DEVELOPMENT_HANDOFF.md` for
job identities and source scope. No existing board or ordinary runner enables
the Z store; external FPGA backing memory remains mandatory.

Independent auditor review initially found seven evidence mutations that could
pass, including omitted frames. The strengthened auditor now requires case-
defined frame counts, exact command and local-log bindings, complete generated
asset roster/program reproduction, chronological events and one consistent
terminal record. It refuses optimized Python execution rather than silently
disabling assertion gates. Original and copied early baselines still pass;
all fourteen previous mutations plus binary/hex IPL digest-rebinding and `-O`
controls reject at matched diagnostics. The 197 original evidence files remain
unchanged. Review evidence: `/tmp/x1-z-kanji-auditor-rereview-pXi2RqA1/`;
auditor SHA-256:
`cef13e8586c867462672891abb5946533349ea470766f93c8c55f9c23e084673`.
This verifies the auditor's bounded evidence contract, not completion of the
native font or hardware qualification. The reusable regression driver
`test_z_kanji_machine_audit.py` also passes an independent Main rerun against
the caller-bound early evidence: two baselines and seventeen exact controls,
with original evidence and monitored sources unchanged.

The [external-font implementation plan](TURBO_Z_EXTERNAL_FONT_PLAN.md) records
full storage, display deadlines, coherence, reset-drain and physical gates.
The isolated [DDR backend](TURBO_Z_DDR_BACKEND_STATUS.md) now passes full-font
32/100-MHz and lifecycle/boundary diagnostics; it is not yet integrated with
ordered loading, display caching or a board.
