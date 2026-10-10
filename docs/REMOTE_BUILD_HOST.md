# Remote build host and reserved MiSTer

Read-only checks on October 8, 2026 confirmed SSH access to `misterubuntu`
(user `alans`) and `mister` (user `root`). The latter is in use by someone
else: **do not deploy, load/reset a core, send input, or run tests until released.**
Its status files reported RBF `SharpMZ`, core `L12`; these are observations,
not an X1 hardware qualification. No commands were sent to Main.

The build checkout is `/home/alans/mister/SharpX1_Mister`, with origin
`https://github.com/alanswx/SharpX1_Mister.git`. Before setup it was clean at
`d684919`, matching the local checkpoint. Preserve any subsequent host edits;
only fast-forward a clean checkout. No ROM/font/game assets were transferred.

Native tools are installed under
`/home/alans/intelFPGA_lite/17.0/quartus/bin`: Quartus Prime Lite
**17.0.2 Build 602**, with Cyclone V device support. This differs from the
local Apple-container 17.0.0 Build 595; record tool versions and do not expect
bit-identical results. The host has 62 GiB RAM and approximately 309 GiB free
on its home filesystem at inspection. Another SharpMZ2500 Quartus build was
running; it was not interrupted, and no competing X1 compile was started.

## Preflight and build

```sh
ssh misterubuntu 'cd ~/mister/SharpX1_Mister && bash scripts/build_quartus_linux.sh --check'
# Coordinate build-host availability first; this does NOT access the MiSTer.
ssh misterubuntu 'cd ~/mister/SharpX1_Mister && QUARTUS_REVISION=sharpx1_turbo_single bash scripts/build_quartus_linux.sh --build'
```

The helper defaults to preflight only. Build mode refuses detected active
Quartus processes, makes a unique ignored `output_files/quartus-linux-*`
snapshot, compares source hashes before/after copying, and preserves a source
manifest, checkout status, full log, exit status and generated RBF hash.
It runs the native project flow including inherited hooks; project settings
(including processor count) remain unchanged. The process check is not a
host-wide lock, so coordinate simultaneous work. The source checkout and other
repositories remain untouched by compilation. `QUARTUS_BIN` overrides the
installation path; `QUARTUS_REVISION` selects the baseline, single,
Turbo single, Turbo video, or separate `sharpx1_turbo_dma_single` qualification
revision. The latter does not establish fitted/timing/hardware acceptance.

Setup/preflight does not prove successful fitting or timing closure. Inspect
all timing corners, unconstrained paths, warnings and source/RBF identities
before offering a tester build. Hardware acceptance remains pending; the
MiSTer reservation takes precedence over any automated deployment workflow.

October 9 follow-up: after a read-only process check found no Quartus jobs,
the clean X1 checkout was fast-forwarded from `e97a4ba` to
`db2dc8cd091065597e5128d8a4ae0fb2c7296eaf`. The handoff revision's native 17.0.2
preflight succeeded, but `--build` terminated one at its competing-process
guard: another `DSPPC604_check_core` flow started in the availability/update
window. A subsequent live process check confirmed `quartus_sh` PID 1569435
and its mapper, while the X1 checkout remained clean. No X1 snapshot/fit was
started and no timing/RBF acceptance is inferred from this attempt. Log:
`/tmp/x1-quartus-db2dc8c-handoff.log`. Preserve other users' jobs; a coordinated
slot and fresh current-source fit are still required for the PCG-reset repair.

After that competing flow ended, a fresh read-only process check found the
host idle again. The same clean, exact `db2dc8c` checkout then successfully
started `sharpx1_turbo_z_handoff` in
`/home/alans/mister/SharpX1_Mister/output_files/quartus-linux-H1XpgcbN/source`.
Local log: `/tmp/x1-quartus-db2dc8c-handoff-retry.log`. This is a source-bound
PCG-reset-repair fit, not a build of the newer local MR16 retention experiment.
That attempt now terminates **three**. Analysis/synthesis succeeds (150
warnings), but the fitter stops at the strict inactive-data SDC guard:
`hdmi_dv_data[0]` has mapped pin `|d`, whereas the selected candidate requires
the earlier fit's `|asdata`. `Read_sdc` fails; a later fitter 11802/resource
message is not separately established as the root cause. The source-bound
snapshot and failed logs remain intact. Repeat stage/topology discovery and
qualify any revised mapped/fitted pin contract before selecting constraints;
do not weaken the guard or classify this as completed timing/PCG qualification.
No new RBF is accepted or deployed, and no MiSTer is accessed by this helper.
