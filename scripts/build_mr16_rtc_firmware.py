#!/usr/bin/env python3
"""Link an experimental RTC extension without editing inherited firmware.

This produces a private/local derived image, not a release ROM or enabled
machine profile. Require unchanged-source parity and an exact byte-change
allowlist before allowing the new reset/EC..EF entry points.
"""
import hashlib
import pathlib
import re
import shutil
import tempfile

from assemble_mr16 import AssemblyError, assemble

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / "bios/reference/fw_subcpu"
EXTENSION = ROOT / "verilator/tests/fixtures/rtc_mr16_host_extension.asm"
DRIVER = ROOT / "verilator/tests/fixtures/rtc_mr16_compact.asm"
BASE_SHA = "2d9c9745e0a1a09d98c0e14ace627c03cd39d71ceb21e3fef5957e7a62428c01"


def build(receive_only=False):
    defines = {"ps2_receive_only": 1} if receive_only else {}
    pristine, original_symbols, _ = assemble(SOURCE / "x1sub.asm")
    if hashlib.sha256(pristine).hexdigest() != BASE_SHA:
        raise AssemblyError("inherited firmware no longer matches saved artifact")
    baseline, baseline_symbols, _ = assemble(SOURCE / "x1sub.asm", defines)
    text = (SOURCE / "x1sub.asm").read_text(encoding="latin1")
    patches = [(r"(?m)^(\s*dw\s+)reset\s*$", r"\1rtc_boot")]
    for command, previous in (("ec", "CMD_EC"), ("ed", "host_w3"),
                              ("ee", "CMD_EE"), ("ef", "host_w3")):
        pointer = "calender" if command in ("ec", "ed") else "time"
        patches.append((rf"(?mi)^(\s*dw\s+){previous}(\s*,\s*{pointer}\s*;{command}\b.*)$",
                        rf"\1rtc_cmd_{command}\2"))
    for pattern, replacement in patches:
        text, count = re.subn(pattern, replacement, text)
        if count != 1:
            raise AssemblyError("missing/ambiguous firmware source patch")
    driver = DRIVER.read_text()
    if driver.count("\nrtc_mode:\n") != 1 or driver.count("\ndriver_end:\n") != 1:
        raise AssemblyError("ambiguous counted driver boundaries")
    driver = "rtc_mode:\n" + driver.split("\nrtc_mode:\n")[1].split("\ndriver_end:\n")[0]
    with tempfile.TemporaryDirectory(prefix="x1-rtc-firmware-link-") as directory:
        scratch = pathlib.Path(directory)
        for item in SOURCE.glob("*.inc"):
            shutil.copy2(item, scratch / item.name)
        # Includes retain their original source/notices; no external tree edits.
        for item in SOURCE.glob("*.asm"):
            shutil.copy2(item, scratch / item.name)
        program = scratch / "x1sub.asm"
        program.write_text(text + "\n" + EXTENSION.read_text() + "\n" + driver +
                           "\nrtc_extension_end:\n", encoding="latin1")
        flat, symbols, _ = assemble(program, defines, rom_size=0x5000)
    for name, address in baseline_symbols.items():
        if symbols.get(name) != address:
            raise AssemblyError(f"inherited symbol moved: {name}")
    allowed = {0, 1}
    for command in range(12, 16):
        address = original_symbols["cmd_tbl"] + 4 * command
        allowed.update((address, address + 1))
    # The saved BIN ends at the final emitted byte; code_end additionally
    # includes alignment. Restore its converter padding, not that alignment.
    padding = len((SOURCE / "verilog/X1SUB.BIN").read_bytes())
    if padding != 0x0fe9 or baseline[padding:] != bytes(4096-padding):
        raise AssemblyError("inherited converter padding changed")
    low = bytearray(flat[:4096])
    low[padding:] = baseline[padding:]
    changed = {i for i in range(4096) if baseline[i] != low[i]}
    if not changed or not changed <= allowed:
        raise AssemblyError(f"unexpected inherited ROM differences: {sorted(changed - allowed)}")
    if flat[0x1000:0x4000] != bytes([255]) * 0x3000:
        raise AssemblyError("ROM emission in RAM/unmapped holes")
    if symbols["rtc_buffer"] != 0x1156 or not 0x4000 < symbols["rtc_extension_end"] < 0x5000:
        raise AssemblyError("extension memory contract changed")
    for address, name in [(0, "rtc_boot")] + [
            (original_symbols["cmd_tbl"] + 4 * i, f"rtc_cmd_{c}")
            for i, c in zip(range(12, 16), ("ec", "ed", "ee", "ef"))]:
        if int.from_bytes(flat[address:address+2], "little") != symbols[name]:
            raise AssemblyError("redirected callback mismatch")
    # The assembler's FF hole policy crosses the new bank; restore ONLY the
    # inherited zero-padded unused tail. No instruction/table byte is repaired.
    image = bytes(low) + flat[0x4000:0x5000]
    return image, symbols
