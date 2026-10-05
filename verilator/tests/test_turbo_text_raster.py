"""Original CPU/real-RGB Turbo row, expansion and reserved-gap fixture.

Not native BASIC, a Kanji font or an independent ASIC timing reference.
"""
import argparse
import hashlib
import json
import pathlib
import re
import shutil
import subprocess
from z80_fixture import Program

parser = argparse.ArgumentParser()
parser.add_argument("executable", type=pathlib.Path)
parser.add_argument("--output", required=True, type=pathlib.Path)
parser.add_argument("--scan", choices=("low", "high"), required=True)
parser.add_argument("--rows", type=int, choices=(10, 12, 20, 25), required=True)
parser.add_argument("--columns", type=int, choices=(40, 80), default=80)
parser.add_argument("--timeout", type=float, default=1800)
parser.add_argument("--exit-underline", action="store_true",
                    help="enter text-only mode, then restore graphics without clearing GRAM")
args = parser.parse_args()
high = args.scan == "high"
if high and args.rows == 10:
    parser.error("The primary Turbo II contract has no high-scan 10-row mode")
expanded = args.rows in (10, 12)
underline = args.rows in (10, 20)
if args.exit_underline and not underline:
    parser.error("--exit-underline requires a 10/20-row text-only initial mode")
font_height = 16 if high else 8
cell_height = (font_height + (4 if high else 2) * underline) * (2 if expanded else 1)
args.output.mkdir(parents=True, exist_ok=False)
# Keep provenance stable while another profile/build replaces shared Vtop.
runner_hash = hashlib.sha256(args.executable.read_bytes()).hexdigest()
frozen_runner = args.output / "Vtop"
shutil.copy2(args.executable, frozen_runner)
assert hashlib.sha256(frozen_runner.read_bytes()).hexdigest() == runner_hash
p = Program()
def out(port, value):
    p.word(0x01, port)
    p.emit(0x3E, value, 0xED, 0x79)
def fill(start, count, value):
    name = f"fill{len(p.code)}"
    p.word(0x01, start)
    p.word(0x11, count)
    p.label(name)
    p.emit(0x3E, value, 0xED, 0x79, 0x03, 0x1B, 0x7A, 0xB3)
    p.jump(0xC2, name)
def input_c():
    p.word(0x01, 0x1A02)
    p.emit(0xED, 0x78)
p.emit(0xF3)
p.word(0x31, 0xFFFF)
out(0x1A03, 0x82)
input_c()
mode_c = 0x40 if args.columns == 40 else 0
# Trigger DAM with a real C5 falling transition, fill all three GRAM planes
# to FF. Suppressed graphics must not pass merely because GRAM was blank.
out(0x1A02, mode_c | 0x20)
out(0x1A02, mode_c)
fill(0, 16384, 255)
# High-scan mode 01 displays both pages on alternating physical rasters.
# Initialize page 1 through the same real DAM transactions, then restore the
# CPU page. Otherwise odd rasters legitimately display uninitialized GRAM.
if high:
    # DAM redirects OUTs away from ordinary register decode. Leave DAM before
    # changing SCRN, then re-enter it with a real C5 falling edge for page 1.
    input_c()
    out(0x1FD0, 0x10)
    out(0x1A02, mode_c | 0x20)
    out(0x1A02, mode_c)
    fill(0, 16384, 255)
    input_c()
    out(0x1FD0, 0)
input_c()
fill(0x3000, 2048, ord("A"))
# Alternating underlined cells, with reverse in alternate pairs; text writes
# are not testbench memory injection and K7 stays clear (ANK, not Kanji).
p.word(0x01, 0x2000)
p.word(0x11, 2048)
p.label("attrs")
p.emit(0x79, 0xE6, 2, 0x07, 0x07, 0xF6, 7, 0xED, 0x79,
       0x03, 0x1B, 0x7A, 0xB3)
p.jump(0xC2, "attrs")
p.word(0x01, 0x3800)
p.word(0x11, 2048)
p.label("underline")
p.emit(0x79, 0xE6, 1, 0x07, 0x07, 0x07, 0x07, 0x07, 0xED, 0x79,
       0x03, 0x1B, 0x7A, 0xB3)
p.jump(0xC2, "underline")
# Raw GRAM 7 = yellow; palette 0 = red, 1 = green. Underline/background use
# palette slots, not the character's white color. Text has priority.
for port, value in ((0x1000, 0), (0x1100, 0x81), (0x1200, 0x82), (0x1300, 0)):
    out(port, value)
