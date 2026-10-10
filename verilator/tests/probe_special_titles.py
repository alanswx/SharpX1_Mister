"""Repeat cold native IPL probes of private Arcus/Bastard Special releases.

PASS means deterministic execution/RGB/RAM and unchanged assets, not game boot.
No RAM injection, restored snapshots, game patching, or writable disk output.
Run from verilator/ so inherited firmware paths resolve correctly.
"""
import argparse
import hashlib
import json
import pathlib
import shutil
import subprocess


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=pathlib.Path)
    parser.add_argument("title", choices=("arcus", "bastard-special"))
    parser.add_argument("--manifest", type=pathlib.Path, default=pathlib.Path("../software/special-unpacked/manifest.json"))
    parser.add_argument("--rom", type=pathlib.Path, default=pathlib.Path("../bios/ipl_x1.hex"))
    parser.add_argument("--seconds", type=int, default=16)
    parser.add_argument("--save-state", action="store_true",
                        help="retain each native cold state; requires a savable executable")
    parser.add_argument("--arcus-drive-b", type=int, choices=(2, 3, 4, 5),
                        help="explicit staged Arcus disk for B; exploratory, not a verified release disk order")
    parser.add_argument("--keys", type=pathlib.Path, default=pathlib.Path("tests/commercial_boot.keys"))
    parser.add_argument("--output", type=pathlib.Path, required=True,
                        help="new ignored directory; contains private RAM/frame evidence")
    parser.add_argument("--io-trace", action="store_true")
    parser.add_argument("--video-observations", action="store_true",
                        help="read-only planes, CRTC, palette, opcode populations and Turbo CTC; compared across cold runs")
    parser.add_argument("--fetch-start-ms", type=int, default=0,
                        help="opcode observation start relative to invocation; requires --video-observations")
    parser.add_argument("--fetch-end-ms", type=int, default=0,
                        help="exclusive opcode observation end; zero is unbounded")
    parser.add_argument("--bus-events", action="store_true", help="last sample per held bus transaction")
    parser.add_argument("--bus-start-ms", type=int, default=0)
    parser.add_argument("--bus-end-ms", type=int, default=0)
    parser.add_argument("--timeout", type=float, default=1800)
    parser.add_argument("--font16", type=pathlib.Path, help="local character-major 4096-byte Turbo ANK font")
    parser.add_argument("--rtc-controller", type=pathlib.Path,
                        help="local packed 8192-byte RTC controller for the separate non-savable runner")
    parser.add_argument("--kanji-physical", type=pathlib.Path,
                        help="authorized 131072-byte first-level physical Kanji candidate; opt-in runner only")
    parser.add_argument("--joya", type=lambda value: int(value, 0), help="exploratory held active-low joystick A pins")
    args = parser.parse_args()
    if args.seconds < 1:
        parser.error("--seconds must be positive")
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    if args.rtc_controller and args.save_state:
        parser.error("RTC probes are non-savable; do not request --save-state")
    if args.joya is not None and not 0 <= args.joya <= 255:
        parser.error("joya must fit one byte")
    if (args.bus_events or args.bus_start_ms or args.bus_end_ms) and not args.io_trace:
        parser.error("bus options require --io-trace")
    if (args.fetch_start_ms or args.fetch_end_ms) and not args.video_observations:
        parser.error("fetch window options require --video-observations")
    if not 0 <= args.fetch_start_ms <= 1000000000 or not 0 <= args.fetch_end_ms <= 1000000000 \
            or (args.fetch_end_ms and args.fetch_end_ms <= args.fetch_start_ms):
        parser.error("require 0 <= fetch-start-ms < fetch-end-ms <= 1000000000 (end 0 means unbounded)")
    manifest = args.manifest.resolve()
    row = next(r for r in json.loads(manifest.read_text())["games"] if r["slug"] == args.title)
    candidates = sorted((f for f in row["files"] if f["native_candidate"]), key=lambda f: f["member"])
    if not candidates:
        parser.error("no locally staged native disk candidate")
    # Arcus Disk 1, or the single Bastard Special disk. Other disks are preserved
    # in the staging manifest; this probe does not claim disk changes work.
    disk = manifest.parent / candidates[0]["path"]
    if digest(disk) != candidates[0]["sha256"]:
        parser.error("staged disk differs from manifest")
    disk_b = None
    member_b = None
    if args.arcus_drive_b:
        if args.title != "arcus":
            parser.error("--arcus-drive-b is only applicable to Arcus")
        member_b = next((f for f in candidates if f"Disk {args.arcus_drive_b}" in f["member"]), None)
        if member_b is None:
            parser.error("requested Arcus B disk is absent from the staging manifest")
        disk_b = manifest.parent / member_b["path"]
        if digest(disk_b) != member_b["sha256"]:
            parser.error("staged B disk differs from manifest")
    exe, rom, keys = (p.resolve() for p in (args.executable, args.rom, args.keys))
    originals = {str(p): digest(p) for p in (disk, rom, keys, manifest)}
    rtc_controller = args.rtc_controller.resolve() if args.rtc_controller else None
    if rtc_controller:
        if rtc_controller.stat().st_size != 8192:
            parser.error("RTC controller must contain exactly 8192 packed bytes")
        originals[str(rtc_controller)] = digest(rtc_controller)
    font16 = args.font16.resolve() if args.font16 else None
    if font16:
        if font16.stat().st_size != 4096:
            parser.error("font16 must contain exactly 4096 bytes")
        originals[str(font16)] = digest(font16)
    kanji = args.kanji_physical.resolve() if args.kanji_physical else None
    if kanji:
        if kanji.stat().st_size != 131072:
            parser.error("physical first-level Kanji must contain exactly 131072 bytes")
        originals[str(kanji)] = digest(kanji)
    if disk_b:
        originals[str(disk_b)] = digest(disk_b)
    folder = args.output.resolve()
    folder.mkdir(parents=True, exist_ok=False)
    # Freeze the executable while another agent rebuilds the shared runner.
    frozen = folder / "Vtop"
    executable_sha = digest(exe)
    shutil.copy2(exe, frozen)
    if digest(frozen) != executable_sha:
        raise RuntimeError("runner changed during copy; rerun with a new output directory")
    runs = []
    artifacts = (".ram", ".text", ".attr", ".subram", ".cpu", ".ppm")
    if args.save_state:
        artifacts += (".state",)
    if args.io_trace:
        artifacts += (".csv",)
    if args.video_observations:
        artifacts += (".gram-b", ".gram-r", ".gram-g", ".pcg-b", ".pcg-r", ".pcg-g",
                      ".video-palette", ".video-samples", ".crtc", ".cpu-fetches")
    for name in ("cold", "repeat"):
        prefix = folder / name
        command = [str(frozen), "--cycles", str(args.seconds * 32000000),
                   "--rom", str(rom), "--disk", str(disk), "--keys", str(keys),
                   "--dump", str(prefix), "--frame", str(prefix) + ".ppm"]
        if args.save_state:
            command += ["--save-state", str(prefix) + ".state"]
        if disk_b:
            command += ["--disk-b", str(disk_b)]
        if font16:
            command += ["--font16", str(font16)]
        if rtc_controller:
            command += ["--rtc-controller", str(rtc_controller)]
        if kanji:
            command += ["--kanji-physical", str(kanji)]
        if args.joya is not None:
            command += ["--joya", str(args.joya)]
        if args.video_observations:
            command += ["--video-dump", str(prefix)]
            if args.fetch_start_ms or args.fetch_end_ms:
                command += ["--fetch-start-ms", str(args.fetch_start_ms), "--fetch-end-ms", str(args.fetch_end_ms)]
        if args.io_trace:
            command += ["--bus-trace", str(prefix) + ".csv", "--io-only"]
            if args.bus_events:
                command += ["--bus-events"]
            command += ["--bus-start-ms", str(args.bus_start_ms), "--bus-end-ms", str(args.bus_end_ms)]
        try:
            result = subprocess.run(command, capture_output=True, text=True, timeout=args.timeout)
        except subprocess.TimeoutExpired as error:
            # Preserve failed probes too; never promote a partial frame or
            # one completed cold run to repeatability/game acceptance.
            def partial(value):
                return value.decode(errors="replace") if isinstance(value, bytes) else (value or "")
            result = subprocess.CompletedProcess(command, 124,
                partial(error.stdout), partial(error.stderr) +
                f"\nHost wall-clock timeout after {args.timeout} seconds; simulation did not complete.\n")
        prefix.with_suffix(".stdout").write_text(result.stdout)
        prefix.with_suffix(".stderr").write_text(result.stderr)
        record = {"command": command, "returncode": result.returncode}
        if result.returncode == 0:
            report = json.loads(result.stdout.splitlines()[-1])
            if args.fetch_start_ms or args.fetch_end_ms:
                if report.get("fetch_start_ms") != args.fetch_start_ms \
                        or report.get("fetch_end_ms") != args.fetch_end_ms \
                        or report.get("fetch_window_policy") != "whole_completed_m1_half_open":
                    raise RuntimeError("runner did not qualify the requested opcode observation window")
            run_artifacts = artifacts
            if args.video_observations and report.get("turbo_foundation"):
                run_artifacts += (".video-controls", ".ctc")
            record.update(report=report, artifacts={suffix: digest(pathlib.Path(str(prefix) + suffix))
                                                   for suffix in run_artifacts})
            if report["disk_writes"] != 0:
                raise RuntimeError("protected native probe wrote disk")
        runs.append(record)
    unchanged = all(digest(pathlib.Path(p)) == h for p, h in originals.items())
    repeated = (all(r["returncode"] == 0 for r in runs)
                and runs[0]["report"] == runs[1]["report"]
                and runs[0]["artifacts"] == runs[1]["artifacts"])
    evidence = {"title": args.title, "disk_member": candidates[0]["member"],
                "disk_b_member": member_b["member"] if member_b else None,
                "disk_order_verified": False,
                "archive_sha256": row.get("archive_sha256"), "inputs_sha256": originals,
                "executable_sha256": executable_sha, "cycles_reference_hz": 32000000,
                "duration_seconds": args.seconds, "runs": runs,
                "rtc_controller_used": bool(rtc_controller),
                "video_observations": args.video_observations,
                "unchanged_inputs": unchanged, "repeatable": repeated,
                "boot_observation": "requires inspection of native PPM; execution is not game boot",
                "gameplay_verified": False}
    (folder / "evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")
    print(json.dumps({"title": args.title, "repeatable": repeated, "unchanged_inputs": unchanged,
                      "evidence": str(folder / "evidence.json"), "runs": [r.get("report", r) for r in runs]}))
    if not unchanged or not repeated:
        raise SystemExit("FAIL: inspect retained evidence (including media rejection); no boot claim")
    print("PASS: repeatable native probe, unchanged inputs; game boot/playability not asserted")


if __name__ == "__main__":
    main()
