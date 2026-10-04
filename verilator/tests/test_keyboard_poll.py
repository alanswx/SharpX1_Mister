"""Original CPU fixture: E4/E6 polling under continuous host traffic."""
import argparse
import json
import pathlib
import subprocess
import tempfile
from z80_fixture import Program

parser = argparse.ArgumentParser()
parser.add_argument("executable", type=pathlib.Path)
parser.add_argument("--timeout", type=float, default=180)
args = parser.parse_args()
exe = str(args.executable.resolve())


def fixture(expected):
    p = Program()
    p.emit(0xF3)
    p.word(0x31, 0xFFFF)
    p.word(0x01, 0x1A03)
    p.emit(0x3E, 0x82, 0xED, 0x79)
    p.label("poll")
    for index, value in enumerate((0xE4, 0, 0xE6)):
        p.word(0x01, 0x1A01)
        p.label(f"ready{index}")
        p.emit(0xED, 0x78, 0xE6, 0x40)
        p.jump(0xC2, f"ready{index}")
        p.word(0x01, 0x1900)
        p.emit(0x3E, value, 0xED, 0x79)
    for index in range(2):
        p.word(0x01, 0x1A01)
        p.label(f"reply{index}")
        p.emit(0xED, 0x78, 0xE6, 0x20)
        p.jump(0xC2, f"reply{index}")
        p.word(0x01, 0x1900)
        p.emit(0xED, 0x78)
        p.word(0x32, 0xF000 + index)
    p.emit(0xFE, expected)
    p.jump(0xC2, "poll")
    p.emit(0x76)
    return p.finish()


with tempfile.TemporaryDirectory(prefix="x1-keyboard-poll-") as temp:
    folder = pathlib.Path(temp)
    for name, scan, ascii_code in (("F", 0x2B, 0x46), ("Space", 0x29, 0x20), ("Enter", 0x5A, 0x0D)):
        rom, keys = folder / "poll.bin", folder / "keys.txt"
        rom.write_bytes(fixture(ascii_code))
        keys.write_text(f"25 {scan:02x}\n")  # Held through the end, no break race.
        prefix = folder / name
        result = subprocess.run([exe, "--cycles", "4000000", "--rom", str(rom),
                                 "--keys", str(keys), "--dump", str(prefix)],
                                capture_output=True, text=True, timeout=args.timeout, check=True)
        report = json.loads(result.stdout.splitlines()[-1])
        print(json.dumps({"key": name, "halted": report["halted"], "reply": report["peek"][:4]}), flush=True)
        assert report["halted"] and report["peek"][2:4] == f"{ascii_code:02x}", (name, report)
print("PASS: held F/Space/Enter decoded while CPU continuously polls E4/E6")
