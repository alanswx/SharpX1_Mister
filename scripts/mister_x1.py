#!/usr/bin/env python3
"""Isolated read-only X1 bring-up on MiSTer; never replace installed cores/media.

Reuse the installed Main command FIFO and mrext API as in the sibling SharpMZ
test runner. Every deployment has a new setname, config, RBF and media copy.
Generated ROM, copied media and screenshots belong under ignored output_files.
"""
import argparse
import datetime
import hashlib
import json
import pathlib
import shlex
import subprocess
import time
import urllib.request
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def ssh(host, command):
    return subprocess.run(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10",
                           "root@" + host, command], check=True,
                          capture_output=True, text=True, timeout=30).stdout


def put(host, source, destination):
    subprocess.run(["scp", "-q", "-o", "BatchMode=yes", str(source),
                    "root@" + host + ":" + destination], check=True, timeout=60)


def command(host, value):
    ssh(host, "printf '%s\\n' " + shlex.quote(value) + " > /dev/MiSTer_cmd")


def status(host):
    # Main versions differ in whether ACTIVEGAME exists, including after MGL.
    return ssh(host, 'for f in /tmp/RBFNAME /tmp/ACTIVEGAME /tmp/CORENAME; do '
                    'if test -r "$f"; then printf "%s: " "$f"; cat "$f"; '
                    'printf "\\n"; fi; done; uname -a')


def capture(host, folder, label):
    name = folder.name + "_" + label + ".png"
    command(host, "screenshot " + name)
    time.sleep(2)
    target = folder / name
    subprocess.run(["scp", "-q", "-o", "BatchMode=yes",
                    "root@" + host + ":/media/fat/screenshots/" + name, str(target)],
                   check=True, timeout=30)
    print(json.dumps({"screenshot": str(target), "sha256": digest(target)}), flush=True)


def key(host, code):
    request = urllib.request.Request(
        f"http://{host}:8182/api/controls/keyboard-raw/{code}", method="POST")
    with urllib.request.urlopen(request, timeout=5) as response:
        response.read()


def burst(host, folder, codes):
    # Execute input and capture close together on MiSTer: separate host SSH
    # round trips let this fast game kill the player before comparison.
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%H%M%S%f")
    names = [folder.name + f"_burst_{stamp}_{i}.png" for i in range(len(codes))]
    actions = []
    for code, name in zip(codes, names):
        actions += [f"curl -fsS --max-time 3 -X POST http://127.0.0.1:8182/api/controls/keyboard-raw/{code}",
                    "sleep 0.15", "printf '%s\\n' " + shlex.quote("screenshot " + name)
                    + " > /dev/MiSTer_cmd", "sleep 0.15"]
    ssh(host, " && ".join(actions))
    for name in names:
        target = folder / name
        subprocess.run(["scp", "-q", "-o", "BatchMode=yes",
                        "root@" + host + ":/media/fat/screenshots/" + name, str(target)],
                       check=True, timeout=30)
        print(json.dumps({"screenshot": str(target), "sha256": digest(target)}), flush=True)


