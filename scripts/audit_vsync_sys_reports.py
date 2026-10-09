"""Strict bounded VSYNC report audit; not physical fanout/MTBF acceptance.

The asynchronous input is reported separately, never called a timing pass.
Requires the native two-stage inventory; no timing exceptions are created.
"""
import argparse
import math
import pathlib
import re

SYS = "emu|pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk"
FIRST = "x1_vsync_sys:hdmi_vsync_to_sys|sample_pipe[0]"
LAST = "x1_vsync_sys:hdmi_vsync_to_sys|sample_pipe[1]"


def rows(path):
    result = []
    for line in path.read_text().splitlines():
        fields = [f.strip() for f in line.split(";")]
        if len(fields) != 10 or not re.fullmatch(r"-?\d+(?:\.\d+)?", fields[1]):
            continue
        row = fields[1:9]
        for index in (0, 5, 6, 7):
            value = float(row[index])
            assert math.isfinite(value), f"nonfinite numeric field: {path}"
        result.append(row)
    assert result, f"empty summary is not acceptance: {path}"
    assert len(result) < 10000, f"report cap reached: {path}"
    return result


def audit(directory, raw_source):
    synchronous = []
    asynchronous = []
    files = 0
    for model in ("slow", "fast"):
        for temperature in (-40, 0, 85, 100):
            for check in ("setup", "hold"):
                prefix = directory / f"sharpx1_turbo_z_video_vsync_sys_{model}_{temperature}"
                reports = {kind: rows(pathlib.Path(str(prefix) + f"_{kind}_{check}.rpt"))
                           for kind in ("input", "chain", "first_fanout", "consumer")}
                files += 4
                for kind in ("chain", "first_fanout"):
                    assert len(reports[kind]) == 1, f"unexpected {kind} coverage"
                    r = reports[kind][0]
                    assert r[1:5] == [FIRST, LAST, SYS, SYS], f"wrong {kind} scope"
                assert reports["chain"] == reports["first_fanout"], "stage-zero paths differ from chain"
                consumers = reports["consumer"]
                assert len(consumers) == 3 and {r[2] for r in consumers} == {"vs_d0", "vs_d1", "vsd"}, "consumer inventory changed"
                for r in consumers:
                    assert r[1] == LAST and r[3:5] == [SYS, SYS], "wrong consumer launch/domain"
                for kind in ("chain", "first_fanout", "consumer"):
                    for r in reports[kind]:
                        assert float(r[0]) >= 0, f"negative synchronous {kind} {model}/{temperature}/{check}"
                        assert 0 <= float(r[7]) < 31.25, "physical synchronous data delay out of period"
                        synchronous.append(float(r[0]))
                inputs = reports["input"]
                assert len(inputs) == 2 and {r[3] for r in inputs} == {"x1_hdmi_mux", "x1_video_mux"}, "input alias coverage changed"
                for r in inputs:
                    assert r[1:3] == [raw_source, FIRST] and r[4] == SYS, "wrong asynchronous endpoint"
                    asynchronous.append(float(r[0]))
    print(f"PASS: {files} VSYNC reports; 80 synchronous rows minimum {min(synchronous):+.3f} ns")
    print(f"OPEN: 32 asynchronous input rows minimum {min(asynchronous):+.3f} ns; not timing acceptance or an exception")
    return len(synchronous), min(synchronous), len(asynchronous), min(asynchronous)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=pathlib.Path)
    parser.add_argument("--raw-source", required=True, help="actual native fitted VSYNC source name")
    args = parser.parse_args()
    audit(args.directory, args.raw_source)


if __name__ == "__main__":
    main()
