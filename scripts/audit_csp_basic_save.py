#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Independent local SAVE/LOAD artifact, pixel, disk and source audit."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / 'scripts'), str(ROOT / 'verilator/tests')]
from compare_video_png import rgb_png
from check_basic_reference import BANNER, check_rows
from check_basic_save import MARKER, MUTANT, check, result, sectors, disk_changes
from qualify_csp_basic import protected_disk


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    assert __debug__
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--cli', type=Path, required=True)
    p.add_argument('--native', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    cli, native = args.cli.resolve(), args.native.resolve()
    q, n = [json.loads((folder / 'terminal.json').read_text()) for folder in (cli, native)]
    assert q['status'] == n['status'] == 'pass' and len(q['cases']) == 22
    assert all(sha(path) == h for path, h in (q['sources'] | q['binaries'] | n['inputs'] | n['qualified_sources']).items())
    original = Path(q['original'])
    assert sha(original) == q['original_sha256'] == 'ef47f5df772f45d97be43646d8f8010d33eca8846913babfd1106e89a361ee6a'
    assert MARKER not in original.read_bytes() and MUTANT not in original.read_bytes()
    for c in q['cases']:
        if c.get('artifacts'):
            assert all(sha(cli / c['name'] / name) == h for name, h in c['artifacts'].items())
        if c['name'].startswith('reject-'):
            assert c['exit'] == 2 and c['final'] is None and c['reason'] in c['stderr']
            assert not any((cli / c['name']).glob('*.d88'))
    for name in ('base', 'warm', 'keyboard', 'turbo', 'z'):
        a, b = [next(c for c in q['cases'] if c['name'] == name + version) for version in ('-v3', '-v4')]
        assert a['artifacts'] == b['artifacts']
    for name in ('protected', 'writable-a', 'mixed', 'writable-both'):
        c = next(c for c in q['cases'] if c['name'] == name)
        for drive in range(2 if name in ('mixed', 'writable-both') else 1):
            writable = c['final']['writable_drives'][drive]
            filename = ('written-' if writable else 'disk-') + ('a' if drive == 0 else 'b') + '.d88'
            assert (cli / name / filename).read_bytes() == (original.read_bytes() if writable else protected_disk(original.read_bytes()))
    assert (cli / 'existing.d88').read_bytes() == b'preserve-existing-output'
    assert (cli / 'source-link.d88').is_symlink() and sha(cli / 'source-link.d88') == sha(original)
    assert (cli / 'source-hardlink.d88').stat().st_ino == original.stat().st_ino
    names = ['save-load', 'save-load-repeat', 'protected', 'no-save-enter', 'no-load',
             'cold-load', 'cold-load-repeat', 'cold-no-load', 'cold-mutant']
    assert [c['name'] for c in n['cases']] == names
    total, rejected = 0, []
    font = (native / 'assets/ANK8.ROM').read_bytes()
    for c in n['cases']:
        assert c['status'] == 'pass' and sha(c['source']) == c['source_sha256']
        folder = native / c['name']
        assert all(sha(folder / name) == h for name, h in c['artifacts'].items())
        assert json.loads((native / (c['name'] + '-process') / 'command.json').read_text()) == c['command']
        for frame, kind in c['phases']:
            dims, rgb = rgb_png(folder / f'frame_{frame:06d}.png')
            if kind == 'before':
                observed = dict(banner=check_rows(dims, rgb, font, 4, (BANNER,)),
                                prompt=check_rows(dims, rgb, font, 12, (b'Ok',)))
            else:
                observed = check(dims, rgb, font, 'program' if kind == 'pending' else kind,
                                 mutant=c['name'] == 'cold-mutant')
            assert observed == c['checks'][str(frame)]
            total += sum(v['checked_pixels'] for v in observed.values())
        if 'unchanged_completion_rejected' in c:
            frame = c['phases'][-1][0]
            dims, rgb = rgb_png(folder / f'frame_{frame:06d}.png')
            try:
                if c['name'] in ('protected', 'no-save-enter'):
                    check(dims, rgb, font, 'saved')
                else:
                    result(dims, rgb, font, c['name'].startswith('cold'))
            except AssertionError as error:
                assert str(error) == c['unchanged_completion_rejected']
                rejected.append(c['name'])
            else:
                raise AssertionError('Control accepted unchanged native completion')
        image = folder / ('writable.d88' if c['writable'] else 'disk-a.d88')
        source = Path(c['source']).read_bytes()
        if c['name'].startswith('cold') or c['name'] == 'protected':
            assert image.read_bytes() == protected_disk(source)
        elif c['name'] == 'no-save-enter':
            assert image.read_bytes() == original.read_bytes()
        else:
            assert disk_changes(original.read_bytes(), image.read_bytes()) == c['observed_sector_changes']
            assert image.read_bytes().count(MARKER) == 1
    assert rejected == ['protected', 'no-save-enter', 'no-load', 'cold-no-load', 'cold-mutant']
    assert next(c for c in n['cases'] if c['name'] == 'cold-load')['source'] == str(native / 'save-load/writable.d88')
    assert next(c for c in n['cases'] if c['name'] == 'cold-load-repeat')['source'] == str(native / 'save-load-repeat/writable.d88')
    mutation = n['mutation']
    a, b = (native / 'save-load/writable.d88').read_bytes(), Path(mutation['source']).read_bytes()
    offset = mutation['offset']
    assert sum(x != y for x, y in zip(a, b)) == 1 and a[offset] == MARKER[-1] and b[offset] == MUTANT[-1]
    assert a[offset - 7:offset + 1] == MARKER and b[offset - 7:offset + 1] == MUTANT
    assert any(start <= offset - 7 and offset + 1 <= end for _, _, _, start, end in sectors(a))
    for name in ('save-load', 'cold-load'):
        first, second = [next(c for c in n['cases'] if c['name'] == x) for x in (name, name + '-repeat')]
        fixed = [key for key in first['artifacts'] if key == 'frames.csv' or key.endswith('.png')]
        assert all(first['artifacts'][key] == second['artifacts'][key] for key in fixed)
        r = next(r for r in n['repeat_checks'] if r['name'] == name)
        assert r['exact_frame_artifacts'] == fixed
        assert r['raw_nonidentical_artifacts'] == [key for key in first['artifacts'] if first['artifacts'][key] != second['artifacts'][key]]
    assert total == n['exact_pixels']
    assert all(sha(path) == h for path, h in (q['sources'] | q['binaries'] | n['inputs']).items())
    record = dict(status='pass', auditor_sha256=sha(Path(__file__)), cli_terminal_sha256=sha(cli / 'terminal.json'),
                  native_terminal_sha256=sha(native / 'terminal.json'), cli_cases=22, native_cases=9,
                  exact_pixels=total, rejected_controls=rejected, original_sha256=sha(original),
                  repeats=n['repeat_checks'], mutant=mutation,
                  scope='Local reference only. User owns MiSTer; hardware SAVE/LOAD unexecuted. Raw disk/RAM not normalized or claimed byte-identical.')
    args.output.open('x').write(json.dumps(record, indent=2) + '\n')
    print('PASS independent native SAVE audit', total, 'pixels, original unchanged, five rejecting controls')


if __name__ == '__main__':
    main()
