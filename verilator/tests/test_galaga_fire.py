"""Private native Galaga enemy-wave and repeatable player-projectile regression."""
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
parser.add_argument("--output", type=pathlib.Path)
parser.add_argument("--timeout", type=float, default=600)
args = parser.parse_args()
exe, source, disk = [p.resolve() for p in (args.executable, args.snapshot, args.disk)]
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
originals = {path: sha(path) for path in (source, disk)}
assert originals[disk] == "d0cdeb8275fbbdd2226851266a7bbf3d5e4ff77c268e331a81083c8eac3c342c", "unknown release"

def run(folder, name, state, joy, ms=300):
    prefix = folder / name
    saved = prefix.with_suffix(".state")
    assert saved != source, "output would overwrite native source snapshot"
    result = subprocess.run([str(exe), "--cycles", str(ms * 32000), "--restore-state", str(state),
                             "--disk", str(disk), "--joya", joy, "--dump", str(prefix),
                             "--frame", str(prefix) + ".ppm", "--save-state", str(saved)],
                            capture_output=True, text=True, timeout=args.timeout, check=True)
    report = json.loads(result.stdout.splitlines()[-1])
    memory = prefix.with_suffix(".ram").read_bytes()
    assert report["disk_requests"] == report["disk_writes"] == report["ps2_bytes_sent"] == 0
    assert (report["frame_width"], report["frame_height"]) == (320, 200)
    assert report["frames"] >= (15 if ms == 300 else 5)
    assert memory[0x230F] == memory[0xDD3] == 1
    # Native collision loop 518B..5199 visits 45 records, 45 bytes apart.
    enemies = sum(2 <= memory[0x4162 + index * 45] <= 8 for index in range(45))
    assert enemies > 0, "only stage introduction, no active enemy wave"
    artifacts = tuple(prefix.with_suffix("." + ext).read_bytes()
                      for ext in ("ram", "text", "attr", "subram", "cpu", "ppm", "state"))
    return memory, report, artifacts, saved, enemies

def check(folder):
    folder.mkdir(parents=True, exist_ok=True)
    idle = run(folder, "idle", source, "0xff")
    fired = run(folder, "fire", source, "0xdf")
    repeat = run(folder, "repeat", source, "0xdf")
    assert fired[:3] == repeat[:3], "projectile input/result/state not repeatable"
    def shots(memory): return int.from_bytes(memory[0x2714:0x2716], "little")
    assert shots(idle[0]) == 0 and shots(fired[0]) == 1
    # Native 5024/502F select two projectile slots; 505C increments count.
    slot = 0x5813
    assert idle[0][slot] == 0 and fired[0][slot] == 1 and fired[0][0x5822] == 0
    assert fired[0][slot + 5:slot + 7] == bytes((0, 255)), "unexpected VX/VY"
    assert idle[2][5] != fired[2][5], "shot RAM changed without actual RGB"
    travel = run(folder, "released", fired[3], "0xff", 100)
    assert shots(travel[0]) == 1 and travel[0][slot] == 1
    assert travel[0][slot + 1] == fired[0][slot + 1]
    assert travel[0][slot + 2] < fired[0][slot + 2], "projectile did not travel upward"
    assert travel[2][5] != fired[2][5]
    assert all(sha(path) == digest for path, digest in originals.items()), "source asset modified"
    print(json.dumps({"title": "Galaga", "enemy_slots": fired[4], "shots": [0, 1],
                      "projectile": list(fired[0][slot + 1:slot + 3]),
                      "released_projectile": list(travel[0][slot + 1:slot + 3]),
                      "idle_frame_hash": idle[1]["frame_hash"], "fire_frame_hash": fired[1]["frame_hash"],
                      "released_frame_hash": travel[1]["frame_hash"], "disk_sha256": originals[disk],
                      "snapshot_sha256": originals[source], "sys_hz": fired[1]["sys_hz"],
                      "video_hz": fired[1]["video_hz"], "reset_edges": fired[1]["reset_edges"]}))
    print("PASS: active enemy wave, native firing/projectile travel, RAM/RGB/state/report repeatability, unchanged sources")

if args.output:
    check(args.output.resolve())
else:
    with tempfile.TemporaryDirectory(prefix="x1-galaga-fire-") as temporary:
        check(pathlib.Path(temporary))
