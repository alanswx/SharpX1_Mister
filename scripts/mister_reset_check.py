#!/usr/bin/env python3
"""Bounded OSD reset acceptance using a completed protected CROSS Chase trial.

Read-only checks by default. Explicit --execute loads the qualified existing
MGL on its released host and exercises both Main menu reset entries. No new
services, installed cores/configs or original media are replaced.
"""
import argparse
import base64
import datetime
import hashlib
import json
import pathlib
import shlex
import subprocess
import time
from compare_video_png import rgb_png
from mister_matrix import HELPER, ROOT


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=pathlib.Path, required=True)
    parser.add_argument("--bridge", default="misterubuntu")
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()
    prior = json.loads(args.manifest.read_text())
    assert prior["host"] in ("mister126", "mister14"), "Reserved/unreleased target"
    test = next(t for t in prior["tests"] if t["title"] == "01_CROSS_Chase")
    assert test["mgl"].startswith("/media/fat/_Computer/") and test["mgl"].endswith(".mgl")
    assert "\n" not in test["mgl"] and "\r" not in test["mgl"], "Invalid MGL command"
    assert test["final_hashes"] == test["initial_hashes"]
    reference = next(s for s in test["screenshots"] if s["label"] == "retained-assets-warm-reset")
    expected_file = args.manifest.parent / reference["file"]
    assert hashlib.sha256(expected_file.read_bytes()).hexdigest() == reference["sha256"]
    expected = rgb_png(expected_file)
    host = {"mister126": "10.0.2.126", "mister14": "10.0.2.14"}[prior["host"]]

    def ssh(command):
        nested = shlex.join(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", "root@"+host, command])
        return subprocess.run(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", args.bridge, nested],
                              check=True, capture_output=True, text=True, timeout=55).stdout

    def status():
        return ssh("cat /tmp/CORENAME /tmp/RBFNAME")

    def cmd(value):
        ssh("printf '%s\\n' " + shlex.quote(value) + " > /dev/MiSTer_cmd")

    def keys(*codes):
        ssh(shlex.join(["python3", HELPER, *map(str, codes), "--gap", "0.5"]))

    def media():
        paths = [line.split(maxsplit=1)[1].strip() for line in test["initial_hashes"].splitlines()]
        return ssh("sha256sum " + " ".join(map(shlex.quote, paths)))

    assert ssh("sha256sum " + shlex.quote(prior["remote_rbf"])).split()[0] == prior["rbf_sha256"]
    assert ssh("sha256sum " + shlex.quote(HELPER)).split()[0] == hashlib.sha256(
        pathlib.Path(__file__).with_name("mister_uinput.py").read_bytes()).hexdigest()
    assert media() == test["initial_hashes"]
    before = status()
    if not args.execute:
        print("CHECKED qualified assets/host/RBF/helper; no core loaded")
        return
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    folder = ROOT / "output_files" / ("X1OSD_" + stamp)
    folder.mkdir(exist_ok=False)
    evidence = {"host": prior["host"], "rbf_sha256": prior["rbf_sha256"],
                "source_manifest": str(args.manifest), "pre_load": before,
                "mgl": test["mgl"], "script_sha256": hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest(),
                "tests": []}

    def save():
        (folder / "manifest.json").write_text(json.dumps(evidence, indent=2)+"\n")

    def capture(label):
        filename = folder.name + "_" + label + ".png"
        cmd("screenshot " + filename)
        time.sleep(2)
        code = "import base64; print(base64.b64encode(open("+repr("/media/fat/screenshots/"+filename)+",'rb').read()).decode())"
        data = base64.b64decode(ssh(shlex.join(["python3", "-c", code])))
        path = folder / filename
        path.write_bytes(data)
        return path, rgb_png(path)

    save()
    cmd("load_core " + test["mgl"])
    time.sleep(30)
    active = status()
    assert test["setname"] in active
    for label, up_count, close in (("reset", 3, False), ("reset-close", 2, True)):
        keys(57, 28, 2, 105, 106, 57)
        time.sleep(3)
        path, pixels = capture(label + "-before")
        entry = {"menu": label, "before_png": path.name,
                 "before_png_sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        evidence["tests"].append(entry)
        save()
        assert pixels != expected, "Already at title; no reset observation possible"
        keys(88, *([103] * up_count), 28)
        time.sleep(30)
        if not close:
            keys(88)
        path, pixels = capture(label + "-after")
        entry["after_png"] = path.name
        entry["after_png_sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
        entry["matches_native_title"] = pixels == expected
        save()
        assert pixels == expected, "OSD reset did not return to qualified native title"
        assert status() == active, "Core/setname changed across menu reset"
        keys(57, 28, 2)
        time.sleep(3)
        path, pixels = capture(label + "-input")
        entry["input_png"] = path.name
        entry["input_png_sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
        entry["input_changes_title"] = pixels != expected
        save()
        assert pixels != expected, "Post-reset input did not advance title"
        assert media() == test["initial_hashes"], "Protected assets changed"
        entry["unchanged_media"] = True
        save()
        print("PASS OSD " + label + " native title and retained input", flush=True)
    print("EVIDENCE " + str(folder), flush=True)


if __name__ == "__main__":
    main()
