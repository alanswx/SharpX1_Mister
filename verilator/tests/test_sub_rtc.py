"""Frozen actual x1_sub qualification via public upload and host pins."""
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


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    runners = [pathlib.Path(arg).resolve() for arg in sys.argv[1:]]
    assert len(runners) == 3, "expected SYS 32M, nominal single, actual board single"
    folder = pathlib.Path(tempfile.mkdtemp(prefix="qualified-", dir=runners[0].parent))
    inputs = [pathlib.Path(__file__).resolve(), ROOT / "scripts/build_mr16_rtc_firmware.py",
              ROOT / "scripts/assemble_mr16.py", ROOT / "verilator/Makefile", ROOT / "rtl/machine.qip",
              ROOT / "verilator/tests/sub_rtc_tb.sv",
              ROOT / "verilator/tests/fixtures/rtc_mr16_host_extension.asm",
              ROOT / "verilator/tests/fixtures/rtc_mr16_compact.asm"]
    inputs += sorted((ROOT / "bios/reference/fw_subcpu").glob("*.asm"))
    inputs += sorted((ROOT / "bios/reference/fw_subcpu").glob("*.inc"))
    inputs += [ROOT / "bios/reference/fw_subcpu/verilog/X1SUB.BIN"]
    inputs += [ROOT / "rtl" / name for name in ("sub_cpu.v", "sub_rom.v", "dpram.sv",
               "mr16core.v", "mr16_x1.v", "x1_mr16_rom_decode.sv", "x1_rtc_clock_enable.sv",
               "x1_cz880_rtc.sv", "x1_upd1990_counter.sv", "x1_upd1990_calendar.sv")]
    inputs += runners
    hashes = {str(path): digest(path) for path in inputs}
    for i, path in enumerate(inputs):
        shutil.copy2(path, folder / f"input-{i}-{path.name}")
    image, symbols = build(receive_only=True)
    rom = folder / "firmware.mem"
    with rom.open("x") as output:
        output.writelines(f"{int.from_bytes(image[i:i+2], 'little'):04x}\n" for i in range(0,len(image),2))
    manifest = {"inputs": hashes, "rom_mem_sha256": digest(rom),
                "rom_image_sha256": hashlib.sha256(image).hexdigest(),
                "extension_end": symbols["rtc_extension_end"],
                "scope": "actual x1_sub public pins, timer IRQs and retained reset; no shared Z80/native/hardware acceptance"}
    (folder / "manifest-before.json").write_text(json.dumps(manifest, indent=2)+"\n")
    for i, runner in enumerate(runners):
        copied = folder / f"runner-{i}"
        shutil.copy2(runner,copied)
        for negative in (False,True):
            label = f"{(32000000,28636364,28571428)[i]}-{'wrong-power' if negative else 'retained'}"
            result = subprocess.run([str(copied),f"+ROM={rom}", *(["+NEGATIVE_POWER"] if negative else [])],
                                    cwd=folder,capture_output=True,text=True)
            (folder / f"{label}.log").write_text(result.stdout+result.stderr)
            if negative:
                assert result.returncode != 0 and "sub RTC retained ticking mismatch" in result.stdout+result.stderr, (folder,label,result.stdout,result.stderr)
            else:
                assert result.returncode == 0 and "PASS: actual x1_sub RTC" in result.stdout,(folder,label,result.stdout,result.stderr)
            print(f"PASS: {label} {'rejected by retained-time oracle' if negative else 'public host pins and real timer execute'}",flush=True)
        assert digest(copied)==hashes[str(runner)], "frozen runner changed"
    assert hashes == {str(path):digest(path) for path in inputs}, "inputs changed during qualification"
    for i,path in enumerate(inputs):
        assert digest(folder / f"input-{i}-{path.name}")==hashes[str(path)]
    assert digest(rom)==manifest['rom_mem_sha256']
    (folder / "manifest-after.json").write_text(json.dumps(manifest,indent=2)+"\n")
    print(f"PASS: immutable actual sub-controller RTC evidence {folder}")


if __name__ == "__main__":
    main()
