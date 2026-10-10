"""Freeze and execute compact RTC driver diagnostics; not machine acceptance."""
import hashlib
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from assemble_mr16 import assemble


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    assert len(sys.argv) == 4, "expected retained CE=1, retained CE=32 and unretained CE=32 runners"
    runners = [pathlib.Path(arg).resolve() for arg in sys.argv[1:]]
    folder = pathlib.Path(tempfile.mkdtemp(prefix="qualified-", dir=runners[0].parent))
    inputs = [ROOT / "scripts/assemble_mr16.py", pathlib.Path(__file__).resolve(),
              ROOT / "verilator/tests/fixtures/rtc_mr16_compact.asm",
              ROOT / "verilator/tests/rtc_mr16_compact_tb.sv"]
    inputs += [ROOT / "rtl" / name for name in (
        "mr16core.v", "mr16_x1.v", "x1_rtc_clock_enable.sv", "x1_cz880_rtc.sv",
        "x1_upd1990_counter.sv", "x1_upd1990_calendar.sv")]
    inputs += [ROOT / "verilator/Makefile", *runners]
    before = {str(path): digest(path) for path in inputs}
    for i, path in enumerate(inputs):
        shutil.copy2(path, folder / f"input-{i}-{path.name}")
    frozen_runners = []
    for i, runner in enumerate(runners):
        frozen = folder / f"runner-{i}"
        shutil.copy2(runner, frozen)
        frozen_runners.append(frozen)
    rom = folder / "driver.mem"
    subprocess.run([sys.executable, str(ROOT / "scripts/assemble_mr16.py"), str(inputs[2]),
                    "--output-mem-new", str(rom)], check=True)
    image, symbols, _ = assemble(inputs[2])
    widths = {"mode": symbols["rtc_write40"] - symbols["rtc_mode"],
              "write40": symbols["rtc_read40"] - symbols["rtc_write40"],
              "read40": symbols["driver_end"] - symbols["rtc_read40"]}
    assert widths == {"mode": 14, "write40": 44, "read40": 48}, widths
    assert symbols["code_end"] == 212, "compact fixture ROM budget changed"
    manifest = {"source_hashes": before, "rom_mem_sha256": digest(rom),
                "rom_image_sha256": hashlib.sha256(image).hexdigest(),
                "serial_routine_bytes": widths, "fixture_bytes": symbols["code_end"],
                "scope": "replacement-MR16 counted driver only; no shared-machine/year/IRQ/native MCU acceptance"}
    (folder / "manifest-before.json").write_text(json.dumps(manifest, indent=2) + "\n")
    cases = [("retained-ce1", 0, [], None), ("retained-ce32", 1, [], None),
             ("wrong-t1", 1, ["+NEGATIVE_T1"], "packed readback mismatch"),
             ("cpu-gated-crystal", 1, ["+NEGATIVE_CLOCK"], "stopped-controller mismatch"),
             ("unretained-ce32", 2, [], "program mismatch")]
    for label, index, flags, expected_failure in cases:
        result = subprocess.run([str(frozen_runners[index]), f"+ROM={rom}", *flags],
                                capture_output=True, text=True, cwd=folder)
        (folder / f"{label}.log").write_text(result.stdout + result.stderr)
        if expected_failure is None:
            assert result.returncode == 0 and "PASS: compact assembled real MR16" in result.stdout, (label, result.stdout, result.stderr)
        else:
            assert result.returncode != 0 and "compact MR16 RTC " + expected_failure in result.stdout + result.stderr, (label, result.stdout, result.stderr)
        print(f"PASS: {label} {'executes driver' if expected_failure is None else 'rejected at required phase by unchanged oracle'}", flush=True)
    assert before == {str(path): digest(path) for path in inputs}, "source/runner changed during qualification"
    assert manifest["rom_mem_sha256"] == digest(rom), "assembled diagnostic changed during qualification"
    for i, path in enumerate(inputs):
        assert digest(folder / f"input-{i}-{path.name}") == before[str(path)], "frozen input changed"
    for i, path in enumerate(runners):
        assert digest(frozen_runners[i]) == before[str(path)], "frozen executable changed"
    (folder / "manifest-after.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"PASS: compact serial routines total {sum(widths.values())} bytes; complete fixture 212 bytes; frozen provenance {folder}")


if __name__ == "__main__":
    main()
