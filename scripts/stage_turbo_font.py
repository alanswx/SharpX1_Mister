"""Stage the user's local 4096-byte character-major Turbo ANK font, unchanged.

No downloads, firmware patching, inferred model authenticity or redistribution.
Uses the existing bounded archive reader and non-overwriting private staging.
"""
import argparse
import json
import pathlib
from stage_top32 import members, sha, write_new


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=pathlib.Path, default=pathlib.Path(
        "software/Sharp X1/[BIOS] X1turbo (Sharp)/[BIOS] X1turbo [ROM] [Set 2].7z"))
    parser.add_argument("--output", type=pathlib.Path, default=pathlib.Path("software/turbo-fonts"))
    args = parser.parse_args()
    original = args.archive.read_bytes()
    fonts = [(name, data) for name, data in members(args.archive)
             if pathlib.PurePosixPath(name.replace("\\", "/")).name.upper() == "FNT0816.X1"]
    if len(fonts) != 1 or len(fonts[0][1]) != 4096:
        raise ValueError("archive must contain exactly one 4096-byte FNT0816.X1")
    name, data = fonts[0]
    if args.archive.read_bytes() != original:
        raise ValueError("archive changed during extraction")
    target = args.output / (sha(data)[:12] + "-FNT0816.X1")
    write_new(target, data)
    record = {"archive": str(args.archive), "archive_sha256": sha(original),
              "member": name, "sha256": sha(data), "bytes": len(data),
              "path": str(target), "layout": "character-major 256 x 16",
              "provenance": "user-supplied local archive; not verified hardware dump"}
    write_new(target.with_suffix(".json"), (json.dumps(record, indent=2) + "\n").encode())
    print(json.dumps(record))


if __name__ == "__main__":
    main()
