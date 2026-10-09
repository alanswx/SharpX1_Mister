# Experimental X3 coherent CRTC writes

## Scope

`TURBO_VIDEO_MASTER=1` now transfers a held nine-bit `{RS,data}` packet
from SYS to VID before the actual inherited CRTC MPU consumes it. Ordinary
machine profiles retain their original direct MPU bus. CPU and DMA WAIT
remain asserted until destination consumption and synchronized acknowledgement.
This is functional transport latency, not a measured native ASIC bus contract.
The mirrored `18xx` write decode and address-bit-zero RS selection are retained;
no CRTC readback port is invented. Local MAME `src/mame/sharp/x1.cpp` maps
address/register writes at `1800`/`1801` without a corresponding read mapping.

`rtl/x1_crtc_write.sv` is original GPL-2.0-only code in the shared machine
manifest. Its request and acknowledgement each use two destination samples;
the bundled packet stays held until acknowledgement. The destination registers
the packet, then acknowledges on the following edge when the MPU actually
consumes the write. Only the MPU bus clock changes: other inherited video
CPU-bus consumers are not silently moved. CRTC programming is retained by
warm reset, as before. A reset before consumption cancels a pending write;
a reset after consumption must not replay it.

## Executed local checks

- `test-crtc-write`: actual inherited MPU, four video half-periods
  11,640/17,500/15,625/125,000 ps against SYS half-period 15,625 ps. R5/R9
  packet sweeps, altered source data after capture, held selection, exact
  single writes, stopped SYS/VID and pre/post-consumption reset checks pass.
  The actual raw-bus negative control fails the expected coherence assertion.
- `test-machine-crtc-write`: generated original IPL uploaded through ioctl,
  real CPU writes through mirrored ports, 132 writes plus retained-IPL warm
  reboot, exactly 264 MPU commits. Three video half-periods
  11,640/17,500/125,000 ps pass, including genuine stopped-video CPU WAIT.
- `test-machine-crtc-dma-reset`: five actual BUSACK-owned reset scenarios
  pass: reset during read/write, stopped SYS, attempted asset upload during
  drain, and stopped VID while a CRTC write is pending. Each drains one
  pair, reboots from retained IPL and completes sixteen more pairs; exactly
  seventeen actual MPU writes and correct R5 values are required.
  The four RAM and five PCG reset controls also pass again.
- The fresh delay-aware X3 pixel matrix passes all sixteen 40/80-column
  graphics/text/mixed/pattern/stretch/PCG/blink cases, checking 1,536,000
  exact pixels at SYS=32 MHz and nominal VID=42,954,540 Hz. Frozen inputs
  are under ignored `verilator/obj_dir_headless/crtc-qualification-KkSnAN/`.
- Current X3 snapshot continuation/profile checks and ordinary snapshot
  checks pass. X3 identity adds bit 62 while retaining format v17; actual
  unmodified pre-CRTC and pre-blink X3 states are rejected before
  deserialization. Ordinary serialized layout/checksum remains unchanged
  against the archived baseline. This is not byte conversion or native boot.
- Connected experimental control/reset tests and wrapper lint pass;
  wrapper lint does not qualify Quartus or physical CDC placement.

### DMA diagnostic correction, not a DMA RTL workaround

The first new CRTC fixture failed: actual DMA I/O address was `0000`, with
IORQ active and M1 inactive-high, rather than intended `1801`. Explicit bus
assertions reproduced that failure in `/tmp/x1-crtc-dma-address-probe.log`.
The generated CPU program omitted the already-qualified fixed-destination
two-LOAD sequence (`dma_tb.sv`, `DMA_CPU_BUS_STATUS.md`): LOAD initializes
only the selected source counter. It now temporarily selects B as source,
LOADs B, then selects/LOADs true A before ENABLE. No DMA RTL was changed.
The actual-address assertion remains, and all five reset cases pass in
`/tmp/x1-crtc-dma-qualified.log`. No assertions or target values were relaxed.

## Source and evidence binding

