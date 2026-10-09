"""Original Z80 1FC0 CPU register probe; no native opacity/renderer claim."""
import argparse
import csv
import hashlib
import json
import pathlib
import subprocess
from z80_fixture import Program


def fixture(mode):
    p = Program(0x8000)
    p.emit(0xF3)
    p.word(0x31, 0xFFFF)

    def out(port, value):
        p.word(0x01, port)
        p.emit(0x3E, value, 0xED, 0x79)

    def equal(port, value):
        p.word(0x01, port)
        p.emit(0xED, 0x78, 0xFE, value)
        p.jump(0xC2, "fail")

    out(0x1A03, 0x82)
    p.word(0x01, 0x1A02)
    p.emit(0xED, 0x78)
    out(0x1FB0, mode)
    # This experiment resets the register, unlike retained palette RAM.
    equal(0x1FC0, 0)
    p.word(0x01, 0x1FC0)
    p.emit(0x16, 0)
    p.label("values")
    p.emit(0x7A, 0xED, 0x79, 0xED, 0x78, 0xBA)
    p.jump(0xC2, "fail")
    p.emit(0x14)
    p.jump(0xC2, "values")
    out(0x1FC0, 0x1A)
    # Adjacent unrelated ports cannot overwrite this exact decode.
    out(0x1FBF, 0x35)
    out(0x1FC1, 0xEE)
    equal(0x1FC0, 0x1A)
    equal(0x1FBF, 0x35)
    out(0x1FB0, 0)
    out(0x1FC0, 0xFF)
    equal(0x1FC0, 0xFF)
    out(0x1FB0, mode)
    equal(0x1FC0, 0x1A)
    out(0x1A02, 0x20)
    out(0x1A02, 0)
    out(0x1FC0, 0xFF)
    p.word(0x01, 0x1A02)
    p.emit(0xED, 0x78)
    equal(0x1FC0, 0x1A)
    for index, value in enumerate(b"ZPRI"):
        p.store(0xF000 + index, value)
    p.emit(0x76)
    p.label("fail")
    p.store(0xF000, 0xEE)
    p.emit(0x76)
    return p.finish()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=pathlib.Path)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    parser.add_argument("--mode", type=lambda value: int(value, 0), choices=(0x80, 0x90), default=0x80)
    parser.add_argument("--warm", action="store_true")
    parser.add_argument("--expect-disabled", action="store_true")
    args = parser.parse_args()
    executable = args.executable.resolve()
    before = hashlib.sha256(executable.read_bytes()).hexdigest()
    args.output.mkdir(parents=True, exist_ok=False)
    program = args.output / "original.bin"
    program.write_bytes(fixture(args.mode))
    command = [str(executable), "--ram", str(program.resolve()), "--cycles", "4000000"]
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
    assert report["peek"].startswith("ee" if args.expect_disabled else b"ZPRI".hex()), report
    assert hashlib.sha256(executable.read_bytes()).hexdigest() == before, "runner changed"
    if not args.expect_disabled:
        assert report["z_text_cpu_experiment"] and report["z_palette_cpu_experiment"], report
    if args.warm:
        with (args.output / "warm-io.csv").open() as stream:
            rows = list(csv.DictReader(stream))
        assert any(int(row["address"]) == 0x1FC0 and row["rd_n"] == "0" for row in rows), "no reset read"
        assert any(int(row["address"]) == 0x1FC0 and row["wr_n"] == "0" for row in rows), "no CPU reprogramming"
    evidence = {"runner_sha256": before, "fixture_sha256": hashlib.sha256(program.read_bytes()).hexdigest(),
                "command": command, "report": report, "mode": args.mode,
                "warm": args.warm, "disabled_control": args.expect_disabled}
    (args.output / "evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")
    print(json.dumps(evidence))
    print("PASS: unchanged disabled priority probe negative" if args.expect_disabled else
          "PASS: actual CPU 1FC0 all 256 values, exact decode, text isolation, inactive/DAM/reset; no rendering claim")


if __name__ == "__main__":
    main()
