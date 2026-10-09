"""Independent clock-only ALTCLKCTRL waveform audit; not FPGA acceptance."""
import argparse
import itertools
import pathlib
import re

FIELDS = {"clk_vid", "clk_hdmi", "outclk", "transition", "select_video",
          "run_vid", "run_hdmi", "checked", "video_half", "hdmi_half", "stop_profile"}


def read_vcd(path):
    """Group delta changes at one physical time; ignore vendor-private hierarchy."""
    lines = path.read_text().splitlines()
    scope, codes = [], {}
    start = None
    assert re.search(r"\$timescale\s+1ps\s+\$end", "\n".join(lines)), "wrong time units"
    for index, line in enumerate(lines):
        words = line.split()
        if line.startswith("$scope"):
            scope.append(words[2])
        elif line.startswith("$upscope"):
            scope.pop()
        elif line.startswith("$var") and scope == ["hdmi_vendor_clock_tb"]:
            if words[4] in FIELDS:
                assert words[3] not in codes, "duplicate top signal code"
                codes[words[3]] = words[4]
        elif line.startswith("$enddefinitions"):
            start = index + 1
            break
    assert start is not None and set(codes.values()) == FIELDS, "incomplete clock waveform"
    values, changes, now = {}, {}, 0
    for line in lines[start:]:
        if line.startswith("#"):
            time = int(line[1:])
            assert time >= now, "nonmonotonic time"
            if time != now:
                if changes:
                    values.update(changes)
                    yield now, values.copy()
                changes, now = {}, time
        elif line and line[0] in "01xXzZ":
            if line[1:] in codes:
                changes[codes[line[1:]]] = line[0].lower()
        elif line.startswith("b"):
            bits, code = line[1:].split()
            if code in codes:
                assert not re.search("[xXzZ]", bits), "unknown top integer"
                changes[codes[code]] = int(bits, 2)
    if changes:
        values.update(changes)
        yield now, values.copy()


def audit_events(events, video_half, hdmi_half, profile):
    previous, last_edge = None, None
    edges, steady_edges, requests, stopped = 0, 0, [], None
    min_interval = None
    stops, recoveries = 0, 0
    for time, value in events:
        assert all(value.get(field) in {"0", "1"} for field in FIELDS - {
            "checked", "video_half", "hdmi_half", "stop_profile"}), "unknown/missing clock or control"
        assert (value["video_half"], value["hdmi_half"], value["stop_profile"]) == (
            video_half, hdmi_half, profile), "waveform/profile mismatch"
        if profile == 0:
            assert value["run_vid"] == value["run_hdmi"] == "1", "running profile stopped a source"
        if previous is None:
            previous = value
            continue
        if value["select_video"] != previous["select_video"]:
            requests.append(value["select_video"])
        run = "run_vid" if profile == 1 else "run_hdmi"
        if profile and value[run] != previous[run]:
            if value[run] == "0":
                assert stopped is None, "nested stopped interval"
                stopped = time
                stops += 1
            else:
                assert stopped is not None and time - stopped >= 200000, "short/missing stop"
                assert previous["outclk"] == "0", "stopped output not quiescent"
                stopped = None
                recoveries += 1
        if value["outclk"] != previous["outclk"]:
            edges += 1
            if last_edge is not None:
                interval = time - last_edge
                assert interval >= min(video_half, hdmi_half), "short output interval"
                min_interval = interval if min_interval is None else min(min_interval, interval)
            last_edge = time
            if value["outclk"] == "1":
                assert any(value[s] == "1" and previous[s] == "0"
                           for s in ("clk_vid", "clk_hdmi")), "output rise away from both sources"
            if stopped is not None and time > stopped + 2 * max(video_half, hdmi_half):
                raise AssertionError("stopped-clock output did not become quiescent")
            if time >= 100000 and value["transition"] == "0":
                source = "clk_vid" if value["select_video"] == "1" else "clk_hdmi"
                assert value[source] == value["outclk"] and previous[source] != value[source], "steady wrong source"
                steady_edges += 1
        previous = value
    assert previous is not None and previous["checked"] == 48, "incomplete steady checks"
    assert previous["transition"] == previous["select_video"] == "0", "unfinished handoff"
    assert requests == ["1", "0"] and steady_edges >= 48 and edges >= 48, "incomplete switch coverage"
    assert stops == recoveries == (1 if profile else 0) and stopped is None, "incomplete stopped-clock recovery"
    return edges, steady_edges, min_interval


def audit_directory(root):
    results = []
    for video, hdmi, profile in itertools.product((11640, 17500), (3366, 6250, 10000), range(3)):
        path = root / f"matrix-{video}-{hdmi}-{profile}" / "vendor-clock.vcd"
        result = audit_events(read_vcd(path), video, hdmi, profile)
        results.append(result)
        print(f"PASS: {path.parent.name}: edges={result[0]} steady={result[1]} minimum interval={result[2]} ps")
    print(f"PASS: {len(results)} native clock waveforms; no board/data-handoff/physical claim")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=pathlib.Path)
    audit_directory(parser.parse_args().directory)
