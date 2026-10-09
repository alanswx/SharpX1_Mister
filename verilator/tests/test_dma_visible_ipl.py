"""Export and qualify original, real-CPU DMA restart hardware IPLs/RGB.

All existing guards and handler assertions stay in the generated program.
Green requires their completion; red denotes pending/failure, not its cause.
"""
import argparse
import hashlib
import json
import pathlib
import subprocess
from test_machine_dma import media
from test_machine_dma_restart_irq import diagnostic as memory
from test_machine_dma_restart_fdc import diagnostic as floppy


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=pathlib.Path)
    parser.add_argument("output", type=pathlib.Path)
    parser.add_argument("--sys-hz", type=int, default=28571428)
    parser.add_argument("--completion-only", type=pathlib.Path,
                        help="negative capability control: red, no transfers")
    args = parser.parse_args()
    exe = args.executable.resolve()
    runner_hash = hashlib.sha256(exe.read_bytes()).hexdigest()
    args.output.mkdir(parents=True, exist_ok=False)
    manifest = {"runner_sha256": runner_hash, "sys_hz": args.sys_hz,
                "reference_cycles": 8000000, "cases": []}
    disks, payloads = [], []
    for drive, seed in enumerate((0x21, 0x93)):
        image, payload = media(seed)
        path = args.output / f"drive-{drive}.d88"
        path.write_bytes(image)
        disks.append(path.resolve())
        payloads.append(payload)
    disk_hashes = [hashlib.sha256(d.read_bytes()).hexdigest() for d in disks]
    manifest["disk_sha256"] = disk_hashes
    for drive in (None, 0, 1):
        for mode in (0, 1, 2):
            for a_source in (False, True):
                name = ("memory" if drive is None else f"drive-{drive}") + f"-mode{mode}-source{'A' if a_source else 'B'}"
                data = memory(a_source, mode, visible=True) if drive is None else floppy(drive, a_source, mode, payloads[drive], visible=True)
                rom = (args.output / (name + ".rom")).resolve()
                rom.write_bytes(data.ljust(32768, b"\xff"))
                frame = (args.output / (name + ".ppm")).resolve()
                dump = (args.output / name).resolve()
                command = [str(exe), "--rom", str(rom), "--cycles", "8000000",
                           "--frame", str(frame), "--dump", str(dump)]
                if drive is not None:
                    command += ["--disk", str(disks[0]), "--disk-b", str(disks[1])]
                result = subprocess.run(command, capture_output=True, text=True, check=True, timeout=300)
                report = json.loads(result.stdout.splitlines()[-1])
                expected = b"RST!" if drive is None else b"FDC!"
                assert report["sys_hz"] == args.sys_hz and report["halted"] and report["peek"].startswith(expected.hex()), report
                pairs = 12 if drive is None else 768
                grants = (12 if mode == 0 else 3) if drive is None else (3 if mode == 1 else 768)
                assert (report["dma_reads"], report["dma_writes"], report["dma_grants"]) == (pairs, pairs, grants), report
                assert report["cpu_fdc_data_reads"] == report["cpu_fdc_data_writes"] == report["disk_writes"] == 0, report
                assert dump.with_suffix(".ram").read_bytes()[0xf010] == 3
                assert (report["frame_width"], report["frame_height"]) == (320, 200), report
                pixels = frame.read_bytes().split(b"\n", 3)
                assert pixels[:3] == [b"P6", b"320 200", b"255"], pixels[:3]
                assert pixels[3] == b"\x00\xff\x00" * (320*200), name
                assert [hashlib.sha256(d.read_bytes()).hexdigest() for d in disks] == disk_hashes
                assert hashlib.sha256(exe.read_bytes()).hexdigest() == runner_hash
                item = {"name": name, "ipl_sha256": hashlib.sha256(rom.read_bytes()).hexdigest(), "report": report}
                manifest["cases"].append(item)
                print("PASS visible CPU/IRQ/RETI " + name + " all 64000 pixels green", flush=True)
                if args.completion_only and drive is None and mode == 0 and not a_source:
                    control = args.completion_only.resolve()
                    control_hash = hashlib.sha256(control.read_bytes()).hexdigest()
                    negative_frame = (args.output / "unsupported-red.ppm").resolve()
                    negative = subprocess.run([str(control), "--rom", str(rom), "--cycles", "8000000", "--frame", str(negative_frame)],
                                              capture_output=True, text=True, check=True, timeout=300)
                    n = json.loads(negative.stdout.splitlines()[-1])
                    assert n["dma_reads"] == n["dma_writes"] == 0 and not n["peek"].startswith(expected.hex()), n
                    assert negative_frame.read_bytes().split(b"\n", 3)[3] == b"\xff\x00\x00" * 64000
                    assert hashlib.sha256(control.read_bytes()).hexdigest() == control_hash
                    manifest["negative"] = {"runner_sha256": control_hash, "report": n}
                    print("PASS unsupported capability remains red with zero pairs", flush=True)
                (args.output / "manifest.json").write_text(json.dumps(manifest, indent=2)+"\n")


if __name__ == "__main__":
    main()
