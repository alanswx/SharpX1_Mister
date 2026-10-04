"""Extract a user-supplied X1 shortlist into private per-title test folders.

No downloads or original-media patches. ZIP and 7z are read without trusting
archive paths. Clean standard .2d sector images also get protected D88 wrappers.
Missing titles and unsupported tape/geometry entries remain explicit in the
manifest. Run from the repository root; requires the existing 7z executable.
"""
import argparse
import hashlib
import json
import pathlib
import re
import subprocess
import zipfile
from x1_raw2d_to_d88 import raw2d_to_d88


def sha(data):
    return hashlib.sha256(data).hexdigest()


def normalize(title):
    return re.sub(r"[^a-z0-9]", "", title.lower())


ALIASES = {
    "BurgerTime": ("Hamburger (Burger Time)",),
    "Tennis": ("Nintendo no Tennis",),
    "The Tower of Druaga": ("The Tower of Druaga", "Tower of Druaga"),
    "Digital Devil Story: Megami Tensei": ("Digital Devil Story - Megami Tensei",),
    "Might and Magic: Book One - The Secret of the Inner Sanctum": ("Might and Magic",),
    "Might and Magic II: Gates to Another World": ("Might and Magic II",),
    "Choplifter!": ("Choplifter",),
    "Spy vs Spy": ("Spy vs. Spy",),
    "The Goonies": ("The Goonies", "Goonies, The"),
    "Ultima III: Exodus": ("Ultima III",),
}


def members(archive):
    if archive.suffix.lower() == ".zip":
        with zipfile.ZipFile(archive) as z:
            for item in z.infolist():
                if item.is_dir():
                    continue
                if not 0 <= item.file_size <= 8 * 1024 * 1024:
                    raise ValueError(f"oversized archive member: {item.filename}")
                yield item.filename, z.read(item)  # CRC verified by zipfile.
    else:
        listing = subprocess.run(["7z", "l", "-slt", str(archive)],
                                 capture_output=True, text=True, check=True).stdout
        entries = listing.split("----------\n", 1)[1].strip().split("\n\n")
        for entry in entries:
            fields = dict(line.split(" = ", 1) for line in entry.splitlines() if " = " in line)
            if ("Path" not in fields or fields.get("Folder") == "+"
                    or "D" in fields.get("Attributes", "") or "Size" not in fields):
                continue
            size = int(fields["Size"])
            if not 0 <= size <= 8 * 1024 * 1024:
                raise ValueError(f"oversized archive member: {fields['Path']}")
            result = subprocess.run(["7z", "e", "-so", "-spd", str(archive), fields["Path"]],
                                    capture_output=True, check=True)
            if len(result.stdout) != size:
                raise ValueError("extracted size mismatch")
            yield fields["Path"], result.stdout


def write_new(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        if path.read_bytes() != data:
            raise ValueError(f"refusing to overwrite differing file: {path}")
    else:
        with path.open("xb") as stream:
            stream.write(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--software", type=pathlib.Path, default=pathlib.Path("software"))
    parser.add_argument("--output", type=pathlib.Path, default=pathlib.Path("software/top32-unpacked"))
    args = parser.parse_args()
    root, output = args.software.resolve(), args.output.resolve()
    shortlist = (root / "top32games.txt").read_bytes()
    titles = re.findall(r"^(.+?)\((\d{4})\)\s*$", shortlist.decode(), re.M)
    if len(titles) != 32:
        raise ValueError(f"expected 32 titles, found {len(titles)}")
    archives = sorted(p for p in root.rglob("*") if p.suffix.lower() in (".zip", ".7z")
                      and output not in p.parents)
    rows = []
    for index, (title, year) in enumerate(titles, 1):
        aliases = {normalize(name) for name in ALIASES.get(title, (title,))}
        matches = []
        for archive in archives:
            if archive.suffix.lower() == ".7z":
                candidate = re.sub(r"\s+\([^)]*\)$", "", archive.parent.name)
            else:
                candidate = re.split(r"\s+\(\d{4}\)", archive.stem)[0]
            if normalize(candidate) in aliases:
                matches.append(archive)
        folder = output / (f"{index:02d}-" + re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-"))
        folder.mkdir(parents=True, exist_ok=True)
        row = {"rank": index, "title": title, "list_year": year,
               "status": "missing" if not matches else "extracted; compatibility unverified",
               "archives": [], "files": []}
        for archive in matches:
            original = archive.read_bytes()
            digest = sha(original)
            row["archives"].append({"source": str(archive.relative_to(root)), "sha256": digest})
            for member, data in members(archive):
                suffix = pathlib.PurePosixPath(member).suffix.lower()
                basename = pathlib.PurePosixPath(member.replace("\\", "/")).name
                safe = re.sub(r"[^a-zA-Z0-9._-]+", "-", basename)[:120]
                target = folder / digest[:12] / (sha(data)[:12] + "-" + safe)
                write_new(target, data)
                record = {"archive_sha256": digest, "member": member, "sha256": sha(data),
                          "bytes": len(data), "path": str(target.relative_to(output)),
                          "format": suffix, "simulator": "native candidate" if suffix in (".d88", ".d77")
                          else "not a supported disk image"}
                if suffix == ".2d" and len(data) == 327680:
                    wrapped = raw2d_to_d88(data)
                    converted = target.with_suffix(".d88")
                    write_new(converted, wrapped)
                    record.update(simulator="converted candidate; unverified", d88=str(converted.relative_to(output)),
                                  d88_sha256=sha(wrapped), conversion="protected 40x2x16x256 D88 wrapper; payload unchanged")
                row["files"].append(record)
            if archive.read_bytes() != original:
                raise ValueError(f"archive changed during extraction: {archive}")
        write_new(folder / "manifest.json", (json.dumps(row, indent=2) + "\n").encode())
        rows.append(row)
        print(f"{index:02d} {title}: {len(matches)} archives, {len(row['files'])} files", flush=True)
    manifest = {"shortlist_sha256": sha(shortlist), "provenance": "User-supplied local media; no redistribution permission inferred", "games": rows}
    write_new(output / "manifest.json", (json.dumps(manifest, indent=2) + "\n").encode())
    lines = ["# Private X1 top-32 test media", "", "Original archives are unchanged. Extracted assets are private and ignored by Git.",
             "Use native D88/D77 or generated protected D88 candidates. Tape files are retained but cassette loading is not implemented.",
             "Extraction/conversion is not proof of compatibility, boot, or gameplay. See manifest.json for hashes and disk-set provenance.", "",
             "| Rank | Title | Archives | Disk candidates | Status |", "|---|---|---:|---:|---|"]
    for row in rows:
        disks = sum(f["simulator"] != "not a supported disk image" for f in row["files"])
        lines.append(f"| {row['rank']} | {row['title']} | {len(row['archives'])} | {disks} | {row['status']} |")
    write_new(output / "README.md", ("\n".join(lines) + "\n").encode())


if __name__ == "__main__":
    main()
