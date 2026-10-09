"""Actual-Z80 regression: held PPI OUT must not overwrite aliased GRAM."""
import argparse
import hashlib
import json
import pathlib
import subprocess
import tempfile
from z80_fixture import Program


def fixture():
    p = Program()
    p.emit(0xF3)
    p.word(0x31, 0xFFFF)
    def out(port, value):
        p.word(0x01, port)
        p.emit(0x3E, value, 0xED, 0x79)
    def clear():
        p.word(0x01, 0x1A02)
        p.emit(0xED, 0x78)
    out(0x1A03, 0x82)
    clear()
    for control, value in ((0x1A03, 0x82), (0x1A02, 0x40)):
        for offset in (0x1A02, 0x1A03):
            for component, base in enumerate((0x4000, 0x8000, 0xC000)):
                out(base + offset, 0x31 + component * 0x27 + (offset & 1))
        out(0x1A02, 0x60)  # C5 high, no graphics override
        out(control, value)  # falling C5 while CPU still holds the OUT
        clear()
        for offset in (0x1A02, 0x1A03):
            for component, base in enumerate((0x4000, 0x8000, 0xC000)):
                p.word(0x01, base + offset)
                p.emit(0xED, 0x78, 0xFE, 0x31 + component * 0x27 + (offset & 1))
                p.jump(0xC2, "fail")
    for i, byte in enumerate(b"DMOK"):
        p.store(0xF000 + i, byte)
    p.emit(0x76)
    p.label("fail")
    p.store(0xF000, 0xEE)
    p.emit(0x76)
    return p.finish()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=pathlib.Path)
    parser.add_argument("--expect-failure", action="store_true")
    args = parser.parse_args()
    exe = args.executable.resolve()
    digest = hashlib.sha256(exe.read_bytes()).hexdigest()
    with tempfile.TemporaryDirectory(prefix="x1-dam-cpu-") as directory:
        rom = pathlib.Path(directory) / "original.bin"
        rom.write_bytes(fixture())
        result = subprocess.run([str(exe), "--rom", str(rom), "--cycles", "1000000"],
                                check=True, capture_output=True, text=True, timeout=180)
        report = json.loads(result.stdout.splitlines()[-1])
        assert report["halted"], report
        assert report["peek"].startswith("ee" if args.expect_failure else b"DMOK".hex()), report
        assert hashlib.sha256(exe.read_bytes()).hexdigest() == digest, "runner replaced"
        print(json.dumps({"runner_sha256": digest,
                          "fixture_sha256": hashlib.sha256(rom.read_bytes()).hexdigest(),
                          "negative_control": args.expect_failure, "report": report}))
        print("PASS: expected old-model corruption" if args.expect_failure else
              "PASS: actual CPU control/C5 OUT preserves both GRAM aliases on all planes")


if __name__ == "__main__":
    main()
