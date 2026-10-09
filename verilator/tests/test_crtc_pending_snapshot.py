"""Real CPU CRTC transaction snapshots; generated RAM, not native software."""
import hashlib
import json
import pathlib
import subprocess
import sys
import tempfile

exe = pathlib.Path(sys.argv[1]).resolve()
exe_hash = hashlib.sha256(exe.read_bytes()).hexdigest()
oracle_path = pathlib.Path(__file__).resolve()
oracle_hash = hashlib.sha256(oracle_path.read_bytes()).hexdigest()
for arguments in (("--cycles", "0"), ("--cycles", "1"), ("--cycles", "64"),
                  ("--cycles", "100", "--reset-cycles", "0")):
    rejected = subprocess.run([str(exe), *arguments], capture_output=True, text=True, timeout=120)
    assert rejected.returncode == 2 and "require 0 < reset-cycles < cycles" in rejected.stderr, "cold-start reset guard relaxed"


def run(arguments):
    result = subprocess.run([str(exe), *map(str, arguments)], capture_output=True, text=True, timeout=120)
    assert result.returncode == 0, (result.returncode, result.stderr)
    return json.loads(result.stdout.splitlines()[-1])


program = bytearray([0xF3])  # DI, no invented IRQ or CRTC readback.


def out(port, value):
    program.extend((0x01, port & 255, port >> 8, 0x3E, value, 0xED, 0x79))


# Genuine CPU timing initialization, as in the existing 40-column fixture.
# Do not disable raster guardrails to accept an unprogrammed CRTC.
for index, value in enumerate((55, 40, 46, 0x28, 31, 2, 25, 28, 0, 7, 0, 0, 0, 0, 0, 0)):
    out(0x1800, index)
    out(0x1801, value)
for i in range(24):
    out(0x1800, 5)
    out(0x1801, (i * 7 + 3) & 31)
    out(0x1800, 9)
    out(0x1801, (i * 11 + 1) & 31)
program.append(0x76)

with tempfile.TemporaryDirectory(prefix="x1-crtc-pending-snapshot-") as directory:
    root = pathlib.Path(directory)
    image = root / "original.bin"
    image.write_bytes(program)
    # Keep the runner's nominal X3 clock contract; vary only original CPU
    # padding, not a forbidden clock override or machine state.
    hz = 42954540
    search_start = 5000
    for padding in (0, 1, 3):
        image.write_bytes(bytes([0x00] * padding) + program)
        found = {}
        # Search real completed invocations, not inferred simulation phases.
        # Every candidate is freshly executed from original generated RAM.
        for cycles in range(search_start, 16001):
            state = root / "candidate.state"
            report = run(["--video-hz", hz, "--cycles", cycles, "--ram", image, "--save-state", state])
            assert report["turbo_video_master"] and not report["intra_assignment_delays"]
            if not report["crtc_busy"] or not report["crtc_packet"] & 256 or report["crtc_index"] not in (5, 9):
                continue
            phase = None
            if report["crtc_request_sync"] != report["crtc_request"]:
                phase = "request-in-flight"
            elif report["crtc_pending_write"]:
                phase = "captured-before-consumption"
            elif report["crtc_ack"] == report["crtc_request"] and report["crtc_ack_sync"] != report["crtc_request"]:
                phase = "consumed-before-source-ack"
            if phase is None or phase in found:
                continue
            saved = root / f"padding-{padding}-{phase}.state"
            state.rename(saved)  # Preserve the actual state, never edit bytes.
            saved_hash = hashlib.sha256(saved.read_bytes()).hexdigest()
            if padding == 0 and not found:
                rejected = subprocess.run([str(exe), "--video-hz", "4000000", "--cycles", "1",
                                           "--restore-state", str(saved)], capture_output=True, text=True, timeout=120)
                assert rejected.returncode == 2 and "requires video-hz = 42954540" in rejected.stderr, "X3 clock contract relaxed"
            found[phase] = cycles
            for delta in (0, 1, 2, 3, 4, 8, 16, 32, 64, 50000):
                resumed_state, straight_state = root / "resumed.state", root / "straight.state"
                resumed = run(["--video-hz", hz, "--cycles", delta, "--restore-state", saved, "--save-state", resumed_state])
                straight = run(["--video-hz", hz, "--cycles", cycles + delta, "--ram", image, "--save-state", straight_state])
                for key in ("time_ps", "sys_edges", "video_edges", "reset_edges", "cpu_enables",
                            "delayed_sys_edges", "cpu_address", "halted", "sub_pc"):
                    assert resumed[key] == straight[key], (hz, phase, delta, key)
                for key in report:
                    if key.startswith("crtc_"):
                        assert resumed[key] == straight[key], (hz, phase, delta, key)
                assert resumed_state.read_bytes() == straight_state.read_bytes(), (hz, phase, delta, "serialized state differs")
                if delta == 50000:
                    assert resumed["halted"] and not resumed["crtc_busy"]
                    assert resumed["crtc_index"] == 9 and resumed["crtc_r5"] == (23 * 7 + 3) & 31
                    assert resumed["crtc_r9"] == (23 * 11 + 1) & 31
            assert hashlib.sha256(saved.read_bytes()).hexdigest() == saved_hash
            print(f"PASS: hz={hz} padding={padding} phase={phase} prefix_cycles={cycles}; ten continuations byte-identical, original state unchanged", flush=True)
            if len(found) == 3:
                break
        assert len(found) == 3, (hz, "missing actual pending transaction phases", found)
        search_start = min(found.values())
assert hashlib.sha256(exe.read_bytes()).hexdigest() == exe_hash
assert hashlib.sha256(oracle_path.read_bytes()).hexdigest() == oracle_hash
print(f"PASS: nine real-CPU pending CRTC states, 90 continuation comparisons; runner={exe_hash}; no converted state/native/hardware claim")
