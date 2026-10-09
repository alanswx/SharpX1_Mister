"""Original real-CPU six-bit text palette probe; no native glyph/ROM assets."""
import argparse
import hashlib
import json
import pathlib
import subprocess
from z80_fixture import Program


def fixture(mode=0x80):
    p = Program(0x8000)
    p.emit(0xF3)
    p.word(0x31, 0xFFFF)

    def out(port, data):
        p.word(0x01, port)
        p.emit(0x3E, data, 0xED, 0x79)

    def equal(port, data, mask=0x3F):
        p.word(0x01, port)
        p.emit(0xED, 0x78, 0xE6, mask, 0xFE, data)
        p.jump(0xC2, "fail")

    out(0x1A03, 0x82)
    p.word(0x01, 0x1A02)
    p.emit(0xED, 0x78)
    out(0x1FB0, mode)
    p.word(0x3A, 0xF040)
    p.emit(0xFE, 0xA5)
    p.jump(0xCA, "retained")
    for color in range(1, 8):
        cold = (0x30 if color & 4 else 0) | (0x0C if color & 2 else 0) | (3 if color & 1 else 0)
        equal(0x1FB8 + color, cold)
        p.word(0x01, 0x1FB8 + color)
        p.emit(0x16, 0)
        p.label(f"values{color}")
        p.emit(0x7A, 0xF6, 0xC0, 0xED, 0x79, 0xED, 0x78, 0xE6, 0x3F, 0xBA)
        p.jump(0xC2, "fail")
        p.emit(0x14, 0x7A, 0xFE, 64)
        p.jump(0xC2, f"values{color}")
        out(0x1FB8 + color, (color * 9 + 13) & 63)
    # Explicit experimental inactive-AEN gate; not a native inactive-mode claim.
    out(0x1FB0, 0)
    for color in range(1, 8):
        out(0x1FB8 + color, 0xFF)
        equal(0x1FB8 + color, 0xFF, 0xFF)
    out(0x1FB0, mode)
    out(0x1FB8, 0xFF)
    equal(0x1FB8, 0xFF, 0xFF)
    # DAM redirects the alias OUT to GRAM; the text entry must not change.
    out(0x1A02, 0x20)
    out(0x1A02, 0)
    out(0x1FB9, 0xFF)
    p.word(0x01, 0x1A02)
    p.emit(0xED, 0x78)
    p.store(0xF040, 0xA5)
    p.label("retained")
    for color in range(1, 8):
        equal(0x1FB8 + color, (color * 9 + 13) & 63)
    for i, byte in enumerate(b"TXPL"):
        p.store(0xF000 + i, byte)
    p.emit(0x76)
    p.label("fail")
    p.store(0xF000, 0xEE)
    p.emit(0x76)
    return p.finish()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=pathlib.Path)
    parser.add_argument("--output", required=True, type=pathlib.Path)
    parser.add_argument("--warm", action="store_true")
    parser.add_argument("--expect-disabled", action="store_true")
    parser.add_argument("--mode", type=lambda value: int(value, 0), choices=(0x80, 0x90), default=0x80)
    args = parser.parse_args()
    exe = args.executable.resolve()
    sha = hashlib.sha256(exe.read_bytes()).hexdigest()
    args.output.mkdir(parents=True, exist_ok=False)
    program = args.output / "original.bin"
    program.write_bytes(fixture(args.mode))
    command = [str(exe), "--ram", str(program.resolve()), "--cycles", "4000000"]
    if args.warm:
        command += ["--reset-at", "100", "--reset-for-us", "10", "--bus-trace",
                    str((args.output / "warm-io.csv").resolve()), "--bus-events", "--io-only",
                    "--bus-start-ms", "100", "--bus-end-ms", "125"]
    result = subprocess.run(command, capture_output=True, text=True, timeout=180)
    (args.output / "stdout.txt").write_text(result.stdout)
    (args.output / "stderr.txt").write_text(result.stderr)
    assert result.returncode == 0, result.stderr
    report = json.loads(result.stdout.splitlines()[-1])
    assert report["halted"] and report["intra_assignment_delays"], report
    assert report["peek"].startswith("ee" if args.expect_disabled else b"TXPL".hex()), report
    assert hashlib.sha256(exe.read_bytes()).hexdigest() == sha, "runner changed"
    if not args.expect_disabled:
        assert report["z_text_cpu_experiment"] and report["z_palette_cpu_experiment"], report
    if args.warm and not args.expect_disabled:
        import csv
        with (args.output / "warm-io.csv").open() as stream:
            writes = [int(row["address"]) for row in csv.DictReader(stream) if row["wr_n"] == "0"]
        assert 0x1FB0 in writes and not any(0x1FB8 <= a <= 0x1FBF for a in writes), writes
    evidence = {"runner_sha256": sha, "fixture_sha256": hashlib.sha256(program.read_bytes()).hexdigest(),
                "command": command, "report": report, "mode": args.mode, "disabled_control": args.expect_disabled}
    (args.output / "evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")
    print(json.dumps(evidence))
    print("PASS: unchanged disabled-profile negative" if args.expect_disabled else
          "PASS: actual CPU cold/read/write/all-six-bit values/inactive/DAM/retained palette; no RGB claim")


if __name__ == "__main__":
    main()
