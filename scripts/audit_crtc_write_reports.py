"""Source-bound CRTC timing audit; raw CDC inputs remain OPEN, not waived."""
import argparse
import pathlib
import re

from audit_vsync_sys_reports import rows, SYS
from audit_video_blink_reports import VIDEO

PREFIX = "emu:emu|sharpx1:sharpx1|x1_crtc_write:x3_crtc.writes|"
MPU_PREFIX = "emu:emu|sharpx1:sharpx1|x1_vid:display|crtc6845s:crtc6845s|mpu_if:mpu_if|"
KINDS = ("request_input", "request_chain", "request_first_fanout", "request_consumer",
         "ack_input", "ack_chain", "ack_first_fanout", "ack_consumer", "packet",
         "capture_consumer", "mpu_input", "mpu_consumer")
PACKET = {PREFIX + f"held_packet[{i}]": PREFIX + (f"video_data[{i}]" if i < 8 else "video_rs")
          for i in range(9)}


def keeper_tokens(value):
    names = [t.strip("{}") for t in re.findall(r"\{[^{}]+\}|[^\s{}]+", value)]
    assert names and len(names) == len(set(names)), "empty/duplicate native keepers"
    assert all(re.fullmatch(r"[A-Za-z0-9_:|.\[\]~/-]+", n) for n in names), "malformed keeper"
    return names


def inventory(log):
    content = log.read_text()
    assert "Evaluation of Tcl script" in content and "was successful" in content, "native reporter not successful"
    assert "TimeQuest Timing Analyzer was successful. 0 errors" in content, "native STA did not finish without errors"
    assert not re.search(r"^\s*Error\b", content, re.MULTILINE), "native log contains an error, including incomplete SDC"

    def matching(marker):
        return [line.split(marker + " ", 1)[1] for line in content.splitlines() if marker + " " in line]

    fields = {}
    for value in matching("CRTC transport register"):
        field, name = value.split(" ", 1)
        assert field not in fields and name == PREFIX + field, "wrong/duplicate transport inventory"
        fields[field] = name
    required = {"request", "request_meta", "request_sync", "acknowledgement", "acknowledgement_meta",
                "acknowledgement_sync", "video_rs", "pending_write"}
    required |= {f"held_packet[{i}]" for i in range(9)} | {f"video_data[{i}]" for i in range(8)}
    assert required <= fields.keys(), "missing transport bits/stages"
    assert fields.keys() <= required | {"busy", "done", "seen"}, "unexpected transport keeper"
    stages = {}
    for value in matching("CRTC native fanout"):
        field, targets = value.split(" ", 1)
        assert field not in stages, "duplicate stage fanout inventory"
        stages[field] = set(keeper_tokens(targets))
    assert set(stages) == {"request_meta", "request_sync", "acknowledgement_meta", "acknowledgement_sync"}
    for source, meta, sync in (("request", "request_meta", "request_sync"),
                              ("acknowledgement", "acknowledgement_meta", "acknowledgement_sync")):
        assert stages[meta] == {PREFIX + sync}, "first stage escaped synchronizer"
        fanins = matching("CRTC first-data fanin")
        sources = [line for line in fanins if re.match(re.escape(PREFIX + meta) + r"\|(d|asdata) ", line)]
        assert len(sources) == 1 and sources[0].endswith(" " + PREFIX + source + " (reg)"), "wrong native first-data source"
    mpu = matching("CRTC MPU register")
    assert mpu and len(mpu) == len(set(mpu)) and all(n.startswith(MPU_PREFIX) for n in mpu), "wrong MPU inventory"
    mpu = set(mpu)
    for field in ("R_Nadj", "R_Nr"):
        assert {n for n in mpu if n.startswith(MPU_PREFIX + field)} == {
            MPU_PREFIX + f"{field}[{i}]" for i in range(5)}, "missing/replicated R5/R9 bit"
    fanouts = {}
    for value in matching("CRTC endpoint native fanout"):
        source, targets = value.split(" ", 1)
        assert source not in fanouts, "duplicate native endpoint observation"
        fanouts[source] = set(keeper_tokens(targets))
    assert set(fanouts) == set(PACKET.values()) | mpu, "incomplete native packet/MPU fanout inventory"
    return stages, mpu, fanouts


