# HuBASIC reference and retained-reset checks

October 15: Common Source macOS revision 3 now has a bounded native
CZ-8FB01 arithmetic, stored-program and retained-reset gate. The separate
RTL warm-reset probe timed out before terminal evidence; it is unaccepted. No emulator VM or FPGA behavior was changed.
An additional [actual MiSTer BASIC gate](BASIC_HARDWARE_RESET_STATUS.md) now
passes arithmetic, LIST/RUN and both Main reset commands with 148,480 exact
pixels on the existing Turbo-IPL fd9a0850 profile. It does not replace the
separate RTL timing/profile experiment. A subsequent
[Turbo input-cadence observation](BASIC_IPL_MATRIX_STATUS.md) preserves a
missing-character run at 4/4 host frames and qualifies exact arithmetic
cold/repeat at 8/8, with an unchanged missing-Enter control. This changes no
emulator timing or VM behavior and does not broaden the base reset gate.

## Accepted CSP gate

`scripts/qualify_csp_basic.py` requires the passing frozen CSP X1 qualification
and the identified local HuBASIC D88 SHA-256
`ef47f5df772f45d97be43646d8f8010d33eca8846913babfd1106e89a361ee6a`.
It copies the four required ROM/font inputs into an isolated directory and
mounts only protected private D88 copies. It loads no snapshot or RAM image.
The [previous BASIC investigation](BASIC_NATIVE_STATUS.md) records release
identification and media provenance; licensing remains open.

Accepted output is `output_files/CSPBasic_20261015T234906Z/accepted-csp/`.
All **303 recorded input paths** and **167 frozen files**, including the
executable, oracle and assets, rehash unchanged. Terminal JSON SHA-256 is
`59aec6bf17bdedcb4ab44feae6c9169a85d17ad95cbddb4402415223b3c9c7ba`.
The CLI remains the already qualified X1 revision-3 binary
`6a87e9bfbd1407b49a2df53237160faaede80357df31bc1b599df14a1815b04d`.

| Case | Native execution and required result |
| --- | --- |
| Arithmetic / repeat | `print 6*7`, separate ` 42` line, then `Ok` |
| Stored program / repeat | `10 print 9`, `list`, listed `10 PRINT 9`, `Ok`, `run`, separate ` 9`, `Ok` |
| Warm reset / repeat | First arithmetic succeeds; reset at frame 1600; new `print 9*9` yields ` 81` and `Ok` after native reboot |
| No reset | New arithmetic appends below the old transcript; unchanged reboot oracle rejects |
| No Enter | Typed expression does not satisfy the unchanged command/result/prompt oracle |

All eight processes complete successfully; process failure is never accepted
as a rejecting control. Cold repeats match every collected machine artifact,
including actual PNGs, memory, CPU/I/O/frame CSVs and mounted disk copies.
The disk-copy audit derives expected headers/payload independently from the
input bytes. Originals and caller inputs remain unchanged.

`verilator/tests/check_basic_reference.py` renders expected cells from the
actual supplied ANK8 bytes, requiring every RGB component of complete 80-cell
rows, including their black padding. It checks the native release banner at
row 4 and command/result/prompt transcript at row 13. The declared positive
comparisons check **450,560 exact pixels**. The no-reset case also checks
30,720 pixels of its appended `81` transcript at row 16, proving that its
failure is specifically the reboot expectation rather than lost keyboard
input. An independent check also verifies the no-Enter control's banner.

Warm/no-reset instruction traces cover frames 1599–1602. A real instruction
at IPL PC `0000`, opcode `C3`, appears exactly once in frame 1600 after reset
and is absent without reset. Before/after screenshots check both distinct
arithmetic results; stale pre-reset `42` cannot qualify the new `81` oracle.
The same process retains ROMs and disk mounts throughout, using public
`EMU::reset` with no frontend reload.

Other CPU/I/O traces cover frames 0–2 only. Frame logs cover every frame.
Arithmetic/program runs complete 1,500 CSP frames; warm/no-reset runs complete
3,100. Initial command frames are 800/1000/1200; post-reset arithmetic starts
at 2400. These are CSP frame numbers, not RTL reference cycles or hardware
time. The nominal X1 CPU is 4 MHz; initial frame constants are 61.94 Hz and
258 lines, with timing subsequently controlled by the existing CRTC model.

The controller is CSP's existing pseudo-sub-CPU; ANK is the user's existing
macOS font; virtual Kanji is explicitly synthetic zero data; sound is
PSG-only. CSP starts with Caps unlocked and echoes unshifted lowercase.
The earlier RTL arithmetic fixture holds Shift with inherited Caps ON and
also echoes lowercase; its unshifted program fixture echoes uppercase.
The checked expectations preserve these distinctions. They do not case-fold
captured text or claim equal native keyboard policies.

The CSP and RTL ANK files differ, including 222 bytes in ASCII glyphs 32–126.
Each renderer must use its own recorded font. CSP outputs 640x400 with each
low-scan line doubled; the RTL native capture is 640x200. Expected pixels are
generated directly at each native geometry. Captures are not scaled, cropped,
retouched or compared under a color tolerance.

## Reproduction and evidence

```sh
python3 scripts/qualify_csp_basic.py \
  --qualification output_files/CSPMac_20261015T225930Z/qualification-v3 \
  --rom-dir output_files/CSPBasic_20261015T234906Z/assets \
  --disk software/basic-unpacked/zzz-unk-hubasic-11a5077cf724/disk-0-ef47f5df772f.d88 \
  --output output_files/NEW_CSP_BASIC_GATE
make -C verilator test-basic-reference-oracle
```

[Actual screenshots](../output_files/CSPBasic_20261015T234906Z/screenshots.html)
embed original PNGs. Per-process command JSON and logs make the schedules
reviewable. Initial arithmetic/program/reset explorations are retained
separately; the accepted CSP collector/oracle were frozen before its eight
fresh runs. Seven asset-free unit methods cover wrong/missing results,
echo-only output, row padding, the second vertical sample, banner/geometry
and separate RTL text/RGB requirements. They do not substitute for native runs.

## RTL warm reset: execution timeout, unaccepted

The 26-second warm/repeat/no-reset collection uses the unchanged historical
fixed-FDC executable `c244826e…`, separately identified in the earlier BASIC
status. It is not a new source-bound build of the current working tree.
It uses shared-machine delay-aware simulation, SYS 32 MHz, VID 28.571428 MHz
and the separate 1-MHz FDC experiment. Reset is at 14 seconds for 20 us;
the same actual PS/2 F/command sequence runs before/after it, with `9*9` as
the second expression. Full-bus events cover 13999–14030 ms.

The checker requires terminal children, exact `81` transcript pixels and
text, unchanged media/ROM/keys/executable, no writes or asset reupload,
CPU IPL reads after reset and a rejecting no-reset control. Its oracle was
frozen after the exploratory matrix launch; no pre-launch freeze is claimed.
The first child hits its 1,800-second execution timeout before a terminal
report; repeat/no-reset children are not launched. Session 33526 is terminal
nonzero. All inputs/executable and partial evidence are retained unchanged,
with no restart. The checker refuses this incomplete evidence before creating
an acceptance file. No native warm-reset correctness rejection or pass is
inferred from the timeout. See `rtl-timeout-audit.json` and the handoff.

This follow-up does not qualify native SAVE/LOAD, representative BASIC
graphics, other BASIC/model releases, active FDC/DMA reset, Main/OSD dispatch,
native controller firmware, exact WAIT timing or physical hardware. General
BASIC compatibility and redistribution provenance remain open.
