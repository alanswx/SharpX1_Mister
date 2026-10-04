"""Read-only inventory of local user-supplied Turbo BIOS archives.

Print names, sizes and hashes; never install firmware or alter IPL loaders.
Uses the existing bounded archive reader; no downloads or inferred license.
"""
import argparse
import json
import pathlib
from stage_top32 import members, sha


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--software", type=pathlib.Path, default=pathlib.Path("software"))
    args = parser.parse_args()
    root = args.software.resolve()
    rows = []
    for path in sorted(root.rglob("*.7z")):
        if "[bios]" not in path.name.lower() or "turbo" not in path.name.lower():
            continue
        original = path.read_bytes()
        row = {"source": str(path.relative_to(root)), "bytes": len(original),
               "sha256": sha(original), "members": []}
        for name, data in members(path):
            row["members"].append({"name": name, "bytes": len(data), "sha256": sha(data)})
        if path.read_bytes() != original:
            raise ValueError(f"archive changed during inventory: {path}")
        rows.append(row)
    print(json.dumps({"provenance": "User-supplied local archives; names are labels, not verified model identities",
                      "status": "inventory only; not booted, installed or redistributed",
                      "archives": rows}, indent=2))


if __name__ == "__main__":
    main()
