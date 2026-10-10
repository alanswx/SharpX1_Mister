"""Private release-bound Xevious gameplay from three continuous timing cold boots.

No snapshots, game-memory injection or patched media. The 16-second IPL boot,
500 ms start, 3-second live interval and 300 ms controls match the existing
release-bound fast diagnostic. Requires authorized local assets.
"""
import argparse
import concurrent.futures
import hashlib
import json
import pathlib
import shutil
import subprocess


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=pathlib.Path)
    parser.add_argument("disk", type=pathlib.Path)
    parser.add_argument("--rom", type=pathlib.Path, required=True)
    parser.add_argument("--keys", type=pathlib.Path, required=True)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    parser.add_argument("--timeout", type=float, default=7200)
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("positive timeout required")
    exe, disk, rom, keys = (p.resolve() for p in (args.executable, args.disk, args.rom, args.keys))
    assert sha(disk) == "3670f283005c90b09a53e1b2dd1164c45c6a997eafbc0ca9c20248b9f7e19903", "unrecognized Xevious release"
    originals = {str(p): sha(p) for p in (exe, disk, rom, keys)}
    folder = args.output.resolve()
    folder.mkdir(parents=True, exist_ok=False)
    frozen = folder / "Vtop"
    shutil.copy2(exe, frozen)
    assert sha(frozen) == originals[str(exe)]
    preflight = subprocess.run([str(frozen), "--cycles", "10000"], capture_output=True, text=True, timeout=60)
    (folder / "profile.stdout").write_text(preflight.stdout)
    (folder / "profile.stderr").write_text(preflight.stderr)
    assert preflight.returncode == 0, "timing runner preflight failed"
    profile = json.loads(preflight.stdout.splitlines()[-1])

    def check_profile(report):
        assert report["machine"] == "sharpx1" and report["intra_assignment_delays"] is True
        assert report["sys_hz"] == 32000000 and report["video_hz"] == 28571428
        for flag in ("turbo_foundation", "turbo_video_master", "turbo_dma", "turbo_dma_irq",
                     "turbo_kanji", "turbo_fm_cpu", "z_palette_cpu_experiment", "z_video_experiment",
                     "z_multimode_experiment", "z_internal8_experiment", "z_text_cpu_experiment"):
            assert report[flag] is False, f"not ordinary timing profile: {flag}"

    check_profile(profile)
    evidence = {"inputs_sha256": originals, "runner_sha256": sha(frozen),
                "scope": "bounded ordinary delay-aware continuous native cold gameplay, not Turbo/Z or hardware",
                "gameplay_verified": False, "runs": []}
    provenance = folder / "provenance.json"
    provenance.write_text(json.dumps(evidence, indent=2) + "\n")

    def run(name, controlled):
        prefix = folder / name
        command = [str(frozen), "--cycles", "633600000", "--rom", str(rom), "--keys", str(keys),
                   "--disk", str(disk), "--joy-at", "16000", "A", "0xdf",
                   "--joy-at", "16500", "A", "0xff",
                   "--joy-at", "19500", "A", "0xf7" if controlled else "0xff",
                   "--dump", str(prefix), "--frame", str(prefix) + ".ppm"]
        print("START: continuous native", name, flush=True)
        try:
            result = subprocess.run(command, capture_output=True, text=True, timeout=args.timeout)
        except subprocess.TimeoutExpired as error:
            def partial(value):
                return value.decode(errors="replace") if isinstance(value, bytes) else (value or "")
            result = subprocess.CompletedProcess(command, 124, partial(error.stdout),
                partial(error.stderr) + "\nIncomplete host timeout; no gameplay acceptance.\n")
        prefix.with_suffix(".stdout").write_text(result.stdout)
        prefix.with_suffix(".stderr").write_text(result.stderr)
        record = {"name": name, "command": command, "returncode": result.returncode}
        if result.returncode == 0:
            record["report"] = json.loads(result.stdout.splitlines()[-1])
            record["ram_sha256"] = sha(prefix.with_suffix(".ram"))
            record["frame_sha256"] = sha(prefix.with_suffix(".ppm"))
        print("TERMINAL:", name, result.returncode, flush=True)
        return record

    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        jobs = [pool.submit(run, name, controlled) for name, controlled in
                (("idle", False), ("controlled", True), ("repeat", True))]
        for job in jobs:
            evidence["runs"].append(job.result())
            provenance.write_text(json.dumps(evidence, indent=2) + "\n")
    results = {}
    for record in evidence["runs"]:
        assert record["returncode"] == 0, f"incomplete native run: {record['name']}"
        report = record["report"]
        check_profile(report)
        assert report["disk_requests"] > 0 and report["disk_writes"] == 0
        assert report["download_bytes"] == 4095 and report["ps2_bytes_sent"] == 6
        assert report["joystick_events_applied"] == 3 and report["joystick_events_pending"] == 0
        assert report["time_ps"] == 19800000000000 and report["frames"] > 1000
        assert (report["frame_width"], report["frame_height"]) == (320, 200)
        memory = (folder / (record["name"] + ".ram")).read_bytes()
        active, y, x, old_y, old_x = memory[0x16E4:0x16E9]
        assert active and 0 < x < 70 and 0 < y < 70 and (x, y) == (old_x, old_y)
        results[record["name"]] = (x, y)
    idle, moved = results["idle"], results["controlled"]
    assert moved[0] > idle[0] and moved[1] == idle[1], results
    controlled, repeated = evidence["runs"][1:]
    assert controlled["report"] == repeated["report"]
    for suffix in (".ram", ".subram", ".text", ".attr", ".cpu", ".ppm"):
        assert (folder / ("controlled" + suffix)).read_bytes() == (folder / ("repeat" + suffix)).read_bytes(), suffix
    assert (folder / "idle.ppm").read_bytes() != (folder / "controlled.ppm").read_bytes()
    assert all(sha(pathlib.Path(p)) == digest for p, digest in originals.items()) and sha(frozen) == originals[str(exe)]
    evidence.update(gameplay_verified=True, unchanged_inputs=True, idle_player=idle, controlled_player=moved)
    provenance.write_text(json.dumps(evidence, indent=2) + "\n")
    print(json.dumps({"idle_player": idle, "controlled_player": moved, "runner_sha256": sha(frozen)}), flush=True)
    print("PASS: continuous timing native cold boot, right movement, actual RGB change, full dump/report repeatability, unchanged assets", flush=True)


if __name__ == "__main__":
    main()
