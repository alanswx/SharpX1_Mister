#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Independently recheck frozen native base-text hardware evidence."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / 'scripts'), str(ROOT / 'verilator/tests')]
from compare_video_png import rgb_png
from check_basic_reference import BANNER, check_rows
from check_basic_print42 import font_bytes
from mister_basic_reset import DirectBridge, ARITHMETIC, WARM_R, WARM_T, PROGRAM, KEYS


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    assert __debug__
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('output', type=Path)
    p.add_argument('--host', default='mister14')
    args = p.parse_args()
    out = args.output.resolve()
    m = json.loads((out / 'manifest.json').read_text())
    assert m['status'] == 'pass' and len(m['cases']) == 4
    assert all(sha(path) == h for path, h in m['inputs'].items())
    assert all(sha(ROOT / name) == h for name, h in m['compiler_inputs'].items())
    audit = json.loads(Path(m['build_audit']).read_text())
    assert audit['status'] == 'pass' and audit['build_exit_status'] == 0
    assert m['rbf_sha256'] == audit['rbf_sha256'] == sha(audit['rbf'])
    assert m['compiler_inputs'] == audit['compiler_inputs']
    for name, h in m['asset_hashes'].items():
        assert sha(out / 'assets' / name) == h
    assert m['asset_hashes']['core.rbf'] == m['rbf_sha256']
    g = font_bytes(ROOT / 'rtl/legacy/x1_cg8.v')
    font = bytes(g[i] for i in range(2048))
    cold_keys = [33, 14, *[KEYS[c] for c in 'PRINT 6*7'], 28]
    warm_keys = [88, 103, 103, 88, *[KEYS[c] for c in 'PRINT 9*9\n'],
                 88, 103, 103, 28, *[KEYS[c] for c in 'PRINT 9*9\n'],
                 88, 103, 103, 103, 28, 88, *[KEYS[c] for c in 'PRINT 8*8\n'],
                 *[KEYS[c] for c in '10 PRINT 9\nLIST\nRUN\n']]
    pixels_checked = 0
    pngs = []
    for index, case in enumerate(m['cases']):
        assert case['status'] == 'pass' and case['turbo'] == (index % 2 == 0)
        assert case['repeat'] == index // 2
        assert [a['key'] for a in case['actions']] == cold_keys + (warm_keys if index == 3 else [])
        folder = out / case['title']
        assert (folder / (case['setname'] + '.CFG')).read_bytes() == bytes(16)
        assert sha(out / (case['title'] + '.d88')) == m['asset_hashes']['basic.d88']
        tree = ET.fromstring((folder / (case['title'] + '.mgl')).read_bytes())
        assert tree.find('setname').text == case['setname']
        files = tree.findall('file')
        assert [(f.get('type'), f.get('index')) for f in files] == [('f', '0'), ('f', '4'), ('f', '5'), ('s', '0')]
        assert [Path(f.get('path')).name for f in files] == [
            'turbo.rom' if case['turbo'] else 'base.rom', 'ank16.rom', 'physical.rom', case['title'] + '.d88']
        assert files[-1].get('path') == case['disk']
        assert '/media/fat/' + tree.find('rbf').text + '.rbf' in m['remote_files']
        phases = ['before-F', 'after-F', 'no-enter', 'arithmetic']
        if index == 3:
            phases += ['menu-no-selection', 'no-reset', 'R-reset-and-close', 'T-reset', 'stored-program']
        assert [s['phase'] for s in case['screenshots']] == phases
        for s in case['screenshots']:
            path = out / s['file']
            assert sha(path) == s['sha256']
            dimensions, pixels = rgb_png(path)
            assert list(dimensions) == s['dimensions']
            phase = s['phase']
            if phase != 'before-F':
                banner = check_rows(dimensions, pixels, font, 4, (BANNER,), 1)
                assert banner == s['banner']
                pixels_checked += banner['checked_pixels']
            expected = {'arithmetic': (13, ARITHMETIC), 'menu-no-selection': (13, ARITHMETIC),
                        'no-reset': (16, WARM_R), 'R-reset-and-close': (13, WARM_R),
                        'T-reset': (13, WARM_T), 'stored-program': (16, PROGRAM)}
            if phase in expected:
                first, rows = expected[phase]
                result = check_rows(dimensions, pixels, font, first, rows, 1)
                assert result == s['transcript']
                pixels_checked += result['checked_pixels']
            if phase in ('no-enter', 'menu-no-selection', 'no-reset'):
                try:
                    check_rows(dimensions, pixels, font, 13, ARITHMETIC if phase == 'no-enter' else WARM_R, 1)
                except AssertionError as error:
                    assert str(error) == s['unchanged_completion_rejected']
                else:
                    raise AssertionError('Unchanged control completion accepted')
            pngs.append(dict(file=s['file'], sha256=sha(path), mrext=s['mrext']))
    assert pixels_checked == m['exact_pixels'] == 245760
    assert len({s['mrext']['path'] for s in pngs}) == len(pngs) == 21
    b = DirectBridge('', args.host)
    assert b.status() == m['final_status'] == m['cases'][-1]['post_test']
    remote = {path: h for path, h in m['remote_files'].items() if not path.endswith('.CFG')}
    remote['/media/fat/MiSTer'] = m['main_sha256']
    assert b.hashes(list(remote)) == remote
    assert b.ddr_hash() == m['asset_hashes']['physical.rom']
    result = dict(status='pass', manifest_sha256=sha(out / 'manifest.json'), auditor_sha256=sha(Path(__file__)),
                  raw_pngs=pngs, exact_pixels=pixels_checked, remote_checks=remote,
                  font_ddr_sha256=m['asset_hashes']['physical.rom'], final_status=b.status(),
                  scope='Bounded native cold arithmetic and base Main R/T reset/LIST/RUN, with unchanged rejecting controls; timing FAIL remains separate')
    (out / 'independent-audit.json').open('x').write(json.dumps(result, indent=2) + '\n')
    print('PASS independent native base-text audit', pixels_checked, 'pixels', len(pngs), 'raw PNGs')


if __name__ == '__main__':
    main()
