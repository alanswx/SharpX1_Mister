#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Recheck terminal matched BASIC observations without touching MiSTer.

Successful arithmetic and absent-Enter controls use the frozen collector's
unchanged oracle. Blank base cases are observations, not negative-test passes.
"""
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
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    out = args.output.resolve()
    sys.path[:0] = [str(root / 'scripts'), str(root / 'verilator/tests')]
    from compare_video_png import rgb_png
    from check_basic_reference import BANNER, check_rows
    from check_basic_print42 import font_bytes
    manifest = json.loads((out / 'manifest.json').read_text())
    assert manifest['status'] == 'observed', 'collection is not terminal'
    assert len(manifest['cases']) == 8
    assert all(sha(path) == value for path, value in manifest['inputs'].items())
    assert all(sha(root / name) == value for name, value in manifest['compiler_inputs'].items())
    assert all(sha(out / 'assets' / name) == value for name, value in manifest['asset_hashes'].items())
    source_count = 0
    for path, value in manifest['inputs'].items():
        frozen = out / 'sources' / Path(path).name
        if frozen.is_file():
            assert sha(frozen) == value
            source_count += 1
    assert source_count == 8
    glyphs = font_bytes(out / 'sources/x1_cg8.v')
    font = bytes(glyphs[i] for i in range(2048))
    phases = ['before-F', 'after-F', 'no-enter', 'arithmetic']
    keys = [33, 14, 25, 19, 23, 49, 20, 57, 7, 55, 8, 28]
    cases, seen_paths, checked_pixels = [], set(), 0
    rows = (b'PRINT 6*7', b' 42', b'Ok')
    for index, case in enumerate(manifest['cases']):
        expected_turbo, expected_ank = [(False, False), (True, False), (False, True), (True, True)][index % 4]
        assert (case['turbo'], case['ank16'], case['repeat']) == (expected_turbo, expected_ank, index // 4)
        assert case['status'] == 'observed'
        assert [action['key'] for action in case['actions']] == keys
        folder = out / case['title']
        mgl_path = folder / (case['title'] + '.mgl')
        tree = ET.fromstring(mgl_path.read_bytes())
        uploads = tree.findall('file')
        assert [(u.attrib['type'], u.attrib['index']) for u in uploads] == [
            ('f', '0'), *([('f', '4')] if expected_ank else []), ('f', '5'), ('s', '0')]
        assert uploads[0].attrib['path'].endswith('/turbo.rom' if expected_turbo else '/base.rom')
        assert uploads[-1].attrib['path'] == case['disk']
        assert tree.find('setname').text == case['setname']
        assert (folder / (case['setname'] + '.CFG')).read_bytes() == bytes(16)
        assert sha(out / (case['title'] + '.d88')) == manifest['asset_hashes']['basic.d88']
        assert sha(mgl_path) == manifest['remote_files'][case['mgl']]
        assert [s['phase'] for s in case['screenshots']] == phases
        observations = []
        for screenshot in case['screenshots']:
            path = out / screenshot['file']
            assert sha(path) == screenshot['sha256']
            assert screenshot['mrext']['path'] not in seen_paths
            seen_paths.add(screenshot['mrext']['path'])
            dimensions, pixels = rgb_png(path)
            assert dimensions == (640, 200)
            completion = False
            try:
                banner = check_rows(dimensions, pixels, font, 4, (BANNER,), 1)
                transcript = check_rows(dimensions, pixels, font, 13, rows, 1)
            except AssertionError:
                pass
            else:
                completion = True
            assert completion == screenshot['completion']
            if screenshot['phase'] == 'no-enter':
                assert not completion
                if expected_turbo:
                    check_rows(dimensions, pixels, font, 4, (BANNER,), 1)
            if screenshot['phase'] == 'arithmetic':
                assert completion == case['native_completion'] == expected_turbo
                if completion:
                    checked_pixels += banner['checked_pixels'] + transcript['checked_pixels']
            all_black = not any(pixels)
            if not expected_turbo:
                assert all_black, 'base observation is no longer the recorded all-black frame'
            observations.append({'file': screenshot['file'], 'phase': screenshot['phase'],
                                 'completion': completion, 'all_black': all_black})
        cases.append({'title': case['title'], 'native_completion': case['native_completion'],
                      'observations': observations})
    assert checked_pixels == 81920 and len(seen_paths) == 32
    assert manifest['final_status'] == manifest['cases'][-1]['post_test']
    audit = {'status': 'pass', 'scope': 'observation audit, not base-profile acceptance or hardware timing',
             'manifest_sha256': sha(out / 'manifest.json'), 'compiler_inputs': len(manifest['compiler_inputs']),
             'frozen_sources': source_count, 'fresh_pngs': len(seen_paths),
             'positive_exact_pixels': checked_pixels, 'cases': cases}
    target = out / 'independent-audit.json'
    with target.open('x') as stream:
        stream.write(json.dumps(audit, indent=2) + '\n')
    print(json.dumps({'status': 'pass', 'audit_sha256': sha(target),
                      'positive_exact_pixels': checked_pixels, 'fresh_pngs': len(seen_paths)}))


if __name__ == '__main__':
    main()
