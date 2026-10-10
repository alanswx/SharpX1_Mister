"""Audit fitted csync stage/consumer timing; raw/global timing stays separate."""
import argparse
import hashlib
import pathlib
import re

from audit_vsync_sys_reports import rows, SYS

VID = "emu|turbo_video_pll|oscillator|general[0].gpll~PLL_OUTPUT_COUNTER|divclk"
PREFIX = "x1_hdmi_clock_handoff:hdmi_handoff|"
PAIRS = {
    "epoch_stage": ("dv_epoch_meta", "dv_epoch_sample"),
    "csync_stage": ("dv_csync_meta", "dv_csync_sample"),
    "epoch_capture": ("dv_epoch_sample", "dv_policy_first"),
    "csync_capture": ("dv_csync_sample", "dv_csync_first"),
    "native_capture": ("dv_csync_sample", "dv_hs1"),
    "epoch_pipe1": ("dv_policy_first", "dv_policy_second"),
    "epoch_pipe2": ("dv_policy_second", "dv_policy_completed"),
    "csync_pipe1": ("dv_csync_first", "dv_csync_second"),
    "csync_pipe2": ("dv_csync_second", "dv_csync_completed"),
    "epoch_return": ("dv_policy_meta", "dv_policy_sample"),
    "csync_return": ("dv_csync_echo_meta", "dv_csync_echo_sample"),
    "native_pipe1": ("dv_hs1", "dv_hs2"),
    "native_pipe2": ("dv_hs2", "dv_hs"),
    "epoch_input": (PREFIX + "video_policy_epoch", "dv_epoch_meta"),
    "csync_input": (PREFIX + "active_mode[2]", "dv_csync_meta"),
    "epoch_echo_input": ("dv_policy_completed", "dv_policy_meta"),
    "csync_echo_input": ("dv_csync_completed", "dv_csync_echo_meta"),
}
FIRST = [("dv_epoch_meta", "dv_epoch_sample"), ("dv_csync_meta", "dv_csync_sample"),
         ("dv_policy_meta", "dv_policy_sample"), ("dv_csync_echo_meta", "dv_csync_echo_sample")]
INPUTS = list(PAIRS)[-4:]
CONSUMERS = {"epoch": "dv_policy_sample", "csync": "dv_csync_echo_sample"}


def audit_sources(log, source_root):
    names = ["rtl/x1_hdmi_clock_handoff.sv", "sys/sys_top.v", "csync_board_inventory_diagnostic.tcl"]
    names += [f"output_files/sharpx1_turbo_z_handoff.{extension}" for extension in ("sta.rpt", "sta.summary", "rbf")]
    hashes = re.findall(r"^([0-9a-f]{64})  (\S+)$", log.read_text(), re.M)
    assert len(hashes) == 12 and [name for _, name in hashes] == names * 2, "missing/reordered frozen hashes"
    assert hashes[:6] == hashes[6:], "source/original artifacts changed"
    paths = names[:2] + ["scripts/quartus_hdmi_csync_inventory.tcl"]
    assert [value for value, _ in hashes[:3]] == [hashlib.sha256((source_root / name).read_bytes()).hexdigest() for name in paths], "current source/reporter mismatch"


def audit(directory, log):
    text = log.read_text()
    assert text.count("TimeQuest Timing Analyzer was successful. 0 errors, 0 warnings") == 1
    assert not re.search(r"^\s*(?:Error|Warning|Critical Warning)\b", text, re.M)
    assert text.count("CSYNC BOARD INVENTORY COMPLETE: existing constraints only; not whole-board acceptance") == 1
    assert re.findall(r"^CSYNC BOARD PAIR (\S+) (\S+) (\S+)$", text, re.M) == [(kind, *pair) for kind, pair in PAIRS.items()]
    assert re.findall(r"^CSYNC BOARD FIRST FANOUT (\S+) (\S+)$", text, re.M) == FIRST
    assert re.findall(r"^CSYNC BOARD INPUT DRIVER (\S+) (\S+)$", text, re.M) == [(kind, PAIRS[kind][0]) for kind in INPUTS]
    fanouts = re.findall(r"^CSYNC BOARD CONSUMER (\S+) (\S+) \((\S+)\)$", text, re.M)
    assert fanouts and len(set(fanouts)) == len(fanouts)
    assert all(source in CONSUMERS.values() and target.startswith(PREFIX) and kind == "reg" for source, target, kind in fanouts)
    corners = [(model, str(t)) for model in ("slow", "fast") for t in (-40, 0, 85, 100)]
    assert re.findall(r"^CSYNC BOARD CORNER (slow|fast) (-?\d+) 1100$", text, re.M) == corners
    minima = {check: float("inf") for check in ("setup", "hold")}
    raw_minima, global_minima = minima.copy(), minima.copy()
    count = raw_count = 0
    for model, temperature in corners:
        for check in minima:
            for kind, (source, target) in PAIRS.items():
                report = rows(directory / f"{model}_{temperature}_{kind}_{check}.rpt")
                assert len(report) == 1 and report[0][1:3] == [source, target], f"wrong pair coverage {kind}"
                r = report[0]
                if kind in INPUTS:
                    clocks = [VID, SYS] if "echo" in kind else [SYS, VID]
                    assert r[3:5] == clocks, f"wrong raw crossing {kind}"
                    raw_minima[check] = min(raw_minima[check], float(r[0]))
                    raw_count += 1
                else:
                    clock = SYS if kind.endswith("return") else VID
                    assert r[3:5] == [clock, clock] and float(r[0]) >= 0, f"wrong/negative synchronous pair {kind}"
                    minima[check] = min(minima[check], float(r[0]))
                    count += 1
            for kind, source in CONSUMERS.items():
                path = directory / f"{model}_{temperature}_{kind}_consumer_{check}.rpt"
                report = rows(path)
                found = re.search(rf"Report Timing: Found (\d+) {check} paths", path.read_text())
                assert found and len(report) == int(found[1]) < 1000, "truncated consumer inventory"
                assert {r[2] for r in report} == {target for src, target, _ in fanouts if src == source}, "missing/substituted consumer"
                assert all(r[1] == source and r[3:5] == [SYS, SYS] and float(r[0]) >= 0 for r in report), "wrong/negative consumer timing"
                minima[check] = min(minima[check], *(float(r[0]) for r in report))
                count += len(report)
            report = rows(directory / f"{model}_{temperature}_global_{check}.rpt")
            assert len(report) == 50, "missing global diagnostic"
            global_minima[check] = min(global_minima[check], *(float(r[0]) for r in report))
    print(f"PASS: 320 csync reports, {count} synchronous stage/consumer rows, minima {minima}")
    print(f"OPEN: {raw_count} raw crossing rows {raw_minima}; global {global_minima}; MTBF/I/O and physical remain separate")
    return count, minima, raw_minima, global_minima


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=pathlib.Path)
    parser.add_argument("--native-log", required=True, type=pathlib.Path)
    parser.add_argument("--source-root", required=True, type=pathlib.Path)
    args = parser.parse_args()
    audit_sources(args.native_log, args.source_root)
    audit(args.directory, args.native_log)
