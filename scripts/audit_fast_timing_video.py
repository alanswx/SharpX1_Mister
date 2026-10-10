"""Compare ordinary logged video fixtures, not native/hardware acceptance."""
import argparse
import json
import pathlib
import re

MODES = {f"{kind}-{width}" for width in (40, 80) for kind in
         ("graphics", "text", "mixed", "pattern", "stretch", "pcg", "blink-off", "blink-on")}
MODES |= {"mixed-40-transition", "mixed-80-transition"}
FIELDS = ("width", "height", "frame_hash", "frames", "program_sha256",
          "font_source_sha256", "font16_sha256", "sys_hz", "video_hz",
          "reset_edges", "reference_cycles", "hs_period_ps", "vs_period_ps",
          "turbo_raster", "nominal_x3_timing_verified")


def collect(path, delayed):
    result = {}
    for line in path.read_text().splitlines():
        if not line.startswith("{"):
            continue
        report = json.loads(line)
        if "mode" not in report:
            continue
        mode = report["mode"]
        assert mode in MODES and mode not in result, "unknown/duplicate video fixture"
        assert report["intra_assignment_delays"] is delayed, "wrong timing profile"
        assert report["sys_hz"] == 32000000 and report["video_hz"] == 28571428, "not ordinary clocks"
        assert report["turbo_raster"] is None and report["nominal_x3_timing_verified"] is False, "not ordinary video"
        assert re.fullmatch(r"[0-9a-f]{64}", report["executable_sha256"]), "missing executable identity"
        for key in ("program_sha256", "font_source_sha256"):
            assert re.fullmatch(r"[0-9a-f]{64}", report[key]), "missing input identity"
        width = int(re.search(r"-(40|80)(?:-transition)?$", mode)[1]) * 8
        assert report["frames"] > 0 and report["width"] == width and report["height"] == 200
        assert re.fullmatch(r"[0-9a-f]{16}", report["frame_hash"]), "missing frame hash"
        result[mode] = report
    assert set(result) == MODES, "incomplete eighteen-case fixture coverage"
    assert len({r["executable_sha256"] for r in result.values()}) == 1, "runner changed during video fixtures"
    return result


def audit(baseline, fast):
    reference, candidate = collect(baseline, True), collect(fast, False)
    for mode in sorted(MODES):
        for field in FIELDS:
            assert reference[mode][field] == candidate[mode][field], (mode, field, reference[mode][field], candidate[mode][field])
    print("PASS: eighteen ordinary logged video/transition cases match frame hashes, clocks, frame counts and input identities; full-suite/native/hardware gates separate")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline", type=pathlib.Path)
    parser.add_argument("fast", type=pathlib.Path)
    args = parser.parse_args()
    audit(args.baseline, args.fast)
