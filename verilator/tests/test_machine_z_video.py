"""Original CPU-written full/reduced-color rasters; no private ROM/font assets."""
import argparse
import csv
import hashlib
import json
import pathlib
import re
import subprocess
from functools import lru_cache
from z80_fixture import Program


SEEDS = (0x53, 0xA7, 0xD9)


def table_byte(row, k):
    v = (k + row * 71) & 255
    shift = row % 7 + 1
    return ((k * 37 + row * 53) ^ (k >> 2) ^
            ((v << shift) | (v >> (8 - shift)))) & 255


@lru_cache()
def font8_path():
    candidates = (pathlib.Path(__file__).with_name("cg8_reference.v"),
                  pathlib.Path("../rtl/legacy/x1_cg8.v"), pathlib.Path("rtl/legacy/x1_cg8.v"))
    return next(path for path in candidates if path.exists())


@lru_cache()
def font8_bytes():
    source = font8_path()
    return {int(a, 16): int(b, 2) for a, b in re.findall(
        r"11'h([0-9A-Fa-f]+):cg8_rom = 8'b([01]{8})", source.read_text())}


def fixture(custom=False, mode="full", screen=0, priority=0x10, text=False, reverse=False):
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
        if text:
            # ANK A glyph, independent cell colors including transparent zero.
            p.emit(*( (0x79, 0xE6, 15 if reverse else 7) if base == 0x2000 else (0x3E, 0x41) ))
        else:
            p.emit(0xAF)
        p.emit(0xED, 0x79, 0x03, 0x1B, 0x7A, 0xB3)
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
    if text:
        # Decouple graphics transparency from the ANK mask. The original
        # random-looking planes never exposed text in some graphics-on-top
        # profiles. Real CPU writes clear all source lanes in a 128x8 window,
        # spanning all eight colors and both normal/reverse cell groups.
        for page in range(2):
            out(0x1FD0, page << 4)
            for component, base in enumerate((0x4000, 0x8000, 0xC000)):
                for row in range(8):
                    for offset in (0, 0x400):
                        label = f"transparent_{page}_{component}_{row}_{offset}"
                        p.word(0x01, base + row * 2048 + offset)
                        p.emit(0x16, 16, 0xAF)
                        p.label(label)
                        p.emit(0xED, 0x79, 0x03, 0x15)
                        p.jump(0xC2, label)
    if custom and mode != "internal8":
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
        if mode == "paired64" or text:
            # Nonzero raw G:R:B=A:5:F is deliberately programmed black.
            # A renderer using RGB zero as transparency would expose the back.
            for base in (0x1000, 0x1100, 0x1200):
                out(base | 0xA5, 0xF0)
    if mode == "internal8":
        # Write different external sentinels first, then prove internal writes
        # and retained CPU selection cannot alias that separate palette.
        out(0x1FD0, 0)
        out(0x1FB0, 0x80)
        out(0x1FC5, 0x80)
        for color in range(8):
            for component, base in enumerate((0x1000, 0x1100, 0x1200)):
                port = base | ((color & 4) << 5) | ((color & 2) << 2)
                out(port, ((color & 1) << 7) | ((color ^ component ^ 15) & 15))
        # Separate internal memory: PA8/4/0 = CPU AB7/AB3/DB7.
        # Read every component through the real Z80 bus, not RAM injection.
        out(0x1A02, 0)
        out(0x1FD0, 1)
        out(0x1FB0, 0x80)
        out(0x1FC5, 0x80)
        for color in range(8):
            for component, base in enumerate((0x1000, 0x1100, 0x1200)):
                port = base | ((color & 4) << 5) | ((color & 2) << 2)
                nibble = ((color * (3, 5, 7)[component] + (2, 1, 4)[component]) & 15) if custom else \
                         (15 if color & (1 << component) else 0)
                if custom:
                    out(port, ((color & 1) << 7) | nibble)
        out(0x1FC5, 0x88)
        for color in range(8):
            for component, base in enumerate((0x1000, 0x1100, 0x1200)):
                port = base | ((color & 4) << 5) | ((color & 2) << 2)
                nibble = ((color * (3, 5, 7)[component] + (2, 1, 4)[component]) & 15) if custom else \
                         (15 if color & (1 << component) else 0)
                out(port, (color & 1) << 7)
                p.word(0x01, port)
                p.emit(0xED, 0x78, 0xE6, 15, 0xFE, nibble)
                p.jump(0xC2, "fail")
        out(0x1A02, 0x40)
        out(0x1FD0, 0)
        for color in range(8):
            for component, base in enumerate((0x1000, 0x1100, 0x1200)):
                port = base | ((color & 4) << 5) | ((color & 2) << 2)
                out(port, (color & 1) << 7)
                p.word(0x01, port)
                p.emit(0xED, 0x78, 0xE6, 15, 0xFE, (color ^ component ^ 15) & 15)
                p.jump(0xC2, "fail")
    if text:
        out(0x1FB0, 0x90)
        for color in range(1, 8):
            # All four channel levels; nonzero text color 7 programmed black.
            bits = 0 if color == 7 else ((color & 3) << 4) | (((color + 1) & 3) << 2) | ((color + 2) & 3)
            out(0x1FB8 + color, bits)
    p.store(0xF040, 0xA5)
    p.label("retained")
    columns = 80 if mode in ("wide64", "internal8") else 40
    # Palette programming uses the supported full/40-column sequence first.
    # Reduced CPU access/bank controls are deliberately not inferred here.
    if columns == 80:
        out(0x1A02, 0)
    out(0x1FD0, 1 if mode in ("tall64", "internal8") else screen << 3 if mode in ("dual64", "paired64") else 0)
    out(0x1FB0, 0x90 if mode in ("dual64", "paired64") else 0x80)
    if mode == "paired64" or text:
        out(0x1FC0, priority)
    registers = [55 if columns == 40 else 111, columns,
                 46 if columns == 40 else 92, 0x28, 31, 2, 25, 28, 0, 7,
                 0, 0, 0, 0, 0, 0]
    if mode in ("tall64", "internal8"):
        registers[4:10] = [27, 0, 25, 26, 0, 15]
    for register, value in enumerate(registers):
        out(0x1800, register)
        out(0x1801, value)
    for i, byte in enumerate(b"ZVID"):
        p.store(0xF000 + i, byte)
    p.emit(0x76)
    p.label("fail")
    p.store(0xF000, 0xEE)
    p.emit(0x76)
    code = p.finish()
    assert len(code) < 0x2000
    return code.ljust(0x2000, b"\0") + bytes(
        table_byte(row, k) for row in range(8) for k in range(256))


