"""Trace the cold PS/2 loss and verify the one-way MR16 firmware profile.

Standalone test: python3 tests/test_keyboard_receiver.py (from verilator).
No ROM/game assets or snapshots are required.
"""
import pathlib
import re
import subprocess
import tempfile

root = pathlib.Path(__file__).resolve().parents[2]
firmware = root / "bios/reference/fw_subcpu"
listing = (firmware / "x1sub.LST").read_text(errors="replace")
def symbol(name):
    match = re.search(rf"^([0-9A-F]{{4}})\s+{name}:\s*$", listing, re.MULTILINE)
    assert match, name
    return int(match[1], 16)

# Guard the layout/encoding used by the one-word RTL profile against drift.
entry, receiver = symbol("PS2_TX"), symbol("ps2_rx_en")
assert (entry, receiver) == (0x45C, 0x452)
assert 0x2F00 | (((receiver - entry) // 2) & 0xFF) == 0x2FFB
binary = (firmware / "verilog/X1SUB.BIN").read_bytes()
assert binary[entry:entry+2] == bytes.fromhex("0071")
sources = [root / name for name in (
    "rtl/mr16core.v", "rtl/mr16_x1.v", "rtl/sub_rom.v", "rtl/sub_cpu.v",
    "rtl/dpram.sv", "verilator/tests/keyboard_receiver_tb.sv")]
with tempfile.TemporaryDirectory(prefix="x1-keyboard-receiver-") as folder:
    for hz, receive_only in ((32000000, 0), (32000000, 1),
                             (28636364, 1), (28571428, 1)):
        output = pathlib.Path(folder) / f"{hz}-{receive_only}"
        command = ["verilator", "--binary", "--timing", "--assert", "-j", "4",
                   "--top-module", "keyboard_receiver_tb", "--Mdir", str(output),
                   f"-GCLOCK_HZ={hz}", f"-GRECEIVE_ONLY={receive_only}",
                   *map(str, sources), "-Wno-fatal"]
        build = subprocess.run(command, cwd=root, capture_output=True, text=True, timeout=180)
        if build.returncode:
            raise RuntimeError(build.stdout + build.stderr)
        result = subprocess.run([str(output / "Vkeyboard_receiver_tb")], cwd=root,
                                capture_output=True, text=True, timeout=180)
        print(result.stdout, end="", flush=True)
        assert result.returncode == 0, result.stderr
print("PASS: original ROM/layout guarded; inherited failure reproduced; receive-only stream at three clocks")
