#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Recompute native graphics pixels/transcripts, CPU writes and matched controls."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / 'scripts'), str(ROOT / 'verilator/tests')]
from compare_video_png import rgb_png
from check_basic_reference import BANNER, check_rows
from check_basic_graphics import command, check_window, check_completion, expected_writes
from check_basic_print42 import font_bytes
from mister_basic_reset import DirectBridge
from mister_basic_graphics import KEYS
from qualify_csp_basic import protected_disk


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def rejected(call, message):
    try:
        call()
    except AssertionError as error:
        assert str(error) == message
    else:
        raise AssertionError('Unchanged completion accepted a control')


def audit_csp(out):
    report = json.loads((out / 'terminal.json').read_text())
    assert report['status'] == 'pass'
    assert all(sha(p) == h for p, h in (report['inputs'] | report['qualified_inputs']).items())
    plans = [('point', 'point', 400, False), ('line', 'line', 400, False),
             ('point-repeat', 'point', 400, False), ('line-repeat', 'line', 400, False),
             ('point-no-enter', 'point', 400, True), ('line-no-enter', 'line', 400, True),
             ('wrong-point', 'point', 401, False)]
    assert [(c['name'], c['kind'], c['x'], c['no_enter']) for c in report['cases']] == plans
    font = (out / 'assets/ANK8.ROM').read_bytes()
    disk = ROOT / 'software/basic-unpacked/zzz-unk-hubasic-11a5077cf724/disk-0-ef47f5df772f.d88'
    total, writes_total = 0, 0
    for c in report['cases']:
        folder = out / c['name']
        assert c['status'] == 'pass'
        assert all(sha(folder / name) == h for name, h in c['artifacts'].items())
        assert (folder / 'disk-a.d88').read_bytes() == protected_disk(disk.read_bytes())
        dims, rgb = rgb_png(folder / 'frame_000799.png')
        before = dict(banner=check_rows(dims, rgb, font, 4, (BANNER,)),
                      prompt=check_rows(dims, rgb, font, 12, (b'Ok',)),
                      graphics=check_window(dims, rgb, vertical=2))
        assert before == c['before']
        dims, rgb = rgb_png(folder / 'frame_001999.png')
        if c['no_enter']:
            after = dict(banner=check_rows(dims, rgb, font, 4, (BANNER,)),
                         graphics=check_window(dims, rgb, vertical=2))
            rejected(lambda: check_completion(dims, rgb, font, c['kind'], vertical=2, lower=True),
                     c['unchanged_completion_rejected'])
        else:
            after = check_completion(dims, rgb, font, c['kind'], c['x'], 2, True)
            if c['x'] != 400:
                rejected(lambda: check_window(dims, rgb, c['kind'], vertical=2),
                         c['unchanged_graphics_rejected'])
        assert after == c['after']
        rows = list(csv.DictReader((folder / 'io.csv').open()))
        writes = [(int(r['address'], 16), int(r['data'], 16)) for r in rows
                  if r['kind'] == 'W' and int(r['address'], 16) >= 0x4000]
        assert writes == ([] if c['no_enter'] else expected_writes(c['kind'], c['x']))
        assert len(writes) == c['cpu_graphics_writes']
        writes_total += len(writes)
        total += sum(v['checked_pixels'] for stage in (before, after) for v in stage.values())
    for kind in ('point', 'line'):
        a, b = [next(c for c in report['cases'] if c['name'] == n) for n in (kind, kind + '-repeat')]
        assert a['artifacts'] == b['artifacts']
    assert total == report['exact_pixels'] == 346112 and writes_total == report['cpu_graphics_writes'] == 105
    return dict(status='pass', terminal_sha256=sha(out / 'terminal.json'), exact_pixels=total,
                cpu_graphics_writes=writes_total, cold_repeats_identical=True)