def deploy(host, rbf, disk, drive=0, ipl=None, font16=None, physical_font=None):
    data = ipl.read_bytes() if ipl else bytes.fromhex((ROOT / "bios/ipl_x1.hex").read_text())
    if ipl:
        if len(data) not in (4096, 32768):
            raise ValueError("explicit binary IPL must be exactly 4 or 32 KiB")
    else:
        if not 0 < len(data) <= 4096:
            raise ValueError("default IPL does not fit 4 KiB")
        # Preserve the inherited missing final byte as FF.
        data += bytes([255]) * (4096 - len(data))
    extra = []
    for index, path, filename, size in ((4, font16, 'font16.rom', 4096),
                                      (5, physical_font, 'physical-font.rom', 262144)):
        if path is not None:
            content = path.read_bytes()
            if len(content) != size:
                raise ValueError(f"{filename} must contain exactly {size} bytes; no format conversion")
            extra.append((index, filename, content, str(path)))
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    name = "X1HW_" + stamp + "_" + digest(rbf)[:8]
    folder = ROOT / "output_files" / name
    folder.mkdir(exist_ok=False)
    remote = "/media/fat/games/SharpX1/HWTest/" + name
    remote_rbf = "/media/fat/_Computer/" + name + ".rbf"
    rom = folder / "ipl.rom"
    rom.write_bytes(data)
    for _, filename, content, _ in extra:
        (folder / filename).write_bytes(content)
    config = folder / (name + ".CFG")
    config.write_bytes(bytes(16))  # Disk writes protected; independent setname.
    mgl = folder / (name + ".mgl")
    tree = ET.Element('mistergamedescription')
    ET.SubElement(tree, 'rbf').text = '_Computer/' + name
    ET.SubElement(tree, 'setname', {'same_dir': '1'}).text = name
    for index, filename in [(0, 'ipl.rom'), *((i, n) for i, n, _, _ in extra)]:
        ET.SubElement(tree, 'file', {'delay': '2', 'type': 'f', 'index': str(index), 'path': remote + '/' + filename})
    ET.SubElement(tree, 'file', {'delay': '2', 'type': 's', 'index': str(drive), 'path': remote + '/test.d88'})
    ET.SubElement(tree, 'reset', {'delay': '1'})
    mgl.write_bytes(ET.tostring(tree) + b'\n')
    evidence = {"host": host, "rbf": str(rbf), "rbf_sha256": digest(rbf),
                "disk": str(disk), "disk_sha256": digest(disk), "drive": drive,
                "ipl_bytes": len(data), "ipl_sha256": digest(rom),
                "ipl_source": str(ipl) if ipl else str(ROOT / 'bios/ipl_x1.hex'),
                "extra_uploads": [{"index": i, "file": n, "source": p, "sha256": digest(folder / n)}
                                  for i, n, _, p in extra],
                "driver_sha256": digest(pathlib.Path(__file__)),
                "remote_rbf": remote_rbf, "remote_directory": remote,
                "pre_load": status(host),
                "write_protection": "zero status config; disposable disk copy; chmod requested but FAT mode bits are not proof"}
    (folder / "manifest.json").write_text(json.dumps(evidence, indent=2) + "\n")
    # Timestamp/setname must not alias a previous test or an installed core.
    ssh(host, f"test ! -e {shlex.quote(remote)} && test ! -e {shlex.quote(remote_rbf)}"
              f" && test ! -e /media/fat/config/{name}.CFG && mkdir -p {remote}")
    put(host, rbf, remote_rbf)
    put(host, rom, remote + "/ipl.rom")
    for _, filename, _, _ in extra:
        put(host, folder / filename, remote + '/' + filename)
    put(host, disk, remote + "/test.d88")
    put(host, config, "/media/fat/config/" + name + ".CFG")
    put(host, mgl, remote + "/" + name + ".mgl")
    upload_paths = [remote_rbf, remote + '/ipl.rom', remote + '/test.d88',
                    *(remote + '/' + n for _, n, _, _ in extra)]
    remote_hashes = ssh(host, f"chmod 444 {remote}/test.d88; sha256sum " + shlex.join(upload_paths))
    for expected in (evidence["rbf_sha256"], evidence["ipl_sha256"], evidence["disk_sha256"],
                     *(u['sha256'] for u in evidence['extra_uploads'])):
        if expected not in remote_hashes:
            raise RuntimeError("remote asset hash mismatch; refusing load")
    evidence["remote_asset_hashes"] = remote_hashes
    command(host, "load_core " + remote + "/" + name + ".mgl")
    time.sleep(12)  # MGL file delays, reset, then native IPL boot.
    evidence["post_load"] = status(host)
    (folder / "manifest.json").write_text(json.dumps(evidence, indent=2) + "\n")
    print(json.dumps({"evidence": str(folder), "post_load": evidence["post_load"]}), flush=True)
    capture(host, folder, "boot")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="mister.local")
    commands = parser.add_subparsers(dest="action", required=True)
    deployment = commands.add_parser("deploy")
    deployment.add_argument("rbf", type=pathlib.Path)
    deployment.add_argument("disk", type=pathlib.Path)
    deployment.add_argument("--drive", type=int, choices=(0, 1), default=0,
                            help="mount test copy in drive A (0) or B (1)")
    deployment.add_argument('--ipl', type=pathlib.Path, help='explicit 4/32-KiB binary IPL; choose for the board profile')
    deployment.add_argument('--font16', type=pathlib.Path, help='optional 4096-byte character-major ANK16 upload, index 4')
    deployment.add_argument('--physical-font', type=pathlib.Path,
                            help='262144-byte physical font upload, index 5; required by the external-font board even for ANK-only software')
    screenshot = commands.add_parser("capture")
    screenshot.add_argument("folder", type=pathlib.Path)
    screenshot.add_argument("label")
    keyboard = commands.add_parser("key")
    keyboard.add_argument("code", type=int, help="Linux input key code, negative holds shift")
    rapid = commands.add_parser("burst")
    rapid.add_argument("folder", type=pathlib.Path)
    rapid.add_argument("codes", type=int, nargs="+")
    args = parser.parse_args()
    if args.action == "deploy":
        deploy(args.host, args.rbf.resolve(), args.disk.resolve(), args.drive,
               args.ipl.resolve() if args.ipl else None, args.font16.resolve() if args.font16 else None,
               args.physical_font.resolve() if args.physical_font else None)
    elif args.action == "capture":
        if not args.label.replace("-", "").replace("_", "").isalnum():
            parser.error("label must be alphanumeric, dash or underscore")
        capture(args.host, args.folder.resolve(), args.label)
    elif args.action == "burst":
        burst(args.host, args.folder.resolve(), args.codes)
    else:
        key(args.host, args.code)


if __name__ == "__main__":
    main()
