# October 8: mister126 hardware matrix

User released mister126 and mister14, while reserving mister192. Only
**mister126 / 10.0.2.126** was used, through misterubuntu SSH; it initially
reported MENU. No commands were sent to mister192. Main executable SHA-256:
`9f6e5a237c36be6404ab4823d804821491db4bf125827f84aca2a1ca31f0a8a6`.
Kernel `6.18.38-MiSTer`, root OS Buildroot 2021.02.4.

## MGLs and native boot observations

### Current v14 source-bound refit running, not deployed

October 9: after the fresh five-game v14 qualification, the authorized
misterubuntu checkout is verified clean and idle, then fast-forwarded to
pushed source `f013d02d125307403f707ecc1edec90e5ce23d11`. Quartus 17.0.2
preflight passes. A separate frozen `sharpx1_turbo_single` full-flow build
starts at `2026-10-09T09:03:23Z`, under
`/home/alans/mister/SharpX1_Mister/output_files/quartus-linux-xsC7rEDR/`.
Input-manifest SHA-256 is
`ca133f8883255f45d9fee023f9eaca9684cd56de726f56e5674f82ef9c550eb0`;
local observation log `/tmp/x1-quartus-f013d02-turbo-single.log`.

The job is still running; no current-source fitted RBF/timing acceptance is
claimed. This revision uses the existing actual 28.571428 MHz single-clock
Turbo subset, with experimental Z, X3, DMA, Kanji, SIO and FM disabled.
It does not qualify those opt-in features. No MiSTer is contacted or loaded
for this refit; physical availability/ownership must be coordinated before
deployment. The available `9748410` RBF below remains the prior artifact,
not a result of this job. Check terminal flow, all eight timing corners,
unconstrained paths and frozen-input mutation before promoting a new artifact.

### Fresh source-bound refit, not yet deployed

The authorized misterubuntu checkout was clean and idle, then fast-forwarded
to pushed source `97484109c98f8d61691ff074dcfebfb104eb8178`. Quartus 17.0.2
preflight passes. A frozen `sharpx1_turbo_single` full-flow build started at
`2026-10-09T06:14:07Z` under
`/home/alans/mister/SharpX1_Mister/output_files/quartus-linux-FnvQHrn8/`.
Input-manifest SHA-256:
`da17fc7815a4d96f64f12a0d8bae67b939aebf27bc10e9f8923c941318e575b2`.
Local observation log `/tmp/x1-quartus-9748410-turbo-single.log`.
Full flow finishes at `2026-10-09T06:21:13Z`, exit zero, 136 warnings. Fit:
20,403 ALMs (49%), 393 RAM blocks (71%), 3,143,528 memory bits. The fresh
[RBF](../output_files/quartus-linux-FnvQHrn8/sharpx1_turbo_single.rbf) is locally
available, SHA-256
`864fe5d299771b7f88155a7ada07beb9d93203483a37193c516a13d40419119e`.
This source predates the subsequently added internal8 simulator experiment.
This existing revision tests default-disabled Z behavior plus the new DAM
transaction state; it does **not** enable X3, Z palettes/modes or DMA.
Supplemental path reporting and all-corner STA finish successfully. The first
multicorner command analyzed only four models; its original report/log remain
preserved. A subsequent explicit `--multicorner=on --all_corners=on` analyzes
all eight supported models. The RBF hash is unchanged. Worst constrained
slack: setup 0.514 ns, hold 0.064 ns, recovery 4.078 ns, removal 0.317 ns,
minimum pulse width 1.122 ns. Zero unconstrained clocks; 3 input ports / 7
input paths and 44 output ports / 50 output paths remain unconstrained.
No constraints changed. This is not full CDC/external-I/O/hardware signoff.
Local evidence: `output_files/quartus-linux-FnvQHrn8/`, including original
four-model report and distinct `eight-corners.sta.rpt`/`all-corners-eight.log`.

Post-build frozen-input checking returns 1: only `sharpx1.qpf` differs among
366 inputs, as Quartus adds its revision/date. All other 365 inputs pass.
Generated QPF hash:
`2477ae0a7eb559d84647efab65ec028c51ea3a0566c4062de16abf09240d78cf`.
The failed checksum audit is retained on the build host, not rewritten as pass.

Read-only status checks find mister126 running our older `X1M_20261009T005633Z_01`
test and mister14 running SharpMZ2500. Neither is loaded or interrupted;
availability coordination is pending before deploying this RBF. No contact
with reserved mister192.

### Earlier hardware observations

Browse `/media/fat/_Computer/X1Tests_20261008/` on mister126:

| MGL | Observed result on earlier RBF `43737566…` |
|---|---|
| `01_CROSS_Chase.mgl` | Native title, LEVEL 01 and live playfield; keyboard starts game |
| `02_Galaga.mgl` | Native title and GAME START after input |
| `03_Druaga.mgl` | GET READY / FLOOR 1 after input |
| `04_Mappy.mgl` | READY and populated stage after input |
| `05_Xevious.mgl` | Populated AREA 1 / SOLVALOU LIFT OFF after input |
| `06_Shanghai.mgl` | Native title after input; no tile-removal/playability qualification |

`07_CROSS_Chase_current.mgl` selects the new `a0a03761…` RBF below.
`08_CROSS_Chase_driveB.mgl` mounts CROSS Chase in B only on that RBF.
The initial B-only trial displays **IPL is looking for a program from CMT**,
not the game. Later cold-start held-F → drive digit 1 → Enter succeeds:
the actual drive-selection prompt and native CROSS Chase title are captured.
Only the B test disk is open in Main; its hash is unchanged. The failed
short/late-input trials remain preserved. See [native B follow-up](NATIVE_DRIVE_B_STATUS.md)
for the exact input sequence and clock-matched simulation qualification.
This qualifies protected B boot, not B writes or arbitrary disk sets.