def audit_hardware(out, csp, host):
    report = json.loads((out / 'manifest.json').read_text())
    assert report['status'] == 'pass'
    assert all(sha(p) == h for p, h in report['inputs'].items())
    assert all(sha(ROOT / n) == h for n, h in report['compiler_inputs'].items())
    plans = [('point', 'point', 400), ('line', 'line', 400), ('point-repeat', 'point', 400),
             ('line-repeat', 'line', 400), ('wrong-point', 'point', 401)]
    assert [(c['name'], c['kind'], c['x']) for c in report['cases']] == plans
    glyphs = font_bytes(ROOT / 'rtl/legacy/x1_cg8.v')
    font = bytes(glyphs[i] for i in range(2048))
    total, pngs, auxiliary, paths = 0, [], [], set()
    for c in report['cases']:
        assert c['status'] == 'pass'
        assert [a['key'] for a in c['actions']] == [88, 103, 103, 28, *[KEYS[ch] for ch in command(c['kind'], c['x'])], 28]
        phases = [s['phase'] for s in c['screenshots']]
        assert set(phases) == {'before', 'no-enter', 'complete'}
        assert phases == sorted(phases, key=('before', 'no-enter', 'complete').index)
        for s in c['screenshots']:
            p = out / s['file']
            assert sha(p) == s['sha256'] and s['mrext']['path'] not in paths
            paths.add(s['mrext']['path'])
            dims, rgb = rgb_png(p)
            assert dims == (640, 200) and list(dims) == s['dimensions']
            if s['phase'] == 'complete':
                expected = check_completion(dims, rgb, font, c['kind'], c['x'])
                if c['x'] != 400:
                    rejected(lambda: check_window(dims, rgb, c['kind']), s['unchanged_graphics_rejected'])
                # Compare logical graphics directly across both renderers;
                # CSP duplicates each low-scan row, hardware emits one row.
                cdims, crgb = rgb_png(csp / c['name'] / 'frame_001999.png')
                assert cdims == (640, 400) and dims == (640, 200)
                for y in range(152, 184):
                    a, b = (y * 640 + 392) * 3, (2 * y * 640 + 392) * 3
                    assert rgb[a:a + 96] == crgb[b:b + 96] == crgb[b + 1920:b + 2016]
            else:
                expected = dict(banner=check_rows(dims, rgb, font, 4, (BANNER,), 1),
                                graphics=check_window(dims, rgb))
                if s['phase'] == 'before':
                    expected['prompt'] = check_rows(dims, rgb, font, 12, (b'Ok',), 1)
                else:
                    rejected(lambda: check_completion(dims, rgb, font, c['kind'], c['x']),
                             s['unchanged_completion_rejected'])
            assert all(s[k] == v for k, v in expected.items())
            total += sum(v['checked_pixels'] for v in expected.values())
            pngs.append(dict(file=s['file'], sha256=sha(p), mrext=s['mrext']))
        for s in c['auxiliary_screenshots']:
            p = out / s['file']
            assert sha(p) == s['sha256'] and s['mrext']['path'] not in paths
            paths.add(s['mrext']['path'])
            dims, _ = rgb_png(p)
            assert dims != (640, 200) and list(dims) == s['dimensions']
            assert s['reason'] == 'auxiliary raster; no native pixel acceptance'
            auxiliary.append(dict(file=s['file'], sha256=sha(p), dimensions=dims, mrext=s['mrext']))
    assert total == report['exact_pixels'] and total >= 168960 and len(pngs) >= 15
    b = DirectBridge('', host)
    assert b.status() == report['final_status'] == report['initial_status']
    assert b.hashes(list(report['remote_checks'])) == report['remote_checks']
    assert b.ddr_hash() == report['font_ddr_sha256']
    return dict(status='pass', manifest_sha256=sha(out / 'manifest.json'), exact_pixels=total,
                raw_pngs=pngs, remote_checks=report['remote_checks'], final_status=b.status(),
                auxiliary_screenshots=auxiliary, logical_graphics_match_csp=True)


def main():
    assert __debug__
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--csp', type=Path, required=True)
    p.add_argument('--hardware', type=Path)
    p.add_argument('--host', default='mister14')
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    result = dict(status='pass', auditor_sha256=sha(Path(__file__)), csp=audit_csp(args.csp))
    if args.hardware:
        result['hardware'] = audit_hardware(args.hardware, args.csp, args.host)
    args.output.open('x').write(json.dumps(result, indent=2) + '\n')
    print('PASS independent BASIC graphics audit', result['csp']['exact_pixels'],
          result.get('hardware', {}).get('exact_pixels', 'hardware pending'))


if __name__ == '__main__':
    main()
