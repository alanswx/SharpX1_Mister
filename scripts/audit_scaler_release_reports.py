#!/usr/bin/env python3
"""Audit native scaler two-stage release before/after reports for one revision.

Checks all eight corners x three domains: stage 0 -> 1 setup/hold and released
reset recovery/removal exist, are non-empty, positive, start at the expected
stage and are unchanged by the candidate. Raw-input reports must be non-empty
before and empty after; an empty raw report is never treated as a timing pass.
HDMI/Avalon raw baselines are expected empty because inherited sys_top clock
groups exclude FPGA_CLK2_50 from those clocks; they are recorded as untimed.
"""
import json
import re
import sys
from pathlib import Path

PATH_RE = re.compile(r"Path #\d+: (Setup|Hold|Recovery|Removal) slack is (-?[\d.]+)")
FROM_RE = re.compile(r"^; From Node\s+; (.+?)\s+;", re.M)
TO_RE = re.compile(r"^; To Node\s+; (.+?)\s+;", re.M)
MODELS = [(m, t) for m in ("slow", "fast") for t in (-40, 0, 85, 100)]
DOMAINS = ("input", "output", "avalon")
KINDS = {"chain": ("setup", "hold"), "input": ("recovery", "removal"), "output": ("recovery", "removal")}


def parse(path: Path):
    text = path.read_text(encoding="latin-1")
    slacks = [float(s) for _, s in PATH_RE.findall(text)]
    return {"slacks": slacks, "from": FROM_RE.findall(text), "to": TO_RE.findall(text)}


def main(report_dir: str, revision: str, out: str) -> int:
    root = Path(report_dir)
    errors, summary = [], {}
    for model, temp in MODELS:
        for domain in DOMAINS:
            stage = f"x1_scaler_reset_release:\\x1_domain_reset:{domain}_release|release_pipe"
            for kind, checks in KINDS.items():
                for check in checks:
                    name = f"{model}_{temp}_{domain}_{kind}_{check}.rpt"
                    before = root / f"{revision}_scaler_release_probe_before_{name}"
                    after = root / f"{revision}_scaler_release_probe_after_{name}"
                    if not before.exists() or not after.exists():
                        errors.append(f"missing {name}")
                        continue
                    b, a = parse(before), parse(after)
                    key = f"{domain}_{kind}_{check}"
                    entry = summary.setdefault(key, {"paths": set(), "min": None})
                    if kind == "input":
                        if domain == "input" and not b["slacks"]:
                            errors.append(f"empty raw baseline {name}")
                        if domain != "input" and b["slacks"]:
                            errors.append(f"raw baseline unexpectedly timed {name}")
                        if a["slacks"]:
                            errors.append(f"raw input still timed after cut {name}")
                        entry["paths"].add(len(b["slacks"]))
                        m = min(b["slacks"], default=None)
                    else:
                        if not b["slacks"]:
                            errors.append(f"empty retained report {name}")
                        if b != a:
                            errors.append(f"retained report changed {name}")
                        if any(s < 0 for s in b["slacks"]):
                            errors.append(f"negative retained slack {name}")
                        want = f"{stage}[0]" if kind == "chain" else f"{stage}[1]"
                        if any(not f.endswith(want) for f in b["from"]):
                            errors.append(f"unexpected source in {name}")
                        if kind == "chain" and any(not t.endswith(f"{stage}[1]") for t in b["to"]):
                            errors.append(f"unexpected chain target in {name}")
                        entry["paths"].add(len(b["slacks"]))
                        m = min(b["slacks"], default=None)
                    if m is not None:
                        entry["min"] = m if entry["min"] is None else min(entry["min"], m)
    result = {
        "revision": revision,
        "status": "pass" if not errors else "fail",
        "errors": errors,
        "per_report": {k: {"path_counts": sorted(v["paths"]), "min_slack_ns": v["min"]} for k, v in summary.items()},
        "scope": "Digital STA reports only; raw inputs excluded by candidate, not physical reset/MTBF acceptance.",
    }
    Path(out).write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"status": result["status"], "errors": errors[:10]}, indent=2))
    return 0 if not errors else 1


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:4]))
