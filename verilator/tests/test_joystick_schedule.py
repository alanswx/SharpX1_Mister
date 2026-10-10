"""Scheduled external joystick pins must reach real CPU PSG IN instructions."""
import argparse
import json
import pathlib
import subprocess
import tempfile
from z80_fixture import Program

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("executable", type=pathlib.Path)
parser.add_argument("--savable", action="store_true")
args = parser.parse_args()
exe = str(args.executable.resolve())

with tempfile.TemporaryDirectory(prefix="x1-joy-schedule-") as temporary:
    folder = pathlib.Path(temporary)
    p = Program()
    p.emit(0xF3)
    p.label("read")
    for register, address in ((14, 0xF000), (15, 0xF001)):
        p.word(0x01, 0x1C00)
        p.emit(0x3E, register, 0xED, 0x79)  # real PSG address OUT
        p.word(0x01, 0x1B00)
        p.emit(0xED, 0x78)  # real PSG data IN
        p.word(0x32, address)
    p.jump(0xC3, "read")
    rom = folder / "original-loop.rom"
    rom.write_bytes(p.finish())
    events = [(0, "A", "0xee"), (1, "B", "0x7f"),
              (2, "A", "0xdf"), (2, "A", "0xf7"),
              (3, "A", "0xff"), (4, "B", "0xff")]

    def schedule(values):
        return [item for event in values for item in ("--joy-at", *map(str, event))]

    def run(name, cycles, extra=(), valid=True):
        output = folder / name
        command = [exe, "--cycles", str(cycles), "--peek", "0xf000",
                   "--dump", str(output), *extra]
        if "--restore-state" not in extra:
            command += ["--rom", str(rom)]
        result = subprocess.run(command, capture_output=True, text=True, timeout=180)
        if not valid:
            assert result.returncode != 0, (command, result.stdout)
            return result
        assert result.returncode == 0, result.stderr
        return json.loads(result.stdout.splitlines()[-1]), output.with_suffix(".ram").read_bytes()

    for clock in ((), ("--video-hz", "24000000")):
        partial = run("partial", 80000, [*clock, *schedule(events)])
        assert partial[0]["joystick_events_applied"] == 4 and partial[0]["joystick_events_pending"] == 2
        assert (partial[0]["joya_n"], partial[0]["joyb_n"]) == (0xF7, 0x7F)
        assert partial[1][0xF000:0xF002] == bytes((0xF7, 0x7F)), "scheduled pins did not reach CPU IN"
        complete = run("complete", 160000, [*clock, *schedule(events)])
        repeat = run("repeat", 160000, [*clock, *schedule(events)])
        assert complete == repeat, "scheduled pin/report/RAM execution is not repeatable"
        assert complete[0]["joystick_events_applied"] == 6 and complete[0]["joystick_events_pending"] == 0
        assert complete[1][0xF000:0xF002] == b"\xff\xff", "release did not reach CPU IN"
        warm = run("warm", 160000, [*clock, *schedule(events), "--reset-at", "3", "--reset-for-us", "50"])
        assert warm[0]["joystick_events_applied"] == 6 and warm[1][0xF000:0xF002] == b"\xff\xff"

    static = run("static", 80000, ["--joya", "0xfb", "--joyb", "0xfe"])
    assert static[1][0xF000:0xF002] == bytes((0xFB, 0xFE))
    for invalid in (["--joy-at", "1", "C", "0xff"], ["--joy-at", "1", "A", "256"],
                    ["--joy-at", "1000001", "A", "0xff"],
                    ["--joy-at", "-1", "A", "0xff"], ["--joy-at", "x", "A", "0xff"],
                    schedule([(2, "A", "0xff"), (1, "B", "0xff")]),
                    ["--joy-at", "1", "A"],
                    [*schedule([(0, "A", "0xff")]), "--interactive", "--joystick-keys"]):
        run("invalid", 128, invalid, valid=False)

    if args.savable:
        state = folder / "drained.state"
        run("save", 160000, [*schedule([*events, (4, "B", "0x7f")]), "--save-state", str(state)])
        restored = run("restored", 64000, ["--restore-state", str(state),
                                          *schedule([(0, "A", "0xfb")])])
        assert restored[0]["joystick_events_applied"] == 1 and restored[1][0xF000:0xF002] == bytes((0xFB, 0x7F))
        pending = folder / "must-not-exist.state"
        rejected = run("pending-save", 80000, [*schedule(events), "--save-state", str(pending)], valid=False)
        assert "quiescent" in rejected.stderr and not pending.exists(), "pending host events were silently lost"

print("PASS: scheduled A/B pins, same-time ordering, real CPU IN, reset/release, two clocks, repeatability, malformed/conflicting input rejection" +
      ("; restored relative scheduling and pending-event snapshot rejection" if args.savable else ""))
