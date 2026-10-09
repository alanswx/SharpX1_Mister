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
