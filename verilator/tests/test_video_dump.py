"""Original CPU graphics writes; raw observation must not change execution."""
import json
import pathlib
import subprocess
import sys
import tempfile
from z80_fixture import Program


def main():
    executable = str(pathlib.Path(sys.argv[1]).resolve())
    turbo = len(sys.argv) > 2 and sys.argv[2] == "turbo"
    p = Program()
    p.emit(0xF3)

    def out(port, value):
        p.word(0x01, port)
        p.emit(0x3E, value, 0xED, 0x79)

    out(0x1A03, 0x82)
    p.word(0x01, 0x1A02)
    p.emit(0xED, 0x78)  # Clear the real PPI-induced DAM latch.
    # PPI initialization itself spills 82 into all planes under initial DAM.
    # Clear that cell through real CPU writes, not by patching debug storage.
    for start in (0x4000, 0x8000, 0xC000):
        out(start + 0x1A03, 0)
    expected = [bytearray(32768 if turbo else 16384) for _ in range(3)]
    for bank in range(2 if turbo else 1):
        if turbo:
            out(0x1FD0, bank << 4)
        for plane, start in enumerate((0x4000, 0x8000, 0xC000)):
            for offset in (0, 1, 0x1FFF, 0x3FFE, 0x3FFF):
                value = 0x31 + plane * 7 + bank * 0x40 + (offset & 3)
                out(start + offset, value)
                expected[plane][bank * 16384 + offset] = value
    if turbo:
        out(0x1FD0, 0x18)
        out(0x1FE0, 0x7F)
    for port, value in ((0x1000, 0xC4), (0x1100, 0xB2), (0x1200, 0xA1), (0x1300, 0x3C)):
        out(port, value)
    p.emit(0x76)
    with tempfile.TemporaryDirectory(prefix="x1-video-observe-") as folder:
        root = pathlib.Path(folder)
        rom = root / "original.rom"
        rom.write_bytes(p.finish())
        reports = []
        for observation in (False, True):
            prefix = root / ("observed" if observation else "ordinary")
            command = [executable, "--rom", str(rom), "--cycles", "1000000", "--dump", str(prefix)]
            if observation:
                command += ["--video-dump", str(prefix)]
            result = subprocess.run(command, capture_output=True, text=True, timeout=120)
            assert result.returncode == 0, (command, result.returncode, result.stdout, result.stderr)
            reports.append(json.loads(result.stdout.splitlines()[-1]))
        assert reports[0] == reports[1] and reports[0]["halted"], reports
        for suffix in ("ram", "text", "attr", "subram", "cpu"):
            assert (root / ("ordinary." + suffix)).read_bytes() == (root / ("observed." + suffix)).read_bytes(), suffix
        for name, data in zip(("b", "r", "g"), expected):
            actual = (root / ("observed.gram-" + name)).read_bytes()
            mismatches = [(index, got, want) for index, (got, want) in enumerate(zip(actual, data)) if got != want]
            assert len(actual) == len(data) and not mismatches, (name, len(actual), len(data), mismatches[:30])
        controls = root / "observed.video-controls"
        palette = dict(line.split("=") for line in (root / "observed.video-palette").read_text().splitlines())
        assert {key: int(value) for key, value in palette.items()} == {
            "PAL_B": 0xC4, "PAL_R": 0xB2, "PAL_G": 0xA1, "PRIORITY": 0x3C}, palette
        if turbo:
            values = dict(line.split("=") for line in controls.read_text().splitlines())
            assert {key: int(value) for key, value in values.items()} == {
                "SCRN": 0x18, "SCRN_VIDEO": 0x18, "BLACK": 0x7F,
                "BLACK_VIDEO": 0x7F, "WIDTH_VIDEO": 0}, values
        else:
            assert not controls.exists()
    print(f"PASS read-only graphics observation: turbo={turbo}, all plane bytes/page boundaries and unchanged reports/dumps")


if __name__ == "__main__":
    main()
