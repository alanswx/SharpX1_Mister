"""CPU-programmed base-X1 rasters, checked against independent pixel formulas."""
import argparse
import hashlib
import json
import pathlib
import re
import subprocess
import tempfile
from z80_fixture import Program

parser = argparse.ArgumentParser()
parser.add_argument("executable", type=pathlib.Path)
parser.add_argument("--output", type=pathlib.Path)
parser.add_argument("--columns", type=int, choices=(40, 80))
parser.add_argument("--kind", choices=("graphics", "text", "mixed", "pattern", "stretch", "pcg", "blink-off", "blink-on"))
parser.add_argument("--timeout", type=float, default=180,
                    help="per-case wall-clock timeout; raise on a busy host")
parser.add_argument("--transition", action="store_true",
                    help="run the opposite width for two frames before switching")
args = parser.parse_args()
exe = str(args.executable.resolve())


def program(columns, kind):
    p = Program(0x8000)
    p.emit(0xF3)
    p.word(0x31, 0xFFFF)
    def out(port, value):
        p.word(0x01, port)
        p.emit(0x3E, value, 0xED, 0x79)
    def fill(start, count, value):
        label = f"fill{len(p.code)}"
        p.word(0x01, start)
        p.word(0x11, count)
        p.label(label)
        p.emit(0x3E, value, 0xED, 0x79, 0x03, 0x1B, 0x7A, 0xB3)
        p.jump(0xC2, label)
    def patterned(start, attributes=False):
        label = f"pattern{len(p.code)}"
        p.word(0x01, start)
        p.word(0x11, 2048)
        p.label(label)
        p.emit(0x79)  # LD A,C
        if attributes: p.emit(0xE6, 15)  # Color/reverse, without blink or PCG.
        else: p.emit(0xA8)  # XOR B: character changes at every address/page.
        p.emit(0xED, 0x79, 0x03, 0x1B, 0x7A, 0xB3)
        p.jump(0xC2, label)
    out(0x1A03, 0x82)
    p.word(0x01, 0x1A02)
    p.emit(0xED, 0x78)  # Mode write lowers C5 and activates DAM.
    out(0x1A02, 0x40 if columns == 40 else 0)
    p.word(0x01, 0x1A02)
    p.emit(0xED, 0x78)  # Clear reset/control-write DAM transitions.
    if kind == "pattern":
        patterned(0x2000, attributes=True)
        patterned(0x3000)
    else:
        fill(0x2000, 2048, 0x17 if kind.startswith("blink-") else 0x27 if kind == "pcg" else 0xC7 if kind == "stretch" else 7 if kind == "text" else 15 if kind == "mixed" else 0)
        fill(0x3000, 2048, ord("A"))
    if kind in ("graphics", "mixed"):
        for plane, base in enumerate((0x4000, 0x8000, 0xC000)):
            for row in range(8):
                value = (0xAA, 0xCC, 0xF0)[plane]
                if row & (1 << plane): value ^= 255
                fill(base + row * 2048, 2048, value)
    # Text/PCG raster cases mask every graphics color to black through real
    # palette writes, so they do not depend on uninitialized GRAM contents.
    # GRAM banking/plane storage is exercised by graphics/mixed and bus tests.
    palette = (0x3C, 0xC3, 0x96) if kind == "mixed" else (0xAA, 0xCC, 0xF0) if kind == "graphics" else (0, 0, 0)
    for port, value in ((0x1000, palette[0]), (0x1100, palette[1]), (0x1200, palette[2]),
                        (0x1300, 255 if kind == "graphics" else 0xA5 if kind == "mixed" else 0)):
        out(port, value)
    registers = [55 if columns == 40 else 111, columns,
                 46 if columns == 40 else 92, 0x28, 31, 2, 25, 28, 0, 7,
                 0, 0, 0, 0, 0, 0]
    if kind == "pattern": registers[12:14] = [7, 0xD5]  # Wrap across 2 KiB VRAM.
    if args.transition:
        opposite = 80 if columns == 40 else 40
        out(0x1A02, 0x40 if opposite == 40 else 0)
        old_registers = registers.copy()
        old_registers[:3] = [55 if opposite == 40 else 111, opposite,
                             46 if opposite == 40 else 92]
        for register, value in enumerate(old_registers):
            out(0x1800, register)
            out(0x1801, value)
        p.word(0x11, 10000)
        p.label("mode_delay")
        p.emit(0x1B, 0x7A, 0xB3)
        p.jump(0xC2, "mode_delay")  # About 60 ms at 4 MHz (> three frames).
        out(0x1A02, 0x40 if columns == 40 else 0)
    for register, value in enumerate(registers):
        out(0x1800, register)
        out(0x1801, value)
    if kind == "pcg":
        # Repeated real beam-addressed writes while every text cell selects A.
        # Multiple complete frames visit all eight glyph rows on every plane;
        # this checks raster selection/color, not exact scanline trap timing.
        p.word(0x11, 4000)
        p.label("pcg_fill")
        for port, value in ((0x1500, 0xAA), (0x1600, 0xCC), (0x1700, 0xF0)):
            out(port, value)
        p.emit(0x1B, 0x7A, 0xB3)
        p.jump(0xC2, "pcg_fill")
    for index, byte in enumerate(b"VID!"): p.store(0xF000 + index, byte)
    p.emit(0x76)
    return p.finish()


