#!/usr/bin/env python3
"""Repeat the protected native game matrix on an explicitly released MiSTer.

Uses nested SSH through the build host (its MiSTer key remains there). Creates
unique MGLs/config/media; does not install services or replace existing tests.
Screenshots are observations, not automatic gameplay verdicts.
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
import xml.etree.ElementTree as ET
from compare_video_png import rgb_png

ROOT = pathlib.Path(__file__).resolve().parents[1]
RBF_SHA = "a0a03761ef9db2bf2a9a14ec5c281175cb02a33d7eaa07978551fe1f393260d3"
OLD = "/media/fat/_Computer/X1Tests_20261008"
RBF = "/media/fat/_Computer/X1HW_20261008T204348Z_a0a03761.rbf"
HELPER = "/media/fat/games/SharpX1/HWTest/X1HW_20261008T204348Z_a0a03761/mister_uinput.py"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", choices=("mister126", "mister14"), required=True)
    parser.add_argument("--bridge", default="misterubuntu")
    parser.add_argument("--execute", action="store_true", help="load MGLs and send keyboard input")
    parser.add_argument("--warm-reset", action="store_true",
                        help="send Main's Ctrl+LeftAlt+RightAlt reset chord without reloading assets")
    parser.add_argument("--rbf-path", default=RBF, help="explicit already-staged RBF; requires matching --rbf-sha256")
    parser.add_argument("--rbf-sha256", default=RBF_SHA)
    parser.add_argument("--title", choices=("01_CROSS_Chase", "02_Galaga", "03_Druaga", "04_Mappy", "05_Xevious", "06_Shanghai"),
                        help="optional single native title; does not qualify the entire matrix")
    parser.add_argument("--video-ipl", type=pathlib.Path,
                        help="instead test six generated graphics/text/PCG IPLs")
    args = parser.parse_args()
    if args.warm_reset and not args.execute:
        parser.error("--warm-reset requires --execute")
    if not args.rbf_path.startswith("/media/fat/_Computer/") or not args.rbf_path.endswith(".rbf"):
        parser.error("RBF must be an explicit file beneath /media/fat/_Computer/")
    if len(args.rbf_sha256) != 64 or any(c not in "0123456789abcdef" for c in args.rbf_sha256):
        parser.error("RBF SHA-256 must be 64 lowercase hex digits")
    if args.title and args.video_ipl:
        parser.error("--title selects native software, not generated video IPLs")
    host = {"mister126": "10.0.2.126", "mister14": "10.0.2.14"}[args.host]

    def ssh(command):
        nested = shlex.join(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10",
                             "root@" + host, command])
        return subprocess.run(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10",
                               args.bridge, nested], check=True, capture_output=True,
                              text=True, timeout=55).stdout

    def remote_python(code):
        return ssh(shlex.join(["python3", "-c", code]))

    def upload(path, data):
        # Exclusive creation: fail rather than overwrite even a test file.
        remote_python("import base64; open(" + repr(path) + ", 'xb').write(base64.b64decode("
                      + repr(base64.b64encode(data).decode()) + "))")

    def cmd(value):
        return ssh("printf '%s\\n' " + shlex.quote(value) + " > /dev/MiSTer_cmd")

    def status():
        return ssh("cat /tmp/CORENAME /tmp/RBFNAME")

    before = status()
    assert ssh("sha256sum " + shlex.quote(args.rbf_path)).split()[0] == args.rbf_sha256, "Unexpected RBF; refusing load"
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    name = "X1Matrix_" + stamp
    folder = ROOT / "output_files" / name
    folder.mkdir(exist_ok=False)
    remote_folder = "/media/fat/_Computer/" + name
    media = "/media/fat/games/SharpX1/HWTest/" + name
    ssh("mkdir " + shlex.quote(remote_folder) + " " + shlex.quote(media))
    manifest = {"host": args.host, "bridge": args.bridge, "pre_load": before,
                "rbf_sha256": args.rbf_sha256, "remote_rbf": args.rbf_path, "remote_mgl_directory": remote_folder,
                "executed": args.execute, "warm_reset": args.warm_reset,
                "script_sha256": hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest(), "tests": []}

    def save():
        (folder / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")

    def capture(test, label):
        filename = test["setname"] + "_" + label + ".png"
        cmd("screenshot " + filename)
        time.sleep(2)
        encoded = remote_python("import base64; print(base64.b64encode(open("
                                + repr("/media/fat/screenshots/" + filename)
                                + ", 'rb').read()).decode())")
        data = base64.b64decode(encoded)
        assert data.startswith(b"\x89PNG\r\n\x1a\n"), "Not a PNG"
        (folder / filename).write_bytes(data)
        test.setdefault("screenshots", []).append({"label": label, "file": filename,
                                                    "sha256": hashlib.sha256(data).hexdigest()})
        save()
        if args.video_ipl:
            reference = args.video_ipl / (test["title"] + "-ipl.ppm")
            header, size, maximum, expected = reference.read_bytes().split(b"\n", 3)
            assert header == b"P6" and maximum == b"255"
            dimensions, actual = rgb_png(folder / filename)
            assert dimensions == tuple(map(int, size.split()))
            assert len(actual) == len(expected)
            mismatches = sum(actual[i:i+3] != expected[i:i+3] for i in range(0, len(actual), 3))
            test["screenshots"][-1]["comparison"] = {
                "reference_sha256": hashlib.sha256(reference.read_bytes()).hexdigest(),
                "dimensions": dimensions, "checked_pixels": len(actual)//3,
                "mismatching_pixels": mismatches}
            save()  # Preserve failed captures before asserting success.
            assert mismatches == 0, "Hardware video differs from qualified CPU IPL reference"

    titles = ("01_CROSS_Chase", "02_Galaga", "03_Druaga", "04_Mappy", "05_Xevious", "06_Shanghai")
    if args.title:
        titles = (args.title,)
    if args.video_ipl:
        titles = tuple(f"{kind}-{columns}" for columns in (40, 80) for kind in ("graphics", "text", "pcg"))
        for title in titles:
            assert (args.video_ipl / (title + ".rom")).stat().st_size == 4096
            assert (args.video_ipl / (title + "-ipl.ppm")).is_file()
    for index, title in enumerate(titles, 1):
        # Keep below Main's name limit; independent configs must not truncate.
        setname = "X1M_" + stamp + f"_{index:02d}"
        subdir = media + "/" + title
        ssh("mkdir " + shlex.quote(subdir))
        files = []
        if args.video_ipl:
            new_path = subdir + "/ipl.rom"
            upload(new_path, (args.video_ipl / (title + ".rom")).read_bytes())
            tree = ET.fromstring('<mistergamedescription><rbf/><setname same_dir="1"/>'
                                 '<file delay="2" type="f" index="0" path="' + new_path
                                 + '"/><reset delay="1"/></mistergamedescription>')
            files.append(new_path)
        else:
            tree = ET.fromstring(ssh("cat " + shlex.quote(OLD + "/" + title + ".mgl")))
        for item in tree.findall("file"):
            if args.video_ipl:
                continue
            old_path = item.attrib["path"]
            new_path = subdir + "/" + pathlib.PurePosixPath(old_path).name
            ssh("cp -n " + shlex.quote(old_path) + " " + shlex.quote(new_path))
            item.set("path", new_path)
            files.append(new_path)
        tree.find("rbf").text = args.rbf_path.removeprefix("/media/fat/").removesuffix(".rbf")
        tree.find("setname").text = setname
        contents = ET.tostring(tree, encoding="utf-8") + b"\n"
        mgl = remote_folder + "/" + title + ".mgl"
        upload(mgl, contents)
        upload("/media/fat/config/" + setname + ".CFG", bytes(16))
        (folder / (title + ".mgl")).write_bytes(contents)
        hashes = ssh("sha256sum " + " ".join(map(shlex.quote, files)))
        test = {"title": title, "setname": setname, "mgl": mgl,
                "protected_config": "zero 16-byte status", "initial_hashes": hashes}
        manifest["tests"].append(test)
        save()
        print("STAGED " + mgl, flush=True)
        if not args.execute:
            continue
        cmd("load_core " + mgl)
        time.sleep(10 if args.video_ipl else 30)
        test["post_load"] = status()
        assert setname in test["post_load"], "Requested MGL setname is not active"
        capture(test, "native-10s" if args.video_ipl else "native-30s")
        if not args.video_ipl:
            ssh(shlex.join(["python3", HELPER, "57", "28", "2", "--gap", "0.5"]))
            time.sleep(3)
            capture(test, "start-input")
            ssh(shlex.join(["python3", HELPER, "105", "106", "103", "108", "57", "--hold", "0.4"]))
            capture(test, "direction-fire-input")
        if args.warm_reset:
            before_reset = status()
            ssh(shlex.join(["python3", HELPER, "29", "56", "100", "--chord", "--hold", "0.3"]))
            time.sleep(10 if args.video_ipl else 30)
            assert status() == before_reset, "Core/setname changed across reset"
            capture(test, "retained-assets-warm-reset")
            if not args.video_ipl:
                ssh(shlex.join(["python3", HELPER, "57", "28", "2", "--gap", "0.5"]))
                time.sleep(3)
                capture(test, "post-reset-start-input")
        test["final_hashes"] = ssh("sha256sum " + " ".join(map(shlex.quote, files)))
        assert test["final_hashes"] == hashes, "Protected test media changed"
        save()
        print("CAPTURED " + title + " (visual review required)", flush=True)
    print("EVIDENCE " + str(folder), flush=True)


if __name__ == "__main__":
    main()
