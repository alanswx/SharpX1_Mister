"""Audit same-fit context repair/data exclusions; not full-flow or FPGA acceptance."""
import argparse
import collections
import hashlib
import pathlib
import re

from audit_vsync_sys_reports import rows
from audit_hdmi_inactive_data_probe import CLOCKS, PREFETCH
from audit_hdmi_inactive_data_inventory import OUTPUTS
from audit_hdmi_csync_reports import INPUTS, PAIRS, VID, SYS, PREFIX
from audit_hdmi_held_mode_probe import KEYS

CORNERS = [(model, str(t)) for model in ("slow", "fast") for t in (-40, 0, 85, 100)]
PACKED = {"hdmi_dv_hs", "hdmi_dv_de", "hdmi_dv_data[0]", "hdmi_dv_data[6]", "hdmi_dv_data[17]"}
PACKED048 = {"hdmi_dv_hs", "hdmi_dv_de"} | {f"hdmi_dv_data[{i}]" for i in (3, 12, 13, 16, 17)}
PACKED3C = {"hdmi_dv_hs", "hdmi_dv_vs"} | {f"hdmi_dv_data[{i}]" for i in (6, 13, 16)}
PACKED16FA = {"hdmi_dv_hs", "hdmi_dv_vs"} | {f"hdmi_dv_data[{i}]" for i in (5, 6, 9, 11)}


def audit_provenance_16fa(log):
    """Bind only the original 16fa816 fit and its unselected v1 study inputs.

    The staged proposal's historical byte hash deliberately does not follow
    today's selected candidate, even when only comments have changed.
    """
    names = ["rtl/x1_hdmi_clock_handoff.sv", "sys/sys_top.v",
             "scripts/constraints/hdmi_held_mode_candidate.sdc"]
    names += ["../held-context-16fa816-v1/" + name for name in (
        "hdmi_held_mode_candidate.sdc", "hdmi_inactive_data_candidate.sdc",
        "quartus_held_sdc_context_probe.tcl")]
    names += [f"output_files/sharpx1_turbo_z_handoff.{ext}" for ext in (
        "fit.rpt", "fit.summary", "sta.rpt", "sta.summary", "rbf")]
    expected = [
        "1ea8f6f3c523efc8de5ecd176c7ff1bb4cf43f42bfb3641bcecf78798d91aeca",
        "583dd6f99967b8fc10df7f83ae92e6206f7c0874c51985669609831fcb800630",
        "e4266eaa455e0603b0df5e2a8439bfb69b36e98956d431808c7e73acf1f3d5e1",
        "e4266eaa455e0603b0df5e2a8439bfb69b36e98956d431808c7e73acf1f3d5e1",
        "208e236c48d5305ffe585dae9641e51a4b02f3dc0868c5ae6c4495d1599ad61f",
        "980d9cb7523d6b556af0a2f65ba693b85374244b30e20634ff79ac96885cb37f",
        "709c5d21abb2b045f53ee21ba37b93decf5e2e459b3b7f90e27529b5bbeb84d2",
        "21182a678ded966e9177777c758096c17ff54d23879d78b457ea72b4b60784b8",
        "8e79bcb271c9cd58c7afbac914956a52d601374178aa166b7a6b4c2449d91e89",
        "2838ece4f86af3367728e30fe013fa908c7b011fe82d7a774fdff36fd6ae9782",
        "45110cb947f00fa690e2b28a24cf666fc363bf9b37513d151c270645dbb6f483"]
    records = list(zip(expected, names))
    hashes = re.findall(r"^([0-9a-f]{64})  (\S+)$", log.read_text(), re.M)
    assert hashes == records * 2, "wrong/reordered/changed 16fa original fit or staged study provenance"
    return records


def verify_bound_files(root, records):
    """Check actual bytes, including all five artifacts, not just log equality."""
    for expected, name in records:
        assert hashlib.sha256((root / name).read_bytes()).hexdigest() == expected, f"bound file changed: {name}"


def audit_sources_16fa(log, root):
    verify_bound_files(root, audit_provenance_16fa(log))


