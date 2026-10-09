#!/usr/bin/env python3
"""Isolated generated DMA restart tests on explicitly released MiSTers.

Requires a locally qualified 18-case fixture manifest and an explicit RBF
identity. Never uses mister192, private media, installed cores or services.
Stage-only by default; execute loads each MGL and checks actual captured RGB.
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


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", choices=("mister126", "mister14"), required=True)
    parser.add_argument("--bridge", default="misterubuntu")
    parser.add_argument("--rbf", type=pathlib.Path, required=True)
    parser.add_argument("--bridge-rbf", required=True, help="same hashed RBF on build host")
    parser.add_argument("--fixtures", type=pathlib.Path, required=True)
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--disabled-control", action="store_true",
                        help="one memory case on a deliberately DMA-disabled RBF: require red, not green")
    args = parser.parse_args()
    host = {"mister126": "10.0.2.126", "mister14": "10.0.2.14"}[args.host]
    fixture = json.loads((args.fixtures / "manifest.json").read_text())
    cases = fixture["cases"]
    assert len(cases) == 18 and len({c["name"] for c in cases}) == 18, "Incomplete fixture qualification"
    assert fixture["sys_hz"] == 28571428
    for case in cases:
        name = case["name"]
        assert name.replace("-", "").isalnum(), "Unsafe case name"
        assert digest((args.fixtures / (name + ".rom")).read_bytes()) == case["ipl_sha256"]
        assert (args.fixtures / (name + ".ppm")).read_bytes() == b"P6\n320 200\n255\n" + b"\x00\xff\x00" * 64000
    for drive in (0, 1):
        assert digest((args.fixtures / f"drive-{drive}.d88").read_bytes()) == fixture["disk_sha256"][drive]
    rbf_hash = digest(args.rbf.read_bytes())

    def bridge(command):
        return subprocess.run(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", args.bridge, command],
                              capture_output=True, text=True, check=True, timeout=55).stdout

    def ssh(command):
        return bridge(shlex.join(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", "root@"+host, command]))

    def python(code):
        return ssh(shlex.join(["python3", "-c", code]))

    def put(path, data):
        python("import base64; open("+repr(path)+", 'xb').write(base64.b64decode("+repr(base64.b64encode(data).decode())+"))")

    def cmd(value):
        ssh("printf '%s\\n' " + shlex.quote(value) + " > /dev/MiSTer_cmd")

    def status():
        return ssh("cat /tmp/CORENAME /tmp/RBFNAME")

    assert bridge("sha256sum " + shlex.quote(args.bridge_rbf)).split()[0] == rbf_hash
    before = status()
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    folder = ROOT / "output_files" / ("X1DMA_" + stamp)
    folder.mkdir(exist_ok=False)
    remote = "/media/fat/games/SharpX1/HWTest/" + folder.name
    mgl_directory = "/media/fat/_Computer/" + folder.name
    remote_rbf = mgl_directory + "/dma.rbf"
    ssh("mkdir " + shlex.quote(remote) + " " + shlex.quote(mgl_directory))
    # New directory + explicit nonexisting file: do not replace an installed RBF.
    ssh("test ! -e " + shlex.quote(remote_rbf))
    bridge(shlex.join(["scp", "-q", args.bridge_rbf, "root@"+host+":"+remote_rbf]))
    assert ssh("sha256sum " + shlex.quote(remote_rbf)).split()[0] == rbf_hash
    for drive in (0, 1):
        put(remote+f"/drive-{drive}.d88", (args.fixtures / f"drive-{drive}.d88").read_bytes())
    manifest = {"host": args.host, "pre_load": before, "rbf_sha256": rbf_hash,
                "fixtures": str(args.fixtures), "qualification": fixture,
                "execute": args.execute, "disabled_control": args.disabled_control,
                "remote_mgl_directory": mgl_directory, "tests": []}

    def save():
        (folder / "manifest.json").write_text(json.dumps(manifest, indent=2)+"\n")

    for number, case in enumerate(cases[:1] if args.disabled_control else cases, 1):
        name = case["name"]
        setname = "X1D_"+stamp+f"_{number:02d}"
        rom_path = remote+"/"+name+".rom"
        put(rom_path, (args.fixtures / (name+".rom")).read_bytes())
        assert ssh("sha256sum " + shlex.quote(rom_path)).split()[0] == case["ipl_sha256"]
        put("/media/fat/config/"+setname+".CFG", bytes(16))
        tree = ET.Element("mistergamedescription")
        ET.SubElement(tree, "rbf").text = remote_rbf.removeprefix("/media/fat/").removesuffix(".rbf")
        ET.SubElement(tree, "setname", same_dir="1").text = setname
        ET.SubElement(tree, "file", delay="2", type="f", index="0", path=rom_path)
        if name.startswith("drive-"):
            for drive in (0, 1):
                ET.SubElement(tree, "file", delay="2", type="s", index=str(drive), path=remote+f"/drive-{drive}.d88")
        ET.SubElement(tree, "reset", delay="1")
        mgl = mgl_directory+"/"+name+".mgl"
        data = ET.tostring(tree, encoding="utf-8")+b"\n"
        put(mgl, data)
        (folder / (name+".mgl")).write_bytes(data)
        entry = {"case": name, "setname": setname, "mgl": mgl, "ipl_sha256": case["ipl_sha256"]}
        manifest["tests"].append(entry)
        save()
        print("STAGED " + mgl, flush=True)
        if not args.execute:
            continue
        cmd("load_core " + mgl)
        time.sleep(12)
        entry["post_load"] = status()
        assert setname in entry["post_load"], "Requested test is not active"
        filename = setname+".png"
        cmd("screenshot " + filename)
        time.sleep(2)
        encoded = python("import base64; print(base64.b64encode(open("+repr("/media/fat/screenshots/"+filename)+", 'rb').read()).decode())")
        image = base64.b64decode(encoded)
        local_png = folder / filename
        local_png.write_bytes(image)
        entry["png"] = filename
        entry["png_sha256"] = digest(image)
        save()  # Preserve failed pixels before asserting success.
        dimensions, rgb = rgb_png(local_png)
        expected = b"\xff\x00\x00" if args.disabled_control else b"\x00\xff\x00"
        assert dimensions == (320, 200) and rgb == expected * 64000, (name, dimensions, "Expected CPU result color absent")
        entry["checked_pixels"] = 64000
        entry["mismatching_pixels"] = 0
        for drive in (0, 1):
            assert ssh("sha256sum " + shlex.quote(remote+f"/drive-{drive}.d88")).split()[0] == fixture["disk_sha256"][drive]
        save()
        print(("PASS disabled hardware control remains red " if args.disabled_control else "PASS actual CPU-driven hardware RGB ") + name, flush=True)
    print("EVIDENCE " + str(folder), flush=True)


if __name__ == "__main__":
    main()
