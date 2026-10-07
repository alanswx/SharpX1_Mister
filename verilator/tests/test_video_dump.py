"""Original CPU graphics writes; raw observation must not change execution."""
import json
import csv
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
    expected_pcg = [bytearray(2048) for _ in range(3)]
    if turbo:
        # Native high-speed selector cells, followed by real bus transactions.
        for cell in (0x7FF, 0x3FF, 0x5FF, 0x1FF):
            out(0x3000 + cell, 0x42)
            out(0x2000 + cell, 0x20)
            out(0x3800 + cell, 0)
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
        # Counter channel 0 has a fixed trigger: configure positive state
        # without generating IRQs or relying on a sampled timer phase.
        out(0x1FA0, 0xD7)
        out(0x1FA0, 6)
    for port, value in ((0x1000, 0xC4), (0x1100, 0xB2), (0x1200, 0xA1), (0x1300, 0x3C)):
        out(port, value)
    crtc_registers = {0: 15, 1: 4, 2: 10, 3: 0x22, 4: 3, 5: 0,
                      6: 2, 7: 2, 8: 0, 9: 7, 12: 0, 13: 0}
    for index, value in crtc_registers.items():
        out(0x1800, index)
        out(0x1801, value)
    if turbo:
        # High-speed PCG waits for a CRTC window; configure CRTC first.
        out(0x1FD0, 0x20)
        for plane, start in enumerate((0x1500, 0x1600, 0x1700)):
            for nibble in range(16):
                value = 0x34 + plane * 0x20 + nibble
                out(start + nibble, value)
                expected_pcg[plane][0x42 * 8 + nibble // 2] = value
        out(0x1FD0, 0x18)
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
        for name, data in zip(("b", "r", "g"), expected_pcg):
            assert (root / ("observed.pcg-" + name)).read_bytes() == data, name
        controls = root / "observed.video-controls"
        palette = dict(line.split("=") for line in (root / "observed.video-palette").read_text().splitlines())
        assert {key: int(value) for key, value in palette.items()} == {
            "PAL_B": 0xC4, "PAL_R": 0xB2, "PAL_G": 0xA1, "PRIORITY": 0x3C}, palette
        observed_crtc = dict(line.split("=") for line in (root / "observed.crtc").read_text().splitlines())
        assert {int(key[1:]): int(value) for key, value in observed_crtc.items()} == crtc_registers, observed_crtc
        samples = {key: int(value) for key, value in (line.split("=") for line in
                   (root / "observed.video-samples").read_text().splitlines())}
        assert samples["PIXEL_SAMPLES"] >= samples["VISIBLE_SAMPLES"] > samples["VISIBLE_NONZERO_RGB"] > 0, samples
        assert samples["LAYER_SAMPLES"] > 0 and samples["GRAPHICS_SELECTED_FROM_INPUTS"] == samples["LAYER_SAMPLES"], samples
        assert sum(samples[f"GRAPHICS_COLOR_{color}"] for color in range(8)) == samples["LAYER_SAMPLES"], samples
        assert samples["TEXT_COLOR_0"] == samples["LAYER_SAMPLES"], samples
        assert sum(samples[f"TEXT_COLOR_{color}"] for color in range(8)) == samples["LAYER_SAMPLES"], samples
        if turbo:
            values = dict(line.split("=") for line in controls.read_text().splitlines())
            assert {key: int(value) for key, value in values.items()} == {
                "SCRN": 0x18, "SCRN_VIDEO": 0x18, "BLACK": 0x7F,
                "BLACK_VIDEO": 0x7F, "WIDTH_VIDEO": 0}, values
            ctc = {key: int(value) for key, value in (line.split("=") for line in
                   (root / "observed.ctc").read_text().splitlines())}
            expected_ctc = {"RUNNING": 1, "PENDING": 0, "IN_SERVICE": 0}
            for channel in range(4):
                expected_ctc.update({f"CONTROL_{channel}": 0xD1 if channel == 0 else 2,
                    f"CONSTANT_{channel}": 6 if channel == 0 else 256,
                    f"DOWN_{channel}": 6 if channel == 0 else 256, f"PRESCALER_{channel}": 0})
            assert ctc == expected_ctc, ctc
        else:
            assert not controls.exists()
            assert not (root / "observed.ctc").exists()
        assert "IFF1=0 IFF2=0 IM=0 I=0" in (root / "observed.cpu").read_text()
        with (root / "observed.cpu-fetches").open() as stream:
            fetches = {int(row["address"]): int(row["fetches"]) for row in csv.DictReader(stream)}
        # DI; LD BC,1A03; LD A,82; ED/79 are opcode fetches, not their
        # immediate operands or RAM dump reads. Count the prefix separately.
        assert all(fetches.get(address) == 1 for address in (0, 1, 4, 6, 7)), fetches
        assert all(address not in fetches for address in (2, 3, 5, 0xF000)), fetches
    print(f"PASS read-only graphics observation: turbo={turbo}, all GRAM/PCG bytes, CRTC/controls, active populations and unchanged reports/dumps")


if __name__ == "__main__":
    main()
