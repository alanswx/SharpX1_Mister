#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Native PSET/LINE through Main reset and real keys on an audited deployment."""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import shutil
import sys
import time
import urllib.parse

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / 'scripts'), str(ROOT / 'verilator/tests')]
from mister_basic_reset import DirectBridge
from compare_video_png import rgb_png
from check_basic_reference import BANNER, check_rows
from check_basic_print42 import font_bytes
from check_basic_graphics import command, check_window, check_completion

# MR16 x1map1 maps Shift+8/9 to parentheses. Negative mrext raw codes
# request a shifted tap. These are physical Linux keys, not injected text.
KEYS = dict(zip('ABCDEFGHIJKLMNOPQRSTUVWXYZ',
                (30, 48, 46, 32, 18, 33, 34, 35, 23, 36, 37, 38, 50,
                 49, 24, 25, 16, 19, 31, 20, 22, 47, 17, 45, 21, 44)))
KEYS.update({str(i): i + 1 for i in range(1, 10)})
KEYS.update({'0': 11, '(': -9, ')': -10, ',': 51, '-': 12})


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    assert __debug__
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--host', default='mister14')
    parser.add_argument('--deployment', type=Path, required=True)
    parser.add_argument('--csp-qualification', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--previous-attempt', type=Path)
    args = parser.parse_args()
    deployment = args.deployment.resolve()
    d = json.loads((deployment / 'manifest.json').read_text())
    audit = json.loads((deployment / 'independent-audit.json').read_text())
    q = json.loads(args.csp_qualification.read_text())
    assert d['status'] == audit['status'] == q['status'] == 'pass'
    assert sha(deployment / 'manifest.json') == audit['manifest_sha256']
    assert all(sha(p) == h for p, h in (d['inputs'] | q['inputs'] | q['qualified_inputs']).items())
    assert all(sha(ROOT / n) == h for n, h in d['compiler_inputs'].items())
    b = DirectBridge('', args.host)
    initial = b.status()
    assert initial == audit['final_status'], 'MiSTer ownership changed'
    assert b.hashes(list(audit['remote_checks'])) == audit['remote_checks']
    assert b.ddr_hash() == audit['font_ddr_sha256']
    out = args.output.resolve()
    out.mkdir()
    own = [Path(__file__).resolve(), ROOT / 'scripts/mister_basic_reset.py',
           ROOT / 'scripts/mister_z_font_osd_reset.py', ROOT / 'scripts/compare_video_png.py',
           ROOT / 'verilator/tests/check_basic_reference.py', ROOT / 'verilator/tests/check_basic_graphics.py',
           ROOT / 'verilator/tests/check_basic_print42.py', ROOT / 'rtl/legacy/x1_cg8.v']
    frozen = out / 'sources'
    frozen.mkdir()
    for p in own:
        shutil.copyfile(p, frozen / p.name)
    inputs = {str(p.resolve()): sha(p) for p in [*own, deployment / 'manifest.json',
              deployment / 'independent-audit.json', args.csp_qualification]}
    if args.previous_attempt:
        old = json.loads(args.previous_attempt.read_text())
        assert old['status'] == 'fail' and old['initial_status'] == initial
        assert sha(args.previous_attempt.parent / 'sources/mister_basic_graphics.py') == old['inputs'][str(Path(__file__).resolve())]
        inputs[str(args.previous_attempt.resolve())] = sha(args.previous_attempt)
    glyphs = font_bytes(ROOT / 'rtl/legacy/x1_cg8.v')
    font = bytes(glyphs[i] for i in range(2048))
    report = dict(status='running', scope='Audited external-font base IPL native PSET/LINE after Main R boots; no core reload/upload/remount. Synthetic font, no timing/native-font/broad graphics claim',
                  deployment=str(deployment), inputs=inputs, compiler_inputs=d['compiler_inputs'],
                  rbf_sha256=d['rbf_sha256'], initial_status=initial, cases=[])
    report['capture_policy'] = 'Preserve every fresh PNG; qualify every native 640x200 frame; retain other rasters as auxiliary without pixel acceptance. Require at least one native frame per phase.'
    report['previous_attempt'] = str(args.previous_attempt.resolve()) if args.previous_attempt else None

    def save():
        (out / 'manifest.json').write_text(json.dumps(report, indent=2) + '\n')

    def key(case, code):
        assert b.status() == initial, 'MiSTer ownership changed'
        case['actions'].append(dict(key=code, utc=datetime.datetime.now(datetime.timezone.utc).isoformat()))
        save()
        b.key(code)

    def capture(case, phase):
        before = {s['path'] for s in json.loads(b.api('GET', 'screenshots'))}
        b.api('POST', 'controls/keyboard/raw_screenshot')
        time.sleep(3)
        fresh = [s for s in json.loads(b.api('GET', 'screenshots')) if s['path'] not in before]
        assert fresh, 'No fresh mrext PNG'
        native_count = 0
        for i, record in enumerate(fresh):
            path = out / case['name'] / f'{phase}-{i:02d}.png'
            path.open('xb').write(b.api('GET', 'screenshots/' + urllib.parse.quote(record['path'], safe='/')))
            dimensions, pixels = rgb_png(path)
            s = dict(phase=phase, file=str(path.relative_to(out)), sha256=sha(path), mrext=record,
                     dimensions=dimensions)
            if dimensions != (640, 200):
                s['reason'] = 'auxiliary raster; no native pixel acceptance'
                case['auxiliary_screenshots'].append(s)
                save()
                continue
            native_count += 1
            case['screenshots'].append(s)
            save()
            if phase == 'complete':
                s.update(check_completion(dimensions, pixels, font, case['kind'], case['x']))
                if case['x'] != 400:
                    try:
                        check_window(dimensions, pixels, case['kind'])
                    except AssertionError as error:
                        assert error.args[0][0] == 'BASIC_GRAPHICS_PIXEL'
                        s['unchanged_graphics_rejected'] = str(error)
                    else:
                        raise AssertionError('Wrong coordinate passed unchanged graphics')
            else:
                s.update(banner=check_rows(dimensions, pixels, font, 4, (BANNER,), 1),
                         graphics=check_window(dimensions, pixels))
                if phase == 'before':
                    s['prompt'] = check_rows(dimensions, pixels, font, 12, (b'Ok',), 1)
                else:
                    try:
                        check_completion(dimensions, pixels, font, case['kind'], case['x'])
                    except AssertionError as error:
                        s['unchanged_completion_rejected'] = str(error)
                    else:
                        raise AssertionError('Missing Enter completed graphics')
            save()
        assert native_count, 'No fresh native 640x200 frame'
        assert b.status() == initial
        save()
        print('PASS_HARDWARE_BASIC_GRAPHICS', case['name'], phase, flush=True)

    save()
    try:
        for name, kind, x in [('point', 'point', 400), ('line', 'line', 400),
                              ('point-repeat', 'point', 400), ('line-repeat', 'line', 400),
                              ('wrong-point', 'point', 401)]:
            (out / name).mkdir()
            case = dict(name=name, kind=kind, x=x, actions=[], screenshots=[], auxiliary_screenshots=[], status='running')
            report['cases'].append(case)
            save()
            for code in (88, 103, 103, 28):
                key(case, code)
            time.sleep(18)
            capture(case, 'before')
            for c in command(kind, x):
                key(case, KEYS[c])
            capture(case, 'no-enter')
            key(case, 28)
            capture(case, 'complete')
            assert b.ddr_hash() == audit['font_ddr_sha256']
            assert b.hashes(list(audit['remote_checks'])) == audit['remote_checks']
            case['status'] = 'pass'
            save()
        assert all(sha(p) == h for p, h in (d['inputs'] | q['inputs'] | q['qualified_inputs'] | inputs).items())
        assert all(sha(ROOT / n) == h for n, h in d['compiler_inputs'].items())
        assert b.status() == initial
        report.update(status='pass', final_status=b.status(), remote_checks=audit['remote_checks'],
                      font_ddr_sha256=b.ddr_hash(), exact_pixels=sum(s[k]['checked_pixels'] for c in report['cases']
                      for s in c['screenshots'] for k in ('banner', 'prompt', 'transcript', 'graphics') if k in s))
    except BaseException as error:
        report.update(status='fail', error=repr(error))
        raise
    finally:
        save()


if __name__ == '__main__':
    main()
