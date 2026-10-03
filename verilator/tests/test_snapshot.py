"""Verify clock phase and RAM/state continuity across fast-model restore."""
import json
import pathlib
import subprocess
import sys
import tempfile
from z80_fixture import Program

exe = str(pathlib.Path(sys.argv[1]).resolve())


def run(args):
    result = subprocess.run([exe, *args], check=True, capture_output=True, text=True)
    return json.loads(result.stdout.splitlines()[-1])


with tempfile.TemporaryDirectory(prefix="x1-snapshot-") as folder:
    folder = pathlib.Path(folder)
    program = folder / "counter.bin"
    # Original loop: increment a high-RAM counter forever.
    program.write_bytes(bytes((0x21, 0x00, 0xF0, 0x34, 0xC3, 0x03, 0x80)))
    state = folder / "state.bin"
    run(["--cycles", "10000", "--ram", str(program), "--save-state", str(state)])
    resumed = run(["--cycles", "10000", "--restore-state", str(state), "--dump", str(folder / "resumed")])
    straight = run(["--cycles", "20000", "--ram", str(program), "--dump", str(folder / "straight")])
    for key in ("time_ps", "sys_edges", "video_edges", "reset_edges", "cpu_enables",
                "delayed_sys_edges", "cpu_address", "peek", "sub_pc", "sub_address", "sub_control"):
        assert resumed[key] == straight[key], (key, resumed, straight)
    for suffix in ("ram", "text", "attr"):
        assert (folder / f"resumed.{suffix}").read_bytes() == (folder / f"straight.{suffix}").read_bytes(), suffix
    assert state.stat().st_size > 65536
    wrong_clock = subprocess.run([exe, "--cycles", "4096", "--restore-state", str(state),
                                  "--video-hz", "28636360"], capture_output=True)
    assert wrong_clock.returncode != 0

    # Saved external joystick pins persist; explicit flags override them.
    p = Program(0x8000)
    p.emit(0xF3)
    p.label("poll")
    for register, address in ((14, 0xF100), (15, 0xF101)):
        p.word(0x01, 0x1C00)
        p.emit(0x3E, register, 0xED, 0x79)
        p.word(0x01, 0x1B00)
        p.emit(0xED, 0x78)
        p.word(0x32, address)
    p.jump(0xC3, "poll")
    program.write_bytes(p.finish())
    saved = run(["--cycles", "20000", "--ram", str(program), "--joya", "0xde",
                 "--joyb", "0xb7", "--peek", "0xf100", "--save-state", str(state)])
    assert saved["peek"].startswith("deb7"), saved
    same = run(["--cycles", "10000", "--restore-state", str(state), "--peek", "0xf100"])
    assert same["peek"].startswith("deb7"), same
    changed = run(["--cycles", "10000", "--restore-state", str(state), "--peek", "0xf100",
                   "--joya", "0xff", "--joyb", "0xfd"])
    assert changed["peek"].startswith("fffd"), changed
print("PASS: RTL snapshot/clock/RAM continuity, clock mismatch rejection and joystick persistence/override")
