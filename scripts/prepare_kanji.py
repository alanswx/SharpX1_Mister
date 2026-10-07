#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Original explicit conversion of the audited model-40 candidate, no ROM data.

The source set is pinned by member hashes, not by arbitrary kanji filenames.
The half-major mapping is inferred from the inspected MAME interleave/display
address and model-20/30 electrical bus. It is NOT native glyph acceptance.
"""
import argparse
import hashlib
import json
import pathlib
import subprocess
import tempfile

MEMBER_SHA1 = {
    "kanji1.rom": "dad7ada1b70c45f1e9db11db273ef7b385ef4f17",
    "kanji2.rom": "103bbe459dc8da27a9400aa45b385255c18fcc75",
    "kanji3.rom": "273f3329c70b332f6a49a3a95e906bbfe3e9f0a1",
    "kanji4.rom": "d3fd24892bb1948c4697dedf5ff065ff3eaf7562",
}
ARCHIVE_SHA256 = "c2449695642e0a914fdabc834a4feb8af90ac2d7a04a163db31432ad8176ec78"
PHYSICAL_ORDER = ("kanji4.rom", "kanji3.rom", "kanji2.rom", "kanji1.rom")


def physical_from_members(members):
    """Pure layout transform; CLI independently authenticates all inputs."""
    if set(members) != set(PHYSICAL_ORDER):
        raise ValueError("expected exactly the four model-40 members")
    if any(len(member) != 32768 for member in members.values()):
        raise ValueError("each model-40 member must contain exactly 32768 bytes")
    return b"".join(members[name] for name in PHYSICAL_ORDER)


def verify_members(members):
    physical_from_members(members)  # Shape checks before identity checks.
    for name, expected in MEMBER_SHA1.items():
        if hashlib.sha1(members[name]).hexdigest() != expected:
            raise ValueError(f"unqualified model-40 member hash: {name}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=pathlib.Path)
    parser.add_argument("--source-format", choices=("audited-model40-raw",), required=True)
    parser.add_argument("--output-dir", type=pathlib.Path, required=True,
                        help="new private directory; existing targets are never overwritten")
    args = parser.parse_args()
    # Bound reads to the known local candidate. A repacked/new source needs
    # its own provenance audit, not an automatic extension of this profile.
    if args.archive.stat().st_size > 1048576:
        raise ValueError("unqualified archive size")
    with args.archive.open("rb") as source:
        archive_bytes = source.read(1048577)
    if len(archive_bytes) > 1048576:
        raise ValueError("unqualified archive size")
    archive_hash = hashlib.sha256(archive_bytes).hexdigest()
    if archive_hash != ARCHIVE_SHA256:
        raise ValueError("unqualified archive hash; this converter only accepts the audited source")
    members = {}
    # Extract the hashed bytes, not a source pathname that could be replaced
    # after hashing by a concurrent download. No archive member is a path.
    with tempfile.TemporaryDirectory(prefix="x1-kanji-conversion-") as directory:
        frozen = pathlib.Path(directory) / "source.7z"
        frozen.write_bytes(archive_bytes)
        for name in PHYSICAL_ORDER:
            result = subprocess.run(["7z", "x", "-so", str(frozen), name],
                                    capture_output=True, check=True, timeout=30)
            members[name] = result.stdout
    verify_members(members)
    physical = physical_from_members(members)
    output_hash = hashlib.sha256(physical).hexdigest()
    metadata = {
        "archive": str(args.archive), "archive_sha256": archive_hash,
        "source_format": args.source_format,
        "member_sha1": MEMBER_SHA1,
        "physical_member_order": list(PHYSICAL_ORDER),
        "bytes": len(physical), "sha256": output_hash,
        "layout": "half-major: half*65536 + bank*4096 + character*16 + row",
        "qualification": "inferred MAME/electrical mapping candidate; not verified hardware chip identity or glyph rendering",
        "reference_mame_commit": "f4bfc5a423f48d48e809c01fc70a47c0c00d40a2",
        "provenance": "user-supplied local archive; private output, no redistribution permission inferred",
    }
    # Do not extract archive paths or use its filenames as filesystem targets.
    # Refuse an existing directory, including symlinks, before creating files.
    args.output_dir.mkdir(parents=True, exist_ok=False)
    with (args.output_dir / "kanji-physical.bin").open("xb") as destination:
        destination.write(physical)
    with (args.output_dir / "provenance.json").open("x") as destination:
        json.dump(metadata, destination, indent=2)
        destination.write("\n")
    print(json.dumps({"path": str(args.output_dir / "kanji-physical.bin"),
                      "sha256": output_hash, "bytes": len(physical),
                      "qualification": metadata["qualification"]}))


if __name__ == "__main__":
    main()
