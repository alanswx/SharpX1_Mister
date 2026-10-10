"""Synthetic discovery-auditor controls, not native fitted timing."""
import contextlib
import hashlib
import io
import pathlib
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "scripts"))
import audit_pcg_reset_inventory as audit


def fixture(root, raw_present=False):
    directory = root / "reports"
    directory.mkdir()
    (directory / "clocks.rpt").write_text("synthetic clocks\n")
    targets = [f"emu:emu|sharpx1:sharpx1|x1_video_ram:pcg_{plane}|mock{bit}~porta_we_reg"
               for plane in "brg" for bit in range(4)]
    log = root / "native.log"
    text = "\n".join(f"PCG RESET FANIN {t} mock_source (reg)" for t in targets) + "\n"
    for model, temperature in audit.CORNERS:
        text += f"PCG RESET CORNER {model} {temperature} 1100\n"
        for kind, checks in (("download", ("setup", "hold")), ("all_we", ("setup", "hold")),
                             ("local", ("setup", "hold", "recovery", "removal"))):
            for check in checks:
                filename = directory / f"{model}_{temperature}_{kind}_{check}.rpt"
                if kind == "local" or (kind == "download" and not raw_present):
                    filename.write_text("Nothing to report.\n")
                    continue
                source = audit.DOWNLOAD if kind == "download" else "mock_registered_control"
                slack = "-10.797" if kind == "download" else "1.000"
                lines = [f"Report Timing: Found 12 {check} paths"]
                lines += [f"; {slack} ; {source} ; {target} ; {audit.SYS} ; {audit.VID} ; 0.000 ; 0.000 ; 1.000 ;"
                          for target in targets]
                filename.write_text("\n".join(lines) + "\n")
    text += "PCG RESET INVENTORY COMPLETE: original SDC only; not timing acceptance\n"
    text += "TimeQuest Timing Analyzer was successful. 0 errors, 0 warnings\n"
    log.write_text(text)
    return directory, log


def run(directory, log):
    with contextlib.redirect_stdout(io.StringIO()):
        return audit.audit(directory, log)


for present in (False, True):
    with tempfile.TemporaryDirectory(prefix="x1-pcg-reset-audit-") as temp:
        directory, log = fixture(pathlib.Path(temp), present)
        counts, minima = run(directory, log)
        assert counts[("download", "setup")] == (96 if present else 0)
        if present:
            assert minima[("download", "setup")] == -10.797

rejected = 0
for mode in ("missing", "extra", "empty_we", "count", "cap", "omitted_we", "wrong_clock",
             "wrong_raw", "wrong_local", "corner", "duplicate_fanin", "wrong_plane", "native_warning"):
    with tempfile.TemporaryDirectory(prefix="x1-pcg-reset-audit-negative-") as temp:
        directory, log = fixture(pathlib.Path(temp), True)
        path = directory / "slow_-40_all_we_setup.rpt"
        text = path.read_text()
        if mode == "missing":
            path.unlink()
        elif mode == "extra":
            (directory / "extra.rpt").write_text(text)
        elif mode == "empty_we":
            path.write_text("Nothing to report.\n")
        elif mode == "count":
            path.write_text(text.replace("Found 12", "Found 11"))
        elif mode == "cap":
            path.write_text(text.replace("Found 12", "Found 10000"))
        elif mode == "omitted_we":
            path.write_text(text.replace("pcg_b|mock0", "pcg_b|mock1"))
        elif mode == "wrong_clock":
            path.write_text(text.replace(audit.VID, audit.SYS))
        elif mode == "wrong_raw":
            path = directory / "slow_-40_download_setup.rpt"
            path.write_text(path.read_text().replace(audit.DOWNLOAD, "wrong_source"))
        elif mode == "wrong_local":
            path = directory / "slow_-40_local_setup.rpt"
            path.write_text(text)
        elif mode == "corner":
            log.write_text(log.read_text().replace("PCG RESET CORNER slow -40 1100\n", ""))
        elif mode == "duplicate_fanin":
            log.write_text(log.read_text().splitlines()[0] + "\n" + log.read_text())
        elif mode == "wrong_plane":
            log.write_text(log.read_text().replace("pcg_b|", "pcg_x|"))
        elif mode == "native_warning":
            log.write_text(log.read_text() + "Warning: mocked warning\n")
        try:
            run(directory, log)
        except (AssertionError, FileNotFoundError):
            rejected += 1
        else:
            raise AssertionError(f"invalid inventory accepted: {mode}")
print(f"PASS: empty/present raw discovery, negative raw slack retained; {rejected} invalid report/scope controls")

source_root = pathlib.Path(__file__).resolve().parents[2]
names = ["rtl/x1_pcg_access.v", "rtl/x1_reset_release.sv", "rtl/sharpx1.v",
         "sharpx1.sv", "pcg_reset_inventory_diagnostic.tcl"]
names += [f"output_files/sharpx1_turbo_z_handoff.{ext}" for ext in ("sta.rpt", "sta.summary", "rbf")]
paths = names[:4] + ["scripts/quartus_pcg_reset_inventory.tcl"]
values = [hashlib.sha256((source_root / p).read_bytes()).hexdigest() for p in paths] + ["0" * 64] * 3
block = [f"{value}  {name}" for value, name in zip(values, names)]
for mode in ("valid", "missing", "reordered", "changed_artifact", "wrong_source"):
    with tempfile.TemporaryDirectory(prefix="x1-pcg-reset-provenance-") as temp:
        log = pathlib.Path(temp) / "native.log"
        lines = block * 2
        if mode == "missing":
            lines.pop()
        elif mode == "reordered":
            lines[0], lines[1] = lines[1], lines[0]
        elif mode == "changed_artifact":
            lines[-1] = lines[-1].replace("0" * 64, "1" * 64)
        elif mode == "wrong_source":
            lines[0] = lines[8] = f"{'1' * 64}  {names[0]}"
        log.write_text("\n".join(lines) + "\n")
        try:
            audit.audit_sources(log, source_root)
        except AssertionError:
            assert mode != "valid", "valid provenance rejected"
        else:
            assert mode == "valid", f"invalid provenance accepted: {mode}"
print("PASS: eight-file before/after provenance and four invalid source/artifact controls (synthetic)")
