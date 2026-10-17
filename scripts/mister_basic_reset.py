#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Native HuBASIC command/reset gate on an already owned fd9a0850 deployment.

No core reload, mount, upload or original-media write is performed here.
Requires the explicit Turbo IPL, ANK16 and synthetic physical-font deployment.
"""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import shlex
import subprocess
import sys
import time
import urllib.parse

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / 'scripts'), str(ROOT / 'verilator/tests')]
from mister_z_font_osd_reset import Bridge
from compare_video_png import rgb_png
from check_basic_print42 import font_bytes
from check_basic_reference import BANNER, check_rows

RBF_SHA = 'fd9a085061a5fa5f6cc3c929a37f5b266d2391b5dd1b14752f3d8f794db83692'
ARITHMETIC = (b'PRINT 6*7', b' 42', b'Ok')
WARM_R = (b'PRINT 9*9', b' 81', b'Ok')
WARM_T = (b'PRINT 8*8', b' 64', b'Ok')
PROGRAM = (b'10 PRINT 9', b'LIST', b'10 PRINT 9', b'Ok', b'RUN', b' 9', b'Ok')
KEYS = {'P': 25, 'R': 19, 'I': 23, 'N': 49, 'T': 20, 'L': 38, 'S': 31, 'U': 22,
        ' ': 57, '0': 11, '1': 2, '6': 7, '7': 8, '8': 9, '9': 10, '*': 55, '\n': 28}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class DirectBridge(Bridge):
    def python(self, code):
        return subprocess.run(['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=8',
                               self.host, shlex.join(['python3', '-c', code])],
                              check=True, capture_output=True, timeout=45).stdout


def main():
    assert __debug__
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--host', default='mister14')
    p.add_argument('--deployment', type=Path, required=True)
    p.add_argument('--compiler-manifest', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    deployment = args.deployment.resolve()
    d = json.loads((deployment / 'manifest.json').read_text())
    old = json.loads(args.compiler_manifest.read_text())
    assert d['rbf_sha256'] == old['rbf_sha256'] == RBF_SHA
    assert d['ipl_bytes'] == 32768
    assert d['disk_sha256'] == 'ef47f5df772f45d97be43646d8f8010d33eca8846913babfd1106e89a361ee6a'
    assert {u['index'] for u in d['extra_uploads']} == {4, 5}
    b = DirectBridge('', args.host)
    initial = b.status()
    assert initial == {'CORENAME': deployment.name, 'RBFNAME': 'SharpX1', 'ACTIVEGAME': ''}, 'MiSTer ownership changed'
    compiler = old['compiler_inputs']
    assert all(sha(ROOT / name) == h for name, h in compiler.items())
    source = ROOT / 'rtl/legacy/x1_cg8.v'
    g = font_bytes(source)
    font = bytes(g[i] for i in range(2048))
    files = [Path(__file__).resolve(), ROOT / 'scripts/mister_z_font_osd_reset.py',
             ROOT / 'scripts/compare_video_png.py', ROOT / 'verilator/tests/check_basic_reference.py',
             ROOT / 'verilator/tests/check_basic_print42.py', source]
    out = args.output.resolve()
    out.mkdir()
    for path in files:
        shutil_target = out / path.name
        shutil_target.write_bytes(path.read_bytes())
    inputs = {str(path): sha(path) for path in files}
    remote_paths = [d['remote_rbf'], d['remote_directory'] + '/ipl.rom', d['remote_directory'] + '/test.d88',
                    *(d['remote_directory'] + '/' + u['file'] for u in d['extra_uploads']), '/media/fat/MiSTer']
    expected = {d['remote_rbf']: RBF_SHA, d['remote_directory'] + '/ipl.rom': d['ipl_sha256'],
                d['remote_directory'] + '/test.d88': d['disk_sha256'],
                **{d['remote_directory'] + '/' + u['file']: u['sha256'] for u in d['extra_uploads']},
                '/media/fat/MiSTer': old['main_sha256']}
    assert b.hashes(remote_paths) == expected
    font_sha = next(u['sha256'] for u in d['extra_uploads'] if u['index'] == 5)
    assert b.ddr_hash() == font_sha
    m = {'status': 'running', 'deployment': str(deployment), 'deployment_manifest_sha256': sha(deployment / 'manifest.json'),
         'compiler_inputs': compiler, 'inputs': inputs, 'remote_expected': expected,
         'initial_status': initial, 'font_ddr_sha256': font_sha, 'actions': [], 'screenshots': [],
         'expected_rows': {'arithmetic': [s.decode() for s in ARITHMETIC], 'reset_R': [s.decode() for s in WARM_R],
                           'reset_T': [s.decode() for s in WARM_T], 'program': [s.decode() for s in PROGRAM]},
         'scope': 'Bounded native HuBASIC arithmetic, LIST/RUN and actual Main T/R reset on fitted fd9a0850; no timing closure, SAVE/LOAD, native Kanji or active-device reset claim'}

    def save():
        (out / 'manifest.json').write_text(json.dumps(m, indent=2) + '\n')

    def key(code, description):
        assert b.status() == initial, 'MiSTer ownership changed'
        m['actions'].append({'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                             'key': code, 'description': description})
        save()
        b.key(code)

    def type_text(text):
        for character in text:
            key(KEYS[character], 'native BASIC key ' + repr(character))

    def capture(phase, rows=None, first=13, reject=None):
        before = {v['path'] for v in json.loads(b.api('GET', 'screenshots'))}
        b.api('POST', 'controls/keyboard/raw_screenshot')
        time.sleep(3)
        fresh = [v for v in json.loads(b.api('GET', 'screenshots')) if v['path'] not in before]
        assert fresh, 'No fresh mrext PNG'
        for i, record in enumerate(fresh):
            data = b.api('GET', 'screenshots/' + urllib.parse.quote(record['path'], safe='/'))
            path = out / f'{phase}-{i:02d}.png'
            path.open('xb').write(data)
            dimensions, pixels = rgb_png(path)
            result = {'phase': phase, 'file': path.name, 'sha256': sha(path), 'mrext': record,
                      'banner': check_rows(dimensions, pixels, font, 4, (BANNER,), 1)}
            m['screenshots'].append(result)
            save()
            if rows is not None:
                result['transcript'] = check_rows(dimensions, pixels, font, first, rows, 1)
            if reject is not None:
                try:
                    check_rows(dimensions, pixels, font, 13, reject, 1)
                except AssertionError as error:
                    result['unchanged_completion_rejected'] = str(error)
                else:
                    raise AssertionError('Control satisfied unchanged completion oracle')
            save()
        print('PASS_HARDWARE_BASIC', phase, flush=True)

    def navigate(up, select):
        key(88, 'F12 open OSD')
        for _ in range(up):
            key(103, 'Up through final reset/Exit entries')
        key(28 if select else 88, 'Enter selects reset' if select else 'F12 closes without reset')

    save()
    try:
        key(14, 'Backspace removes exploratory F echoed at the BASIC prompt')
        type_text('PRINT 6*7')
        capture('no-enter', reject=ARITHMETIC)
        key(28, 'Enter executes the already typed native expression')
        capture('arithmetic', ARITHMETIC)
        navigate(2, False)
        capture('menu-no-selection', ARITHMETIC, reject=WARM_R)
        type_text('PRINT 9*9\n')
        capture('no-reset', WARM_R, 16, WARM_R)
        navigate(2, True)
        time.sleep(18)
        type_text('PRINT 9*9\n')
        capture('R-reset-and-close', WARM_R)
        navigate(3, True)
        time.sleep(18)
        key(88, 'F12 closes OSD retained by T Reset')
        type_text('PRINT 8*8\n')
        capture('T-reset', WARM_T)
        type_text('10 PRINT 9\nLIST\nRUN\n')
        capture('stored-program', PROGRAM, 16)
        assert b.status() == initial
        assert b.hashes(remote_paths) == expected and b.ddr_hash() == font_sha
        assert all(sha(ROOT / name) == h for name, h in compiler.items())
        assert all(sha(Path(path)) == h for path, h in inputs.items())
        assert sha(Path(d['disk'])) == d['disk_sha256']
        m['exact_pixels'] = sum(sum(s[k]['checked_pixels'] for k in ('banner', 'transcript') if k in s)
                                for s in m['screenshots'])
        m['status'] = 'pass'
        m['final_status'] = b.status()
    except BaseException as error:
        m.update(status='fail', error=repr(error))
        raise
    finally:
        save()


if __name__ == '__main__':
    main()