out(0x1FD0, int(high) | (4 if expanded else 0) | (128 if underline else 0))
registers = [55 if args.columns == 40 else 111, args.columns,
             46 if args.columns == 40 else 92, 0x28,
             args.rows + 2, 0, args.rows, args.rows + 1, 0, cell_height - 1,
             0, 0, 0, 0, 0, 0]
for register, value in enumerate(registers):
    out(0x1800, register)
    out(0x1801, value)
if args.exit_underline:
    p.word(0x11, 10000)
    p.label("mode_delay")
    p.emit(0x1B, 0x7A, 0xB3)
    p.jump(0xC2, "mode_delay")
    out(0x1FD0, int(high) | (4 if expanded else 0))
for i, value in enumerate(b"TXRS"):
    p.store(0xF000 + i, value)
p.emit(0x76)
rom = args.output / "original.bin"
rom.write_bytes(p.finish())
frame = args.output / "actual.ppm"
command = [str(frozen_runner.resolve()), "--cycles", "32000000",
           "--rom", str(rom), "--frame", str(frame)]
font16 = bytes((a ^ (a >> 8)) & 255 for a in range(4096))
if high:
    font = args.output / "original.font16"
    font.write_bytes(font16)
    command += ["--font16", str(font)]
result = subprocess.run(command, capture_output=True, text=True, timeout=args.timeout)
(args.output / "stdout.log").write_text(result.stdout)
(args.output / "stderr.log").write_text(result.stderr)
assert result.returncode == 0, (result.returncode, result.stderr)
report = json.loads(result.stdout.splitlines()[-1])
assert report["turbo_foundation"] and report["halted"] and report["peek"].startswith(b"TXRS".hex()), report
assert report["frames"] >= 3, report
header, dimensions, maximum, pixels = frame.read_bytes().split(b"\n", 3)
width, height = map(int, dimensions.split())
assert (header, maximum, width, height) == (b"P6", b"255", args.columns * 8, args.rows * cell_height), report
font_source = pathlib.Path("../rtl/legacy/x1_cg8.v").read_text()
font8 = {int(a, 16): int(b, 2) for a, b in re.findall(r"11'h([0-9A-Fa-f]+):cg8_rom = 8'b([01]{8})", font_source)}
mismatches = []
for y in range(height):
    source_row = (y % cell_height) // (2 if expanded else 1)
    for x in range(width):
        cell = (y // cell_height) * args.columns + x // 8
        if underline and not args.exit_underline and source_row >= font_height:
            color = 4 if cell & 1 and source_row < font_height + (2 if high else 1) else 2
        else:
            glyph_row = source_row % font_height
            bits = font16[ord("A") * 16 + glyph_row] if high else font8[ord("A") * 8 + glyph_row]
            color = (7 if bits & (128 >> (x % 8)) else 0) ^ (7 if cell & 2 else 0)
            if not color:
                color = 2 if underline and not args.exit_underline else 6
        expected = bytes(255 if color & bit else 0 for bit in (2, 4, 1))
        offset = (y * width + x) * 3
        if pixels[offset:offset+3] != expected and len(mismatches) < 16:
            mismatches.append((x, y, color, pixels[offset:offset+3].hex()))
assert not mismatches, (mismatches, report)
line_edges = 1792 if high or not report.get("turbo_video_master") else 2688
tolerance = (10**12 + report["sys_hz"] - 1) // report["sys_hz"] + 1
for field, edges in (("hs_period_ps", line_edges),
                     ("vs_period_ps", line_edges * (args.rows + 3) * cell_height)):
    expected = round(edges * 10**12 / report["video_hz"])
    assert abs(report[field] - expected) <= tolerance, (field, expected, report[field])
evidence = {"report": report, "command": command, "scan": args.scan,
            "rows": args.rows, "columns": args.columns, "cell_height": cell_height,
            "expanded": expanded, "underline": underline,
            "exit_underline": args.exit_underline,
            "runner_sha256": runner_hash,
            "rom_sha256": hashlib.sha256(rom.read_bytes()).hexdigest()}
(args.output / "evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")
assert hashlib.sha256(frozen_runner.read_bytes()).hexdigest() == runner_hash
print(json.dumps(evidence), flush=True)
print("PASS: CPU-programmed text expansion, reserved gap/color, reverse and graphics suppression; no ASIC/native acceptance")
