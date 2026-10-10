"""Release-bound action gameplay from continuous ordinary timing cold boots.

Preserves requalify_commercial.py's native startup durations and the original
test_commercial_gameplay.py player symbols/directions. No snapshots or RAM
injection. Private authorized media are required; pure plans are asset-free.
"""
import argparse
import concurrent.futures
import hashlib
import json
import pathlib
import shutil
import subprocess


MEDIA = {
    "druaga": "bb8556981f0910f33d7129f82de620a232e61b0fc41a61ed565366b5de4560b9",
    "mappy": "297e89aa7a8d9feb72651823bab210e66c09fdc1863bb6e4a9528c8ca652325b",
    "galaga": "d0cdeb8275fbbdd2226851266a7bbf3d5e4ff77c268e331a81083c8eac3c342c",
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def plan(title, controlled):
    # Input at segment boundaries reproduces the previous native prefix; the
    # final 300 ms is the unchanged direction-vs-neutral comparison interval.
    if title == "druaga":
        live = 30250
        events = [(16000, 0xdf), (16250, 0xff)]
    elif title == "galaga":
        live = 33000
        events = [(16000, 0xdf), (16500, 0xff), (20500, 0xdf),
                  (20750, 0xff), (23750, 0xdf), (24000, 0xff)]
    elif title == "mappy":
        live = 27000
        events = []
    else:
        raise ValueError("unqualified title")
    direction = 0xf7 if title == "galaga" else 0xfb
    return live + 300, events + [(live, direction if controlled else 0xff)]


def key_events(text):
    events = []
    for line in text.splitlines():
        fields = line.split("#", 1)[0].split()
        if not fields:
            continue
        assert len(fields) == 2, "bad original key script"
        event = int(fields[0]), int(fields[1], 16)
        assert event[0] >= 0 and 0 <= event[1] <= 255
        assert not events or event[0] >= events[-1][0], "unordered original keys"
        events.append(event)
    return events


def cold_keys(title, boot, mappy=None):
    events = key_events(boot)
    assert events and events[-1][0] < 16000, "boot keys outside native boot"
    if title == "mappy":
        start = key_events(mappy)
        assert start and start[-1][0] < 3000, "start keys outside original segment"
        events += [(offset + ms, byte) for offset in (18000, 24000) for ms, byte in start]
    return events


def player(title, memory):
    assert len(memory) == 65536, "incomplete native RAM dump"
    if title == "galaga":
        x, y = memory[0x2311], memory[0x2313]
        assert memory[0xDD3] == memory[0x230F] == 1
        assert 0 < x < 64 and 0 < y < 32
    elif title == "mappy":
        x, y = memory[0xF80B], memory[0xF809]
        assert memory[0xF800] == 3 and 0 < x < 256 and 0 < y < 200
    elif title == "druaga":
        x, y = memory[0xF828:0xF82A]
        assert 0 < x < 128 and 0 < y < 64
    else:
        raise ValueError("unqualified title")
    return x, y


def check_profile(report):
    assert report["machine"] == "sharpx1" and report["intra_assignment_delays"] is True
    assert report["sys_hz"] == 32000000 and report["video_hz"] == 28571428
    for flag in ("turbo_foundation", "turbo_video_master", "turbo_dma", "turbo_dma_irq",
                 "turbo_kanji", "turbo_fm_cpu", "z_palette_cpu_experiment", "z_video_experiment",
                 "z_multimode_experiment", "z_internal8_experiment", "z_text_cpu_experiment"):
        assert report[flag] is False, f"not ordinary timing profile: {flag}"


def command(exe, title, disk, rom, keys, prefix, controlled):
    duration, events = plan(title, controlled)
    result = [str(exe), "--cycles", str(duration * 32000), "--rom", str(rom),
              "--keys", str(keys), "--disk", str(disk), "--dump", str(prefix),
              "--frame", str(prefix) + ".ppm"]
    for ms, value in events:
        result += ["--joy-at", str(ms), "A", hex(value)]
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=pathlib.Path)
    parser.add_argument("title", choices=tuple(MEDIA))
    parser.add_argument("disk", type=pathlib.Path)
    parser.add_argument("--rom", type=pathlib.Path, required=True)
    parser.add_argument("--keys", type=pathlib.Path, required=True)
    parser.add_argument("--mappy-keys", type=pathlib.Path)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    parser.add_argument("--timeout", type=float, default=10800)
    args = parser.parse_args()
    if args.timeout <= 0 or (args.title == "mappy" and not args.mappy_keys):
        parser.error("positive timeout and Mappy start keys when applicable required")
    if args.title != "mappy" and args.mappy_keys:
        parser.error("Mappy start keys only apply to Mappy")
    exe, disk, rom, keys = (p.resolve() for p in (args.executable, args.disk, args.rom, args.keys))
    assert sha(disk) == MEDIA[args.title], "unrecognized release"
    inputs = [exe, disk, rom, keys, pathlib.Path(__file__).resolve()]
    if args.mappy_keys:
        inputs.append(args.mappy_keys.resolve())
    originals = {str(p): sha(p) for p in inputs}
    events = cold_keys(args.title, keys.read_text(),
                       args.mappy_keys.read_text() if args.mappy_keys else None)
    folder = args.output.resolve()
    folder.mkdir(parents=True, exist_ok=False)
    frozen = folder / "Vtop"
    shutil.copy2(exe, frozen)
    assert sha(frozen) == originals[str(exe)]
    combined_keys = folder / "continuous.keys"
    combined_keys.write_text("# Original startup events at continuous native times.\n" +
                             "".join(f"{ms} {byte:02x}\n" for ms, byte in events))
    combined_hash = sha(combined_keys)
    preflight = subprocess.run([str(frozen), "--cycles", "10000"], capture_output=True,
                               text=True, timeout=60)
    (folder / "profile.stdout").write_text(preflight.stdout)
    (folder / "profile.stderr").write_text(preflight.stderr)
    assert preflight.returncode == 0
    check_profile(json.loads(preflight.stdout.splitlines()[-1]))
    evidence = {"title": args.title, "inputs_sha256": originals, "runner_sha256": sha(frozen),
                "continuous_keys_sha256": combined_hash,
                "scope": "bounded ordinary delay-aware continuous cold movement; not full game, Turbo/Z or hardware",
                "gameplay_verified": False, "runs": []}
    provenance = folder / "provenance.json"
    provenance.write_text(json.dumps(evidence, indent=2) + "\n")

    def run(name, controlled):
        prefix = folder / name
        invocation = command(frozen, args.title, disk, rom, combined_keys, prefix, controlled)
        print("START: continuous native", args.title, name, flush=True)
        try:
            result = subprocess.run(invocation, capture_output=True, text=True, timeout=args.timeout)
        except subprocess.TimeoutExpired as error:
            def partial(value):
                return value.decode(errors="replace") if isinstance(value, bytes) else (value or "")
            result = subprocess.CompletedProcess(invocation, 124, partial(error.stdout),
                partial(error.stderr) + "\nIncomplete host timeout; no gameplay acceptance.\n")
        prefix.with_suffix(".stdout").write_text(result.stdout)
        prefix.with_suffix(".stderr").write_text(result.stderr)
        record = {"name": name, "command": invocation, "returncode": result.returncode}
        if result.returncode == 0:
            record["report"] = json.loads(result.stdout.splitlines()[-1])
            record["artifacts_sha256"] = {ext: sha(prefix.with_suffix("." + ext))
                                         for ext in ("ram", "subram", "text", "attr", "cpu", "ppm")}
        print("TERMINAL:", args.title, name, result.returncode, flush=True)
        return record

    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        jobs = [pool.submit(run, name, controlled) for name, controlled in
                (("idle", False), ("controlled", True), ("repeat", True))]
        for job in jobs:
            evidence["runs"].append(job.result())
            provenance.write_text(json.dumps(evidence, indent=2) + "\n")
    positions = {}
    for record in evidence["runs"]:
        assert record["returncode"] == 0, f"incomplete native run: {record['name']}"
        report = record["report"]
        check_profile(report)
        duration, joystick = plan(args.title, record["name"] != "idle")
        assert report["time_ps"] == duration * 1000000000 and report["frames"] > 1000
        assert report["disk_requests"] > 0 and report["disk_writes"] == 0
        assert report["download_bytes"] == 4095 and report["ps2_bytes_sent"] == len(events)
        assert report["joystick_events_applied"] == len(joystick) and report["joystick_events_pending"] == 0
        assert (report["frame_width"], report["frame_height"]) == (320 if args.title == "galaga" else 640, 200)
        memory = (folder / (record["name"] + ".ram")).read_bytes()
        positions[record["name"]] = player(args.title, memory)
        if args.title == "druaga" and record["name"] != "idle":
            assert memory[0xF82A] == 3, "native left direction missing"
    idle, moved = positions["idle"], positions["controlled"]
    assert moved[1] == idle[1] and (moved[0] > idle[0] if args.title == "galaga" else moved[0] < idle[0]), positions
    controlled, repeated = evidence["runs"][1:]
    assert controlled["report"] == repeated["report"]
    for ext in ("ram", "subram", "text", "attr", "cpu", "ppm"):
        assert (folder / ("controlled." + ext)).read_bytes() == (folder / ("repeat." + ext)).read_bytes(), ext
    assert (folder / "idle.ppm").read_bytes() != (folder / "controlled.ppm").read_bytes()
    assert all(sha(pathlib.Path(p)) == digest for p, digest in originals.items())
    assert sha(frozen) == originals[str(exe)] and sha(combined_keys) == combined_hash
    evidence.update(gameplay_verified=True, unchanged_inputs=True, idle_player=idle, controlled_player=moved)
    provenance.write_text(json.dumps(evidence, indent=2) + "\n")
    print(json.dumps({"title": args.title, "idle_player": idle, "controlled_player": moved,
                      "runner_sha256": sha(frozen)}), flush=True)
    print("PASS: continuous timing native cold movement, RGB change, full dump/report repeatability, unchanged inputs", flush=True)


if __name__ == "__main__":
    main()
