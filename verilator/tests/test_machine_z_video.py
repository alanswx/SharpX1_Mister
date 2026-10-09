"""Original CPU-written 320x200/4096 raster; no private ROM/font assets."""
import argparse
import csv
import hashlib
import json
import pathlib
import subprocess
from z80_fixture import Program


SEEDS = (0x53, 0xA7, 0xD9)


def table_byte(row, k):
    v = (k + row * 71) & 255
    shift = row % 7 + 1
    return ((k * 37 + row * 53) ^ (k >> 2) ^
            ((v << shift) | (v >> (8 - shift)))) & 255


def fixture(custom=False):
    p = Program(0x8000)
    p.emit(0xF3)
    p.word(0x31, 0xFFFF)

    def out(port, value):
        p.word(0x01, port)
        p.emit(0x3E, value, 0xED, 0x79)

    out(0x1A03, 0x82)
    p.word(0x01, 0x1A02)
    p.emit(0xED, 0x78)  # mode-set C5 transition arms DAM; clear before OUT C
    out(0x1A02, 0x40)
    p.word(0x01, 0x1A02)
    p.emit(0xED, 0x78)  # genuine IN clears DAM
    out(0x1FD0, 0)
    p.word(0x3A, 0xF040)
    p.emit(0xFE, 0xA5)
    p.jump(0xCA, "retained")
    for base in (0x2000, 0x3000):
        label = f"clear{base}"
        p.word(0x01, base)
        p.word(0x11, 2048)
        p.label(label)
        p.emit(0xAF, 0xED, 0x79, 0x03, 0x1B, 0x7A, 0xB3)
        p.jump(0xC2, label)
    for page in range(2):
        out(0x1FD0, page << 4)
        for component, base in enumerate((0x4000, 0x8000, 0xC000)):
            label = f"plane{page}_{component}"
            p.word(0x01, base)
            p.emit(0x16, SEEDS[component] ^ (0x91 if page else 0x2D))
            p.label(label)
            # H=A0+RA; L=B^C^seed; read the original RAM lookup table.
            p.emit(0x78, 0xE6, 0x38, 0x0F, 0x0F, 0x0F, 0xC6, 0xA0, 0x67,
                   0x78, 0xA9, 0xAA, 0x6F, 0x7E, 0xED, 0x79, 0x03,
                   0x78, 0xE6, 0x3F, 0xB1)
            p.jump(0xC2, label)
    if custom:
        out(0x1FD0, 0)
        out(0x1FB0, 0x80)
        out(0x1FC5, 0x80)
        for component, seed in enumerate((3, 9, 5)):
            p.word(0x01, (0x10 + component) << 8)
            p.word(0x11, seed << 8)  # D=seed, E=blue-index high nibble
            p.word(0x21, 0x1000)  # H=16 outer iterations; L=blue index
            outer, inner = f"pal_outer{component}", f"pal_inner{component}"
            p.label(outer)
            p.label(inner)
            p.emit(0x79)  # C encodes G:R
            if component != 2:
                p.emit(0x0F, 0x0F, 0x0F, 0x0F)  # G
            if component == 0:
                p.emit(0xA9)  # G xor R
            p.emit(0xAD, 0xAA, 0xE6, 15, 0xB3, 0xED, 0x79, 0x0C)
            p.jump(0xC2, inner)
            p.emit(0x2C, 0x7D, 0x0F, 0x0F, 0x0F, 0x0F, 0xE6, 0xF0,
                   0x5F, 0x25)
            p.jump(0xC2, outer)
    p.store(0xF040, 0xA5)
    p.label("retained")
    out(0x1FD0, 0)
    out(0x1FB0, 0x80)
    registers = (55, 40, 46, 0x28, 31, 2, 25, 28, 0, 7, 0, 0, 0, 0, 0, 0)
    for register, value in enumerate(registers):
        out(0x1800, register)
        out(0x1801, value)
    for i, byte in enumerate(b"ZVID"):
        p.store(0xF000 + i, byte)
    p.emit(0x76)
    code = p.finish()
    assert len(code) < 0x2000
    return code.ljust(0x2000, b"\0") + bytes(
        table_byte(row, k) for row in range(8) for k in range(256))


