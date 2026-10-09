"""Original X3 continuation/profile-rejection diagnostic, not native boot."""
import json
import pathlib
import subprocess
import struct
import sys
import tempfile

turbo, baseline = (str(pathlib.Path(p).resolve()) for p in sys.argv[1:3])
previous_x3 = str(pathlib.Path(sys.argv[3]).resolve()) if len(sys.argv) == 4 else None

def execute(executable, arguments):
    result = subprocess.run([executable, *arguments], capture_output=True, text=True, timeout=180)
    assert result.returncode == 0, result.stderr
    return json.loads(result.stdout.splitlines()[-1])

with tempfile.TemporaryDirectory(prefix="x1-x3-snapshot-") as directory:
    root = pathlib.Path(directory)
    program = root / "counter.bin"
    program.write_bytes(bytes((0x21,0x00,0xf0,0x34,0xc3,0x03,0x80)))
    state = root / "turbo.state"
    execute(turbo,["--cycles","10000","--ram",str(program),"--save-state",str(state)])
    resumed = execute(turbo,["--cycles","10000","--restore-state",str(state),"--dump",str(root/"resumed")])
    straight = execute(turbo,["--cycles","20000","--ram",str(program),"--dump",str(root/"straight")])
    assert resumed["turbo_foundation"] and resumed["turbo_video_master"]
    assert resumed["sys_hz"] == 32000000 and resumed["video_hz"] == 42954540
    for field in ("time_ps","sys_edges","video_edges","reset_edges","cpu_enables",
                  "delayed_sys_edges","cpu_address","sub_pc","sub_address","sub_control"):
        assert resumed[field] == straight[field], (field,resumed[field],straight[field])
    for suffix in ("ram","text","attr","subram","cpu"):
        assert (root/f"resumed.{suffix}").read_bytes() == (root/f"straight.{suffix}").read_bytes(), suffix
    # Equal system AND video rates must not defeat model-profile rejection.
    base_state = root / "base.state"
    execute(baseline,["--cycles","10000","--video-hz","42954540","--ram",str(program),
                      "--save-state",str(base_state)])
    for executable, incompatible in ((turbo,base_state),(baseline,state)):
        result = subprocess.run([executable,"--cycles","10000","--video-hz","42954540",
                                 "--restore-state",str(incompatible)],capture_output=True,text=True,timeout=180)
        assert result.returncode == 2, (result.returncode,result.stderr)
        assert "snapshot version, video clock or disk fingerprint mismatch" in result.stderr, result.stderr
    if previous_x3:
        previous_state = root / "previous-x3.state"
        execute(previous_x3,["--cycles","10000","--ram",str(program),"--save-state",str(previous_state)])
        old_magic = struct.unpack_from("<Q", previous_state.read_bytes(), 16)[0]
        new_magic = struct.unpack_from("<Q", state.read_bytes(), 16)[0]
        assert old_magic ^ new_magic == 1 << 63, "previous runner is not the matching pre-blink v17 X3 profile"
        rejected = subprocess.run([turbo,"--cycles","10000","--restore-state",str(previous_state)],
                                  capture_output=True,text=True,timeout=180)
        assert rejected.returncode == 2 and "snapshot version, video clock or disk fingerprint mismatch" in rejected.stderr, rejected.stderr
        print("PASS: actual unmodified pre-blink v17 X3 state rejected before deserialization; no conversion")
    font = root / "font16.bin"
    font.write_bytes(bytes(4096))
    invalid = subprocess.run([turbo,"--cycles","10000","--restore-state",str(state),
                              "--font16",str(font)],capture_output=True,text=True,timeout=180)
    assert invalid.returncode == 2 and "snapshot restore cannot also download ROM/RAM/font16" in invalid.stderr, invalid.stderr
print("PASS: X3 clock/RAM/CPU continuation and graceful same-rate base/Turbo profile rejection; no state conversion")