def audit_sources_3c(log, root):
    """Exact 3c6242e original fit and cef2210 diagnostic inputs, not any RBF."""
    names = ["rtl/x1_hdmi_clock_handoff.sv", "sys/sys_top.v",
             "scripts/constraints/hdmi_held_mode_candidate.sdc"]
    staged = ["hdmi_held_mode_candidate.sdc", "hdmi_inactive_data_candidate.sdc",
              "quartus_held_sdc_context_probe.tcl"]
    names += ["../held-context-3c6242e-v1/" + name for name in staged]
    names += [f"output_files/sharpx1_turbo_z_handoff.{ext}"
              for ext in ("fit.rpt", "fit.summary", "sta.rpt", "sta.summary", "rbf")]
    expected = [
        "47ca9d7da65df077b8a3b20012a2ede6a98d638756fbc6a746c9b20c71f7f58a",
        "583dd6f99967b8fc10df7f83ae92e6206f7c0874c51985669609831fcb800630",
        "e4266eaa455e0603b0df5e2a8439bfb69b36e98956d431808c7e73acf1f3d5e1",
        "e4266eaa455e0603b0df5e2a8439bfb69b36e98956d431808c7e73acf1f3d5e1",
        "b9525e32811c49d1cb3144eae46c8dcb32c73f03ce7f375ecf17429ff88d2cb5",
        "980d9cb7523d6b556af0a2f65ba693b85374244b30e20634ff79ac96885cb37f",
        "1f1c32f1bbd0720cb30f6ef3424abde76c6b1ddc7998e54d7ff1d0ddbfd657e8",
        "f2e9648892464210ff30e08dc26d78eb1ac96a7c099a7805517dbda3e5811212",
        "1eb0fcc7ab73052e2541eb7fa6b1a325b29fc5d2933c1b60c8dfb9a81fcd6f2f",
        "e64eacd636a2543bcbd1c8fa95f50d2ae979a281dfea1a799662f9a6da07ad49",
        "7f6a2009cbebe2caa34fec785bd39a19da0ba58e4f970f2ca80b9f0384d5a993"]
    hashes = re.findall(r"^([0-9a-f]{64})  (\S+)$", log.read_text(), re.M)
    assert hashes == list(zip(expected, names)) * 2, "wrong/reordered/changed 3c fit or cef diagnostic provenance"
    paths = names[:3] + ["scripts/constraints/" + name for name in staged[:2]]
    paths += ["scripts/" + staged[2]]
    assert [hashlib.sha256((root / name).read_bytes()).hexdigest() for name in paths] == expected[:6], "3c source/proposal binding changed"


def audit_sources_048(log, root):
    """Separate exact provenance for the preserved 048d996 completed fit."""
    names = ["rtl/x1_hdmi_clock_handoff.sv", "sys/sys_top.v",
             "scripts/constraints/hdmi_held_mode_candidate.sdc",
             "../held-context-048d996-v1/hdmi_held_mode_candidate.sdc",
             "../held-context-048d996-v1/hdmi_inactive_data_candidate.sdc",
             "../held-context-048d996-v1/quartus_held_sdc_context_probe.tcl"]
    names += [f"output_files/sharpx1_turbo_z_handoff.{ext}" for ext in ("fit.rpt", "fit.summary", "sta.rpt", "sta.summary", "rbf")]
    hashes = re.findall(r"^([0-9a-f]{64})  (\S+)$", log.read_text(), re.M)
    assert len(hashes) == 22 and [name for _, name in hashes] == names * 2, "missing/reordered 048 provenance"
    assert hashes[:11] == hashes[11:], "048 source/original artifacts changed"
    expected_artifacts = [
        "24e81859acbebe38cffd6590c326898f27789413c472f87cf865d12ad7ae5ee2",
        "757466f7a8dcae2b80f81e4c933d04d44b5813de3af55e651252c3fdf32c849d",
        "96220a82666d86e8f3f8b57de6aed3f704fb9d0baf6ac74033167fc2a611c946",
        "6f08e1948e0e6d791e344d01cb170d58f46b9f8dc5ff73cd59e4444016f1b408",
        "16fd053ce22f7ab13f2a2d4982bda07092ede03a7011a5d98a3c3aa16e934a88"]
    assert [value for value, _ in hashes[6:11]] == expected_artifacts, "wrong 048 fit/reports/RBF"
    assert hashes[2][0] == "e4266eaa455e0603b0df5e2a8439bfb69b36e98956d431808c7e73acf1f3d5e1", "048 baseline held SDC changed"
    paths = names[:3] + ["scripts/constraints/hdmi_held_mode_candidate.sdc",
                         "scripts/constraints/hdmi_inactive_data_candidate.sdc",
                         "scripts/quartus_held_sdc_context_probe.tcl"]
    assert [value for value, _ in hashes[:6]] == [hashlib.sha256((root / name).read_bytes()).hexdigest() for name in paths], "048 current source mismatch"


