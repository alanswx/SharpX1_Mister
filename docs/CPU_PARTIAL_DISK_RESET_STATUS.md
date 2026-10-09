# CPU partial-sector reset with live FM

October 9, 2026. An explicit `CPU_PARTIAL=1` extension of the original
generated-media SD reset fixture exercises actual CPU IN/OUT payload cycles,
not DMA transfers. Production RTL, v17 snapshots and board revisions are
unchanged. SYS=32 MHz / VID=28.571428 MHz, Turbo and FM enabled. DMA capability
is enabled **only so its reset guard retains the short request**; no DMA
program, grant or payload pair occurs. SIO/Z/X3/Kanji are off.

## Executed checks

The unchanged real loader and autonomous SD host serve two distinct generated
D88 images. Actual CPU instructions program sound/timer/CT, mount/select the
drive, poll DRQ and perform the sector data transfers. The fixture waits for
64 genuine CPU payload strobes and their bus release before resetting; FDC
must still be busy with no pending SD request. No ownership, Ready, CPU
register, disk buffer, audio sample or media byte is injected.

Eight cases cover A/B, read/write and held/2 ns reset. Every case requires:

- Zero DMA grants/reads/writes throughout; exactly 64 aborted CPU bytes.
- Live FM/PSG sample observations, genuine timer IRQ and CT before reset;
  reset clears sound/control, and retained-program reboot restores them.
- No additional payload or host-write publication during the bounded reset
  interval. Held reset stops CPU/FDC enables; the 2 ns pulse is retained by
  the opt-in guard.
- Both complete images unchanged **before retry**, including deleted mark,
  B0 data-CRC status, padding and the untouched drive. A later successful
  write cannot conceal an incorrectly published partial sector.
- The unchanged retained IPL re-enters twice without another upload, finishes
  256 fresh CPU bytes and HALTs with its own A5 result. Total payload count is
  320 in the selected direction and zero in the other. CPU read validation
  compares every returned byte; writes compare both whole final images,
  including normal-mark/CRC repair.

`make -C verilator test-machine-cpu-partial-reset` finishes with exit zero,
all eight distinct profiles (`/tmp/x1-cpu-partial-reset-final.log`). An
independent profile-count audit passes. Original FM-disabled DMA pending-host
payload regression also finishes zero, eight distinct cases
(`/tmp/x1-cpu-partial-default-final.log`). The earlier 64-case FM metadata
qualification remains bound to its recorded previous fixture/executable;
this increment does not retrospectively requalify that frozen result.

Pre/post hashes match:

| Artifact | SHA-256 |
|---|---|
| Extended fixture | `2bb38c967a51bae99f8ae19b8995a01e91d1148daa5622750e90ac4755af4fe6` |
| Shared machine | `ddb49969b0c4e3cb0000c0aaac434c175e841e4dfa8c99f14b8c2f568e333b67` |
| CPU-partial executable | `2c73402553f1f9f0b2dffd1ba247b671820a53dacebfa0b9643abe34bfbd55ca` |
| Default DMA regression executable | `ae2297330b6fa108356c9b0be4d3fadfceae0876ae8bbad52fd04237150d0455` |

Verilator 5.044 runs delay-aware scheduling/assertions. No new fixture warning
or suppression is added; inherited machine warnings remain. This tests the
64-byte interruption point, not every byte or exact rotational/reset timing.
Base profiles without the DMA reset guard, short pulses on fitted hardware,
Ready loss, no-ready, CRC/lost-data interruptions, mixed services, native
software and physical OSD/media/audio remain open. Work groups 1–6 are not done.

## READY follow-up: separate the contracts

The existing Fujitsu datasheet was inspected again, locally and through its
[manufacturer-authored scan](https://knetonator.de/dashboard/PPG/Manuals/WT-A%20MB8876A_FujitsuMediaDevices.pdf).
PDF page 3/printed 4-29 describes READY admission for read/write separately
from seeks; page 7/printed 4-33 describes live not-ready status and Type II/III
admission. Type IV separately programs READY transition interrupt sources.
That prose does not specify an unconditional immediate abort at every
mid-payload READY fall. Do not add one merely to make a new fixture pass.
PDF SHA-256: `3358e0cefabb858261177d3f658c63db3f4142f9bfb826339135d5c19ab1b91b`.

Read-only inspection of existing MAME revision
`f4bfc5a423f48d48e809c01fc70a47c0c00d40a2` confirms separate
`read_sector_start()` admission, live `status_r()` READY reporting and
`ready_callback()` Type-IV edge handling, without an unconditional command
abort in that callback. Neetan's inspected scheduler checks drive availability
at command-task execution; that is not a native pin trace or proof of equal
mid-byte behavior. Neither emulator was executed for this comparison.

In this core, `x1_disk_media.ready` additionally reflects host image presence,
selection/rescan quarantine and valid D88 indexing. Removing an image is not
an independently controlled mechanical READY pin. Next acceptance must label
these separately: no-ready command rejection; READY-edge status/interrupts;
image-removal/host-drain safety; and authentic mid-transfer READY/pin behavior.
The current partial reset tests cover none of those by resetting the machine.
