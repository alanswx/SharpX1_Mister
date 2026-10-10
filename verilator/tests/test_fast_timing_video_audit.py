"""Synthetic report comparison controls, not simulator execution."""
import contextlib
import io
import json
import pathlib
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "scripts"))
import audit_fast_timing_video as checker

reports = []
for mode in sorted(checker.MODES):
    report = {key: 1 for key in checker.FIELDS}
    report.update(mode=mode, width=320 if "-40" in mode else 640, height=200,
                  frame_hash="1" * 16, program_sha256="a" * 64,
                  font_source_sha256="b" * 64, font16_sha256=None,
                  sys_hz=32000000, video_hz=28571428, turbo_raster=None,
                  nominal_x3_timing_verified=False, executable_sha256="c" * 64)
    reports.append(report)

with tempfile.TemporaryDirectory(prefix="x1-fast-timing-audit-") as temp:
    root = pathlib.Path(temp)
    baseline, fast = root / "baseline.log", root / "fast.log"
    def write(path, data, delayed):
        path.write_text("\n".join(json.dumps(dict(r, intra_assignment_delays=delayed)) for r in data) + "\n")
    write(baseline, reports, True)
    write(fast, reports, False)
    def execute():
        with contextlib.redirect_stdout(io.StringIO()):
            checker.audit(baseline, fast)
    execute()
    faults = []
    for field in checker.FIELDS:
        altered = [dict(r) for r in reports]
        altered[0][field] = "wrong" if isinstance(altered[0][field], str) else 2
        faults.append((field, altered, False))
    faults.append(("missing", reports[:-1], False))
    faults += [("duplicate", reports + [reports[0]], False), ("wrong_profile", reports, True)]
    changed = [dict(r) for r in reports]
    changed[0]["executable_sha256"] = "d" * 64
    faults.append(("runner_changed", changed, False))
    for name, data, delayed in faults:
        write(fast, data, delayed)
        try:
            execute()
        except AssertionError:
            pass
        else:
            raise AssertionError(f"invalid fast/reference reports accepted: {name}")
print(f"PASS: eighteen-case logged comparison; {len(faults)} invalid timing/input/profile/coverage controls (synthetic)")
