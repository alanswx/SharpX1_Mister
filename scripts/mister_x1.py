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


def deploy(host, rbf, disk):
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    name = "X1HW_" + stamp + "_" + digest(rbf)[:8]
    folder = ROOT / "output_files" / name
    folder.mkdir(exist_ok=False)
    remote = "/media/fat/games/SharpX1/HWTest/" + name
    remote_rbf = "/media/fat/_Computer/" + name + ".rbf"
    rom = folder / "ipl.rom"
    data = bytes.fromhex((ROOT / "bios/ipl_x1.hex").read_text())
    # Existing IPL is 4095 bytes; preserve the core's FF fill of the last byte.
    if not 0 < len(data) <= 4096:
        raise ValueError("IPL does not fit 4 KiB")
    rom.write_bytes(data + bytes([255]) * (4096 - len(data)))
    config = folder / (name + ".CFG")
    config.write_bytes(bytes(16))  # Disk writes protected; independent setname.
    mgl = folder / (name + ".mgl")
    mgl.write_text("<mistergamedescription>\n"
                   f"  <rbf>_Computer/{name}</rbf>\n"
                   f'  <setname same_dir="1">{name}</setname>\n'
                   f'  <file delay="2" type="f" index="0" path="{remote}/ipl.rom"/>\n'
                   f'  <file delay="2" type="s" index="0" path="{remote}/test.d88"/>\n'
                   '  <reset delay="1"/>\n'
                   "</mistergamedescription>\n")
    evidence = {"host": host, "rbf": str(rbf), "rbf_sha256": digest(rbf),
                "disk": str(disk), "disk_sha256": digest(disk),
                "ipl_bytes": len(data), "ipl_sha256": digest(rom),
                "remote_rbf": remote_rbf, "remote_directory": remote,
                "pre_load": ssh(host, "cat /tmp/RBFNAME /tmp/ACTIVEGAME; uname -a"),
                "write_protection": "zero status config; disposable disk copy; chmod requested but FAT mode bits are not proof"}
    (folder / "manifest.json").write_text(json.dumps(evidence, indent=2) + "\n")
    # Timestamp/setname must not alias a previous test or an installed core.
    ssh(host, f"test ! -e {shlex.quote(remote)} && test ! -e {shlex.quote(remote_rbf)}"
              f" && test ! -e /media/fat/config/{name}.CFG && mkdir -p {remote}")
    put(host, rbf, remote_rbf)
    put(host, rom, remote + "/ipl.rom")
    put(host, disk, remote + "/test.d88")
    put(host, config, "/media/fat/config/" + name + ".CFG")
    put(host, mgl, remote + "/" + name + ".mgl")
    remote_hashes = ssh(host, f"chmod 444 {remote}/test.d88; sha256sum {remote_rbf} {remote}/ipl.rom {remote}/test.d88")
    for expected in (evidence["rbf_sha256"], evidence["ipl_sha256"], evidence["disk_sha256"]):
        if expected not in remote_hashes:
            raise RuntimeError("remote asset hash mismatch; refusing load")
    evidence["remote_asset_hashes"] = remote_hashes
    command(host, "load_core " + remote + "/" + name + ".mgl")
    time.sleep(12)  # MGL file delays, reset, then native IPL boot.
    evidence["post_load"] = ssh(host, "cat /tmp/RBFNAME /tmp/ACTIVEGAME /tmp/CORENAME")
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
        deploy(args.host, args.rbf.resolve(), args.disk.resolve())
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
