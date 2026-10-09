"""Audit the unselected input-only probe; no physical/native acceptance claim."""
import argparse
import pathlib
from audit_vsync_sys_reports import audit, rows


def audit_probe(directory, raw_source):
    audit(directory, raw_source, "sharpx1_turbo_z_video_vsync_sys_probe_before")
    paired = 0
    synchronous_rows = 0
    excluded = 0
    global_slacks = {(phase, check): [] for phase in ("before", "after") for check in ("setup", "hold")}
    for model in ("slow", "fast"):
        for temperature in (-40, 0, 85, 100):
            for check in ("setup", "hold"):
                prefix = directory / f"sharpx1_turbo_z_video_vsync_sys_probe_before_{model}_{temperature}"
                for kind in ("chain", "first_fanout", "consumer"):
                    before = pathlib.Path(str(prefix) + f"_{kind}_{check}.rpt")
                    after = pathlib.Path(str(before).replace("probe_before", "probe_after"))
                    assert rows(before) == rows(after), f"synchronous timing changed: {kind}/{model}/{temperature}/{check}"
                    paired += 1
                    synchronous_rows += len(rows(before))
                after_input = pathlib.Path(str(prefix).replace("probe_before", "probe_after") + f"_input_{check}.rpt")
                assert rows(after_input, allow_excluded=True) == [], "asynchronous input cut did not bind"
                excluded += 1
                for phase in ("before", "after"):
                    path = pathlib.Path(str(prefix).replace("probe_before", "probe_" + phase) + f"_global_{check}.rpt")
                    global_slacks[phase, check].extend(float(r[0]) for r in rows(path))
    assert paired == 48 and synchronous_rows == 80 and excluded == 16
    minima = {key: min(values) for key, values in global_slacks.items()}
    print("PASS: 48 identical synchronous before/after report pairs, 80 rows; 16 raw input reports explicitly excluded, not passes")
    for check in ("setup", "hold"):
        print(f"REPORTED GLOBAL {check}: before {minima['before', check]:+.3f} ns, after {minima['after', check]:+.3f} ns; physical/I/O gates separate")
    return minima


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=pathlib.Path)
    parser.add_argument("--raw-source", required=True)
    args = parser.parse_args()
    audit_probe(args.directory, args.raw_source)
