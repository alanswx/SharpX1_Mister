"""Freeze a current runner, repeat CROSS native cold boot, then test controls.

Fresh private snapshots are generated here, never reused from earlier RTL.
Run from verilator/. Outputs contain private game/firmware bytes and stay ignored.
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
    parser.add_argument("--disk", type=pathlib.Path,
                        default=pathlib.Path("../references/software/private-downloads/cross-chase/Xchase_x1.d88"))
    parser.add_argument("--output", type=pathlib.Path, required=True)
    parser.add_argument("--timeout", type=float, default=1800)
    args = parser.parse_args()
    exe, disk = args.executable.resolve(), args.disk.resolve()
    rom, keys = pathlib.Path("../bios/ipl_x1.hex").resolve(), pathlib.Path("tests/cross_start.keys").resolve()
    original = {str(p): sha(p) for p in (disk, rom, keys)}
    if sha(disk) != "2fb70389737a7d54bff5a746b581343385ebde115cefb77ded32c473dcde97ec":
        parser.error("unrecognized CROSS release")
    folder = args.output.resolve()
    folder.mkdir(parents=True, exist_ok=False)
    frozen = folder / "Vtop"
    executable_sha = sha(exe)
    shutil.copy2(exe, frozen)
    if sha(frozen) != executable_sha:
        raise RuntimeError("runner changed during copy")
    runs = []
    for name in ("cold", "repeat"):
        prefix = folder / name
        command = [str(frozen), "--cycles", "416000000", "--rom", str(rom),
                   "--disk", str(disk), "--keys", str(keys), "--save-state", str(prefix) + ".state",
                   "--dump", str(prefix), "--frame", str(prefix) + ".ppm"]
        result = subprocess.run(command, capture_output=True, text=True, timeout=args.timeout)
        prefix.with_suffix(".stdout").write_text(result.stdout)
        prefix.with_suffix(".stderr").write_text(result.stderr)
        result.check_returncode()
        report = json.loads(result.stdout.splitlines()[-1])
        assert report["disk_writes"] == 0
        runs.append({"command": command, "report": report,
                     "artifacts": {s: sha(pathlib.Path(str(prefix) + s))
                                   for s in (".ram", ".text", ".attr", ".subram", ".cpu", ".ppm", ".state")}})
    repeated = runs[0]["report"] == runs[1]["report"] and runs[0]["artifacts"] == runs[1]["artifacts"]
    control_command = ["python3", "tests/test_gameplay.py", str(frozen), str(folder / "cold.state"), str(disk)]
    controls = subprocess.run(control_command, capture_output=True, text=True, timeout=args.timeout)
    (folder / "controls.stdout").write_text(controls.stdout)
    (folder / "controls.stderr").write_text(controls.stderr)
    unchanged = all(sha(pathlib.Path(p)) == h for p, h in original.items())
    evidence = {"executable_sha256": executable_sha, "inputs_sha256": original, "runs": runs,
                "cold_boot_repeatable": repeated, "unchanged_inputs": unchanged,
                "control_command": control_command, "control_returncode": controls.returncode,
                "control_stdout": controls.stdout, "control_stderr": controls.stderr,
                "scope": "fresh native baseline CROSS boot + release-specific PS/2 I/J control check"}
    (folder / "evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")
    print(json.dumps({"evidence": str(folder / "evidence.json"), "executable_sha256": executable_sha,
                      "cold_boot_repeatable": repeated, "unchanged_inputs": unchanged,
                      "control_returncode": controls.returncode, "control_stdout": controls.stdout}))
    if not repeated or not unchanged or controls.returncode:
        raise SystemExit("FAIL: inspect native boot and controls evidence")
    print("PASS: repeated fresh native CROSS boot + original PS/2 I/J gameplay regression")


if __name__ == "__main__":
    main()
