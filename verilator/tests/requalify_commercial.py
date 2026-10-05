"""Regenerate native v03 states and run private release-bound controls.

No bundled media, injected RAM, patched games or old-state conversion. Run
from verilator/. Only the historical four action-game input sequences are
encoded here; Shanghai's cursor/pair preparation remains a separate check.
"""
import argparse
import hashlib
import json
import pathlib
import shutil
import subprocess


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=pathlib.Path)
    parser.add_argument("title", choices=("druaga", "xevious", "mappy", "galaga"))
    parser.add_argument("disk", type=pathlib.Path)
    parser.add_argument("--output", required=True, type=pathlib.Path)
    args = parser.parse_args()
    exe, disk = args.executable.resolve(), args.disk.resolve()
    rom = pathlib.Path("../bios/ipl_x1.hex").resolve()
    keys = pathlib.Path("tests/commercial_boot.keys").resolve()
    originals = {str(p): sha(p) for p in (disk, rom, keys)}
    folder = args.output.resolve()
    folder.mkdir(parents=True, exist_ok=False)
    frozen = folder / "Vtop"
    exe_sha = sha(exe)
    shutil.copy2(exe, frozen)
    assert sha(frozen) == exe_sha, "executable changed during freeze"
    runs = []
    state = None

    def run(name, milliseconds, joy=0xff):
        nonlocal state
        prefix = folder / name
        command = [str(frozen), "--cycles", str(milliseconds * 32000),
                   "--disk", str(disk), "--joya", str(joy),
                   "--save-state", str(prefix) + ".state", "--dump", str(prefix),
                   "--frame", str(prefix) + ".ppm"]
        command += (["--restore-state", str(state)] if state else
                    ["--rom", str(rom), "--keys", str(keys)])
        result = subprocess.run(command, capture_output=True, text=True, timeout=1800)
        prefix.with_suffix(".stdout").write_text(result.stdout)
        prefix.with_suffix(".stderr").write_text(result.stderr)
        record = {"command": command, "returncode": result.returncode}
        if result.returncode == 0:
            report = json.loads(result.stdout.splitlines()[-1])
            assert report["disk_writes"] == 0
            record["report"] = report
            state = prefix.with_suffix(".state")
            record["state_sha256"] = sha(state)
        runs.append(record)
        (folder / "provenance.json").write_text(json.dumps({
            "title": args.title, "executable_sha256": exe_sha,
            "inputs_sha256": originals, "native_boot_chain": runs,
            "gameplay_verified": False}, indent=2) + "\n")
        if result.returncode:
            raise RuntimeError(f"native run failed: {prefix}; inspect stderr")
        print(f"{args.title}: {name}, frame {report['frame_hash']}", flush=True)

    run("cold16s", 16000)
    if args.title == "druaga":
        sequence = [("start", 250, 0xdf), ("live", 14000, 0xff)]
    elif args.title == "xevious":
        sequence = [("start", 500, 0xdf), ("live", 3000, 0xff)]
    elif args.title == "mappy":
        sequence = [("title18s", 2000, 0xff), ("start", 350, 0xdf),
                    ("live", 2650, 0xff)]
    else:
        sequence = [("trigger", 500, 0xdf), ("title", 4000, 0xff),
                    ("start", 250, 0xdf), ("selection", 3000, 0xff),
                    ("level", 250, 0xdf), ("live", 9000, 0xff)]
    for name, milliseconds, joy in sequence:
        run(name, milliseconds, joy)
    command = ["python3", "tests/test_commercial_gameplay.py", str(frozen),
               args.title, str(state), str(disk), "--output", str(folder / "controls")]
    result = subprocess.run(command, capture_output=True, text=True, timeout=1800)
    (folder / "controls.stdout").write_text(result.stdout)
    (folder / "controls.stderr").write_text(result.stderr)
    unchanged = all(sha(pathlib.Path(p)) == digest for p, digest in originals.items())
    evidence = {"title": args.title, "executable_sha256": exe_sha,
                "inputs_sha256": originals, "native_boot_chain": runs,
                "control_command": command, "control_returncode": result.returncode,
                "unchanged_inputs": unchanged,
                "gameplay_verified": result.returncode == 0 and unchanged,
                "scope": "bounded fast baseline native controls, not Turbo or hardware"}
    (folder / "provenance.json").write_text(json.dumps(evidence, indent=2) + "\n")
    print(result.stdout, end="", flush=True)
    if result.returncode or not unchanged:
        raise SystemExit("FAIL: retained native evidence; no gameplay claim")


if __name__ == "__main__":
    main()
