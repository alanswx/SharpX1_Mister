"""Repeat cold native IPL probes of private Arcus/Bastard Special releases.

PASS means deterministic execution/RGB/RAM and unchanged assets, not game boot.
No RAM injection, restored snapshots, game patching, or writable disk output.
Run from verilator/ so inherited firmware paths resolve correctly.
"""
import argparse
import hashlib
import json
import pathlib
import shutil
import subprocess


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=pathlib.Path)
    parser.add_argument("title", choices=("arcus", "bastard-special"))
    parser.add_argument("--manifest", type=pathlib.Path, default=pathlib.Path("../software/special-unpacked/manifest.json"))
    parser.add_argument("--rom", type=pathlib.Path, default=pathlib.Path("../bios/ipl_x1.hex"))
    parser.add_argument("--seconds", type=int, default=16)
    parser.add_argument("--keys", type=pathlib.Path, default=pathlib.Path("tests/commercial_boot.keys"))
    parser.add_argument("--output", type=pathlib.Path, required=True,
                        help="new ignored directory; contains private RAM/frame evidence")
    parser.add_argument("--io-trace", action="store_true")
    parser.add_argument("--bus-events", action="store_true", help="last sample per held bus transaction")
    parser.add_argument("--bus-start-ms", type=int, default=0)
    parser.add_argument("--bus-end-ms", type=int, default=0)
    parser.add_argument("--timeout", type=float, default=1800)
    args = parser.parse_args()
    if args.seconds < 1:
        parser.error("--seconds must be positive")
    if (args.bus_events or args.bus_start_ms or args.bus_end_ms) and not args.io_trace:
        parser.error("bus options require --io-trace")
    manifest = args.manifest.resolve()
    row = next(r for r in json.loads(manifest.read_text())["games"] if r["slug"] == args.title)
    candidates = sorted((f for f in row["files"] if f["native_candidate"]), key=lambda f: f["member"])
    if not candidates:
        parser.error("no locally staged native disk candidate")
    # Arcus Disk 1, or the single Bastard Special disk. Other disks are preserved
    # in the staging manifest; this probe does not claim disk changes work.
    disk = manifest.parent / candidates[0]["path"]
    if digest(disk) != candidates[0]["sha256"]:
        parser.error("staged disk differs from manifest")
    exe, rom, keys = (p.resolve() for p in (args.executable, args.rom, args.keys))
    originals = {str(p): digest(p) for p in (disk, rom, keys, manifest)}
    folder = args.output.resolve()
    folder.mkdir(parents=True, exist_ok=False)
    # Freeze the executable while another agent rebuilds the shared runner.
    frozen = folder / "Vtop"
    executable_sha = digest(exe)
    shutil.copy2(exe, frozen)
    if digest(frozen) != executable_sha:
        raise RuntimeError("runner changed during copy; rerun with a new output directory")
    runs = []
    artifacts = (".ram", ".text", ".attr", ".subram", ".cpu", ".ppm")
    for name in ("cold", "repeat"):
        prefix = folder / name
        command = [str(frozen), "--cycles", str(args.seconds * 32000000),
                   "--rom", str(rom), "--disk", str(disk), "--keys", str(keys),
                   "--dump", str(prefix), "--frame", str(prefix) + ".ppm"]
        if args.io_trace:
            command += ["--bus-trace", str(prefix) + ".csv", "--io-only"]
            if args.bus_events:
                command += ["--bus-events"]
            command += ["--bus-start-ms", str(args.bus_start_ms), "--bus-end-ms", str(args.bus_end_ms)]
        result = subprocess.run(command, capture_output=True, text=True, timeout=args.timeout)
        prefix.with_suffix(".stdout").write_text(result.stdout)
        prefix.with_suffix(".stderr").write_text(result.stderr)
        record = {"command": command, "returncode": result.returncode}
        if result.returncode == 0:
            report = json.loads(result.stdout.splitlines()[-1])
            record.update(report=report, artifacts={suffix: digest(pathlib.Path(str(prefix) + suffix))
                                                   for suffix in artifacts})
            if report["disk_writes"] != 0:
                raise RuntimeError("protected native probe wrote disk")
        runs.append(record)
    unchanged = all(digest(pathlib.Path(p)) == h for p, h in originals.items())
    repeated = (all(r["returncode"] == 0 for r in runs)
                and runs[0]["report"] == runs[1]["report"]
                and runs[0]["artifacts"] == runs[1]["artifacts"])
    evidence = {"title": args.title, "disk_member": candidates[0]["member"],
                "archive_sha256": row.get("archive_sha256"), "inputs_sha256": originals,
                "executable_sha256": executable_sha, "cycles_reference_hz": 32000000,
                "duration_seconds": args.seconds, "runs": runs,
                "unchanged_inputs": unchanged, "repeatable": repeated,
                "boot_observation": "requires inspection of native PPM; execution is not game boot",
                "gameplay_verified": False}
    (folder / "evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")
    print(json.dumps({"title": args.title, "repeatable": repeated, "unchanged_inputs": unchanged,
                      "evidence": str(folder / "evidence.json"), "runs": [r.get("report", r) for r in runs]}))
    if not unchanged or not repeated:
        raise SystemExit("FAIL: inspect retained evidence (including media rejection); no boot claim")
    print("PASS: repeatable native probe, unchanged inputs; game boot/playability not asserted")


if __name__ == "__main__":
    main()