def glyph_color(x, y, reverse=False):
    cell = (y // 8) * 40 + x // 8
    ink = bool(font8_bytes()[0x41 * 8 + y % 8] & (128 >> (x % 8)))
    # Reverse acts on the masked three-bit source, NOT the palette RGB.
    return ((cell & 7) if ink else 0) ^ (7 if reverse and cell & 8 else 0)


def text_visibility_coverage(mode, screen, priority, reverse=False, windows=True):
    counts = [0] * 8
    masked = 0
    for y in range(200):
        for x in range(320):
            color = glyph_color(x, y, reverse)
            banks = [expected_pixel(x, y, False, "dual64", bank, windows=windows) for bank in (0, 1)] \
                if mode == "paired64" else [expected_pixel(x, y, False, mode, screen, windows=windows)]
            if mode == "paired64":
                front = (priority >> 3) & 1
                layers = ("text", front, 1-front) if priority & 3 == 0 else \
                    (front, 1-front, "text") if priority & 3 == 1 else (front, "text", 1-front)
            else:
                layers = (0, "text") if priority & 1 else ("text", 0)
            for layer in layers:
                if layer == "text" and color:
                    counts[color] += 1
                    break
                if layer != "text" and banks[layer] != bytes(3):
                    masked += bool(color)
                    break
    return {"selected_text_colors": counts, "present_text_masked_by_graphics": masked}


def require_text_visibility(coverage):
    counts = coverage["selected_text_colors"]
    assert len(counts) == 8 and all(value > 0 for value in counts[1:]), coverage


def expected_pixel(x, y, custom=False, mode="full", screen=0, priority=0x10, text=False, reverse=False, windows=False):
    if text and mode in ("full", "dual64"):
        raw = expected_pixel(x, y, False, mode, screen, windows=True)
        color = glyph_color(x, y, reverse)
        for layer in (("graphics", "text") if priority & 1 else ("text", "graphics")):
            if layer == "text" and color:
                return bytes(3) if color == 7 else bytes((((color + 1) & 3) * 85, (color & 3) * 85, ((color + 2) & 3) * 85))
            if layer == "graphics" and raw != bytes(3):
                return bytes(3) if custom and raw == bytes((85, 170, 255)) else expected_pixel(x, y, custom, mode, screen, windows=True)
        return bytes(3) if priority & 1 else expected_pixel(x, y, custom, mode, screen, windows=True)
    if mode == "paired64":
        # Independent per-screen address/color oracle. Presence is raw source
        # code, not final RGB: custom palette black must not reveal the back.
        front = (priority >> 3) & 1
        color = glyph_color(x, y, reverse) if text else 0
        order = ("text", front, 1 - front) if priority & 3 == 0 else \
                (front, 1 - front, "text") if priority & 3 == 1 else (front, "text", 1 - front)
        for bank in order:
            if bank == "text":
                if color:
                    return bytes(3) if color == 7 else bytes((((color + 1) & 3) * 85, (color & 3) * 85, ((color + 2) & 3) * 85))
                continue
            raw = expected_pixel(x, y, False, "dual64", bank, windows=text)
            if raw != bytes(3):
                if custom and raw == bytes((85, 170, 255)):
                    return bytes(3)
                return expected_pixel(x, y, custom, "dual64", bank, windows=text)
        return bytes(3) if priority & 1 else expected_pixel(x, y, custom, "dual64", 1 - front, windows=text)
    columns = 80 if mode in ("wide64", "internal8") else 40
    high = mode in ("tall64", "internal8")
    q = ((y // 2) % 8 if high else y % 8) * 2048 + \
        (y // (16 if high else 8)) * columns + x // 8
    sources = ((0, 0), (0, 0x400), (1, 0), (1, 0x400)) if mode == "full" else \
              ((0, 0), (1, 0)) if mode == "wide64" else \
              ((y & 1, 0), (y & 1, 0x400)) if mode == "tall64" else \
              ((y & 1, 0),) if mode == "internal8" else ((screen, 0), (screen, 0x400))
    components = []
    for component, base in enumerate((0x4000, 0x8000, 0xC000)):
        nibble = 0
        for lane, (page, offset) in enumerate(sources):
            address = (q + offset) & 0x3FFF
            port = base + address
            seed = SEEDS[component] ^ (0x91 if page else 0x2D)
            k = (port >> 8) ^ (port & 255) ^ seed
            value = table_byte((port & 0x3800) >> 11, k)
            # CPU/physical-PA table 4-22: source BD0/QHA0 is CPU DB7,
            # not DB4. All three component nibbles reverse the PA ordering.
            nibble |= (bool(value & (128 >> (x % 8))) *
                       ((1 << (3 - lane)) if mode == "full" else 15 if mode == "internal8" else (10, 5)[lane]))
        if windows and y < 8 and x < 128:
            nibble = 0
        components.append(nibble)
    blue, red, green = components
    if custom and mode == "internal8":
        color = (bool(green) << 2) | (bool(red) << 1) | bool(blue)
        blue, red, green = (color * 3 + 2) & 15, (color * 5 + 1) & 15, (color * 7 + 4) & 15
    elif custom:
        blue, red, green = green ^ red ^ blue ^ 3, green ^ blue ^ 9, red ^ blue ^ 5
    return bytes((red * 17, green * 17, blue * 17))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=pathlib.Path)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    parser.add_argument("--warm", action="store_true")
    parser.add_argument("--custom", action="store_true")
    parser.add_argument("--mode", choices=("full", "dual64", "paired64", "wide64", "tall64", "internal8"), default="full")
    parser.add_argument("--priority", type=lambda value: int(value, 0), default=0x10)
    parser.add_argument("--text", action="store_true")
    parser.add_argument("--reverse", action="store_true", help="alternate native reverse attributes between cell groups")
    parser.add_argument("--screen", type=int, choices=(0, 1), default=0)
    parser.add_argument("--timeout", type=float, default=900)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    executable = args.executable.resolve()
    digest = hashlib.sha256(executable.read_bytes()).hexdigest()
    font_digest = hashlib.sha256(font8_path().read_bytes()).hexdigest() if args.text else None
    code = args.output / "original.bin"
    assert args.mode != "paired64" or args.priority in (0x10, 0x11, 0x12, 0x18, 0x19, 0x1A)
    assert not args.text or args.mode in ("full", "dual64", "paired64")
    assert not args.reverse or args.text
    assert 0 <= args.priority <= 255
    assert not (args.text and args.mode == "dual64" and args.priority & 0x10), "single-screen fixture requires simultaneous-display disabled"
    code.write_bytes(fixture(args.custom, args.mode, args.screen, args.priority, args.text, args.reverse))
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
                      "oracle_revision": "table-4-22-CPU-PA-v2",
                      "fixture_source_sha256": hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest(),
                      "font8_source_sha256": font_digest,
                      "program_sha256": hashlib.sha256(code.read_bytes()).hexdigest(),
                      "command": command}), flush=True)
    result = subprocess.run(command, capture_output=True, text=True, timeout=args.timeout)
    (args.output / "stdout.txt").write_text(result.stdout)
    (args.output / "stderr.txt").write_text(result.stderr)
    assert result.returncode == 0, result.stderr
    report = json.loads(result.stdout.splitlines()[-1])
    print(json.dumps(report), flush=True)
    assert report["z_video_experiment"] and report["z_palette_cpu_experiment"], report
    if args.mode != "full":
        assert report["z_multimode_experiment"], report
    if args.mode == "paired64" or args.text:
        assert report["z_text_cpu_experiment"], report
    if args.mode == "internal8":
        assert report["z_internal8_experiment"], report
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
        assert addresses.count(0x1A03) == 1 and addresses.count(0x1A02) == (2 if args.mode in ("wide64", "internal8") else 1), addresses
        assert not any(a >= 0x2000 or 0x1000 <= a < 0x1300 for a in addresses), addresses[:60]
        if args.mode == "paired64" or args.text:
            assert addresses.count(0x1FC0) == 1, addresses
            assert not any(0x1FB9 <= a <= 0x1FBF for a in addresses), addresses
    tolerance = 31251
    high = args.mode in ("tall64", "internal8")
    line_edges = 1792 if high else 2688
    for field, edges in (("hs_period_ps", line_edges), ("vs_period_ps", line_edges * (448 if high else 258))):
        assert abs(report[field] - round(edges * 10**12 / 42954540)) <= tolerance, report
    header, dimensions, maximum, actual = frame.read_bytes().split(b"\n", 3)
    width, height = (640 if args.mode in ("wide64", "internal8") else 320), (400 if high else 200)
    assert (header, dimensions, maximum) == (b"P6", f"{width} {height}".encode(), b"255"), report
    expected = b"".join(expected_pixel(x, y, args.custom, args.mode, args.screen, args.priority, args.text, args.reverse) for y in range(height) for x in range(width))
    if args.mode == "paired64":
        coverage = dict(front_only=0, back_only=0, overlap=0, both_zero=0, black_front_over_back=0)
        for y in range(height):
            for x in range(width):
                front = expected_pixel(x, y, False, "dual64", (args.priority >> 3) & 1)
                back = expected_pixel(x, y, False, "dual64", 1 - ((args.priority >> 3) & 1))
                coverage[("overlap" if back != bytes(3) else "front_only") if front != bytes(3)
                         else ("back_only" if back != bytes(3) else "both_zero")] += 1
                coverage["black_front_over_back"] += front == bytes((85, 170, 255)) and back != bytes(3)
        assert all(coverage.values()), coverage
        print(json.dumps({"paired_raw_code_coverage": coverage}), flush=True)
    if args.text:
        visibility = text_visibility_coverage(args.mode, args.screen, args.priority, args.reverse)
        require_text_visibility(visibility)
        print(json.dumps({"text_visibility_coverage": visibility}), flush=True)
        colored = sum(bool(expected_pixel(x, y, False, args.mode, args.screen, 0x10, True, args.reverse) != bytes(3))
                      for y in range(height) for x in range(width))
        assert colored > 1000, colored
    (args.output / "expected.ppm").write_bytes(f"P6\n{width} {height}\n255\n".encode() + expected)
    mismatches = [(i // 3 % width, i // (width * 3), tuple(actual[i:i+3]), tuple(expected[i:i+3]))
                  for i in range(0, len(expected), 3) if actual[i:i+3] != expected[i:i+3]]
    assert actual == expected, (len(mismatches), mismatches[:20])
    if args.text:
        alternative = ((args.priority & ~3) | (0 if args.priority & 3 else 2)) if args.mode == "paired64" else args.priority ^ 1
        wrong_order = b"".join(expected_pixel(x, y, args.custom, args.mode, args.screen, alternative, True, args.reverse)
                              for y in range(height) for x in range(width))
        different = sum(actual[i:i+3] != wrong_order[i:i+3] for i in range(0, len(actual), 3))
        assert different > 100, (args.priority, alternative, different)
        print(json.dumps({"wrong_text_order_rejected_pixels": different}), flush=True)
    if args.reverse:
        without_reverse = b"".join(expected_pixel(x, y, args.custom, args.mode, args.screen, args.priority, True)
                                   for y in range(height) for x in range(width))
        different = sum(actual[i:i+3] != without_reverse[i:i+3] for i in range(0, len(actual), 3))
        assert different > 100, different
        print(json.dumps({"missing_reverse_rejected_pixels": different}), flush=True)
    assert hashlib.sha256(executable.read_bytes()).hexdigest() == digest, "runner changed during test"
    if args.text:
        assert hashlib.sha256(font8_path().read_bytes()).hexdigest() == font_digest, "font source changed during test"
    print(f"PASS: {width*height} CPU-written {args.mode} pixels; screen={args.screen}; retained reset={args.warm}")


if __name__ == "__main__":
    main()
