# Reset recovery

## Report and scope

Before this bring-up, a user reported that neither **Reset** nor **Reset and
close OSD** recovered Jason's X1 core; reloading the core was necessary.
That report remains a hardware acceptance item, not a confirmed diagnosis of
the old revision. Both the upstream wrapper and current `sharpx1.sv` map those
entries to status bit 0. The current reset is `RESET | status[0] | buttons[1] |
ioctl_download`, connected to the shared `rtl/sharpx1.v` machine. The active
machine restores the IPL overlay and resets CPU/sub-CPU/peripherals. This code
audit does not establish that Main dispatches either OSD action correctly on
the board, or that every reset-duration/software combination recovers.

## Confirmed current defect

The preceding disk transport fix had a reset regression: ACK sampling remained
gated by the FDC enable. The shared machine freezes that enable during reset.
An SD transfer completing while reset stayed asserted could therefore leave a
published request/transport busy forever. The original transport fixture used
CE=1 throughout reset and missed this integration detail.

Changing the fixture to CE=`!reset` reproduced `request not released after ACK
rise` on the pre-fix revision. ACK history and host-request completion now run
on every `clk_sys` edge, independently of emulated FDC enables. The controller
FSM still uses the FDC enable. Twelve pending-read/write D0/reset cases now pass
with stopped enables, including reset held through host completion, stable LBA
and pending-write data samples. Accepted host writes can still commit; this is
not a rollback mechanism or stalled-host timeout. This fix is not proof that
the historical report had the same cause.

## Local regression interfaces

The runner supports repeated `--reset-at MS` options and `--reset-for-us US`
(default 1000). Times are relative to the start of the invocation or restored
snapshot, not absolute snapshot time. Pulses must be ordered, non-overlapping,
after startup reset and wholly inside the requested run. Disk and PS/2 host
interfaces keep operating while machine reset is asserted. These are direct
machine reset events, not emulated Main/HPS menu commands.

`tests/test_warm_reset.py` uses an original ROM/RAM fixture. The ROM increments
a persistent RAM counter and enters a program which disables IPL and HALTs.
Two warm resets with widths 1, 100 and 1000 microseconds must re-enter retained
IPL, preserve RAM, and recover from HALT without another download. Runs repeat
deterministically; invalid pulse schedules are rejected. This test runs in the
baseline, single-clock and fast diagnostic suites.

Private-asset game reboot tests use freshly regenerated native checkpoints:

```sh
make -C verilator boot-game test-game test-game-reset
make -C verilator boot-game-single test-game-single test-game-reset-single
```

The warm game test restores the running game, resets at 1 ms for 1 ms, keeps
the disk mounted and sends the original start/input script. After 13 seconds,
it checks no ROM download occurred, disk reads resumed without writes, and the
rebooted game passes the original keyboard movement regression. Generated
states/images contain private assets and remain ignored. Successful machine
tests do not substitute for physical OSD-button testing.

Baseline and single-clock fresh boot and warm reboot pass, with 81 warm-boot disk reads,
zero writes and zero download bytes. The unchanged 200 ms movement test returns
idle/control player cells (22,14)/(21,13) and frame hashes
`2917b1d92124ea6c` / `16f792d1d2c74a8c`. These are real core RGB frames,
not reconstructed emulator screenshots. Baseline uses 32 MHz system and
28,571,428 Hz video; single uses 28,636,364 Hz for both. Both fresh boot and warm
reboot checkpoints are regenerated after the RTL fix. The retained IPL is the
checked-in 4095-byte image; private disk SHA-256 is
`2fb70389737a7d54bff5a746b581343385ebde115cefb77ded32c473dcde97ec`.

The generated-media machine test also resets during mount scanning (1 ms) and
again after scanning (50 ms), each for 1 ms. Baseline, single-clock and fast
variants complete actual register-driven disk reads with byte-exact sector
readback and unchanged original media. This exercises scanner continuation,
not cancellation/replacement of the mounted image or every parser-state phase.

The local Quartus single-clock build is bound to source checkpoint `5721df5`:
all stages pass, core setup/hold/recovery +10.050/+0.241/+12.561 ns, zero
unconstrained clocks. It still has 3 unconstrained input/44 output ports and
incomplete CDC/I/O signoff. RBF SHA-256:
`bf408a3927b0fa14768f7cc3cb7badd9094d364b814fa19712eca4bb498cb053`.
See `QUARTUS_BUILD.md`; no hardware deployment or physical reset validation
of this artifact is claimed.

## Hardware acceptance still open

MiSTer and cottageubuntu are unavailable while the user is travelling; do not
attempt remote access. When explicitly available again, test a source-bound RBF
with protected disposable media, without using core reload as recovery:

- Reset and Reset-and-close from both native title and running gameplay.
- Repeated presses and the physical/user reset input; confirm IPL re-entry and
  game restart, retained media and working keyboard after every reset.
- Reset during disk loading, plus separately instrumented host-I/O cases.
- OSD remains open for T and closes for R; Main dispatch and pulse width need
  actual board evidence. Retain screenshots, source/RBF/asset hashes and logs.

Malformed media, eject/remount, stopped host service, scanner reset and physical
input/PLL/CDC behavior remain separate bring-up items.

## Prepared repeated physical-menu check, not yet executed

October 9: the user has subsequently released named units; the travelling
availability note above is historical. A new availability confirmation is
requested before sending input or loading another test on mister126.
`scripts/mister_reset_check.py` now supports 1–8 rounds of both actual Main
menu entries, with one initial protected MGL load and no recovery reload
between rounds. Repeated execution requires `--expect-active SETNAME` and
checks the exact active set before creating evidence or issuing load/input.
Each menu iteration keeps distinct before/after/post-reset-input PNG names,
exact native-title pixel comparisons, unchanged set/core and media hashes.
Default one-round behavior remains unchanged.

Asset-free orchestration tests pass six cases, including bounds/required
active guard, read-only preflight, three rounds/one load/18 unique images,
changed-core refusal and retained failing-pixel evidence. Existing five
matrix CLI safety cases also pass. Log:
`/tmp/x1-repeated-osd-orchestration-final.log`. These mocked pixels/SSH/sleeps
are not MiSTer or native gameplay results. Script SHA-256:
`bccfa0ec071da959778d2e3e7827ee9d5ac9c70d50319279f151f99206799e77`;
test SHA-256:
`2bb3b4d8657da714dae6b5440c1ca28d28f1e4f089a68e0ad7cca0b26864d752`.

Actual read-only preflight subsequently terminates zero through misterubuntu
on mister126: prior RBF `c1d83e6b...98bc8ca3`, existing protected IPL/disk and
installed input-helper hashes match the original matrix; active set remains
`X1M_20261009T005633Z_01`. Log:
`/tmp/x1-repeated-osd-hardware-preflight.log`. No core is loaded, no input is
sent and no screenshot is requested by preflight. This is readiness for an
older source-bound DMA-board artifact, not current Z/PCG fitting or physical
reset acceptance. mister14 and reserved mister192 remain untouched.