def audit_sources(log, root):
    names = ["rtl/x1_hdmi_clock_handoff.sv", "sys/sys_top.v",
             "scripts/constraints/hdmi_held_mode_candidate.sdc",
             "../held-context-d02ee67-v3/hdmi_held_mode_candidate.sdc",
             "../held-context-d02ee67-v3/hdmi_inactive_data_candidate.sdc",
             "../held-context-d02ee67-v3/quartus_held_sdc_context_probe.tcl"]
    names += [f"output_files/sharpx1_turbo_z_handoff.{ext}" for ext in ("fit.rpt", "fit.summary", "sta.rpt", "sta.summary", "rbf")]
    hashes = re.findall(r"^([0-9a-f]{64})  (\S+)$", log.read_text(), re.M)
    assert len(hashes) == 22 and [name for _, name in hashes] == names * 2, "missing/reordered provenance"
    assert hashes[:11] == hashes[11:], "source/original artifacts changed"
    assert hashes[2][0] == "71889e04b0f6dc073f8139988418662edf755b0f45a10bb5fa61235a5b5b1763", "original held baseline changed"
    assert hashes[10][0] == "38a779e9e6e72ea80d8d19087b32978e705b192b14573f180248496b027fb8ee", "wrong historical fit/RBF"
    for index, path in [(0, names[0]), (1, names[1]),
                        (3, "scripts/constraints/hdmi_held_mode_candidate.sdc"),
                        (4, "scripts/constraints/hdmi_inactive_data_candidate.sdc"),
                        (5, "scripts/quartus_held_sdc_context_probe.tcl")]:
        assert hashes[index][0] == hashlib.sha256((root / path).read_bytes()).hexdigest(), "current source mismatch"