Each points to a unique core/setname and disposable disk beneath
`/media/fat/games/SharpX1/HWTest/X1HW_20261008T…/`. No installed core,
configuration or original media was replaced. Zero per-test status config
requests protected writes; FAT chmod is not protection evidence. All six
remote disk hashes match the staged originals after testing.
MGL/manifest/actual PNG copies stay ignored under
`output_files/hardware126-20261008/`. Four commercial game-start observations
are **not five verified playable commercial games** and do not qualify
joystick movement, firing or fidelity. Twelve-second shots sometimes showed
loading/black screens; thirty-second captures and later inputs are preserved
separately. Screenshot labels are not assertions about contents.

MGL index 0 uploads the checked-in 4,095 IPL bytes padded with FF to 4 KiB;
uploaded SHA-256 `e6295a523008688421991b651ab61de392b28c67bec9efbf040b0004e4b70a2a`.
No debug RAM injection, converted state or patched game/firmware was used.

The installed remote-control service was stopped and was **not started**.
`scripts/mister_uinput.py` creates a temporary Linux keyboard, sends explicit
taps/chords, releases keys and destroys the device. Full key capabilities
allow Main's keyboard classification. An exploratory F12 opened OSD and
blocked later game input; closing OSD and sending Space reached LEVEL 01.
This is not physical-keyboard cold-start acceptance.

## Fresh source-bound RBF and timing

Build evidence on misterubuntu:
`/home/alans/mister/SharpX1_Mister/output_files/quartus-linux-ZOMREvtv/`.
Frozen source commit `5a40859092902b9fbbcfc551b2b3291bbd9ff695`, input-manifest
SHA-256 `0c8d1a5019ee2bef9c6e9264c488b1ff631833ed7689151f9ce647f96c5dc9c2`.
Quartus 17.0.2 Build 602, native full flow including build-ID hook; started
20:32:36 UTC, finished 20:39:58 UTC, exit zero, 126 warnings. Fit uses
20,432 ALMs (49%), 393 RAM blocks (71%), 3,143,528 memory bits.

Local artifact:
[sharpx1_turbo_single.rbf](../output_files/quartus-linux-ZOMREvtv/sharpx1_turbo_single.rbf).
SHA-256 `a0a03761ef9db2bf2a9a14ec5c281175cb02a33d7eaa07978551fe1f393260d3`.
Partial Turbo/single-clock configuration: configured board master 28.571428
MHz with enables, static F1 DIP. **No X3, DMA/IRQ/Ready, Kanji renderer, SIO,
FM or Turbo Z palette/modes are enabled by this revision.**

Supplemental unchanged-fit all-corner STA exited zero. All eight analyzed
models have positive constrained slack; RBF hash is unchanged afterward.

| Check | Worst slack (ns) |
|---|---:|
| Setup | 0.454 |
| Hold | 0.066 |
| Recovery | 3.551 |
| Removal | 0.409 |
| Minimum pulse width | 1.122 |

Zero unconstrained clocks, but 3 input ports / 7 input paths and 44 output
ports remain unconstrained. Inherited warnings, PLL startup/lock, external
signals, CDC and physical qualification remain open: not full signoff.
Reports/artifact copies are ignored under local
`output_files/quartus-linux-ZOMREvtv/`.

## Reset observations

Fresh deployment `X1HW_20261008T204348Z_a0a03761` boots CROSS Chase to the
same native title image as the earlier RBF. Keyboard input advances it.
The earlier RBF's Ctrl+Left Alt+Right Alt warm reset returned to that title,
and subsequent input advanced again without reloading the core or media.

On the fresh RBF, separate **OSD Reset** and **Reset and close OSD** input
sequences each return to the exact title PNG, SHA-256
`b9e2d2e38fb1e486fa130401aa3688284098a9625a5cda1b102070f2d2572ec5`.
Subsequent input advances again, SHA-256
`8a92b3ed5133ac2ef36505791801c400cacc263cf3b0750c460fd9473c49cc53`.
The latter is a starting score screen, not independently a live playfield.
No load_core, IPL upload or disk remount was sent between either reset and
its post-reset input. Core/setname remains unchanged and disk SHA-256 remains
`2fb70389737a7d54bff5a746b581343385ebde115cefb77ded32c473dcde97ec`.

Menu navigation was derived from the wrapper's eight selectable options and
inspected Main generic-menu code: F12, Up three times, Enter selects Reset;
close F12 before input. Reopen F12, Up twice, Enter selects Reset-and-close.
These are bounded dispatch/restart observations; PNGs capture core video,
not the OSD overlay. They do not prove every physical/menu/timing condition
behind the original reset report is fixed.

## Remaining hardware gates

The later [current-RBF/video matrix](HARDWARE_VIDEO_MATRIX_STATUS.md) rechecks
all six native titles on `a0a03761…`, reaches Shanghai's tile board, and adds
exact hardware RGB acceptance for six generated 40/80-column diagnostics plus
one PCG warm reset. It does not close the remaining gates below.

Repeat resets during active disk loading and longer gameplay; drive B and
ordered two-drive native tests; writable disposable media/error/format tests;
physical keyboard/joystick; audio capture/listening; HDMI/VGA and measured
clock. Requalify commercial controls on the fresh RBF separately. X3/400-line,
DMA, Kanji, SIO, FM and Turbo Z require distinct implemented/enabled
source-bound builds; this matrix cannot qualify them. No TODO group is complete.
Do not touch reserved mister192.