Machine SHA-256:
`4970b7922499432ae2106ab650b0bc635af9f3a988df0b0254c5822f575f0d7e`.
Transport SHA-256:
`e7a0711caa01b04c84b1174efcc076bb2d5aae199a1bf75f72b5a6aed7897fa7`.
Legacy video SHA-256:
`0441f52361d5a668d356b2a05a9ce566571dc35d527cc3c5d1c2b274121033db`.
Frozen X3 delay-aware runner SHA-256:
`0a479baab7e5656de37abb33056fe6ffba995d512e51a3c3b772cf0121b41e99`.
Logs: `/tmp/x1-crtc-write-phases.log`,
`/tmp/x1-crtc-machine-regression.log`,
`/tmp/x1-crtc-x3-pixel-matrix-cwd.log`,
`/tmp/x1-crtc-x3-snapshot.log`, `/tmp/x1-crtc-base-snapshot.log`,
`/tmp/x1-crtc-connected-regression.log`.

## Still open

The full ordinary regression process is now terminal. Its transcript reaches
the last prescribed disk-control/index fixture with 143 PASS reports and no
failure marker, and the delay-aware runner hash remains
`e249710de0653c60424dd3f8c6d2b3e423fe4ff285de2c8d174e5d256c04336d`.
Log `/tmp/x1-crtc-full-baseline.log`; the original outer execution handle was
lost during a tool reset, so an observed outer exit status is not claimed.
The final command sequence and actual fixture results, not a missing handle
alone, establish that the test execution reached its end.
The two older frozen 120-case Z
matrices are historical for this changed machine. A fresh current-source
120-case combined matrix now runs under
`verilator/obj_dir_headless/z-crtc-combined/qualified-inputs-bJ8Ldf/all-120/`,
log `/tmp/x1-crtc-z-combined-all-120.log`. Its actual-runner preflight passes
all seven requested feature flags and nominal clock checks before the first
pixel case. Runner SHA-256:
`46ecba0cc7d69c80480b012856e585b19984f89d02f734363cd498100b92e1d9`.
The runner, oracle, emitter, scheduler, font reference and RTL copies are
frozen; scheduler checks input hashes before/after each case. Started is not
completed. Fresh combined-Z pixels,
commercial/native Turbo software, physical reset/input/audio and current-source
Quartus fitting/timing remain required. Commit `72b77c4` has started a frozen
`sharpx1_turbo_z_video` build on idle `misterubuntu`, under
`output_files/quartus-linux-4005kWb5/`; log
`/tmp/x1-quartus-72b77c4-build.log`. It is now terminal: manifest exit status
3 at 21:02:46 UTC. The fitter and assembler complete, but final STA rejects
the PCG address-destination inventory. Reported setup is -12.532 ns under
incomplete constraints; this is neither closure nor a valid complete audit.
RBF SHA-256 `5ffbe347971be075e4d080a99f9ef1cae170b8d79316d8aa27505d6639e916ac`
is unqualified. Original output reports are preserved as `completed-flow/`
before supplemental tools run. No native CRTC report pass is claimed.
The earlier `6e334b4` blink RBF does
not include this change and fails overall setup timing.

FPGA acceptance needs source-bound request/ack synchronizer inventories,
held nine-bit packet bounds, actual VID MPU/consumer endpoints, reset-release
checks and complete global timing. Do not waive whole clock domains or treat
per-bit synchronizers as coherent register writes. No new timing exception
or physical hardware acceptance is established by these simulation tests.

## Supplemental reporter prepared, not executed natively

`scripts/quartus_crtc_write_paths.tcl` inventories the unique transport,
all nine held/captured bits, both exact two-stage chains and native first-data
pin fanins. It requires actual R5/R9 MPU bits and reports all MPU register
inputs/consumers. Its twelve scopes cover request/ACK input, chain, first-stage
fanout and final-stage consumers, held packet, captured packet fanout, and
MPU input/output. Eight corners and setup/hold produce 192 reports. The script
does not add timing exceptions or modify project settings. Raw input and
bundle edge timing must not be called synchronous acceptance.

`make -C verilator test-crtc-write-paths` passes exact mock scope/bit coverage
and 28 malformed-inventory negatives. The fixture rejects any exception
command. This qualifies reporter logic only; the current fit must finish,
its original reports must be preserved, and the host must be idle before
native execution. Physical inventory, clock domains, bounded payload delays
and global timing are still unqualified.

Current Quartus mapping accepts/elaborates the new transport but emits warning
10335 for its generic `async_reg` attributes on both synchronizer pairs.
Do not infer Intel synchronizer recognition or metastability placement from
those attributes. The recognized preservation hint and logical two-stage
structure are not physical acceptance either. Review the actual fitted
inventory first; the Intel-specific identification hint already used in
`x1_video_blink.sv` is a candidate for a separately source-bound follow-up,
not something silently attributed to this active frozen build.

