# Default-off shared-machine FM CPU bus

October 9, 2026. `rtl/sharpx1.v` now has a default-zero `TURBO_FM_CPU`
parameter active only with `TURBO=1`. It connects the conservative decoder,
original adapter and attributed genuine JT51 in `rtl/x1_fm_bus.sv`.
Dependencies are in `rtl/machine.qip`. Existing C++/board profiles stay off.
This is a CPU-bus increment, not completed native Turbo Z sound.

## Implemented boundary

Only exact `0700/0701` unambiguous CPU I/O cycles are selected, excluding
DAM/reset/ACK/active memory and actual DMA ownership. Functional adapter WAIT
joins the existing machine WAIT. Status is live during selected read and
retained through its trailing I/O phase; reset/next memory read clears that
tail. Writes still capture once and dispatch one immutable pending operation.
CPU software polls genuine busy; the adapter does not pretend busy writes
are accepted. The existing drained `core_reset` resets FM, not raw BUSRQ or
an early reset that abandons an owned DMA pair.

FM advances using the existing fractional 4 MHz/half-rate enables on SYS,
at 32 MHz or the configured single-clock master. No fabric-generated clock
is introduced. Device IRQ, sample and signed stereo wires are genuine but
remain diagnostic outputs: unresolved native IRQ routing is not connected
to CPU/CTC; CT1/CT2 are not invented CTC inputs. The base unsigned PSG audio
port and MiSTer audio path are unchanged. **Enabling this CPU profile does
not yet provide mixed FM sound to MiSTer or the C++ WAV interface.**

No ASIC mirrors, optional `0704..0707` CTC or Turbo Z capability signature
are invented. Native select/WAIT/pin timing, IRQ routing, DMA-owned FM
transactions, signed PSG conversion and stereo/mono gain/output remain gates.
Licenses and JT51 provenance are unchanged; source-notice/release review
remains necessary before distribution.

## Executed shared-machine test

`test-machine-fm` uploads an original generated 8 KiB IPL through ioctl with
`ioctl_wait` honored. Actual CPU IN/OUT/store instructions read reset status,
program CT/timer registers, poll busy, observe Timer A and stop/clear it.
Actual PPI mode/C5 transitions arm DAM; the following `0700` OUT goes to
GRAM, not FM. An unselected `0702` IN returns FF and clears DAM. A real
four-byte DMA copy of CPU-written `31..34` from `8000` to `9000` completes
through actual BUSRQ/BUSACK and never selects FM while owning the bus.

Every complete native execution requires exactly ten real chip dispatches,
observed busy/WAIT/DAM transactions, four DMA reads/writes and exact RAM bytes.
CPU-written reset/timer/clear/unselected results are `00/01/00/FF`. Both
HALT and actual timer-flag warm resets reboot unchanged retained IPL without
uploading assets or forcing CPU/device state. During 256 reset edges, CPU
and device advancement CE stop; FM WAIT/tail/timer IRQ/CT/sample clear.
This tests drained resets, not reset requested during an owned SD/DMA pair.

All three enabled models and the disabled negative terminate zero with seven
PASS reports in `/tmp/x1-v16-fm-tail-monitored.log`, Verilator 5.044:

| Model | SYS | Video |
|---|---:|---:|
| Baseline independent clocks | 32,000,000 Hz | 28,571,428 Hz |
| Nominal single-clock | 28,636,364 Hz | same SYS |
| Board-frequency single-clock | 28,571,428 Hz | same SYS |

SV half periods are integer picoseconds, rounded down from each stated nominal
frequency. These are functional fixtures, not physical phase measurements.
The disabled profile executes the unchanged IPL and must fail specifically
`shared FM programmed decode/read failed`, not time out.

Initial failures are retained: `/tmp/x1-machine-fm-first.log` incorrectly
programs interrupt controls into a no-IRQ DMA fixture; the next stream still
lacks a Ready configuration (`/tmp/x1-machine-fm-no-irq-stream.log`). A forced
Ready attempt transfers only one byte before Byte mode clears the force
(`/tmp/x1-machine-fm-force-ready.log`). The final program uses real WR5=8A
to accept the existing inactive-FDC Ready level. No DMA RTL or count/payload
assertion is changed to pass these failures.

A separate `/tmp` source mutation removes FM read tail. The initial CPU
program alone still passes (`/tmp/x1-fm-tail-negative.log`), exposing a
coverage gap, not proving a CPU failure. The strengthened fixture checks
the actual post-read bus phase: held status, tail and CPU DI must agree,
and at least one such phase must occur. The same mutation now fails
`shared FM trailing read response lost`, exit 1
(`/tmp/x1-fm-tail-negative-monitored.log`). It is never applied to working RTL.