font_source = pathlib.Path("../rtl/legacy/x1_cg8.v").read_text()
font = {int(address, 16): int(bits, 2) for address, bits in
        re.findall(r"11'h([0-9A-Fa-f]+):cg8_rom = 8'b([01]{8})", font_source)}


def run(folder, columns, kind):
    name = f"{kind}-{columns}" + ("-transition" if args.transition else "")
    code, frame = folder / (name + ".bin"), folder / (name + ".ppm")
    code.write_bytes(program(columns, kind))
    # The inherited MR16 firmware clears CLK_1HZ at boot and toggles it every
    # 500 ms. Capture away from an edge, testing real firmware-driven reversal
    # rather than forcing the renderer's blink input.
    duration_ms = 700 if kind == "blink-on" else 1000 if kind in ("graphics", "mixed") else 300 if kind == "pcg" else 200
    cycles = duration_ms * 32000
    result = subprocess.run([exe, "--cycles", str(cycles), "--ram", str(code),
                             "--frame", str(frame)], capture_output=True, text=True, timeout=args.timeout)
    assert result.returncode == 0, (name, result.stderr)
    report = json.loads(result.stdout.splitlines()[-1])
    assert report["halted"] and report["peek"].startswith(b"VID!".hex()), (name, report)
    assert report["frames"] >= 3, (name, "too few completed frames", report)
    # R0+1 = 56/112 characters, 8 dots and /4 or /2 pixel rate: both
    # widths have 1792 video-master edges per line. R4=31, R9=7, R5=2
    # produce 32*8+2 = 258 scanlines per frame. Periods are measured on
    # clk_sys, so allow one system sampling edge, not arbitrary percentage.
    tolerance = (10**12 + report["sys_hz"] - 1) // report["sys_hz"] + 1
    for field, master_edges in (("hs_period_ps", 1792), ("vs_period_ps", 1792 * 258)):
        expected = round(master_edges * 10**12 / report["video_hz"])
        assert abs(report[field] - expected) <= tolerance, (name, field, expected, report[field], tolerance)
    header, dimensions, maximum, pixels = frame.read_bytes().split(b"\n", 3)
    width, height = map(int, dimensions.split())
    assert (header, maximum, width, height) == (b"P6", b"255", columns * 8, 200), (name, report)
    mismatches = []
    for y in range(height):
        for x in range(width):
            color = ((7 - x % 8) ^ (y % 8)) if kind == "graphics" else (
                7 if font[ord("A") * 8 + y % 8] & (128 >> (x % 8)) else 0)
            if kind == "pattern":
                offset = (0x7D5 + (y // 8) * columns + x // 8) & 0x7FF
                address = 0x3000 + offset
                character = (address >> 8) ^ (address & 255)
                attributes = offset & 15
                dot = bool(font[character * 8 + y % 8] & (128 >> (x % 8)))
                color = ((attributes & 7) if dot else 0) ^ (7 if attributes & 8 else 0)
            if kind == "stretch":
                color = 7 if font[ord("A") * 8 + (y // 2) % 8] & (128 >> ((x // 2) % 8)) else 0
            if kind == "pcg": color = 7 - x % 8
            if kind == "blink-on": color ^= 7
            if kind == "mixed":
                raw = (7 - x % 8) ^ (y % 8)
                text = color ^ 7  # Reverse attribute precedes transparency.
                mapped = sum(((entry >> raw) & 1) << plane for plane, entry in enumerate((0x3C, 0xC3, 0x96)))
                color = mapped if not text or (0xA5 >> raw) & 1 else text
            expected = bytes((255 if color & 2 else 0, 255 if color & 4 else 0, 255 if color & 1 else 0))
            offset = (y * width + x) * 3
            if pixels[offset:offset + 3] != expected:
                if len(mismatches) < 12: mismatches.append((x, y, color, pixels[offset:offset + 3].hex()))
    assert not mismatches, (name, "raster mismatch", mismatches, report)
    print(json.dumps({"mode": name, "width": width, "height": height,
                      "frame_hash": report["frame_hash"], "frames": report["frames"],
                      "program_sha256": hashlib.sha256(code.read_bytes()).hexdigest(),
                      "font_source_sha256": hashlib.sha256(font_source.encode()).hexdigest(),
                      "sys_hz": report["sys_hz"], "video_hz": report["video_hz"],
                      "reset_edges": report["reset_edges"], "reference_cycles": cycles,
                      "hs_period_ps": report["hs_period_ps"], "vs_period_ps": report["vs_period_ps"],
                      "intra_assignment_delays": report["intra_assignment_delays"]}), flush=True)


def cases(folder):
    folder.mkdir(parents=True, exist_ok=True)
    for columns in ((args.columns,) if args.columns else (40, 80)):
        for kind in ((args.kind,) if args.kind else ("graphics", "text", "mixed", "pattern", "stretch", "pcg", "blink-off", "blink-on")):
            run(folder, columns, kind)
    print("PASS: CPU-programmed base video modes match independently calculated RGB pixels")

if args.output:
    cases(args.output.resolve())
else:
    with tempfile.TemporaryDirectory(prefix="x1-video-modes-") as temporary:
        cases(pathlib.Path(temporary))