def expected_pixel(x, y, custom=False):
    q = (y % 8) * 2048 + (y // 8) * 40 + x // 8
    components = []
    for component, base in enumerate((0x4000, 0x8000, 0xC000)):
        nibble = 0
        for lane in range(4):
            address = (q + (0x400 if lane & 1 else 0)) & 0x3FFF
            port = base + address
            seed = SEEDS[component] ^ (0x91 if lane & 2 else 0x2D)
            k = (port >> 8) ^ (port & 255) ^ seed
            value = table_byte((port & 0x3800) >> 11, k)
            nibble |= bool(value & (128 >> (x % 8))) << lane
        components.append(nibble)
    blue, red, green = components
    if custom:
        blue, red, green = green ^ red ^ blue ^ 3, green ^ blue ^ 9, red ^ blue ^ 5
    return bytes((red * 17, green * 17, blue * 17))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=pathlib.Path)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    parser.add_argument("--warm", action="store_true")
    parser.add_argument("--custom", action="store_true")
    parser.add_argument("--timeout", type=float, default=900)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    executable = args.executable.resolve()
    digest = hashlib.sha256(executable.read_bytes()).hexdigest()
    code = args.output / "original.bin"
    code.write_bytes(fixture(args.custom))
    frame = args.output / "actual.ppm"
    # Full palette programming adds actual CPU/ownership cycles. Leave enough
    # time to finish cold initialization BEFORE a retained warm reset.
    duration_ms = 5000 if args.custom else 4000
    reset_ms = 4500 if args.custom else 3500
    command = [str(executable), "--ram", str(code.resolve()), "--cycles", str(duration_ms * 32000),
               "--frame", str(frame.resolve())]
    if args.warm:
        bus = args.output / "warm-io.csv"
        command += ["--reset-at", str(reset_ms), "--reset-for-us", "10",
                    "--bus-trace", str(bus.resolve()), "--bus-events", "--io-only",
                    "--bus-start-ms", str(reset_ms), "--bus-end-ms", str(duration_ms)]
    print(json.dumps({"runner_sha256": digest,
                      "program_sha256": hashlib.sha256(code.read_bytes()).hexdigest(),
                      "command": command}), flush=True)
    result = subprocess.run(command, capture_output=True, text=True, timeout=args.timeout)
    (args.output / "stdout.txt").write_text(result.stdout)
    (args.output / "stderr.txt").write_text(result.stderr)
    assert result.returncode == 0, result.stderr
    report = json.loads(result.stdout.splitlines()[-1])
    print(json.dumps(report), flush=True)
    assert report["z_video_experiment"] and report["z_palette_cpu_experiment"], report
    assert report["intra_assignment_delays"] and report["turbo_video_master"], report
    assert report["sys_hz"] == 32000000 and report["video_hz"] == 42954540, report
    assert report["halted"] and report["peek"].startswith(b"ZVID".hex()), report
    assert report["frames"] >= 3, report
    if args.warm:
        with bus.open() as stream:
            writes = [row for row in csv.DictReader(stream) if row["wr_n"] == "0"]
        addresses = [int(row["address"]) for row in writes]
        # A correct final frame alone could hide a cold refill. Observe actual
        # reboot I/O: real CRTC/PPI reinitialization, no GRAM/text/palette writes.
        assert addresses.count(0x1800) == 16 and addresses.count(0x1801) == 16, addresses
        assert addresses.count(0x1A03) == 1 and addresses.count(0x1A02) == 1, addresses
        assert not any(a >= 0x2000 or 0x1000 <= a < 0x1300 for a in addresses), addresses[:60]
    tolerance = 31251
    for field, edges in (("hs_period_ps", 2688), ("vs_period_ps", 2688 * 258)):
        assert abs(report[field] - round(edges * 10**12 / 42954540)) <= tolerance, report
    header, dimensions, maximum, actual = frame.read_bytes().split(b"\n", 3)
    assert (header, dimensions, maximum) == (b"P6", b"320 200", b"255"), report
    expected = b"".join(expected_pixel(x, y, args.custom) for y in range(200) for x in range(320))
    (args.output / "expected.ppm").write_bytes(b"P6\n320 200\n255\n" + expected)
    mismatches = [(i // 3 % 320, i // 960, tuple(actual[i:i+3]), tuple(expected[i:i+3]))
                  for i in range(0, len(expected), 3) if actual[i:i+3] != expected[i:i+3]]
    assert actual == expected, (len(mismatches), mismatches[:20])
    assert hashlib.sha256(executable.read_bytes()).hexdigest() == digest, "runner changed during test"
    print(f"PASS: 64000 CPU-written full-color pixels; retained reset={args.warm}")


if __name__ == "__main__":
    main()
