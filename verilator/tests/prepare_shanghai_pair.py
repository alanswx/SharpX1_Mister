"""Prepare the same release-bound tile pair using native cursor feedback.

Only normal joystick pins and authentic snapshot continuation are used. RAM
dumps are read-only observations, never restored, edited or injected. Keep
test_shanghai_gameplay.py's fixed tile/count/removal assertions unchanged.
"""
import argparse
import hashlib
import json
import pathlib
import subprocess


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=pathlib.Path)
    parser.add_argument("cursor_state", type=pathlib.Path)
    parser.add_argument("disk", type=pathlib.Path)
    parser.add_argument("--output", required=True, type=pathlib.Path)
    parser.add_argument("--timeout", type=float, default=600)
    args = parser.parse_args()
    exe, source, disk = (p.resolve() for p in
                         (args.executable, args.cursor_state, args.disk))
    originals = {str(p): sha(p) for p in (exe, source, disk)}
    assert originals[str(disk)] == "648d150e8e36b5ba282bb7e3475e704f5f938d5c4a77ef6d7d000908f48513dc"
    folder = args.output.resolve()
    folder.mkdir(parents=True, exist_ok=False)
    state = source
    records = []

    def advance(name, ms, joy=0xff):
        nonlocal state
        prefix = folder / f"{len(records):03d}-{name}"
        command = [str(exe), "--restore-state", str(state), "--disk", str(disk),
                   "--cycles", str(ms * 32000), "--joya", str(joy),
                   "--dump", str(prefix), "--save-state", str(prefix) + ".state",
                   "--frame", str(prefix) + ".ppm"]
        result = subprocess.run(command, capture_output=True, text=True, timeout=args.timeout)
        prefix.with_suffix(".stdout").write_text(result.stdout)
        prefix.with_suffix(".stderr").write_text(result.stderr)
        assert result.returncode == 0, result.stderr
        report = json.loads(result.stdout.splitlines()[-1])
        assert report["disk_requests"] == report["disk_writes"] == report["download_bytes"] == 0
        assert report["ps2_bytes_sent"] == 0
        memory = prefix.with_suffix(".ram").read_bytes()
        xy = [int.from_bytes(memory[a:a+2], "little") for a in (0x5145, 0x5147)]
        state = prefix.with_suffix(".state")
        records.append({"command": command, "state_sha256": sha(state),
                        "xy": xy, "selected": memory[0x2d2f], "report": report})
        assert all(sha(pathlib.Path(p)) == digest for p, digest in originals.items())
        (folder / "provenance.json").write_text(json.dumps({
            "inputs_sha256": originals, "native_continuations": records,
            "pair_prepared": False, "gameplay_verified": False}, indent=2) + "\n")
        print(name, xy, "selected", memory[0x2d2f], flush=True)
        return memory, xy

    memory, xy = advance("observe", 20)

    def move(axis, target, lower, higher):
        nonlocal memory, xy
        for _ in range(200):
            if xy[axis] == target:
                return
            previous = xy[axis]
            memory, xy = advance("move", 20, lower if previous > target else higher)
            assert 0 <= xy[0] < 640 and 0 <= xy[1] < 200
            assert (previous-target) * (xy[axis]-target) >= 0, "cursor overshot target"
        raise AssertionError("cursor failed to reach fixed tile coordinate")

    assert memory[0x2d2f] == 0 and memory[0x3f9f] == 0
    assert [memory[a] for a in (0x3e1b, 0x3eba)] == [0x11, 0x11]
    move(0, 56, 0xfb, 0xf7)
    move(1, 18, 0xfe, 0xfd)
    memory, xy = advance("first-click", 200, 0xbf)
    assert xy == [56, 18] and memory[0x2d2f] == 1
    assert [memory[a] for a in (0x3e1b, 0x3eba)] == [0x91, 0x11]
    advance("first-release", 100)
    move(0, 152, 0xfb, 0xf7)
    move(1, 128, 0xfe, 0xfd)
    memory, xy = advance("second-click", 200, 0xbf)
    assert xy == [152, 128] and memory[0x2d2f] == 2
    assert [memory[a] for a in (0x3e1b, 0x3eba)] == [0x91, 0x91]
    memory, xy = advance("second-release", 300)
    assert memory[0x2d2f] == 2 and memory[0x3f9f] == 0
    result = subprocess.run(["python3", str(pathlib.Path(__file__).with_name("test_shanghai_gameplay.py")),
                             str(exe), str(source), str(state), str(disk),
                             "--output", str(folder / "controls"), "--timeout", str(args.timeout)],
                            capture_output=True, text=True, timeout=args.timeout * 10)
    (folder / "controls.stdout").write_text(result.stdout)
    (folder / "controls.stderr").write_text(result.stderr)
    unchanged = all(sha(pathlib.Path(p)) == digest for p, digest in originals.items())
    (folder / "provenance.json").write_text(json.dumps({
        "inputs_sha256": originals, "native_continuations": records,
        "pair_prepared": True, "unchanged_inputs": unchanged,
        "control_returncode": result.returncode,
        "gameplay_verified": result.returncode == 0 and unchanged}, indent=2) + "\n")
    print(result.stdout, end="", flush=True)
    assert result.returncode == 0 and unchanged, result.stderr


if __name__ == "__main__":
    main()
