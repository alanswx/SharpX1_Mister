"""Optional private-media native IPL/B boot; never inject RAM or patch assets.

Run from verilator/. Uses the separate actual-board-frequency runner.
Preserves a frozen runner, inputs, trace observations and real RGB capture.
"""
import argparse
import csv
import hashlib
import json
import pathlib
import shutil
import subprocess


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=pathlib.Path)
    parser.add_argument("disk", type=pathlib.Path)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    parser.add_argument("--timeout", type=float, default=1800)
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("timeout must be positive")
    root = pathlib.Path(__file__).resolve().parents[2]
    exe, disk = args.executable.resolve(), args.disk.resolve()
    rom = root / "bios/ipl_x1.hex"
    keys = pathlib.Path(__file__).with_name("native_drive_b.keys")
    assert sha(disk) == "2fb70389737a7d54bff5a746b581343385ebde115cefb77ded32c473dcde97ec"
    original = {str(p): sha(p) for p in (exe, rom, keys, disk)}
    folder = args.output.resolve()
    folder.mkdir(parents=True, exist_ok=False)
    frozen = []
    for source, name in zip((exe, rom, keys, disk), ("Vtop", "ipl.hex", "keys.txt", "disk.d88")):
        target = folder / name
        shutil.copy2(source, target)
        assert sha(target) == original[str(source)], "input changed while freezing"
        frozen.append(target)
    runner, ipl, events, media = frozen
    prefix = folder / "native"
    command = [str(runner), "--cycles", "320000000", "--rom", str(ipl),
               "--disk-b", str(media), "--keys", str(events),
               "--dump", str(prefix), "--frame", str(prefix) + ".ppm",
               "--video-dump", str(prefix)]
    record = {"inputs_sha256": original, "command": command, "passed": False}
    manifest = folder / "provenance.json"
    manifest.write_text(json.dumps(record, indent=2) + "\n")
    result = subprocess.run(command, capture_output=True, text=True, timeout=args.timeout)
    (folder / "stdout.log").write_text(result.stdout)
    (folder / "stderr.log").write_text(result.stderr)
    record["returncode"] = result.returncode
    manifest.write_text(json.dumps(record, indent=2) + "\n")
    assert result.returncode == 0, result.stderr
    report = json.loads(result.stdout.splitlines()[-1])
    assert report["sys_hz"] == report["video_hz"] == 28571428
    assert report["turbo_foundation"] and not any(report[k] for k in
        ("turbo_video_master", "turbo_dma", "turbo_dma_irq", "turbo_kanji"))
    assert report["time_ps"] == 10000000000000 and report["download_bytes"] == 4095
    assert report["ps2_bytes_sent"] == 9 and report["disk_requests"] == 763
    assert report["disk_writes"] == 0 and report["frame_width"] == 320 and report["frame_height"] == 200
    with prefix.with_suffix(".cpu-fetches").open() as stream:
        fetches = {int(row["address"]): int(row["fetches"]) for row in csv.DictReader(stream)}
    assert fetches.get(0x017A, 0) > 0 and fetches.get(0x019E, 0) > 0
    ram = prefix.with_suffix(".ram").read_bytes()
    assert ram[0xFF87] & 3 == 1, "native IPL did not select physical B"
    assert b"C r o s s  C h a s e" in prefix.with_suffix(".text").read_bytes()
    assert sha(media) == original[str(disk)]
    assert all(sha(pathlib.Path(p)) == digest for p, digest in original.items())
    record.update(passed=True, report=report, drive_register=ram[0xFF87],
                  outputs_sha256={p.name: sha(p) for p in folder.glob("native.*")})
    manifest.write_text(json.dumps(record, indent=2) + "\n")
    print(json.dumps({"passed": True, "drive": 1, "disk_requests": 763,
                      "frame_sha256": sha(prefix.with_suffix(".ppm")), "evidence": str(folder)}))
    print("PASS: native IPL drive-1 selection, B-only protected boot, real title pixels/text; not gameplay acceptance")


if __name__ == "__main__":
    main()
