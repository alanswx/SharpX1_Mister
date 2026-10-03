"""Optional private-asset test: compare idle and keyboard-controlled native game state."""
import argparse
import hashlib
import json
import pathlib
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("executable", type=pathlib.Path)
parser.add_argument("snapshot", type=pathlib.Path)
parser.add_argument("disk", type=pathlib.Path)
parser.add_argument("--duration-ms", type=int, default=200)
parser.add_argument("--key-spacing-ms", type=int, default=0,
                    help="extra spacing before the second key; default keeps the original regression")
args = parser.parse_args()
assert args.duration_ms >= 200 and args.key_spacing_ms >= 0
assert args.duration_ms > 122 + args.key_spacing_ms
exe, state, disk = (str(path.resolve()) for path in (args.executable, args.snapshot, args.disk))


assert hashlib.sha256(pathlib.Path(disk).read_bytes()).hexdigest() == "2fb70389737a7d54bff5a746b581343385ebde115cefb77ded32c473dcde97ec"


def player(memory, text):
    # Release-specific symbol inferred from disassembly and CharacterStruct:
    # code at 044C loads player=35C0; 0454 decrements player.y at 35C1 for 'i'.
    # The cyan '*' is the player. '#' is a different actor, not its position.
    x, y, active = memory[0x35C0:0x35C3]
    assert active and 0 < x < 39 and 0 < y < 24, (x, y, active)
    assert text[y * 40 + x] == ord("*"), (x, y, text[y * 40 + x])
    return x, y


with tempfile.TemporaryDirectory(prefix="x1-gameplay-") as folder:
    folder = pathlib.Path(folder)
    keys = folder / "move.keys"
    gap = args.key_spacing_ms
    keys.write_text(f"10 43\n50 f0\n52 43\n{70+gap} 3b\n{120+gap} f0\n{122+gap} 3b\n")

    def run(name, controlled):
        prefix = folder / name
        command = [exe, "--cycles", str(args.duration_ms * 32000), "--restore-state", state,
                   "--disk", disk, "--dump", str(prefix), "--frame", str(prefix) + ".ppm"]
        if controlled:
            command += ["--keys", str(keys)]
        result = subprocess.run(command, check=True, capture_output=True, text=True)
        report = json.loads(result.stdout.splitlines()[-1])
        text = prefix.with_suffix(".text").read_bytes()
        memory = prefix.with_suffix(".ram").read_bytes()
        return player(memory, text), report, prefix.with_suffix(".ppm").read_bytes()

    idle, baseline, idle_frame = run("idle", False)
    moved, controlled, moved_frame = run("controlled", True)
    repeated, repeated_report, repeated_frame = run("repeat", True)
    assert moved[0] < idle[0] and moved[1] < idle[1], (idle, moved, controlled)
    assert idle_frame != moved_frame, "no visible output change"
    assert (moved, controlled, moved_frame) == (repeated, repeated_report, repeated_frame), "nondeterministic input"
    assert baseline["disk_requests"] == controlled["disk_requests"] == 0
    assert baseline["frames"] > 5 and baseline["frame_width"] == 320 and baseline["frame_height"] == 200
    print(json.dumps({"idle_player": idle, "controlled_player": moved,
                      "idle_frame_hash": baseline["frame_hash"], "controlled_frame_hash": controlled["frame_hash"],
                      "duration_ms": args.duration_ms, "key_spacing_ms": gap,
                      "native_snapshot": state, "repeatable": True}))
print("PASS: native game responds to PS/2 I/J movement with changed player coordinates and real RGB frames")
