"""Bounded fitted blink report coverage, not physical/MTBF acceptance."""
import argparse
import pathlib
import re

from audit_vsync_sys_reports import rows, SYS

VIDEO = "emu|turbo_video_pll|oscillator|general[0].gpll~PLL_OUTPUT_COUNTER|divclk"
PREFIX = "emu:emu|sharpx1:sharpx1|x1_video_blink:x3_blink.video_blink|crossing.sample_pipe"
FIRST, LAST = PREFIX + "[0]", PREFIX + "[1]"
SOURCE = "emu:emu|sharpx1:sharpx1|x1_sub:subCPU|mr16_x1:sub_cpu|O_P1[4]"


def native_consumers(log):
    content = log.read_text()
    markers = ("video blink stage 0 native fanout", "video blink stage 1 native fanout")
    found = []
    for marker in markers:
        lines = [line.split(marker + " ", 1)[1] for line in content.splitlines()
                 if marker + " " in line]
        assert len(lines) == 1, f"missing/duplicate native inventory: {marker}"
        names = [token.strip("{}") for token in re.findall(r"\{[^{}]+\}|[^\s{}]+", lines[0])]
        assert all(re.fullmatch(r"[A-Za-z0-9_:|.\[\]~/-]+", n) for n in names), "malformed keeper inventory"
        assert len(names) == len(set(names)), "duplicate native keepers"
        found.append(names)
    assert found[0] == [LAST], "native stage zero escaped the synchronizer"
    assert found[1] and FIRST not in found[1] and LAST not in found[1]
    assert "first-data fanin " + SOURCE + " (reg)" in content, "native blink source not confirmed"
    assert "Evaluation of Tcl script" in content and "was successful" in content, "native tool not successful"
    return set(found[1])


def audit(directory, log):
    keepers = native_consumers(log)
    synchronous, asynchronous = [], []
    files = 0
    for model in ("slow", "fast"):
        for temperature in (-40, 0, 85, 100):
            for check in ("setup", "hold"):
                prefix = f"sharpx1_turbo_z_video_video_blink_{model}_{temperature}"
                reports = {kind: rows(directory / f"{prefix}_{kind}_{check}.rpt")
                           for kind in ("input", "chain", "first_fanout", "consumer")}
                files += 4
                inputs = reports["input"]
                assert len(inputs) == 1 and inputs[0][1:5] == [SOURCE, FIRST, SYS, VIDEO], "wrong raw-input scope"
                assert 0 <= float(inputs[0][7]) < 31.25, "invalid raw-input physical data delay"
                asynchronous.append(float(inputs[0][0]))
                assert len(reports["chain"]) == 1 and reports["chain"][0][1:5] == [FIRST, LAST, VIDEO, VIDEO], "wrong stage pair/domain"
                assert reports["chain"] == reports["first_fanout"], "stage-zero report escapes chain"
                consumers = reports["consumer"]
                assert {r[2] for r in consumers} == keepers, "reported consumers do not match independent native keepers"
                for r in consumers:
                    assert r[1] == LAST and r[3:5] == [VIDEO, VIDEO], "wrong consumer source/domain"
                for kind in ("chain", "first_fanout", "consumer"):
                    for r in reports[kind]:
                        assert float(r[0]) >= 0, f"negative synchronous blink {kind}"
                        assert 0 <= float(r[7]) < 23.28, "synchronous physical data exceeds video period"
                        synchronous.append(float(r[0]))
    print(f"PASS: {files} blink reports, {len(keepers)} independent native consumer keepers, {len(synchronous)} synchronous rows; minimum {min(synchronous):+.3f} ns")
    print(f"OPEN: {len(asynchronous)} raw asynchronous input rows, minimum {min(asynchronous):+.3f} ns; no input exception or physical/MTBF acceptance")
    return len(synchronous), min(synchronous), min(asynchronous)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=pathlib.Path)
    parser.add_argument("--native-log", required=True, type=pathlib.Path)
    args = parser.parse_args()
    audit(args.directory, args.native_log)
