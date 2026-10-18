#!/usr/bin/env python3
"""Save a raw (core-native, unscaled) MiSTer screenshot through mrext.

Requests mrext POST /api/controls/keyboard/raw_screenshot on the MiSTer, waits
for the new file in GET /api/screenshots and writes its PNG locally. The Mac
reaches the MiSTer through a jump host (default misterubuntu). Read-only apart
from the screenshot Main itself stores under /media/fat/screenshots.
Usage: mister_rawshot.py OUT.png [--host 10.0.2.192] [--jump misterubuntu]
"""
import argparse
import base64
import json
import shlex
import subprocess
import time
import urllib.parse


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('out')
    parser.add_argument('--host', default='10.0.2.192')
    parser.add_argument('--jump', default='misterubuntu')
    args = parser.parse_args()

    def ssh(command):
        inner = shlex.join(['ssh', '-o', 'BatchMode=yes', 'root@' + args.host, command])
        return subprocess.run(['ssh', '-o', 'BatchMode=yes', args.jump, inner],
                              check=True, capture_output=True, timeout=60).stdout

    def api(method, path):
        code = ("import urllib.request,base64; r=urllib.request.urlopen(urllib.request.Request("
                f"'http://127.0.0.1:8182/api/{path}',method='{method}'),timeout=35); "
                "print(base64.b64encode(r.read()).decode())")
        return base64.b64decode(ssh(shlex.join(['python3', '-c', code])))

    before = {v['path'] for v in json.loads(api('GET', 'screenshots'))}
    api('POST', 'controls/keyboard/raw_screenshot')
    for _ in range(10):
        time.sleep(2)
        new = [v for v in json.loads(api('GET', 'screenshots')) if v['path'] not in before]
        if new:
            break
    else:
        raise SystemExit('no new screenshot appeared')
    shot = max(new, key=lambda v: v['modified'])
    data = api('GET', 'screenshots/' + urllib.parse.quote(shot['path'], safe='/'))
    assert data.startswith(b'\x89PNG\r\n\x1a\n')
    with open(args.out, 'xb') as handle:
        handle.write(data)
    print(json.dumps({'mister_path': shot['path'], 'out': args.out}))


if __name__ == '__main__':
    main()
