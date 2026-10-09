"""Run the existing CPU/pixel oracle on a frozen combined-feature runner.

This schedules diagnostics, not native software or hardware qualification.
Outputs are new disposable directories; originals are never overwritten.
"""
import argparse
import hashlib
import json
import pathlib
import subprocess
import sys


def cases():
    templates = []
    for mode in ("full", "dual64", "wide64", "tall64"):
        for screen in ((0, 1) if mode in ("full", "dual64") else (0,)):
            templates.append(("graphics", mode, screen, 0x10, False, False))
    for priority in (0x10, 0x18, 0x11, 0x19, 0x12, 0x1A):
        for text in (False, True):
            templates.append(("paired-text" if text else "paired-graphics",
                              "paired64", 1, priority, text, False))
    for mode in ("full", "dual64"):
        for priority in (0, 1, 0xEA, 0xEB):
            templates.append(("single-text", mode, 1, priority, True, False))
    templates.append(("internal8", "internal8", 0, 0x10, False, False))
    for mode, priority in (("paired64", 0x1A), ("full", 1), ("dual64", 1)):
        templates.append(("reverse", mode, 1, priority, True, True))
    result = []
    for group, mode, screen, priority, text, reverse in templates:
        for custom in (False, True):
            for warm in (False, True):
                name = f"{group}-{mode}-s{screen}-p{priority:02x}-{'custom' if custom else 'identity'}-{'warm' if warm else 'cold'}"
                flags = ["--mode", mode, "--screen", str(screen), "--priority", hex(priority)]
                flags += [flag for flag, enabled in (("--text", text), ("--reverse", reverse),
                                                    ("--custom", custom), ("--warm", warm)) if enabled]
                result.append({"name": name, "group": group, "flags": flags})
    return result


def hashes(root):
    return {name: hashlib.sha256((root / name).read_bytes()).hexdigest()
            for name in ("Vtop", "test_machine_z_video.py", "z80_fixture.py", "cg8_reference.v")}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--frozen-root", type=pathlib.Path)
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument("--group", action="append", choices=sorted({c["group"] for c in cases()}))
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--timeout", type=float, default=900)
    args = parser.parse_args()
    selected = [c for c in cases() if not args.group or c["group"] in args.group]
    if args.list:
        print(json.dumps(selected, indent=2))
        return
    if not args.frozen_root or not args.output:
        parser.error("--frozen-root and --output required for execution")
    root = args.frozen_root.resolve()
    before = hashes(root)
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    (output / "inputs.json").write_text(json.dumps(before, indent=2) + "\n")
    (output / "cases.json").write_text(json.dumps(selected, indent=2) + "\n")
    completed = []
    for case in selected:
        assert hashes(root) == before, "frozen input changed before case"
        command = [sys.executable, str(root / "test_machine_z_video.py"), str(root / "Vtop"),
                   *case["flags"], "--timeout", str(args.timeout), "--output", str(output / case["name"])]
        print("START:", case["name"], flush=True)
        with (output / (case["name"] + ".log")).open("w") as log:
            result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=args.timeout + 60)
        assert result.returncode == 0, f"pixel oracle failed: {case['name']} (see case log)"
        report = json.loads((output / case["name"] / "stdout.txt").read_text().splitlines()[-1])
        for feature in ("z_palette_cpu_experiment", "z_video_experiment", "z_multimode_experiment",
                        "z_internal8_experiment", "z_text_cpu_experiment", "turbo_video_master", "intra_assignment_delays"):
            assert report[feature], f"not a combined delay-aware runner: {feature}"
        assert hashes(root) == before, "frozen input changed during case"
        assert (output / case["name"] / "actual.ppm").read_bytes() == (output / case["name"] / "expected.ppm").read_bytes()
        completed.append(case["name"])
        (output / "completed.json").write_text(json.dumps(completed, indent=2) + "\n")
        print("PASS:", case["name"], flush=True)
    (output / "final-inputs.json").write_text(json.dumps(hashes(root), indent=2) + "\n")
    print(f"PASS: {len(completed)} combined diagnostic cases; native/physical acceptance separate", flush=True)


if __name__ == "__main__":
    main()
