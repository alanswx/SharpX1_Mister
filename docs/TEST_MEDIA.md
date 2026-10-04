# Private game test media

The user-supplied `software/top32games.txt` shortlist is staged locally in
`software/top32-unpacked/`. All software folders are ignored by Git. No
commercial assets, extracted manuals or derived machine states are bundled.

From the repository root:

```sh
python3 scripts/stage_top32.py
python3 scripts/test_media_staging.py
```

`7z` is already installed on this host. The staging script reads ZIP and 7z
members without extracting archive-provided paths. It groups each shortlist
title under a numbered directory, preserves separate archive/disk-set
provenance, retains cassette files and extras, and writes SHA-256 manifests.
Native D88/D77 containers are unchanged. Exactly 327680-byte `.2d` files also
receive write-protected D88 wrappers with 40 cylinders, two sides, 16 ascending
256-byte sectors; sector payloads are byte-for-byte unchanged. Geometry and
track order were checked against the existing local MAME `2d_dsk.cpp` and
`wd177x_dsk.cpp`. Raw images cannot retain physical gaps, CRC errors or
protection timing. This is container conversion, not a patched game loader.

Files are created exclusively. Identical files can be reused; differing files
are never overwritten. To stage a changed shortlist or newly added archives,
use a fresh `--output software/top32-unpacked-v2` directory. The script checks
source hashes before/after each extraction and rejects oversized members.
Synthetic tests verify every converted sector/header and exclusive writes.

## Collection coverage, 2026-10-04

The current snapshot contains **20 of 32 titles** and **14 titles with disk
candidates**. Native/converted disks are only candidates: extraction does not
prove simulator preflight, IPL boot, base-X1 compatibility, controls or gameplay.
Some entries have only tape or documentation. Cassette loading is not yet
implemented. The shortlist years are retained as supplied, not verified X1
release dates. The generated private README lists all 32 entries.

A 128-reference-cycle run of the current fast simulator accepted **22 of 26
disk candidates** through structural preflight. Both Lode Runner images and
both Hydlide images were rejected for sector length/size codes outside the
current runtime. They remain intact in the test folder; do not patch headers
to conceal unsupported media. This short check loads no IPL and proves neither
disk scanning nor boot. Source archive hashes were unchanged, and a second
staging run reused all matching files without overwriting them.

Missing: Bruce Lee, Archon, Advanced Dungeons & Dragons: Pool of Radiance,
Binary Land, Fatal Fury Special, New Rally-X, Soko-Ban, Impossible Mission,
Fatal Fury 2, Bump 'n' Jump, Might and Magic II: Gates to Another World,
Ultima III: Exodus. Similar titles/sequels are deliberately not substituted.

`scripts/prepare_x1_media.py` separately stages a single ZIP for focused
commercial boot investigations. It preserves original archive/member hashes
and records any raw-to-D88 wrapping in a private manifest.

## Commercial acceptance gate

The ongoing five-game milestone requires five distinct commercial games
booting through the native IPL/controller, reaching live gameplay, and
responding reproducibly to documented/tested controls. Loading/title/credits
screens and direct RAM injection do not satisfy this gate. Initial six-second
native boots reached Druaga/Xevious loading screens and Shanghai credits;
none of those initial observations proves gameplay. Longer runs and control
probes are in progress. CROSS Chase is an existing homebrew regression, not
one of the five commercial games. Hardware retesting is unavailable while
travelling; simulation results must not be described as hardware validation.