def audit(directory, log):
    stages, mpu, fanouts = inventory(log)
    synchronous, raw, bundle = [], [], []
    files = 0
    for model in ("slow", "fast"):
        for temperature in (-40, 0, 85, 100):
            for check in ("setup", "hold"):
                prefix = f"sharpx1_turbo_z_video_crtc_write_{model}_{temperature}"
                reports = {kind: rows(directory / f"{prefix}_{kind}_{check}.rpt") for kind in KINDS}
                files += len(reports)
                for label, source, meta, sync, clock, other in (
                    ("request", "request", "request_meta", "request_sync", VIDEO, SYS),
                    ("ack", "acknowledgement", "acknowledgement_meta", "acknowledgement_sync", SYS, VIDEO)):
                    inputs = reports[label + "_input"]
                    assert len(inputs) == 1 and inputs[0][1:5] == [PREFIX + source, PREFIX + meta, other, clock], "wrong raw input scope/domain"
                    assert 0 <= float(inputs[0][7]) < 31.25, "invalid raw physical delay"
                    raw.append(float(inputs[0][0]))
                    chain = reports[label + "_chain"]
                    assert len(chain) == 1 and chain[0][1:5] == [PREFIX + meta, PREFIX + sync, clock, clock], "wrong synchronizer chain/domain"
                    assert reports[label + "_first_fanout"] == chain, "first-stage report escapes chain"
                    consumers = reports[label + "_consumer"]
                    assert {r[2] for r in consumers} == stages[sync], "missing/extra synchronized consumer"
                    assert all(r[1] == PREFIX + sync and r[3:5] == [clock, clock] for r in consumers), "wrong synchronized fanout domain"
                packet = reports["packet"]
                assert len(packet) == 9 and {(r[1], r[2]) for r in packet} == set(PACKET.items()), "missing/aliased packet bit"
                for r in packet:
                    assert r[3:5] == [SYS, VIDEO], "wrong packet clock direction"
                    # Minimum capture age is two VID periods; deliberately use
                    # a stricter one-period bound, not unrelated edge slack.
                    assert 0 <= float(r[7]) < 23.28, "packet exceeds strict physical bound"
                    bundle.append(float(r[7]))
                for kind, sources in (("capture_consumer", set(PACKET.values())), ("mpu_consumer", mpu)):
                    expected = {(s, t) for s in sources for t in fanouts[s]}
                    assert {(r[1], r[2]) for r in reports[kind]} == expected, f"incomplete native {kind} keepers"
                assert {r[2] for r in reports["mpu_input"]} == mpu, "incomplete MPU input coverage"
                for r in reports["mpu_input"]:
                    assert r[1] in mpu | set(PACKET.values()) | {PREFIX + "pending_write"}, "unexpected MPU launch source"
                for kind in KINDS:
                    if (kind.endswith("_input") and kind != "mpu_input") or kind == "packet":
                        continue
                    clock = SYS if kind.startswith("ack_") else VIDEO
                    for r in reports[kind]:
                        assert r[3:5] == [clock, clock], f"non-local clock in {kind}"
                        assert float(r[0]) >= 0, f"negative synchronous {kind} {model}/{temperature}/{check}"
                        assert 0 <= float(r[7]) < (31.25 if clock == SYS else 23.28), "synchronous data delay exceeds period"
                        synchronous.append(float(r[0]))
    print(f"PASS: {files} CRTC reports; {len(synchronous)} native-covered synchronous rows minimum {min(synchronous):+.3f} ns; {len(bundle)} bounded packet rows maximum {max(bundle):.3f} ns")
    print(f"OPEN: {len(raw)} raw input rows minimum {min(raw):+.3f} ns; no exceptions, MTBF or global/hardware acceptance")
    return files, min(synchronous), max(bundle), min(raw)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=pathlib.Path)
    parser.add_argument("--native-log", required=True, type=pathlib.Path)
    args = parser.parse_args()
    audit(args.directory, args.native_log)
