"""Original asset-free timeout/provenance test, not a machine/game simulation."""
import contextlib
import hashlib
import io
import json
import pathlib
import subprocess
import sys
import tempfile
from unittest.mock import patch
import probe_special_titles

with tempfile.TemporaryDirectory(prefix="x1-probe-timeout-") as temporary:
    root = pathlib.Path(temporary)
    for name in ("runner", "rom", "keys", "disk"):
        (root / name).write_bytes(b"original timeout test input " + name.encode())
    manifest = root / "manifest.json"
    manifest.write_text(json.dumps({"games": [{"slug": "bastard-special", "files": [{
        "native_candidate": True, "member": "original-test.d88", "path": "disk",
        "sha256": hashlib.sha256((root / "disk").read_bytes()).hexdigest()}]}]}))
    folder = root / "evidence"
    kanji = root / "synthetic.physical"
    kanji.write_bytes(bytes(131072))
    arguments = ["probe", str(root / "runner"), "bastard-special", "--manifest", str(manifest),
                 "--rom", str(root / "rom"), "--keys", str(root / "keys"),
                 "--seconds", "1", "--save-state", "--timeout", "0.01",
                 "--kanji-physical", str(kanji), "--output", str(folder)]
    def timeout(command, **options):
        raise subprocess.TimeoutExpired(command, options["timeout"], b"partial stdout", b"partial stderr")
    with patch.object(sys, "argv", arguments), patch.object(subprocess, "run", timeout), contextlib.redirect_stdout(io.StringIO()):
        try:
            probe_special_titles.main()
            raise AssertionError("timeout reported success")
        except SystemExit as error:
            assert str(error).startswith("FAIL:")
    evidence = json.loads((folder / "evidence.json").read_text())
    assert evidence["unchanged_inputs"] and not evidence["repeatable"] and not evidence["gameplay_verified"]
    assert [run["returncode"] for run in evidence["runs"]] == [124, 124]
    assert all("--save-state" in run["command"] for run in evidence["runs"])
    assert all(run["command"][run["command"].index("--kanji-physical") + 1] == str(kanji.resolve())
               for run in evidence["runs"])
    assert evidence["inputs_sha256"][str(kanji.resolve())] == hashlib.sha256(kanji.read_bytes()).hexdigest()
    for prefix in ("cold", "repeat"):
        assert (folder / f"{prefix}.stdout").read_text() == "partial stdout"
        assert "simulation did not complete" in (folder / f"{prefix}.stderr").read_text()
    # A tool-style glyph export is not a physical ROM. Refuse it before
    # making evidence directories or launching the runner, even under mock.
    bad_font, bad_folder = root / "wrong-size.font", root / "bad-shape"
    bad_font.write_bytes(bytes(306176))
    bad_arguments = arguments[:-2] + ["--output", str(bad_folder)]
    bad_arguments[bad_arguments.index("--kanji-physical") + 1] = str(bad_font)
    def unexpected_run(*unused_args, **unused_options):
        raise AssertionError("wrong-size physical font launched a probe")
    with patch.object(sys, "argv", bad_arguments), patch.object(subprocess, "run", unexpected_run), contextlib.redirect_stderr(io.StringIO()):
        try:
            probe_special_titles.main()
            raise AssertionError("wrong-size physical font accepted")
        except SystemExit as error:
            assert error.code == 2, error
    assert not bad_folder.exists()
print("PASS: timeout retains partial logs/commands, unchanged assets and explicit failed acceptance; physical Kanji forwarding/hash/size rejection")
