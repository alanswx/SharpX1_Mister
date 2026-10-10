# Verilator runner object isolation

October 10, 2026. Build-system repair; no machine RTL or snapshot-format change.

## Actual failure

An ordinary FM recheck uses a new nested Mdir
`obj_dir_v17_rtc_x3_dma_kanji_fm/ordinary-fm-check/`. Verilator's generated
makefile correctly advertises ordinary-FM CFLAGS, but inherited
`verilated.mk` adds `..` to VPATH. GNU make consequently links
**`../sim_headless.o`** from the RTC/X3/DMA/Kanji/FM parent instead of
compiling a local object. The resulting executable wrongly demands
`--rtc-controller` and terminates two before running the test.
This is not an ordinary-FM or audio acceptance result. Failed binary/logs
remain ignored and intact: `/tmp/x1-combined-fm-ordinary-build.log` and
`/tmp/x1-combined-fm-ordinary-run.log`.

Absolute C++ source paths alone cannot fix this: the unwanted parent-object
search originates in the common makefile, not just VM_USER_DIR. Do not feed
controller assets to make such a mismatched build execute.

## Repair

All thirty-one current shared C++ runner recipes pass internal make **`-B`**
when Verilator is invoked. The initial repair covered twenty-nine; the later
wide-D88 and HD-media recipes preserve the same flag. GNU make rebuilds each required object
locally rather than accepting an up-to-date parent object/executable found
through VPATH. Existing optimization/profile flags remain unchanged. Outer
repository make remains incremental: it does not invoke Verilator when its
runner target/dependencies are already current. No parent objects are deleted
or overwritten, and no tracked historical generated tree is regenerated.

## Executed acceptance

The fresh nested `ordinary-fm-check-fixed/` log shows local `sim_headless.o`
compilation with ordinary-FM flags and local-only link inputs. Its actual
800-ms capture passes the unchanged ordinary checker: 38,400 signed stereo
frames, centered PSG 1000.000 Hz and isolated FM 491.617 Hz. Original parent
runner/object hashes remain unchanged. Logs:
`/tmp/x1-combined-fm-ordinary-fixed-build.log` and
`/tmp/x1-combined-fm-ordinary-fixed-run.log`.

The separately rebuilt nested `combined-local-objects-check/` produces exactly
the qualified combined runner hash:
`79a8dab4f1bd1b920c0710774c9578135b4cd7141b4b6e3abbbb590c8f2b171b`.
Log `/tmp/x1-combined-fm-local-objects-build.log`. This is identity preservation,
not a new functional game or hardware gate.

```sh
make -C verilator test-runner-build-isolation
```

The original asset-free regression compiles a real parent and nested child
with different C++ and RTL profile constants. On this Verilator 5.044, the
unforced child reports build success/"Nothing to be done" but produces no
local executable: it reuses the parent's whole target via VPATH. The forced
child creates its own object/executable and returns exactly **CPP=2, RTL=23**;
parent CPP=1/RTL=17 object/binary hashes stay unchanged. The checker also
requires `-B` on every shared runner recipe. It explicitly reports if a
future upstream version already isolates the unforced child; it never
manufactures a negative or relaxes the forced-positive assertions.

The next run also reproduces the other parent-reuse subtype: the unforced
child links the parent's C++ object and returns **CPP=1, RTL=23**. The forced
child still returns **CPP=2, RTL=23**, with parent hashes unchanged. Both
subtypes are observed failures, not inferred from a compile error.
Latest log `/tmp/x1-runner-nested-isolation-final3.log`, terminal zero;
ignored evidence `verilator/obj_dir_headless/runner-isolation-e0t9djxe/`.
The preceding whole-target case remains in
`/tmp/x1-runner-nested-isolation-final2.log` and
`verilator/obj_dir_headless/runner-isolation-fp47rbkb/`.
Earlier fixture attempts assumed the wrong-profile child would always create
a binary, then looked for GNU make's message only on stdout. Their failures
remain recorded; that historical check required the exact successful-build/no-local-
artifact/message combination across stdout/stderr for that negative subtype.
Timeout/compile failure cannot count as the matched isolation negative.

The HD-media final recheck exposes a third log variant: an unforced child
rebuilds some intermediates, silently borrows the parent executable, and
prints neither no-work message. The earlier message-dependent assertion
fails in `/tmp/x1-hd-media-isolation-final.log`; this is a checker failure,
not a forced-child isolation pass. A direct GNU make query reports
`../Visolation` up to date. The checker now records a successful dry-run
target query and requires that exact parent-target resolution, plus the
parent's actual CPP=1/RTL=17 output, when the child artifact is absent.
The forced positive and unchanged-parent hashes remain mandatory.
The repaired recheck passes all 31 recipe checks and the actual nested
positive/borrowed-parent negative, terminal zero in
`/tmp/x1-hd-media-isolation-resolved-target.log`; evidence remains under
`verilator/obj_dir_headless/runner-isolation-e7mzoeo8/`.

The default delay-aware headless rebuild/200,000-cycle smoke also completes
zero with every optional feature off and expected 32-MHz SYS/28.571428-MHz
video. Its CRTC is unprogrammed, so zero HS/VS/frames is not a boot claim.
DMA-wrapper PLL-stand-in lint completes zero separately, not Quartus/physical
acceptance. Logs `/tmp/x1-runner-isolation-headless-smoke.log` and
`/tmp/x1-combined-fm-build-isolation-wrapper-lint.log`.

Historical frozen qualifications are not retroactively rebound to a changed
Makefile. Keep their original source copies/hashes, runner identities and
scope; inspect nested build logs for parent-object reuse before relying on
an older profile. This repair itself qualifies no Quartus RBF, native game,
full Turbo Z or hardware timing.
