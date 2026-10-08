"""Qualify real-CPU IPL-copy video fixtures against their RAM-entry execution."""
import argparse
import hashlib
import json
import pathlib
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("executable", type=pathlib.Path)
parser.add_argument("images", type=pathlib.Path)
args = parser.parse_args()
exe = args.executable.resolve()
digest = hashlib.sha256(exe.read_bytes()).hexdigest()
print("runner_sha256=" + digest, flush=True)
with tempfile.TemporaryDirectory(prefix="x1-video-ipl-") as temporary:
    folder = pathlib.Path(temporary)
    for columns in (40, 80):
        for kind in ("graphics", "text", "pcg"):
            name = f"{kind}-{columns}"
            rom = (args.images / (name + ".rom")).resolve()
            data = rom.read_bytes()
            assert len(data) == 4096
            ram = folder / (name + ".ram")
            ram.write_bytes(data[32:])
            frames = []
            for option, asset, label in (("--rom", rom, "ipl"), ("--ram", ram, "ram")):
                frame = folder / (name + "-" + label + ".ppm")
                result = subprocess.run([str(exe), option, str(asset), "--cycles", "32000000",
                                         "--frame", str(frame), "--peek", "0xf000"],
                                        capture_output=True, text=True, check=True, timeout=180)
                report = json.loads(result.stdout.splitlines()[-1])
                assert report["halted"] and report["peek"].startswith("56494421"), report
                assert (report["frame_width"], report["frame_height"]) == (columns*8, 200), report
                frames.append(frame.read_bytes())
            assert frames[0] == frames[1], name
            assert hashlib.sha256(exe.read_bytes()).hexdigest() == digest
            print("PASS real IPL copy/native CPU/RGB " + name, flush=True)
