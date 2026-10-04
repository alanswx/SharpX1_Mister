"""Private release-bound Shanghai cursor and legal matching-pair removal check.

Requires native-booted cursor and selected-pair states, never bundled assets.
"""
import argparse
import hashlib
import json
import pathlib
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("executable", type=pathlib.Path)
parser.add_argument("cursor_state", type=pathlib.Path)
parser.add_argument("pair_state", type=pathlib.Path)
parser.add_argument("disk", type=pathlib.Path)
parser.add_argument("--output", type=pathlib.Path)
parser.add_argument("--timeout", type=float, default=600)
args = parser.parse_args()
exe, cursor, pair, disk = [path.resolve() for path in
                         (args.executable, args.cursor_state, args.pair_state, args.disk)]
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
originals = {path: sha(path) for path in (cursor, pair, disk)}
assert originals[disk] == "648d150e8e36b5ba282bb7e3475e704f5f938d5c4a77ef6d7d000908f48513dc", "unknown release"

def run(folder, name, source, joy):
    prefix = folder / name
    result = subprocess.run([str(exe), "--restore-state", str(source), "--cycles", "9600000",
                             "--disk", str(disk), "--joya", joy, "--dump", str(prefix),
                             "--frame", str(prefix) + ".ppm", "--save-state", str(prefix) + ".state"],
                            capture_output=True, text=True, timeout=args.timeout, check=True)
    report = json.loads(result.stdout.splitlines()[-1])
    assert report["disk_requests"] == report["disk_writes"] == report["download_bytes"] == 0
    assert report["ps2_bytes_sent"] == 0, "joystick-only trial sent keyboard bytes"
    assert report["frame_width"] == 640 and report["frame_height"] == 200 and report["frames"] >= 15
    memory = prefix.with_suffix(".ram").read_bytes()
    artifacts = tuple(prefix.with_suffix("." + extension).read_bytes()
                      for extension in ("ram", "text", "attr", "subram", "cpu", "ppm", "state"))
    return memory, report, artifacts, prefix.with_suffix(".state")

def check(folder):
    folder.mkdir(parents=True, exist_ok=True)
    idle = run(folder, "cursor-idle", cursor, "0xff")
    right = run(folder, "cursor-right", cursor, "0xf7")
    repeat = run(folder, "cursor-repeat", cursor, "0xf7")
    assert right[:3] == repeat[:3], "cursor repeat mismatch"
    def xy(memory): return tuple(int.from_bytes(memory[a:a + 2], "little") for a in (0x5145, 0x5147))
    ix, iy = xy(idle[0]); rx, ry = xy(right[0])
    assert 0 <= iy < 200 and 0 <= ry < 200 and ix < rx < 640, (xy(idle[0]), xy(right[0]))
    assert idle[2][5] != right[2][5], "cursor moved without actual RGB change"
    results = []
    for name, joy in (("pair-idle", "0xff"), ("pair-remove", "0xbf"), ("pair-repeat", "0xbf")):
        first = run(folder, name + "-click", pair, joy)
        results.append(run(folder, name + "-release", first[3], "0xff"))
    neutral, removed, repeated = results
    assert removed[:3] == repeated[:3], "removal repeat mismatch"
    # Native removal routine 2AC3..2B30 clears two selected type-11 tiles and
    # increments 3F9F twice. High bit80 is highlighting, not tile identity.
    assert [neutral[0][a] for a in (0x3E1B, 0x3EBA)] == [0x91, 0x91]
    assert [removed[0][a] for a in (0x3E1B, 0x3EBA)] == [0, 0]
    assert neutral[0][0x2D2F] == 2 and removed[0][0x2D2F] == 0
    assert neutral[0][0x3F9F] == 0 and removed[0][0x3F9F] == 2
    assert neutral[2][5] != removed[2][5], "removed tiles without actual RGB change"
    assert all(sha(path) == digest for path, digest in originals.items()), "source asset modified"
    print(json.dumps({"title": "Shanghai", "cursor_idle": [ix, iy], "cursor_right": [rx, ry],
                      "removed_count": [0, 2], "idle_frame_hash": neutral[1]["frame_hash"],
                      "removed_frame_hash": removed[1]["frame_hash"],
                      "disk_sha256": originals[disk], "cursor_state_sha256": originals[cursor],
                      "pair_state_sha256": originals[pair], "sys_hz": removed[1]["sys_hz"],
                      "video_hz": removed[1]["video_hz"], "reset_edges": removed[1]["reset_edges"]}))
    print("PASS: native cursor input, selected matching-pair removal, RGB and full dump/state/report repeatability")

if args.output:
    check(args.output.resolve())
else:
    with tempfile.TemporaryDirectory(prefix="x1-shanghai-gameplay-") as temporary:
        check(pathlib.Path(temporary))
