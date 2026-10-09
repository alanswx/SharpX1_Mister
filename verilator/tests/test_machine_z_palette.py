"""Original shared-Z80 external-palette diagnostic; no native/private assets."""
import argparse
import hashlib
import json
import pathlib
import subprocess
import tempfile
from z80_fixture import Program


INDICES = (0, 1, 15, 16, 31, 127, 128, 255, 256, 511, 512,
           1023, 1024, 2047, 2048, 0xABC, 0xFED, 4094, 4095)


def fixture():
    p = Program()
    p.emit(0xF3)
    p.word(0x31, 0xFFFF)

    def output(port, value):
        p.word(0x01, port)
        p.emit(0x3E, value, 0xED, 0x79)

    def read_component(index, component, expected):
        output(0x1FC5, 0x88)
        port = 0x1000 + component * 256 + index // 16
        output(port, (index % 16) * 16 + 15)  # dummy low nibble must not write
        p.emit(0xED, 0x78, 0xE6, 15, 0xFE, expected)  # IN; AND 0F; CP
        p.jump(0xC2, "fail")

    output(0x1A03, 0x82)
    p.word(0x01, 0x1A02)
    p.emit(0xED, 0x78)  # clear DAM through genuine PPI access
    output(0x1A02, 0)  # 40 columns
    output(0x1FD0, 0)  # low scan
    output(0x1FB0, 0x80)
    p.word(0x3A, 0xF040)
    p.emit(0xFE, 0xA5)
    p.jump(0xCA, "warm")
    for index in INDICES:
        for component in range(3):
            read_component(index, component, (index // (16 ** component)) % 16)
    for index in INDICES:
        for component in range(3):
            output(0x1FC5, 0x80)
            value = (index * 7 + component * 5 + 3) % 16
            output(0x1000 + component * 256 + index // 16, (index % 16) * 16 + value)
    p.jump(0xC3, "check")
    p.label("warm")
    p.label("check")
    # Provisional profile gates must not leak writes into external RAM.
    # These are protection checks, not claims about native inactive-mode pins.
    index = 0xABC
    for gate_port, disabled_value, enabled_value in (
        (0x1FB0, 0, 0x80),  # leave analog mode
        (0x1FC5, 0, 0x80),  # unsupported palette control
        (0x1FD0, 1, 0),     # unsupported high scan
        (0x1A02, 0x40, 0),  # unsupported 80 columns
    ):
        output(0x1FC5, 0x80)
        output(gate_port, disabled_value)
        for component in range(3):
            value = ((index * 7 + component * 5 + 3) % 16) ^ 15
            output(0x1000 + component * 256 + index // 16,
                   (index % 16) * 16 + value)
        output(gate_port, enabled_value)
    for index in INDICES:
        for component in range(3):
            read_component(index, component, (index * 7 + component * 5 + 3) % 16)
    p.word(0x3A, 0xF040)
    p.emit(0xFE, 0xA5)
    p.jump(0xCA, "warm_done")
    p.store(0xF040, 0xA5)
    for i, value in enumerate(b"ZPAL"):
        p.store(0xF000 + i, value)
    p.emit(0x76)
    p.label("warm_done")
    for i, value in enumerate(b"ZWAR"):
        p.store(0xF000 + i, value)
    p.emit(0x76)
    p.label("fail")
    p.store(0xF000, 0xEE)
    p.emit(0x76)
    return p.finish()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=pathlib.Path)
    parser.add_argument("--expect-disabled", action="store_true")
    args = parser.parse_args()
    executable = args.executable.resolve()
    digest = hashlib.sha256(executable.read_bytes()).hexdigest()
    with tempfile.TemporaryDirectory(prefix="x1-z-palette-machine-") as folder:
        rom = pathlib.Path(folder) / "original.bin"
        program = fixture()
        rom.write_bytes(program)
        program_digest = hashlib.sha256(program).hexdigest()
        for warm in ((False,) if args.expect_disabled else (False, True)):
            command = [str(executable), "--rom", str(rom), "--cycles", "6400000"]
            if warm:
                command += ["--reset-at", "100", "--reset-for-us", "10"]
            result = subprocess.run(command, check=True, capture_output=True, text=True, timeout=180)
            report = json.loads(result.stdout.splitlines()[-1])
            expected = b"ZWAR" if warm else b"ZPAL"
            assert report["intra_assignment_delays"], report
            assert report["sys_hz"] == 32000000 and report["video_hz"] == 28571428, report
            assert report["turbo_foundation"] and not report["turbo_dma"], report
            if args.expect_disabled:
                assert not report["z_palette_cpu_experiment"] and report["halted"] and report["peek"].startswith("ee"), report
            else:
                assert report["z_palette_cpu_experiment"], report
                assert report["halted"] and report["peek"].startswith(expected.hex()), report
            print(json.dumps({"warm": warm, "peek": report["peek"][:8],
                              "runner_sha256": digest, "program_sha256": program_digest,
                              "sys_hz": report["sys_hz"], "video_hz": report["video_hz"],
                              "reference_cycles": 6400000,
                              "reset_at_ms": 100 if warm else None,
                              "reset_for_us": 10 if warm else None}), flush=True)
    assert hashlib.sha256(executable.read_bytes()).hexdigest() == digest, "runner changed during qualification"
    if args.expect_disabled:
        print("PASS disabled ordinary Turbo control: unchanged CPU diagnostic reaches genuine failure marker without palette support")
    else:
        print("PASS shared Z80 external palette: control OUTs, 19 boundary indices/three components, cold/read/write/dummy select, mode-exit/unsupported-mode write protection and retained warm reset; lower nibble only")


if __name__ == "__main__":
    main()