Source SHA-256:

| Source | SHA-256 |
|---|---|
| `rtl/sharpx1.v` | `f10c56237dedb6aac06bd542124d9f87e8b81af8a3eaa530704bb75e9bebafe2` |
| `rtl/x1_fm_bus.sv` | `9ffc0b92ae994ba22f99a2a87157abb934bd192b6de36a7cc1549ef1b7385931` |
| `verilator/tests/machine_fm_tb.sv` | `aa796f195ab50ed0c4ddb7df7279030b2309bd5878cd9f2e2127670a83fce190` |

Inherited CPU/vendor warnings remain visible; no new suppression is added.
Base, Turbo DMA and X3 wrapper PLL-stand-in lint also exits zero
(`/tmp/x1-v16-fm-wrapper-lint.log`), not Quartus or hardware acceptance.
Existing shared SIO cold/warm/WAIT/×1/×16/absent-DMA checks pass alongside
the preceding FM fixture (`/tmp/x1-v16-fm-sio-machine.log`, 20 PASS reports;
the strengthened FM tail monitor is qualified by the separate final log above).

## Snapshot and full acceptance status

The optional FM integration changes generated ordinary model binaries; no
compatibility with older serialized layouts is assumed. Application snapshots
are now **v16**, rejecting v15/older before deserialization. The negative
version test changes only its generated incompatible header, never a real
private state. Fresh direct ordinary snapshot/continuation/input/clock checks
exit zero (`/tmp/x1-v16-snapshot.log`). No enabled-FM savable C++ profile exists.

The full ordinary v16 fast suite terminates zero with 137 PASS reports
(`/tmp/x1-v16-fast.log`). The delay-aware suite remains running separately
in `/tmp/x1-v16-baseline.log`. Earlier ordinary v15
baseline finishes zero with 140 PASS reports in `/tmp/x1-sio-x1-baseline.log`;
that runner is `f1af4f88...`, not current-source v16 acceptance.

Fresh five-game v16 native boot/control qualifications now all terminate zero from the
pre-frozen runner/support/IPL/source tree
`verilator/obj_dir_v16_fm_machine/games-r7GvWa`. Executable SHA-256 is
`b7ae59432af08fd357f5721840a54316587819a021c81dd82dc44df40105435a`;
delay-aware v16 runner is `9b55d9cb5ef0502509d549d91fc2e3f9ad29b6f3dbc3f3413b189d6fe2b75231`.
Private originals are protected and snapshots/screens/media remain ignored.
An independent post-completion audit checks all collector flags/return codes,
every native-prefix state hash, original/frozen input hashes and all six runner
copies. Galaga firing also exits zero. See [commercial evidence](COMMERCIAL_COMPATIBILITY.md).
The delay-aware baseline remains separate; do not reuse/convert older states.
No new current-source Quartus fit, RBF or MiSTer load is claimed. Native
FM/audio/Z acceptance and work groups 1–6 remain incomplete.

## Explicit PPI C5 follow-up

The initial program's PPI mode-set could itself arm DAM before the following
C5 OUTs, so that earlier case primarily qualified mode-set-induced DAM. The
strengthened IPL explicitly reads unselected `0702` after mode-set to clear
that arm, then writes C5 high and low. The observer now requires both actual
PPI values during unambiguous non-DAM writes, followed by the DAM `0700` OUT.
All three clocks and the disabled negative terminate zero again, seven PASS
reports in `/tmp/x1-v16-fm-ppi-transition-final.log`. The updated fixture hash is
`ed0d96217b3dbe6a4466a4c3f883aa809534d5722da6e132bbe2b05fa76afdf4`;
the earlier hash/log remains historical. Machine RTL/runner/snapshot layout is
unchanged by this fixture-only extension.

An authorized source-frozen Quartus 17.0.2 refit of pushed
`832766f9a81146c10511dfc85b1876b4d16aa857` is now running on misterubuntu
under `output_files/quartus-linux-c70iRYNK`;
local log `/tmp/x1-quartus-832766f-turbo-single.log`. Host checkout was clean
and no Quartus job was active before launch. This revision still disables
FM/SIO/Z/X3/DMA/Kanji. No completed fit/timing/new RBF or enabled-FM physical
acceptance is claimed from this live process. No MiSTer is accessed/loaded.
