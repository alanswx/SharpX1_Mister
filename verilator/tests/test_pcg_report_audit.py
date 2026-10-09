#!/usr/bin/env python3
"""Generated STA-table checks; no ROMs, native fitter or private reports."""
import pathlib
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
CG = "emu:emu|sharpx1:sharpx1|x1_pcg_access:cg_bus|"
SYS = "emu|pll|pll_inst|altera_pll_i|divclk"
VID = "emu|turbo_video_pll|oscillator|divclk"


def row(src, dst, launch=SYS, latch=VID, slack=1.0, delay=3.0):
    return f"; {slack:.3f} ; {src} ; {dst} ; {launch} ; {latch} ; 0.000 ; 0.001 ; {delay:.3f} ;\n"


def fixture(folder, captures, stage_replicas=1, address_replicas=0):
    addresses = [row(CG + (f"frozen_addr[{i}]" if i < 4 else f"font_cpu_addr[{i+1}]"),
                     CG + f"access_addr[{i}]") for i in range(11)]
    controls = [CG + leaf for leaf in ("plane[0]", "plane[1]", "write_request", "high_speed_request", "unsupported_request")]
    targets = ([CG + f"access_addr[{i}]" for i in range(11)] +
               [CG + f"response[{i}]" for i in range(8)] +
               [CG + leaf for leaf in ("seen", "stage.00", "stage.01", "stage.01~DUPLICATE")] +
               [f"emu|x1_video_ram:pcg_{color}|bank{i}~porta_we_reg" for color in "brg" for i in range(4)])
    if not stage_replicas:
        targets.remove(CG + "stage.01~DUPLICATE")
    control_rows = [row(controls[i % 5], targets[i % len(targets)]) for i in range(89 + stage_replicas)]
    if address_replicas:
        addresses.append(row(CG + "font_cpu_addr[5]", CG + "access_addr[4]~DUPLICATE"))
        sources = {controls[i % 5] for i in range(89 + stage_replicas) if targets[i % len(targets)] == CG + "access_addr[4]"}
        control_rows += [row(source, CG + "access_addr[4]~DUPLICATE") for source in sorted(sources)]
    payload = [row(CG + f"payload[{i%8}]", f"emu|x1_video_ram:pcg_{color}|bank{i}~porta_datain_reg0")
               for color in "brg" for i in range(64)]
    bits = list(range(8)) + [0, 3, 1, 2, 4, 5, 6, 7][:captures-8]
    responses = [row(CG + f"response[{bit}]", CG + f"cpu_q[{bit}]" + ("~DUPLICATE" if i >= 8 else ""),
                     VID, SYS) for i, bit in enumerate(bits)]
    for model in ("slow", "fast"):
        for temp in (-40, 0, 85, 100):
            for check in ("setup", "hold"):
                for group, rows in (("address", addresses), ("control", control_rows), ("payload", payload), ("response", responses)):
                    probe = "response" if group == "response" else "request"
                    path = folder / f"sharpx1_turbo_z_video_pcg_{probe}_probe_{model}_{temp}_{group}_{check}.rpt"
                    path.write_text("Generated fixture, not native evidence\n" + "".join(rows))


def audit(folder, captures, stage_replicas=1, address_replicas=0):
    return subprocess.run(["bash", str(ROOT / "scripts/audit_pcg_timing_reports.sh"), str(folder), str(captures), str(stage_replicas), str(address_replicas)],
                          capture_output=True, text=True)


with tempfile.TemporaryDirectory(prefix="x1-pcg-report-audit-") as tmp:
    folder = pathlib.Path(tmp)
    for captures in (8, 9, 10, 16):
        for replicas in (0, 1):
            for address_replicas in (0, 1):
                fixture(folder, captures, replicas, address_replicas)
                result = audit(folder, captures, replicas, address_replicas)
                assert result.returncode == 0, result.stderr
                assert audit(folder, captures, 1-replicas, address_replicas).returncode != 0, "wrong independently fitted stage replica count accepted"
                assert audit(folder, captures, replicas, 1-address_replicas).returncode != 0, "wrong independently fitted address replica count accepted"
    fixture(folder, 10)
    response = folder / "sharpx1_turbo_z_video_pcg_response_probe_slow_-40_response_setup.rpt"
    address = folder / "sharpx1_turbo_z_video_pcg_request_probe_slow_-40_address_setup.rpt"
    payload = folder / "sharpx1_turbo_z_video_pcg_request_probe_slow_-40_payload_setup.rpt"
    controls = folder / "sharpx1_turbo_z_video_pcg_request_probe_slow_-40_control_setup.rpt"
    cases = [
        (response, lambda s: s.replace("cpu_q[1]", "cpu_q[0]")),
        (response, lambda s: s.replace("response[0]", "response[1]")),
        (response, lambda s: s.replace("cpu_q[7]", "cpu_q[8]")),
        (response, lambda s: s.replace("~DUPLICATE", "~UNKNOWN")),
        (response, lambda s: s.replace("; 1.000 ;", "; -0.001 ;", 1)),
        (response, lambda s: s.replace("; 3.000 ;", "; 31.250 ;", 1)),
        (response, lambda s: s.replace(VID, SYS, 1)),
        (address, lambda s: s.replace("access_addr[10]", "access_addr[11]")),
        (payload, lambda s: s.replace("; 3.000 ;", "; 23.280 ;", 1)),
        (payload, lambda s: s.replace("pcg_b", "pcg_r")),
        (controls, lambda s: s.replace("unsupported_request", "other_request")),
        (controls, lambda s: s.replace("|seen", "|stage.10")),
        (response, lambda s: "\n".join(s.splitlines()[:-1]) + "\n"),
    ]
    for path, mutate in cases:
        original = path.read_text()
        path.write_text(mutate(original))
        result = audit(folder, 10)
        assert result.returncode != 0, f"bad report accepted: {path}"
        path.write_text(original)
    original = response.read_text()
    response.unlink()
    assert audit(folder, 10).returncode != 0, "missing corner accepted"
    response.write_text(original)
    assert audit(folder, 9).returncode != 0, "wrong fitted capture count accepted"
print("PASS: generated report audit at 8/9/10/16 captures and independent 0/1 stage/address replicas; invalid report/count controls rejected")