`audit_crtc_write_reports.py` independently compares both chain consumer sets
and every capture/MPU source-to-consumer pair against native fanout observations.
It requires all nine logical packet mappings, actual domains, nonnegative
same-clock slack and a strict one-VID-period physical packet bound. Raw
request/ACK edge slack stays OPEN, and no exception is issued. Its 192-report
synthetic fixture and 30 scope/domain/data/inventory/tool-error negative controls pass
through `test-crtc-write-report-audit`. This is parser coverage, not fitted
timing, global closure or metastability qualification.

## PCG fitted-inventory rejection diagnosed

The new fit retains eleven primary `access_addr` bits plus exactly
`access_addr[4]~DUPLICATE`. No new logical bit is implemented. Reporting-only
native inspection without reading SDC records all twelve endpoints and their
fanins/fanouts in `/tmp/x1-crtc-pcg-address-inventory.log`. Primary and clone
have identical native input keepers; both drive actual PCG RAM address pins.
The strict previous eleven-endpoint gate correctly refused this new layout.

The follow-up candidate recognizes only that exact fitted alias, includes
both destinations in address/control bounds, checks their native fanins match,
and still rejects unknown/duplicate/mapped aliases before issuing any bounds.
Native candidate inventory validation passes all six groups (16/5/8 source
registers, 12/36/192 destination registers) without loading project SDC or
claiming timing: `/tmp/x1-crtc-pcg-candidate-native.log`. The independently
reported stage-01 replica count is zero. Mock inventory tests now reject
115 bad profiles, including missing/different clone inputs; generated report
tests separately require independently supplied stage/address replica counts
and matching primary/clone control-source sets. Fresh source-bound full flow,
mapped inventory, physical delay and all-corner timing remain required.

Commit `fcd1086` now starts the fresh full flow in
`output_files/quartus-linux-6FBt6YWN/` on `misterubuntu`; log
`/tmp/x1-quartus-fcd1086-build.log`. It is still running, not a completed fit
or timing pass. The prior build's preserved reports and manifest have been
retrieved locally under ignored `output_files/quartus-linux-4005kWb5/`.
The independent CRTC auditor now rejects any native error line or missing
zero-error STA completion, including an SDC failure alongside a successful
Tcl evaluation. It cannot turn the rejected original flow into acceptance.

## Completed PCG follow-up fit; native CRTC inventory still open

The `fcd1086` full flow finishes zero at 21:16:25 UTC, with no SDC inventory
error. The RBF hash remains `5ffbe347971be075e4d080a99f9ef1cae170b8d79316d8aa27505d6639e916ac`:
the repaired endpoint gate does not imply a new physical core. Reported flow
minima are setup -12.003 ns, hold +0.127 ns, recovery +4.377 ns,
removal +0.878 ns and pulse width +0.529 ns. These are the original flow
summaries, not a completed independent eight-corner audit or timing closure.
Original reports are preserved on the host in this build's `completed-flow/`.

The first native CRTC reporter exits 3 before any corner reports: it rejects
`acknowledgement~DUPLICATE`. Its log is `/tmp/x1-crtc-native-timing.log`.
An isolated reporting-only inventory without SDC then finishes zero, log
`/tmp/x1-crtc-fitted-inventory.log`, using
`scripts/quartus_crtc_write_inventory.tcl`. It finds 29 transport registers
(including the acknowledgement replica), 81 MPU registers, and actual
first-data pins named through Quartus's untyped instance aliases. Request
meta's ASDATA is fed by `request`; acknowledgement meta's ASDATA is fed by
the replica. MPU replicas include `R_ADR[0]` and `R_Nhsp[3]`; R5/R9 remain
primary bits. Next work must review native alias equivalence and bind reports
to the actual first-stage source/pins, not simply accept arbitrary duplicates.
No CRTC corner timing, bounded packet or physical placement pass is claimed.

