#!/usr/bin/env python3
"""Group negative-slack CSV rows from quartus_global_failure_inventory.tcl.

Groups by check, clock pair and register hierarchy (bit indices and fitter
duplicate suffixes removed). Reporting aid only; grouping is not a CDC proof.
"""
import csv
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

CLOCKS = [
    ("turbo_video_pll", "VID"), ("emu|pll|", "SYS"), ("pll_hdmi", "HDMI"),
    ("pll_audio", "AUDIO"), ("h2f_user0_clk", "HPS"), ("FPGA_CLK1_50", "CLK1"),
    ("FPGA_CLK2_50", "CLK2"), ("FPGA_CLK3_50", "CLK3"), ("spi_sck", "SPI"), ("hdmi_sck", "I2C"),
]


def clock(name: str) -> str:
    for needle, short in CLOCKS:
        if needle in name:
            return short
    return name or "?"


def node(name: str, depth: int) -> str:
    name = re.sub(r"\[\d+\]", "[*]", name)
    name = re.sub(r"~DUPLICATE(_\d+)?", "", name)
    name = re.sub(r"~FF_\d+", "~FF", name)
    parts = name.split("|")
    if len(parts) > depth:
        parts = parts[:depth - 1] + ["...", parts[-1]]
    return "|".join(parts)


def main(directory: str, out: str, depth: str = "4") -> int:
    groups = defaultdict(lambda: {"rows": 0, "min": 0.0, "corners": set()})
    totals = {}
    for path in sorted(Path(directory).glob("*.csv")):
        model, temp, check = path.stem.split("_")
        with path.open(newline="") as fh:
            rows = list(csv.DictReader(fh))
        totals[path.stem] = len(rows)
        for row in rows:
            key = (check, clock(row["from_clock"]), clock(row["to_clock"]),
                   node(row["from"], int(depth)), node(row["to"], int(depth)))
            g = groups[key]
            g["rows"] += 1
            g["min"] = min(g["min"], float(row["slack"]))
            g["corners"].add(f"{model}_{temp}")
    ordered = sorted(groups.items(), key=lambda kv: kv[1]["min"])
    result = {
        "totals": totals,
        "groups": [
            {"check": k[0], "from_clock": k[1], "to_clock": k[2], "from": k[3], "to": k[4],
             "rows": v["rows"], "min_slack_ns": round(v["min"], 3), "corners": len(v["corners"])}
            for k, v in ordered
        ],
    }
    Path(out).write_text(json.dumps(result, indent=1) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
