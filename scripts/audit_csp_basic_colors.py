#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Recompute native color pixels, command policy, CPU writes and preservation."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / 'scripts'), str(ROOT / 'verilator/tests')]
from compare_video_png import rgb_png
from check_basic_colors import check, check_window
from qualify_csp_basic import protected_disk


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    assert __debug__
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--native', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    out = args.native.resolve()
    n = json.loads((out / 'terminal.json').read_text())
    assert n['status'] == 'pass'
    assert all(sha(path) == h for path, h in (n['inputs'] | n['qualified_sources']).items())
    for path in n['inputs']:
        source = Path(path)
        if source.is_relative_to(ROOT) and source.suffix == '.py' and 'output_files' not in source.parts:
            assert (out / 'sources' / source.relative_to(ROOT)).read_bytes() == source.read_bytes()
    disk = ROOT / 'software/basic-unpacked/zzz-unk-hubasic-11a5077cf724/disk-0-ef47f5df772f.d88'
    assert sha(disk) == 'ef47f5df772f45d97be43646d8f8010d33eca8846913babfd1106e89a361ee6a'
    qpath = ROOT / 'output_files/BASIC_SAVE_20261016T223258Z/cli-qualification/terminal.json'
    q = json.loads(qpath.read_text())
    assert q['status'] == 'pass' and len(q['cases']) == 22
    assert all(sha(path) == h for path, h in (q['sources'] | q['binaries']).items())
    assert sha(out / 'x1') == sha(qpath.parent / 'bin/x1')
    original_assets = ROOT / 'output_files/CSPBasic_20261015T234906Z/accepted-csp/assets'
    assert {p.name: sha(p) for p in (out / 'assets').iterdir()} == {p.name: sha(p) for p in original_assets.iterdir()}
    names = [f'color-{c}{suffix}' for suffix in ('', '-repeat') for c in range(8)]
    names += ['erase', 'erase-repeat', 'color-no-enter', 'erase-no-enter', 'wrong-color', 'wrong-erase']
    assert [c['name'] for c in n['cases']] == names
    font = (out / 'assets/ANK8.ROM').read_bytes()
    total, writes_total, rejected = 0, 0, []
    for c in n['cases']:
        name, kind = c['name'], c['kind']
        assert c['status'] == 'pass'
        pending = name.endswith('no-enter')
        erase = name.startswith('erase') or name == 'wrong-erase'
        color = int(name.split('-')[1]) if name.startswith('color-') and not pending else 2 if name == 'wrong-color' else 1
        x = 401 if name == 'wrong-erase' else 400
        assert (kind, c['color'], c['x'], c['pending']) == ('erase' if erase else 'point', color, x, pending)
        final_text = f'PRESET({x},160)' if erase else f'PSET({x},160,{color})'
        plan = [(800, 'PSET(400,160,7)\n'), (1400, 'PSET(401,160,7)\n'),
                (2000, final_text + ('' if pending else '\n'))]
        assert c['plan'] == [list(pair) for pair in plan]
        folder = out / name
        assert all(sha(folder / key) == h for key, h in c['artifacts'].items())
        expected_command = [str(out / 'x1'), '--headless', '--rom-dir', str(out / 'assets'),
                            '--disk-a', str(disk), '--out', str(folder), '--stop-at-frame', '2799',
                            '--trace-io', 'io.csv', '--trace-from', '790', '--trace-to', '2799']
        for frame in (799, 1999, 2799):
            expected_command += ['--screenshot', str(frame)]
        for frame, text in plan:
            for char in text:
                key, shift = {',': (188, False), '(': (56, True), ')': (57, True),
                              '\n': (13, False)}.get(char, (ord(char), False))
                if shift:
                    expected_command += ['--key-down', f'{frame}:16']
                expected_command += ['--key-down', f'{frame}:{key}', '--key-up', f'{frame + 16}:{key}']
                if shift:
                    expected_command += ['--key-up', f'{frame + 16}:16']
                frame += 32
        assert c['command'] == expected_command
        assert json.loads((out / (name + '-process') / 'command.json').read_text()) == expected_command
        final = json.loads((out / (name + '-process') / 'stdout.log').read_text().splitlines()[-1])
        assert final == c['final'] == dict(status='complete', model='x1', completed_frames=2800,
            scheduled_resets=0, psg_only=True, disks_protected=True, headless=True, cli_revision=4,
            disk_policy='protected_private_copy', writable_drives=[False, False])
        assert (folder / 'disk-a.d88').read_bytes() == protected_disk(disk.read_bytes())
        phases = [(799, 'before'), (1999, 'seed'), (2799, 'pending' if pending else 'final')]
        assert c['phases'] == [list(pair) for pair in phases]
        for frame, stage in phases:
            dims, rgb = rgb_png(folder / f'frame_{frame:06d}.png')
            observed = check(dims, rgb, font, stage, kind, color, x)
            assert observed == c['checks'][str(frame)]
            total += sum(v['checked_pixels'] for v in observed.values())
        if pending or name.startswith('wrong-'):
            dims, rgb = rgb_png(folder / 'frame_002799.png')
            colors = {400: 0 if erase else 1, 401: 7}
            try:
                check_window(dims, rgb, colors)
            except AssertionError as error:
                assert error.args[0][0] == 'BASIC_COLOR_PIXEL'
                assert str(error) == c['unchanged_graphics_rejected']
                rejected.append(name)
            else:
                raise AssertionError('Control passed unchanged pixel oracle')
            if pending:
                try:
                    check(dims, rgb, font, 'final', kind, color, x)
                except AssertionError as error:
                    assert str(error) == c['unchanged_completion_rejected']
                else:
                    raise AssertionError('Missing Enter passed native completion')
        with (folder / 'frames.csv').open() as stream:
            frames = list(csv.DictReader(stream))
        assert len(frames) == 2800
        for i, row in enumerate(frames):
            assert tuple(int(row[key]) for key in ('frame', 'clock', 'width', 'height')) == (i, (i + 1) * 64580, 640, 400)
        # Independently derive all three plane writes for the two seeds and final RMW.
        addresses = [0x4000 + 20 * 80 + 50, 0x8000 + 20 * 80 + 50, 0xc000 + 20 * 80 + 50]
        final_colors = {400: 7, 401: 7}
        final_colors[x] = 0 if erase else color
        final_bytes = [sum((0x80 if col == 400 else 0x40) for col, ink in final_colors.items() if ink & (1 << bit))
                       for bit in range(3)]
        expected = list(zip(addresses, [0x80] * 3)) + list(zip(addresses, [0xc0] * 3))
        if not pending:
            expected += list(zip(addresses, final_bytes))
        with (folder / 'io.csv').open() as stream:
            writes = [row for row in csv.DictReader(stream) if row['kind'] == 'W' and int(row['address'], 16) >= 0x4000]
        actual = [(int(row['address'], 16), int(row['data'], 16)) for row in writes]
        assert actual == expected and len(writes) == c['cpu_graphics_writes']
        for i, row in enumerate(writes):
            lower, upper = [(800, 1400), (1400, 2000), (2000, 2800)][i // 3]
            assert lower <= int(row['frame']) < upper
        writes_total += len(writes)
    assert rejected == ['color-no-enter', 'erase-no-enter', 'wrong-color', 'wrong-erase']
    for name in [*(f'color-{c}' for c in range(8)), 'erase']:
        a, b = [next(c for c in n['cases'] if c['name'] == key) for key in (name, name + '-repeat')]
        fixed = [key for key in a['artifacts'] if key.endswith('.png') or key == 'frames.csv']
        assert all(a['artifacts'][key] == b['artifacts'][key] for key in fixed)
        repeat = next(r for r in n['repeat_checks'] if r['name'] == name)
        assert repeat['exact_artifacts'] == fixed
        assert repeat['other_raw_differences'] == [key for key in a['artifacts'] if a['artifacts'][key] != b['artifacts'][key]]
    assert total == n['exact_pixels'] and writes_total == n['cpu_graphics_writes']
    result = dict(status='pass', native_cases=len(n['cases']), pngs=3 * len(n['cases']),
                  exact_pixels=total, cpu_graphics_writes=writes_total, rejected=rejected,
                  native=str(out), native_manifest_sha256=sha(out / 'terminal.json'),
                  auditor_sha256=sha(Path(__file__)),
                  scope='Independent local artifact/pixel/CPU-write/command/source audit; no RTL or hardware acceptance')
    with args.output.open('x') as stream:
        stream.write(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))


if __name__ == '__main__':
    main()
