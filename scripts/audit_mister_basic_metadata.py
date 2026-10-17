#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Audit terminal generated metadata controls; read MiSTer, never load/reset it."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import xml.etree.ElementTree as ET


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    if not __debug__:
        raise SystemExit('assertions must be enabled')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    parser.add_argument('--host', default='mister14')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    sys.path[:0] = [str(root / 'scripts'), str(root / 'verilator/tests')]
    from mister_basic_reset import DirectBridge
    from compare_video_png import rgb_png
    from check_basic_reference import BANNER, check_rows
    from check_basic_print42 import font_bytes
    out = args.output.resolve()
    manifest = json.loads((out / 'manifest.json').read_text())
    assert manifest['status'] == 'observed' and len(manifest['cases']) == 4
    assert all(sha(p) == h for p, h in manifest['inputs'].items())
    assert all(sha(root / n) == h for n, h in manifest['compiler_inputs'].items())
    assert all(sha(out / 'assets' / n) == h for n, h in manifest['asset_hashes'].items())
    frozen_count = 0
    for p, h in manifest['inputs'].items():
        frozen = out / 'sources' / Path(p).name
        if frozen.is_file():
            assert sha(frozen) == h
            frozen_count += 1
    assert frozen_count == 8
    base = (out / 'assets/base.rom').read_bytes()
    assert len(base) == 4096 and sha(out / 'assets/base.rom') == 'e6295a523008688421991b651ab61de392b28c67bec9efbf040b0004e4b70a2a'
    shim = bytes.fromhex('f3 210000 010038 110008 ed61 03 1b 7a b3 20f8 c30600')
    for initialize, name in ((False, 'skip.rom'), (True, 'initialize.rom')):
        expected = bytearray(base + b'\xff' * 28672)
        expected[:3] = bytes.fromhex('c30010')
        expected[0x1000:0x1000 + len(shim)] = shim
        if not initialize:
            expected[0x100a:0x100c] = bytes(2)
        assert (out / 'assets' / name).read_bytes() == expected
    glyphs = font_bytes(out / 'sources/x1_cg8.v')
    font = bytes(glyphs[i] for i in range(2048))
    checked, paths, cases = 0, set(), []
    for index, case in enumerate(manifest['cases']):
        initialize = index % 2 == 1
        assert case['status'] == 'observed' and case['initialize_kan'] == initialize and case['repeat'] == index // 2
        assert [a['key'] for a in case['actions']] == [33, 14, 25, 19, 23, 49, 20, 57, 7, 55, 8, 28]
        assert [s['phase'] for s in case['screenshots']] == ['before-F', 'after-F', 'no-enter', 'arithmetic']
        folder = out / case['title']
        mgl = folder / (case['title'] + '.mgl')
        tree = ET.fromstring(mgl.read_bytes())
        files = tree.findall('file')
        assert [(f.attrib['type'], f.attrib['index']) for f in files] == [('f', '0'), ('f', '5'), ('s', '0')]
        assert files[0].attrib['path'].endswith('/initialize.rom' if initialize else '/skip.rom')
        assert files[-1].attrib['path'] == case['disk']
        assert tree.find('setname').text == case['setname']
        assert sha(mgl) == manifest['remote_files'][case['mgl']]
        assert (folder / (case['setname'] + '.CFG')).read_bytes() == bytes(16)
        assert sha(out / (case['title'] + '.d88')) == manifest['asset_hashes']['basic.d88']
        frames = []
        for s in case['screenshots']:
            assert sha(out / s['file']) == s['sha256'] and s['mrext']['path'] not in paths
            paths.add(s['mrext']['path'])
            dimensions, pixels = rgb_png(out / s['file'])
            assert dimensions == (640, 200)
            assert (not any(pixels)) == s['all_black']
            complete = False
            try:
                banner = check_rows(dimensions, pixels, font, 4, (BANNER,), 1)
                transcript = check_rows(dimensions, pixels, font, 13, (b'PRINT 6*7', b' 42', b'Ok'), 1)
            except AssertionError:
                pass
            else:
                complete = True
            assert complete == s['completion']
            if s['phase'] == 'no-enter':
                assert not complete
            if initialize:
                check_rows(dimensions, pixels, font, 4, (BANNER,), 1)
            else:
                assert s['all_black']
            if s['phase'] == 'arithmetic':
                assert complete == case['native_interpreter_completion'] == initialize
                if complete:
                    checked += banner['checked_pixels'] + transcript['checked_pixels']
            frames.append({'file': s['file'], 'completion': complete, 'all_black': s['all_black']})
        cases.append({'title': case['title'], 'initialize_kan': initialize, 'frames': frames})
    assert len(paths) == 16 and checked == 40960
    bridge = DirectBridge('', args.host)
    assert bridge.status() == manifest['final_status']
    expected_remote = {p: h for p, h in manifest['remote_files'].items() if not p.endswith('.CFG')}
    expected_remote['/media/fat/MiSTer'] = manifest['main_sha256']
    assert bridge.hashes(list(expected_remote)) == expected_remote
    assert bridge.ddr_hash() == manifest['asset_hashes']['physical.rom']
    assert bridge.status() == manifest['final_status']
    audit = {'status': 'pass', 'scope': 'generated metadata initialization versus skip; not unmodified native base qualification',
             'manifest_sha256': sha(out / 'manifest.json'), 'auditor_sha256': sha(Path(__file__)),
             'fresh_pngs': len(paths), 'positive_exact_pixels': checked, 'cases': cases,
             'compiler_inputs': len(manifest['compiler_inputs']), 'remote_checks': expected_remote,
             'font_ddr_sha256': manifest['asset_hashes']['physical.rom']}
    with (out / 'independent-audit.json').open('x') as stream:
        stream.write(json.dumps(audit, indent=2) + '\n')
    print(json.dumps({'status': 'pass', 'audit_sha256': sha(out / 'independent-audit.json'),
                      'positive_exact_pixels': checked, 'fresh_pngs': len(paths)}))


if __name__ == '__main__':
    main()
