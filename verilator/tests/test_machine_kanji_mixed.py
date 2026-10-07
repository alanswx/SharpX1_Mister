# SPDX-License-Identifier: GPL-2.0-only
"""Original CPU-only writes; actual mixed ANK/PCG/Kanji RGB and mode exits."""
import argparse
import json
import pathlib
import re
import subprocess
import tempfile
from z80_fixture import Program
from test_machine_kanji_render import pattern


def pcg_byte(character, row, plane):
    return ((0x96 << plane) ^ (row * 41) ^ (character * 17)) & 255


def font16_byte(address):
    return ((address * 11) ^ (address >> 4) ^ 0xA6) & 255


def geometry(high, expanded, underline):
    rows = (12 if high else 10) if expanded else 20 if underline else 25
    height = ((16 if high else 8) + ((4 if high else 2) if underline else 0)) * (2 if expanded else 1)
    return rows, height


def fixture(high, columns, exit_kanji=False, expanded=False, underline=False):
    p = Program()
    p.emit(0xF3)
    p.word(0x31, 0xFFFF)

    def out(port, value):
        p.word(0x01, port)
        p.emit(0x3E, value, 0xED, 0x79)

    def crtc(registers):
        for index, value in enumerate(registers):
            out(0x1800, index)
            out(0x1801, value)

    out(0x1A03, 0x82)
    p.word(0x01, 0x1A02)
    p.emit(0xED, 0x78)
    out(0x1A02, 0x40 if columns == 40 else 0)
    p.emit(0xED, 0x78)
    # Real recurrent HSYNC is required by the native high-speed PCG WAIT.
    crtc((15, 1, 2, 0x12, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0))
    out(0x1FD0, 0x20)
    for cell in (0x7FF, 0x3FF, 0x5FF, 0x1FF):
        out(0x2000 + cell, 0x27)
        out(0x3000 + cell, 0xA0)
        out(0x3800 + cell, 0x80)
    for plane in (1, 2, 3):
        for row in range(16):
            port = 0x1400 + plane * 256 + row
            value = pcg_byte(0xA0 + row // 8, row % 8, plane)
            out(port, value)
            # Verify each CPU-owned byte through the actual WAIT/read path.
            p.emit(0xED, 0x78, 0xFE, value)
            p.jump(0xC2, "fail")
    for port in (0x2000, 0x3000, 0x3800):
        tag = str(port)
        p.word(0x01, port)
        p.word(0x21, 2048)
        p.label("fill" + tag)
        if port == 0x2000:
            p.emit(0x79, 0x0F, 0x0F, 0xE6, 15, 0x57,
                   0x79, 0xE6, 3, 0xFE, 1)
            p.jump(0xC2, "plain" + tag)
            p.emit(0x7A, 0xF6, 0x20)
            p.jump(0xC3, "write" + tag)
            p.label("plain" + tag)
            p.emit(0x7A)
        elif port == 0x3000:
            p.emit(0x79, 0xE6, 3, 0xFE, 1)
            p.jump(0xC2, "plain" + tag)
            p.emit(0x3E, 0xA0)
            p.jump(0xC3, "write" + tag)
            p.label("plain" + tag)
            p.emit(0x79)
        else:
            p.emit(0x79, 0xE6, 3)
            p.jump(0xCA, "ank" + tag)
            p.emit(0x79, 0xE6, 0x40, 0xF6, 0x80, 0x57,
                   0x79, 0x0F, 0x0F, 0xE6, 15, 0xB2, 0x57,
                   0x79, 0xE6, 3, 0xFE, 3)
            p.jump(0xC2, "plain" + tag)
            p.emit(0x7A, 0xF6, 0x10)
            p.jump(0xC3, "write" + tag)
            p.label("plain" + tag)
            p.emit(0x7A)
            p.jump(0xC3, "write" + tag)
            p.label("ank" + tag)
            p.emit(0xAF)
        p.label("write" + tag)
        if port == 0x3800 and underline:
            # Apply cell underline AFTER all type branches, including level 2.
            p.emit(0x57, 0x79, 0xE6, 0x10, 0x07, 0xB2)
        p.emit(0xED, 0x79, 0x03, 0x2B, 0x7C, 0xB5)
        p.jump(0xC2, "fill" + tag)
    if underline:
        # Palette 0=red background/gap, palette 1=green underline.
        out(0x1000, 0)
        out(0x1100, 0x81)
        out(0x1200, 0x82)
    out(0x1FD0, int(high) | (4 if expanded else 0) | (128 if underline else 0))
    rows, cell_height = geometry(high, expanded, underline)
    crtc((55 if columns == 40 else 111, columns, 46 if columns == 40 else 92,
          0x28, rows + 2, 0, rows, rows + 1, 0, cell_height - 1, 0, 0, 0, 0, 0, 0))
    if exit_kanji:
        p.word(0x11, 15000)
        p.label("delay")
        p.emit(0x1B, 0x7A, 0xB3)
        p.jump(0xC2, "delay")
        p.word(0x01, 0x3800)
        p.word(0x21, 2048)
        p.label("exit")
        p.emit(0xAF, 0xED, 0x79, 0x03, 0x2B, 0x7C, 0xB5)
        p.jump(0xC2, "exit")
    for index, value in enumerate(b"KMIX"):
        p.store(0xF000 + index, value)
    p.emit(0x76)
    p.label("fail")
    p.store(0xF000, 0xEE)
    p.emit(0x76)
    return p.finish()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("executable", type=pathlib.Path)
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument("--first-only", action="store_true", help="diagnostic only, not full acceptance")
    parser.add_argument("--policy-only", action="store_true", help="only the four expansion/underline cases, not full acceptance")
    args = parser.parse_args()
    source = pathlib.Path("../rtl/legacy/x1_cg8.v").read_text()
    font8 = {int(a, 16): int(b, 2) for a, b in re.findall(r"11'h([0-9A-Fa-f]+):cg8_rom = 8'b([01]{8})", source)}
    with tempfile.TemporaryDirectory(prefix="x1-kanji-mixed-") as directory:
        root = args.output if args.output else pathlib.Path(directory)
        if args.output:
            root.mkdir(parents=True, exist_ok=False)
        font, ank16 = root / "original.physical", root / "original.ank16"
        font.write_bytes(bytes(pattern(address) for address in range(131072)))
        ank16.write_bytes(bytes(font16_byte(address) for address in range(4096)))
        cases = [(high, columns, warm, False, False, False) for high in (False, True)
                 for columns in (40, 80) for warm in (False, True)]
        cases += [(high, 80, False, True, False, False) for high in (False, True)]
        policies = [(False, 40, False, False, True, True),
                    (False, 80, False, False, False, True),
                    (True, 40, False, False, False, True),
                    (True, 80, False, False, True, False)]
        cases += policies
        selected = cases[:1] if args.first_only else policies if args.policy_only else cases
        for high, columns, warm, exiting, expanded, underline in selected:
            name = f"{'high' if high else 'standard'}-{columns}-{'warm' if warm else 'cold'}-{'exit' if exiting else 'mixed'}"
            if expanded: name += "-expanded"
            if underline: name += "-underline"
            rom, frame = root / f"{name}.rom", root / f"{name}.ppm"
            rom.write_bytes(fixture(high, columns, exiting, expanded, underline))
            command = [str(args.executable.resolve()), "--rom", str(rom), "--kanji-physical", str(font),
                       "--font16", str(ank16), "--cycles", "16000000", "--frame", str(frame)]
            if warm:
                command += ["--reset-at", "200", "--reset-for-us", "10"]
            result = subprocess.run(command, capture_output=True, text=True, timeout=240)
            (root / f"{name}.stdout.log").write_text(result.stdout)
            (root / f"{name}.stderr.log").write_text(result.stderr)
            assert result.returncode == 0, result.stderr
            report = json.loads(result.stdout.splitlines()[-1])
            assert report["halted"] and report["peek"].startswith(b"KMIX".hex()), report
            assert report["frames"] >= 3, report
            expected_hs = 112 * (16 if high else 24) * 1e12 / 42954540
            assert (report["sys_hz"], report["video_hz"]) == (32000000, 42954540), report
            assert abs(report["hs_period_ps"] - expected_hs) <= 62500, report
            rows, cell_height = geometry(high, expanded, underline)
            assert abs(report["vs_period_ps"] - expected_hs * (rows + 3) * cell_height) <= 62500, report
            header, dimensions, maximum, pixels = frame.read_bytes().split(b"\n", 3)
            width, height = map(int, dimensions.split())
            assert (header, maximum, width, height) == (b"P6", b"255", columns * 8, rows * cell_height), report
            errors = []
            for y in range(height):
                row = (y % cell_height) // (2 if expanded else 1)
                for x in range(width):
                    cell = (y // cell_height) * columns + x // 8
                    kind = cell % 4
                    mask, reverse = (cell // 4) % 8, bool(cell & 32)
                    if kind == 1:
                        character = 0xA0 + (row // 8 if high and not exiting else 0)
                        pcg_row = row // 2 if high and exiting else row % 8
                        color = sum(bit if pcg_byte(character, pcg_row, plane) & (128 >> (x % 8)) and mask & bit else 0
                                    for plane, bit in ((1, 1), (2, 2), (3, 4)))
                    else:
                        if kind == 0 or exiting:
                            bits = font16_byte((cell % 256) * 16 + row) if high else font8[(cell % 256) * 8 + row]
                        elif kind == 2:
                            address = ((cell // 64) % 2) * 65536 + ((cell // 4) % 16) * 4096 + (cell % 256) * 16 + (row if high else row * 2)
                            bits = pattern(address)
                        else:
                            bits = 0
                        color = mask if bits & (128 >> (x % 8)) else 0
                    color ^= 7 if reverse else 0
                    if underline and row >= (16 if high else 8):
                        color = 4 if cell & 16 and row < (18 if high else 9) else 2
                    elif underline and color == 0:
                        color = 2
                    expected = bytes(255 if color & bit else 0 for bit in (2, 4, 1))
                    offset = (y * width + x) * 3
                    if pixels[offset:offset + 3] != expected and len(errors) < 16:
                        errors.append((x, y, kind, expected.hex(), pixels[offset:offset + 3].hex()))
            assert not errors, (name, errors, report)
            print(f"PASS actual mixed RGB: {name} {width}x{height}, 48 CPU PCG writes/readbacks, ANK/PCG/Kanji/level2, all colors/reverse", flush=True)


if __name__ == "__main__":
    main()
