"""Regenerate native states and run private release-bound controls.

No bundled media, injected RAM, patched games or old-state conversion. Run
from verilator/. Input sequences reproduce historical action-game controls.
Shanghai can prepare the fixed historical pair with native cursor feedback;
release-bound assertions still decide PASS. The old timed replay is opt-in.
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
    parser.add_argument("title", choices=("druaga", "xevious", "mappy", "galaga", "shanghai"))
    parser.add_argument("disk", type=pathlib.Path)
    parser.add_argument("--output", required=True, type=pathlib.Path)
    parser.add_argument("--resume", action="store_true",
                        help="resume a verified successful native prefix after interruption; never convert states")
    parser.add_argument("--timeout", type=float, default=1800,
                        help="host timeout per native/control run; does not change simulation duration")
    parser.add_argument("--boot-chunk-ms", type=int, default=16000,
                        help="checkpoint interval; total 16-second boot and neutral-stage durations stay unchanged")
    parser.add_argument("--shanghai-preparation", choices=("feedback", "historical"), default="feedback",
                        help="feedback uses native joystick cursor observations; historical preserves the old timed replay")
    args = parser.parse_args()
    if args.timeout <= 0 or not 1 <= args.boot_chunk_ms <= 16000:
        parser.error("timeout must be positive and boot chunk must be 1..16000 ms")
    exe, disk = args.executable.resolve(), args.disk.resolve()
    rom = pathlib.Path("../bios/ipl_x1.hex").resolve()
    keys = pathlib.Path("tests/commercial_boot.keys").resolve()
    last_key_ms = max(int(line.split()[0]) for line in keys.read_text().splitlines()
                      if line.strip() and not line.lstrip().startswith("#"))
    if args.boot_chunk_ms <= last_key_ms:
        parser.error("first boot chunk must include every boot key event before saving state")
    originals = {str(p): sha(p) for p in (disk, rom, keys)}
    mappy_keys = pathlib.Path("tests/mappy_start.keys").resolve()
    if args.title == "mappy":
        originals[str(mappy_keys)] = sha(mappy_keys)
    folder = args.output.resolve()
    frozen = folder / "Vtop"
    exe_sha = sha(exe)
    completed = []
    if args.resume:
        previous = json.loads((folder / "provenance.json").read_text())
        assert previous["title"] == args.title and not previous["gameplay_verified"]
        if args.title == "shanghai":
            assert previous.get("shanghai_preparation", "historical") == args.shanghai_preparation, \
                "resume preparation differs; preserve old failure evidence and use a new output"
        assert previous["executable_sha256"] == exe_sha == sha(frozen), "runner identity changed"
        assert previous["inputs_sha256"] == originals, "native input identity changed"
        completed = previous["native_boot_chain"]
        assert completed and all(r["returncode"] == 0 for r in completed), "unsuccessful native prefix"
        for record in completed:
            command = record["command"]
            saved = pathlib.Path(command[command.index("--save-state") + 1])
            assert sha(saved) == record["state_sha256"], "native checkpoint changed"
    else:
        folder.mkdir(parents=True, exist_ok=False)
        shutil.copy2(exe, frozen)
        assert sha(frozen) == exe_sha, "executable changed during freeze"
    runs = []
    state = None

    def execute(command):
        try:
            return subprocess.run(command, capture_output=True, text=True, timeout=args.timeout)
        except subprocess.TimeoutExpired as error:
            def partial(value):
                return value.decode(errors="replace") if isinstance(value, bytes) else (value or "")
            return subprocess.CompletedProcess(command, 124, partial(error.stdout),
                partial(error.stderr) + f"\nHost timeout after {args.timeout} seconds; command incomplete.\n")

    def run(name, milliseconds, joy=0xff, continuation_keys=None):
        nonlocal state
        if state is not None and milliseconds > args.boot_chunk_ms and continuation_keys is None:
            remaining = milliseconds
            part = 0
            while remaining:
                part += 1
                duration = min(args.boot_chunk_ms, remaining)
                run(f"{name}-part{part}", duration, joy)
                remaining -= duration
            return
        prefix = folder / name
        command = [str(frozen), "--cycles", str(milliseconds * 32000),
                   "--disk", str(disk), "--joya", str(joy),
                   "--save-state", str(prefix) + ".state", "--dump", str(prefix),
                   "--frame", str(prefix) + ".ppm"]
        command += (["--restore-state", str(state)] if state else
                    ["--rom", str(rom), "--keys", str(keys)])
        if state and continuation_keys:
            command += ["--keys", str(continuation_keys)]
        if len(runs) < len(completed):
            record = completed[len(runs)]
            assert record["command"] == command, "resume schedule/model differs from original prefix"
            assert record["report"]["disk_writes"] == 0
            state = prefix.with_suffix(".state")
            runs.append(record)
            print(f"{args.title}: retained {name}, verified native checkpoint", flush=True)
            return
        result = execute(command)
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
            "shanghai_preparation": args.shanghai_preparation if args.title == "shanghai" else None,
            "inputs_sha256": originals, "native_boot_chain": runs,
            "gameplay_verified": False}, indent=2) + "\n")
        if result.returncode:
            raise RuntimeError(f"native run failed: {prefix}; inspect stderr")
        print(f"{args.title}: {name}, frame {report['frame_hash']}", flush=True)

    remaining = 16000
    while remaining:
        duration = min(args.boot_chunk_ms, remaining)
        elapsed = 16000 - remaining + duration
        name = "cold16s" if args.boot_chunk_ms == 16000 else (
            f"cold{elapsed}ms" if state is None else f"boot{elapsed}ms")
        run(name, duration)
        remaining -= duration
    if args.title == "druaga":
        sequence = [("start", 250, 0xdf), ("live", 14000, 0xff)]
    elif args.title == "xevious":
        sequence = [("start", 500, 0xdf), ("live", 3000, 0xff)]
    elif args.title == "mappy":
        run("title18s", 2000)
        run("intro21s", 3000, continuation_keys=mappy_keys)
        run("ready24s", 3000)
        run("live", 3000, continuation_keys=mappy_keys)
        sequence = []
    elif args.title == "galaga":
        sequence = [("trigger", 500, 0xdf), ("title", 4000, 0xff),
                    ("start", 250, 0xdf), ("selection", 3000, 0xff),
                    ("level", 250, 0xdf), ("live", 9000, 0xff)]
    else:
        sequence = [("start", 500, 0xdf), ("board", 3000, 0xff),
                    ("cursor", 3000, 0xff)]
    for name, milliseconds, joy in sequence:
        run(name, milliseconds, joy)
    if args.title == "shanghai":
        cursor_state = state
        if args.shanghai_preparation == "feedback":
            command = ["python3", "tests/prepare_shanghai_pair.py", str(frozen),
                       str(cursor_state), str(disk), "--output", str(folder / "feedback")]
        else:
            command = None
        preparation = [("left1",100,0xfb),("left2",400,0xfb),
                       ("right1",200,0xf7),("right2",50,0xf7),("right3",70,0xf7),
                       ("select",300,0xbf),("cancel",200,0xdf),
                       ("left",1000,0xfb),("up",1000,0xfe),("first",200,0xbf)]
        preparation += [(f"right{i}",20,0xf7) for i in range(13)]
        preparation += [(f"down{i}",20,0xfd) for i in range(22)]
        preparation += [("second",300,0xbf),("release",300,0xff)]
        if command is None:
            for i, (name, milliseconds, joy) in enumerate(preparation):
                run(f"pair-{i:02d}-{name}", milliseconds, joy)
            command = ["python3", "tests/test_shanghai_gameplay.py", str(frozen),
                       str(cursor_state), str(state), str(disk)]
    else:
        command = ["python3", "tests/test_commercial_gameplay.py", str(frozen),
                   args.title, str(state), str(disk)]
    if not (args.title == "shanghai" and args.shanghai_preparation == "feedback"):
        command += ["--output", str(folder / "controls")]
    command += ["--timeout", str(args.timeout)]
    result = execute(command)
    (folder / "controls.stdout").write_text(result.stdout)
    (folder / "controls.stderr").write_text(result.stderr)
    fire_record = None
    if args.title == "galaga" and result.returncode == 0:
        run("wave39s", 6000)
        fire_command = ["python3", "tests/test_galaga_fire.py", str(frozen),
                        str(state), str(disk), "--output", str(folder / "fire"),
                        "--timeout", str(args.timeout)]
        fired = execute(fire_command)
        (folder / "fire.stdout").write_text(fired.stdout)
        (folder / "fire.stderr").write_text(fired.stderr)
        fire_record = {"command": fire_command, "returncode": fired.returncode}
        print(fired.stdout, end="", flush=True)
    unchanged = all(sha(pathlib.Path(p)) == digest for p, digest in originals.items())
    evidence = {"title": args.title, "executable_sha256": exe_sha,
                "shanghai_preparation": args.shanghai_preparation if args.title == "shanghai" else None,
                "inputs_sha256": originals, "native_boot_chain": runs,
                "control_command": command, "control_returncode": result.returncode,
                "fire_check": fire_record,
                "unchanged_inputs": unchanged,
                "gameplay_verified": result.returncode == 0 and unchanged and
                    (fire_record is None or fire_record["returncode"] == 0),
                "scope": "bounded fast baseline native controls, not Turbo or hardware"}
    (folder / "provenance.json").write_text(json.dumps(evidence, indent=2) + "\n")
    print(result.stdout, end="", flush=True)
    if not evidence["gameplay_verified"]:
        raise SystemExit("FAIL: retained native evidence; no gameplay claim")


if __name__ == "__main__":
    main()
