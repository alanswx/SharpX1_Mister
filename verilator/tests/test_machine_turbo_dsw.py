"""Original asset-free CPU DIP diagnostic; no native firmware or RAM injection."""
import argparse
import json
import pathlib
import subprocess
import tempfile
from z80_fixture import Program


def fixture(expected):
    p = Program()
    p.emit(0xF3)
    p.word(0x31, 0xFFFF)

    def output(port, value):
        p.word(0x01, port)
        p.emit(0x3E, value, 0xED, 0x79)

    def equal(port, value):
        p.word(0x01, port)
        p.emit(0xED, 0x78, 0xFE, value)
        p.jump(0xC2, "fail")

    output(0x1A03, 0x82)
    # Native PPI read clears DAM before ordinary device access.
    equal(0x1A02, 0)
    output(0x1A02, 0x40)
    for port in range(0x1FF0, 0x2000):
        equal(port, expected)
        output(port, expected ^ 255)
        equal(port, expected)
    for port in (0x1FEF, 0x0FF0):
        equal(port, 255)
    output(0x1A02, 0x60)
    output(0x1A02, 0x40)  # Falling mode-C bit 5 activates DAM.
    # DAM clears on an I/O read before the CPU's final sample; do not
    # assert an instantaneous decoder value as a completed CPU transaction.
    p.word(0x01, 0x1A02)
    p.emit(0xED, 0x78)
    equal(0x1FF0, expected)
    p.word(0x3A, 0xF040)
    p.emit(0xFE, 0xA5)
    p.jump(0xCA, "warm")
    p.store(0xF040, 0xA5)
    for i, value in enumerate(b"DSW!"):
        p.store(0xF000 + i, value)
    p.emit(0x76)
    p.label("warm")
    for i, value in enumerate(b"WARM"):
        p.store(0xF000 + i, value)
    p.emit(0x76)
    p.label("fail")
    p.store(0xF000, 0xEE)
    p.emit(0x76)
    return p.finish()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=pathlib.Path)
    parser.add_argument("--expected", type=lambda s: int(s, 0), default=0xF1)
    args = parser.parse_args()
    if not 0 <= args.expected <= 255:
        parser.error("expected raw DIP must fit one byte")
    with tempfile.TemporaryDirectory(prefix="x1-dsw-cpu-") as temp:
        rom = pathlib.Path(temp) / "original.bin"
        rom.write_bytes(fixture(args.expected))
        for warm in (False, True):
            command = [str(args.executable.resolve()), "--rom", str(rom),
                       "--cycles", "6400000"]
            if warm:
                command += ["--reset-at", "100", "--reset-for-us", "10"]
            result = subprocess.run(command, check=True, capture_output=True, text=True, timeout=180)
            report = json.loads(result.stdout.splitlines()[-1])
            expected = b"WARM" if warm else b"DSW!"
            assert report["halted"] and report["peek"].startswith(expected.hex()), report
            print(json.dumps({"warm": warm, "raw_dip": args.expected,
                              "peek": report["peek"][:8]}), flush=True)
    print("PASS real CPU DIP: all 16 mirrors, ignored writes, PPI DAM recovery, neighboring unmapped ports, cold/warm")


if __name__ == "__main__":
    main()
