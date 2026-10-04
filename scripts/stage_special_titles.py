"""Stage only locally supplied Arcus/Bastard Special archives; never download.

Reuses the top-32 archive reader, safe names and non-overwriting writes.
Extracted private bytes are unchanged; hashes bind probes to this release.
"""
import argparse
import json
import pathlib
import re
from stage_top32 import members, sha, write_new

TITLES = {
    "arcus": ("Arcus", "Sharp X1/Arcus (Wolf Team)/Arcus (X1turbo) [FD].7z"),
    "bastard-special": ("Bastard Special", "Sharp X1/Bastard Special (Xain Soft)/Bastard Special [FD].7z"),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--software", type=pathlib.Path, default=pathlib.Path("software"))
    parser.add_argument("--output", type=pathlib.Path, default=pathlib.Path("software/special-unpacked"))
    args = parser.parse_args()
    root, output = args.software.resolve(), args.output.resolve()
    rows = []
    for slug, (title, relative) in TITLES.items():
        archive = root / relative
        row = {"slug": slug, "title": title, "source": relative, "files": [],
               "status": "missing local archive"}
        if archive.is_file():
            original = archive.read_bytes()
            digest = sha(original)
            row.update(archive_sha256=digest, status="staged; boot/gameplay unverified")
            for member, data in members(archive):
                basename = pathlib.PurePosixPath(member.replace("\\", "/")).name
                safe = re.sub(r"[^a-zA-Z0-9._-]+", "-", basename)[:120]
                target = output / slug / digest[:12] / (sha(data)[:12] + "-" + safe)
                write_new(target, data)
                row["files"].append({"member": member, "sha256": sha(data), "bytes": len(data),
                                     "path": str(target.relative_to(output)),
                                     "native_candidate": target.suffix.lower() in (".d88", ".d77")})
            if archive.read_bytes() != original:
                raise ValueError(f"archive changed during staging: {archive}")
        rows.append(row)
        print(f"{slug}: {row['status']}; {len(row['files'])} members")
    manifest = {"provenance": "User-supplied local archives; no redistribution permission inferred",
                "games": rows}
    write_new(output / "manifest.json", (json.dumps(manifest, indent=2) + "\n").encode())


if __name__ == "__main__":
    main()
