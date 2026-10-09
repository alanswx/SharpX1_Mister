"""Bounded completed-fit packet probe; raw CDC and global closure stay separate."""
import argparse
import pathlib
import re

from audit_crtc_write_reports import PACKET, PREFIX, SYS, VIDEO
from audit_vsync_sys_reports import rows


def audit(directory, native_log):
    log = native_log.read_text()
    assert "TimeQuest Timing Analyzer was successful. 0 errors" in log, "native probe not successful"
    assert not re.search(r"^\s*(?:Error\b|Warning.*Ignored filter)", log, re.MULTILINE), "native error/ignored filter"
    marker = "CRTC packet candidate: nine exact physical pairs; max 23.28 ns/min 0; raw inputs untouched"
    assert log.count(marker) == 1, "candidate did not apply exactly once"
    sources = re.findall(r"CRTC packet probe actual ACK source ([^\s]+)", log)
    assert len(sources) == 1 and sources[0] in {
        PREFIX + "acknowledgement", PREFIX + "acknowledgement~DUPLICATE"}, "wrong actual ACK source"
    packet_slack, delays, raw_slack = [], [], []
    global_min = {stage: {check: [] for check in ("setup", "hold")} for stage in ("before", "after")}
    files = 0
    for model in ("slow", "fast"):
        for temperature in (-40, 0, 85, 100):
            for check in ("setup", "hold"):
                reports = {}
                for stage in ("before", "after"):
                    reports[stage] = {}
                    for kind in ("packet", "request_input", "ack_input", "global"):
                        filename = f"sharpx1_turbo_z_video_crtc_packet_probe_{stage}_{model}_{temperature}_{kind}_{check}.rpt"
                        reports[stage][kind] = rows(directory / filename)
                        files += 1
                    packet = reports[stage]["packet"]
                    assert len(packet) == 9 and {(r[1], r[2]) for r in packet} == set(PACKET.items()), "incomplete/aliased packet pairs"
                    assert all(r[3:5] == [SYS, VIDEO] for r in packet), "wrong packet clock direction"
                    assert all(0 <= float(r[7]) < 23.28 for r in packet), "physical packet budget exceeded"
                    if stage == "after":
                        assert all(float(r[0]) >= 0 for r in packet), "negative candidate packet slack"
                        packet_slack.extend(float(r[0]) for r in packet)
                        delays.extend(float(r[7]) for r in packet)
                    for kind, source, target, clocks in (
                        ("request_input", PREFIX + "request", PREFIX + "request_meta", [SYS, VIDEO]),
                        ("ack_input", sources[0], PREFIX + "acknowledgement_meta", [VIDEO, SYS])):
                        raw = reports[stage][kind]
                        assert len(raw) == 1 and raw[0][1:5] == [source, target, *clocks], "wrong/excluded raw scope"
                        if stage == "after":
                            assert raw == reports["before"][kind], "packet constraint changed raw input timing"
                            raw_slack.append(float(raw[0][0]))
                    global_min[stage][check].append(min(float(r[0]) for r in reports[stage]["global"]))
                before = {(r[1], r[2]): r[7] for r in reports["before"]["packet"]}
                after = {(r[1], r[2]): r[7] for r in reports["after"]["packet"]}
                assert before == after, "probe changed physical packet routing/delay"
    minima = {stage: {check: min(values) for check, values in checks.items()}
              for stage, checks in global_min.items()}
    print(f"PASS: {files} before/after reports; {len(packet_slack)} candidate packet rows minimum {min(packet_slack):+.3f} ns, physical maximum {max(delays):.3f} ns")
    print(f"OPEN: {len(raw_slack)} unchanged raw request/ACK rows minimum {min(raw_slack):+.3f} ns; no input waiver or MTBF claim")
    print(f"GLOBAL WORST-REPORTED MINIMA (not closure): {minima}")
    return files, min(packet_slack), max(delays), min(raw_slack), minima


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=pathlib.Path)
    parser.add_argument("--native-log", required=True, type=pathlib.Path)
    args = parser.parse_args()
    audit(args.directory, args.native_log)
