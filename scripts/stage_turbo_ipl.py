"""Stage unchanged Turbo IPL from a user's local archive, never download it.

Record matching local MAME ROM metadata separately from hardware authenticity.
No firmware bytes, native state, or commercial media are committed.
"""
import argparse
import hashlib
import json
import pathlib
from stage_top32 import members, sha, write_new


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=pathlib.Path, default=pathlib.Path(
        "software/Sharp X1/[BIOS] X1turbo (Sharp)/[BIOS] X1turbo [ROM] [Set 2].7z"))
    parser.add_argument("--output", type=pathlib.Path, default=pathlib.Path("software/turbo-firmware"))
    args = parser.parse_args()
    original = args.archive.read_bytes()
    candidates = [(name, data) for name, data in members(args.archive)
                  if pathlib.PurePosixPath(name.replace("\\", "/")).name.upper()
                  in ("IPLROM.X1T", "IPL.X1T")]
    if len(candidates) != 1 or len(candidates[0][1]) != 32768:
        raise ValueError("expected exactly one unchanged 32 KiB Turbo IPL member")
    name, data = candidates[0]
    if args.archive.read_bytes() != original:
        raise ValueError("archive changed during extraction")
    target = args.output / (sha(data)[:12] + "-ipl.x1t")
    write_new(target, data)
    sha1 = hashlib.sha1(data).hexdigest()
    record = {"archive": str(args.archive), "archive_sha256": sha(original),
              "member": name, "sha256": sha(data), "sha1": sha1,
              "bytes": len(data), "path": str(target),
              "matches_local_mame_x1turbo_rom_metadata":
                  sha1 == "44620f57a25f0bcac2b57ca2b0f1ebad3bf305d3",
              "provenance": "user-supplied archive; metadata match is not a verified hardware dump"}
    write_new(target.with_suffix(".json"), (json.dumps(record, indent=2) + "\n").encode())
    print(json.dumps(record))


if __name__ == "__main__":
    main()
