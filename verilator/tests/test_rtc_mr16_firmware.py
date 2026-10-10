"""Freeze and execute source-linked inherited firmware, not machine acceptance."""
import hashlib
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from build_mr16_rtc_firmware import build
from assemble_mr16 import assemble


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    arguments = sys.argv[1:]
    control = bool(arguments and arguments[0] == "--control")
    if control:
        arguments = arguments[1:]
    runners = [pathlib.Path(arg).resolve() for arg in arguments]
    assert len(runners) == 2, "expected CE=1/32 runners"
    directory = pathlib.Path(tempfile.mkdtemp(prefix="qualified-", dir=runners[0].parent))
    inputs = [pathlib.Path(__file__).resolve(), ROOT / "scripts/build_mr16_rtc_firmware.py",
              ROOT / "scripts/assemble_mr16.py", ROOT / "verilator/Makefile",
              ROOT / "verilator/tests/rtc_mr16_firmware_tb.sv",
              ROOT / "verilator/tests/fixtures/rtc_mr16_host_extension.asm",
              ROOT / "verilator/tests/fixtures/rtc_mr16_compact.asm"]
    inputs += sorted((ROOT / "bios/reference/fw_subcpu").glob("*.asm"))
    inputs += sorted((ROOT / "bios/reference/fw_subcpu").glob("*.inc"))
    inputs += [ROOT / "bios/reference/fw_subcpu/verilog/X1SUB.BIN"]
    inputs += [ROOT / "rtl" / name for name in ("mr16core.v", "mr16_x1.v",
               "x1_rtc_clock_enable.sv", "x1_cz880_rtc.sv", "x1_upd1990_counter.sv",
               "x1_upd1990_calendar.sv", "x1_mr16_rom_decode.sv")]
    inputs += runners
    hashes = {str(path): digest(path) for path in inputs}
    # These ignored frozen derivatives carry inherited notices and are not
    # distributable merely because the original extension is GPL licensed.
    for index, path in enumerate(inputs):
        shutil.copy2(path, directory / f"input-{index}-{path.name}")
    if control:
        image, symbols, _ = assemble(ROOT / "bios/reference/fw_subcpu/x1sub.asm", {"ps2_receive_only": 1})
        image += bytes(4096)
    else:
        image, symbols = build(receive_only=True)
    rom = directory / "firmware.mem"
    with rom.open("x") as output:
        output.writelines(f"{int.from_bytes(image[i:i+2], 'little'):04x}\n" for i in range(0, len(image), 2))
    manifest = {"inputs": hashes, "rom_sha256": hashlib.sha256(image).hexdigest(),
                "mem_sha256": digest(rom), "extension_end": symbols.get("rtc_extension_end"),
                "original_firmware_control": control,
                "scope": "inherited firmware callbacks in replacement memory/mailbox fixture; no shared machine/FDC/DMA/IRQ/native acceptance"}
    (directory / "manifest-before.json").write_text(json.dumps(manifest, indent=2)+"\n")
    for index, runner in enumerate(runners):
        frozen = directory / f"runner-{index}"
        shutil.copy2(runner, frozen)
        result = subprocess.run([str(frozen), f"+ROM={rom}", *(["+BASELINE_CONTROL"] if control else [])], capture_output=True, text=True, cwd=directory)
        (directory / f"ce-{(1,32)[index]}.log").write_text(result.stdout+result.stderr)
        marker = "PASS: original inherited firmware E7/E8 control" if control else "PASS: linked inherited firmware real EC/ED/EE/EF"
        assert result.returncode == 0 and marker in result.stdout, (directory, result.stdout, result.stderr)
        assert digest(frozen) == hashes[str(runner)], "frozen runner changed"
        print(f"PASS: actual source-linked firmware CE={(1,32)[index]}", flush=True)
    assert hashes == {str(path): digest(path) for path in inputs}, "qualification inputs changed"
    for index, path in enumerate(inputs):
        assert digest(directory / f"input-{index}-{path.name}") == hashes[str(path)]
    assert digest(rom) == manifest["mem_sha256"]
    (directory / "manifest-after.json").write_text(json.dumps(manifest, indent=2)+"\n")
    print(f"PASS: immutable source/runner/ROM qualification {directory}")


if __name__ == "__main__":
    main()