def audit(directory, log, profile="fitted4cd"):
    assert profile in ("fitted4cd", "fitted048", "fitted3c", "fitted16fa"), "unqualified context profile"
    packed = {"fitted4cd": PACKED, "fitted048": PACKED048, "fitted3c": PACKED3C, "fitted16fa": PACKED16FA}[profile]
    text = log.read_text()
    assert text.count("TimeQuest Timing Analyzer was successful. 0 errors, 0 warnings") == 1, "native flow incomplete/warned"
    assert not re.search(r"^\s*(?:Error|Warning|Critical Warning)\b", text, re.M), "native diagnostic warning/error"
    assert text.count("HELD CONTEXT BASELINE INACTIVE OMITTED: paths remain timed") == 1, "baseline must time inactive paths"
    assert text.count("HELD MUX CANDIDATE: 29 exact D-route pairs; max 31.25 ns/min -31.25; raw inputs and clock pins untouched") == 2, "held guard missing/repeated"
    assert re.findall(r"^INACTIVE DATA PIN PROFILE (\S+)$", text, re.M) == [profile], "wrong new fitted pin profile"
    assert text.count("HELD CONTEXT PROBE COMPLETE: same-fit context comparison only; no full-flow or hardware acceptance") == 1, "native footer missing"
    assert re.findall(r"^HELD CONTEXT CORNER (before|after) (slow|fast) (-?\d+) 1100$", text, re.M) == [(p, *c) for p in ("before", "after") for c in CORNERS]
    cuts = re.findall(r"^INACTIVE DATA CUT (output|prefetch) (\S+)$", text, re.M)
    expected = [("output", f"{name}|{pin}") for name in OUTPUTS for pin in (["d"] if name == "vs" else ["d", "asdata"])]
    expected += [("prefetch", f"{name}|{'asdata' if name in packed else 'd'}") for name in PREFETCH]
    assert len(cuts) == 77 and collections.Counter(cuts) == collections.Counter(expected), "new fit cut scope changed"
    assert len(list(directory.glob("*.rpt"))) == 384, "missing/extra report inventory"
    preserved = excluded = raw_excluded = mode_rows = 0
    minima = {"setup": float("inf"), "hold": float("inf")}
    reference = {}
    for model, temperature in CORNERS:
        for check in ("setup", "hold"):
            for kind in [*CLOCKS, *INPUTS, "mode", "global"]:
                before_path = directory / f"before_{model}_{temperature}_{kind}_{check}.rpt"
                after_path = directory / f"after_{model}_{temperature}_{kind}_{check}.rpt"
                old = rows(before_path, allow_excluded=kind in INPUTS)
                new = rows(after_path, allow_excluded=kind.startswith("inactive") or kind in INPUTS)
                if kind.startswith("inactive"):
                    assert not new, "inactive paths still timed"
                    targets = OUTPUTS if kind.endswith("hdmi") else PREFETCH
                    assert {r[2] for r in old} == targets and all(r[3:5] == list(CLOCKS[kind]) for r in old), "inactive baseline scope changed"
                    excluded += len(old)
                    continue
                if kind == "global":
                    # Excluding inactive paths intentionally changes the
                    # global worst-path ranking; it must not be called equal.
                    assert len(old) == len(new) == 50, "global report truncated/empty"
                    minima[check] = min(minima[check], *(float(r[0]) for r in new))
                    continue
                assert collections.Counter(map(tuple, old)) == collections.Counter(map(tuple, new)), f"context repair changed timed/excluded rows: {kind}"
                scope = collections.Counter(tuple(r[1:5]) for r in old)
                if kind != "global":
                    if kind not in reference:
                        reference[kind] = scope
                    assert scope == reference[kind], "corner endpoint/clock scope changed"
                if kind in CLOCKS:
                    assert old and all(r[3:5] == list(CLOCKS[kind]) for r in old), "active/pipe route clock changed"
                if kind in INPUTS:
                    if not old:
                        raw_excluded += 1
                    else:
                        clocks = [VID, SYS] if "echo" in kind else [SYS, VID]
                        assert len(old) == 1 and old[0][1:5] == [*PAIRS[kind], *clocks], "raw endpoint/clock changed"
                if kind == "mode":
                    selected = [r for r in old if tuple(r[1:5]) in KEYS]
                    assert len(selected) == 58 and {tuple(r[1:5]) for r in selected} == KEYS, "incomplete held budget scope"
                    assert all(float(r[5]) == (31.25 if check == "setup" else -31.25) for r in selected), "held relationship changed"
                    assert all(r[1].startswith(PREFIX + "active_mode[") and r[3] == SYS for r in old), "mode source/domain changed"
                    mode_rows += len(selected)
                preserved += len(old)
    print(f"PASS same-fit context/data diagnostic: 384 reports; {mode_rows} held budget rows and {preserved} active/raw/mode rows unchanged; {excluded} inactive rows EXCLUDED; {raw_excluded} pre-existing raw reports remain excluded")
    print(f"OPEN: global setup/hold {minima}; exclusions are not timing passes; fresh full flow, PCG-WE, CDC/MTBF/I/O and hardware acceptance remain required")
    return preserved, excluded, raw_excluded, mode_rows, minima


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=pathlib.Path)
    parser.add_argument("--native-log", type=pathlib.Path, required=True)
    parser.add_argument("--source-root", type=pathlib.Path, required=True)
    fit = parser.add_mutually_exclusive_group()
    fit.add_argument("--fit-048d996", action="store_true", help="require the separate exact 048d996 fit/proposal binding")
    fit.add_argument("--fit-3c6242e", action="store_true", help="require exact 3c6242e fit and cef2210 diagnostic inputs")
    fit.add_argument("--fit-16fa816", action="store_true", help="require all eleven actual files of the exact original 16fa816 fit and v1 staged study")
    args = parser.parse_args()
    if args.fit_16fa816:
        audit_sources_16fa(args.native_log, args.source_root)
    elif args.fit_3c6242e:
        audit_sources_3c(args.native_log, args.source_root)
    elif args.fit_048d996:
        audit_sources_048(args.native_log, args.source_root)
    else:
        audit_sources(args.native_log, args.source_root)
    audit(args.directory, args.native_log,
          "fitted16fa" if args.fit_16fa816 else "fitted3c" if args.fit_3c6242e else "fitted048" if args.fit_048d996 else "fitted4cd")