The [Standard Edition synchronizer-identification guidance](https://docs.altera.com/r/docs/683323/18.1/quartus-prime-standard-edition-user-guide-design-recommendations/force-the-identification-of-synchronization-registers?contentId=P3OZQDuuMGqhph_2qBxDhw)
describes the Forced If Asynchronous setting. This is a newer documentation
reference, not proof of Quartus 17 placement or a changed CRTC source hint.

### Reviewed ACK replica and failed independent coverage audit

The reporter now permits only the exact fitted `acknowledgement~DUPLICATE`
source, requires its nonempty native input-keeper set (names and types) to
equal the primary's, and selects the source observed at the first-stage
data pin. Synchronizer-stage aliases remain rejected. The independent auditor
checks both observations rather than trusting a replica acceptance marker.
Mock reporter/parser checks pass with 31/38 rejected inventories respectively;
these are synthetic controls, not native timing evidence.

The reporting-only native run ends at 21:27:33 UTC with zero errors/warnings,
producing 192 reports from the existing `fcd1086` fit and unchanged constraints.
Log `/tmp/x1-crtc-native-alias-timing.log`; reports retrieved into ignored
`output_files/quartus-linux-6FBt6YWN/crtc-alias-acceptance/`.
This run predates the reporter's additional explicit first-data register-type
check, although its actual observed sources are registers. No new fit or RBF
was generated.

**Independent acceptance fails:** the first slow/-40/setup MPU consumer
inventory expects 1,341 unique source/target pairs, but reports contain
1,269; all 72 missing pairs are attributed to original `R_ADR[0]`.
Hold shows the same discrepancy. A name lookup of that register resolves
both primary and `R_ADR[0]~DUPLICATE`; a replica lookup resolves only the
replica. Therefore name-expanded fanout observations must not be mistaken
for exact physical keeper coverage. `scripts/quartus_crtc_replica_probe.tcl`
is a reporting-only alias-group diagnostic, not an acceptance gate. Its
collection-based run finishes zero errors/warnings at 21:34:49 UTC, log
`/tmp/x1-crtc-replica-probe-alias-group.log`; original-name and replica-only
groups report separately without substituting node IDs as collection strings.
Exploratory register-ID-as-string attempts generated ignored-filter warnings
and are not accepted evidence. Additionally, actual MPU input reports include
the video-domain reset-release register, which the current launch-source
allowlist does not cover. Its native route needs explicit qualification, not
a general unknown-source exemption.

Next: resolve physical versus alias-group inventory, qualify the local reset
source, rerun the final reporter and independent all-corner audit. Until then
there is no native CRTC synchronous/bundle pass. Raw input/MTBF, global timing,
native software and physical acceptance remain open.

## Actual pending-transaction snapshot follow-up

Read-only X3 runner JSON now exposes held packet, handshake phase and actual
MPU R5/R9/index observations. No machine port, CRTC bus readback or serialized
state is added; ordinary JSON remains unchanged. The cold-reset duration
guard previously also rejected short restores, even though restored RTL does
not take a cold reset. The runner now applies that guard only to cold starts,
allowing zero/single-cycle continuation while retaining header/clock/range/
asset checks. No snapshot format conversion or identity change is needed.

`test-crtc-pending-snapshot` freezes its executable/emitter before running an
original CPU program that sets actual CRTC timing then alternates R5/R9 data.
It observes request-in-flight, captured-before-consumption and
consumed-before-source-ACK states for three CPU-padding variants at the
unchanged nominal X3 rate. Nine unmodified saved states pass ninety resumed
versus straight-run comparisons, including zero and single-cycle boundaries,
with byte-identical full serialized states, matching actual MPU/handshake/CPU
observations, correct final HALT/registers and preserved original state hashes.
Cold reset-only/zero-reset runs and forbidden X3 clock overrides remain rejected.

Frozen runner SHA-256:
`da47f228c34a9d095fcccc47398ea114d3fee2dc35cd01dcb40d2d20ac33f5c2`.
The initial frozen pass is under
`verilator/obj_dir_headless/crtc-snapshot-qualified-ZYufRv/`, with both hashes
rechecked successfully; log `/tmp/x1-crtc-pending-snapshot-frozen.log`.
The final target also includes cold/clock negative controls; log
`/tmp/x1-crtc-pending-snapshot-final-target.log`.
Existing X3 profile/continuation and ordinary snapshot regressions pass in
`/tmp/x1-crtc-short-restore-profile-regression.log` and
`/tmp/x1-crtc-short-restore-base-snapshot.log`.
Actual old pre-CRTC/pre-blink v17 runners also generate unmodified states
that the new runner rejects before deserialization, log
`/tmp/x1-crtc-short-restore-old-profile-regression.log`.
This is non-delay-aware snapshot qualification of generated diagnostics, not
native game boot or a physical reset/timing claim. The invocation-local
rolling `video_hash` is not serialized and cannot be compared between a zero
continuation and an entire cold run; actual model bytes and observations are
compared instead. Unprogrammed raster failures were corrected by actual CPU
timing initialization, never by disabling frame bounds.
