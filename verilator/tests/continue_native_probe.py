"""Continue an unchanged, successful native probe using its frozen runner.

Run from verilator/. Preserves the original clock/model profile and asset
hashes; never loads ROM, fonts or RAM on restore. Checkpoints are accepted
only by the runner's quiescence checks. No gameplay assertion is made here.
"""
import argparse
import hashlib
import json
import pathlib
import subprocess


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", type=pathlib.Path)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    parser.add_argument("--chunks-ms", type=int, nargs="+", required=True)
    parser.add_argument("--timeout", type=float, default=7200)
    parser.add_argument("--final-keys", type=pathlib.Path,
                        help="relative-time key events in the final continuation only")
    parser.add_argument("--from-continuation", type=pathlib.Path,
                        help="resume the last verified checkpoint of this probe's continuation provenance")
    args = parser.parse_args()
    if args.timeout <= 0 or any(ms <= 0 for ms in args.chunks_ms):
        parser.error("timeout and all chunk durations must be positive")
    evidence_path = args.evidence.resolve()
    evidence = json.loads(evidence_path.read_text())
    if not evidence["repeatable"] or not evidence["unchanged_inputs"]:
        parser.error("requires a successful, repeatable native cold probe")
    cold = evidence["runs"][0]
    original = cold["command"]
    runner = pathlib.Path(original[0])
    state = pathlib.Path(original[original.index("--save-state") + 1])
    disk = pathlib.Path(original[original.index("--disk") + 1])
    if "--disk-b" in original:
        parser.error("dual-drive snapshots are unsupported")
    expected = dict(evidence["inputs_sha256"])
    expected[str(evidence_path)] = sha(evidence_path)
    expected[str(runner)] = evidence["executable_sha256"]
    expected[str(state)] = cold["artifacts"][".state"]
    elapsed = evidence["duration_seconds"] * 1000
    if args.from_continuation:
        parent_path = args.from_continuation.resolve()
        parent = json.loads(parent_path.read_text())
        if parent["cold_evidence"] != str(evidence_path) or not parent["unchanged_inputs"]:
            parser.error("continuation does not belong to this unchanged cold probe")
        if not parent["continuations"] or any(r["returncode"] for r in parent["continuations"]):
            parser.error("cannot resume an incomplete continuation chain")
        for path, digest in parent["inputs_sha256"].items():
            if path in expected and expected[path] != digest:
                parser.error("continuation changes an original asset identity")
            expected[path] = digest
        expected[str(parent_path)] = sha(parent_path)
        last = parent["continuations"][-1]
        command = last["command"]
        if command[0] != str(runner) or command[command.index("--disk") + 1] != str(disk):
            parser.error("continuation runner/media differ from the original probe")
        state = pathlib.Path(command[command.index("--save-state") + 1])
        expected[str(state)] = last["state_sha256"]
        elapsed = last["absolute_duration_ms"]
    keys = args.final_keys.resolve() if args.final_keys else None
    if keys:
        last_ms = max(int(line.split()[0]) for line in keys.read_text().splitlines()
                      if line.strip() and not line.lstrip().startswith("#"))
        if last_ms >= args.chunks_ms[-1]:
            parser.error("final chunk must include all key events before checkpoint")
        expected[str(keys)] = sha(keys)
    if not all(sha(pathlib.Path(p)) == h for p, h in expected.items()):
        parser.error("native runner, checkpoint or source asset changed")
    folder = args.output.resolve()
    folder.mkdir(parents=True, exist_ok=False)
    records = []
    for i, ms in enumerate(args.chunks_ms):
        elapsed += ms
        prefix = folder / f"native{elapsed}ms"
        command = [str(runner), "--cycles", str(ms * evidence["cycles_reference_hz"] // 1000),
                   "--disk", str(disk), "--restore-state", str(state),
                   "--save-state", str(prefix) + ".state", "--dump", str(prefix),
                   "--frame", str(prefix) + ".ppm"]
        if keys and i == len(args.chunks_ms) - 1:
            command += ["--keys", str(keys)]
        try:
            result = subprocess.run(command, capture_output=True, text=True, timeout=args.timeout)
        except subprocess.TimeoutExpired as error:
            def partial(value):
                return value.decode(errors="replace") if isinstance(value, bytes) else (value or "")
            result = subprocess.CompletedProcess(command, 124, partial(error.stdout),
                partial(error.stderr) + f"\nHost timeout after {args.timeout}s; incomplete.\n")
        prefix.with_suffix(".stdout").write_text(result.stdout)
        prefix.with_suffix(".stderr").write_text(result.stderr)
        record = {"command": command, "returncode": result.returncode,
                  "absolute_duration_ms": elapsed}
        if result.returncode == 0:
            report = json.loads(result.stdout.splitlines()[-1])
            if report["disk_writes"] or report["time_ps"] != elapsed * 1000000000:
                raise RuntimeError("unexpected media write or simulation duration")
            state = prefix.with_suffix(".state")
            record.update(report=report, state_sha256=sha(state))
        records.append(record)
        unchanged = all(sha(pathlib.Path(p)) == h for p, h in expected.items())
        (folder / "provenance.json").write_text(json.dumps({
            "cold_evidence": str(evidence_path), "inputs_sha256": expected,
            "parent_continuation": str(args.from_continuation.resolve()) if args.from_continuation else None,
            "continuations": records, "unchanged_inputs": unchanged,
            "gameplay_verified": False}, indent=2) + "\n")
        if result.returncode or not unchanged:
            raise SystemExit("FAIL: retained evidence; no boot/playability claim")
        print(f"native {elapsed}ms: {report['frame_hash']}", flush=True)
    print("PASS: unchanged native continuation; gameplay not asserted")


if __name__ == "__main__":
    main()
