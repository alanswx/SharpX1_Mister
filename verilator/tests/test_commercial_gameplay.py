"""Release-bound, private-media player-control regression after native IPL boot.

Requires locally generated live snapshots; no game bytes/states are bundled.
This checks bounded gameplay input, not full title/level compatibility.
"""
import argparse
import hashlib
import json
import pathlib
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("executable", type=pathlib.Path)
parser.add_argument("title", choices=("druaga", "xevious", "mappy"))
parser.add_argument("snapshot", type=pathlib.Path)
parser.add_argument("disk", type=pathlib.Path)
parser.add_argument("--output", type=pathlib.Path)
parser.add_argument("--timeout", type=float, default=600)
args = parser.parse_args()
exe, state, disk = (path.resolve() for path in (args.executable, args.snapshot, args.disk))
media_hashes = {
    "druaga": "bb8556981f0910f33d7129f82de620a232e61b0fc41a61ed565366b5de4560b9",
    "xevious": "3670f283005c90b09a53e1b2dd1164c45c6a997eafbc0ca9c20248b9f7e19903",
    "mappy": "297e89aa7a8d9feb72651823bab210e66c09fdc1863bb6e4a9528c8ca652325b",
}
original_disk = disk.read_bytes()
disk_sha = hashlib.sha256(original_disk).hexdigest()
assert disk_sha == media_hashes[args.title], "unrecognized release: establish symbols/controls before adding it"
state_sha = hashlib.sha256(state.read_bytes()).hexdigest()


def player(memory):
    if args.title == "mappy":
        # 03CD selects IX=F800; 0992/09B8 increment/decrement +0B.
        # 0973 checks Y at +09 against floor heights. Joystick bit2 is left.
        x, y = memory[0xF80B], memory[0xF809]
        assert memory[0xF800] == 3 and 0 < x < 256 and 0 < y < 200, (x, y)
        return (x, y)
    if args.title == "druaga":
        # 0680 loads BC from F828; joystick handlers 1BAB/1BBC/1BCE/1BE0
        # change B/C and 1C16 stores BC back. F830/F832 are background-save
        # pointers, NOT coordinates. Left (bit2) changes C, direction=3.
        x, y = memory[0xF828:0xF82A]
        assert 0 < x < 128 and 0 < y < 64, (x, y)
        return (x, y)
    # Render routine 43BC selects IX=16E4 and calls the sprite renderer 16F5;
    # offsets +1/+2 are y/x and +3/+4 are retained copies. +0 is active.
    active, y, x, old_y, old_x = memory[0x16E4:0x16E9]
    assert active and 0 < x < 70 and 0 < y < 70, (active, x, y)
    assert x == old_x and y == old_y, (x, y, old_x, old_y)
    return (x, y)


def run(folder, name, controlled):
    prefix = folder / name
    joy = "0xf7" if args.title == "xevious" else "0xfb"
    command = [str(exe), "--cycles", "9600000", "--restore-state", str(state),
               "--disk", str(disk), "--joya", joy if controlled else "0xff",
               "--dump", str(prefix), "--frame", str(prefix) + ".ppm"]
    result = subprocess.run(command, capture_output=True, text=True, check=True, timeout=args.timeout)
    report = json.loads(result.stdout.splitlines()[-1])
    memory = prefix.with_suffix(".ram").read_bytes()
    frame = prefix.with_suffix(".ppm").read_bytes()
    assert report["disk_requests"] == report["disk_writes"] == 0, report
    assert report["ps2_bytes_sent"] == 0, "joystick-only trial sent keyboard bytes"
    assert report["frames"] >= 15 and report["frame_height"] == 200, report
    assert report["frame_width"] == (320 if args.title == "xevious" else 640), report
    if controlled and args.title == "druaga": assert memory[0xF82A] == 3
    return player(memory), report, memory, frame


def check(folder):
    folder.mkdir(parents=True, exist_ok=True)
    idle = run(folder, "idle", False)
    moved = run(folder, "controlled", True)
    repeated = run(folder, "repeat", True)
    assert moved == repeated, "input/result/RAM/RGB not deterministic"
    ix, iy = idle[0]
    mx, my = moved[0]
    assert my == iy and (mx > ix if args.title == "xevious" else mx < ix), (idle[0], moved[0])
    assert idle[3] != moved[3], "player RAM changed without a real RGB frame change"
    assert disk.read_bytes() == original_disk, "disk modified"
    assert hashlib.sha256(state.read_bytes()).hexdigest() == state_sha, "source snapshot modified"
    print(json.dumps({"title": args.title, "duration_ms": 300, "idle_player": idle[0],
                      "controlled_player": moved[0], "direction": "right" if args.title == "xevious" else "left",
                      "idle_frame_hash": idle[1]["frame_hash"], "controlled_frame_hash": moved[1]["frame_hash"],
                      "disk_sha256": disk_sha, "snapshot_sha256": state_sha,
                      "sys_hz": moved[1]["sys_hz"], "video_hz": moved[1]["video_hz"],
                      "reset_edges": moved[1]["reset_edges"], "repeatable": True}))
    print("PASS: release-bound live player movement, actual RGB change, main RAM/report/RGB repeatability, unchanged assets")


if args.output:
    check(args.output.resolve())
else:
    with tempfile.TemporaryDirectory(prefix="x1-commercial-gameplay-") as temp:
        check(pathlib.Path(temp))
