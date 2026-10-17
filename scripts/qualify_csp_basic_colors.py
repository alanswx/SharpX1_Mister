#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Frozen native eight-color PSET/PRESET matrix, repeats and matched controls."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / 'scripts'), str(ROOT / 'verilator/tests')]
from compare_video_png import rgb_png
from check_basic_colors import SEED, command, check, check_window, expected_writes, state
from qualify_csp_basic import protected_disk


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def events(frame, text):
    result = []
    for c in text:
        vk, shift = {',': (0xbc, False), '(': (ord('8'), True), ')': (ord('9'), True),
                     '\n': (13, False)}.get(c, (ord(c), False))
        if shift:
            result += ['--key-down', f'{frame}:16']
        result += ['--key-down', f'{frame}:{vk}', '--key-up', f'{frame + 16}:{vk}']
        if shift:
            result += ['--key-up', f'{frame + 16}:16']
        frame += 32
    return result, frame


def plans():
    cases = [(f'color-{c}{suffix}', 'point', c, 400, False)
             for suffix in ('', '-repeat') for c in range(8)]
    cases += [(f'erase{suffix}', 'erase', 1, 400, False) for suffix in ('', '-repeat')]
    return cases + [('color-no-enter', 'point', 1, 400, True),
                    ('erase-no-enter', 'erase', 1, 400, True),
                    ('wrong-color', 'point', 2, 400, False),
                    ('wrong-erase', 'erase', 1, 401, False)]


def main():
    assert __debug__
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--cli-qualification', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    qpath = args.cli_qualification.resolve()
    q = json.loads(qpath.read_text())
    assert q['status'] == 'pass' and len(q['cases']) == 22
    assert all(sha(n) == h for n, h in (q['sources'] | q['binaries']).items())
    out = args.output.resolve()
    out.mkdir()
    shutil.copy2(qpath.parent / 'bin/x1', out / 'x1')
    shutil.copytree(ROOT / 'output_files/CSPBasic_20261015T234906Z/accepted-csp/assets', out / 'assets')
    disk = Path(q['original'])
    assert sha(disk) == q['original_sha256']
    own = [Path(__file__).resolve(), ROOT / 'verilator/tests/check_basic_colors.py',
           ROOT / 'verilator/tests/check_basic_reference.py', ROOT / 'scripts/compare_video_png.py',
           ROOT / 'scripts/qualify_csp_basic.py']
    for n in own:
        target = out / 'sources' / n.relative_to(ROOT)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(n, target)
    inputs = {str(n): sha(n) for n in [*own, qpath, out / 'x1', disk, *(out / 'assets').iterdir()]}
    report = dict(status='running', inputs=inputs, qualified_sources=q['sources'], cases=[],
                  scope='Native CZ-8FB01 CSP base pseudo-controller/PSG-only PSET eight digital colors, shared-byte preservation and PRESET; not RTL, hardware or broad graphics acceptance')

    def save():
        (out / 'terminal.json').write_text(json.dumps(report, indent=2) + '\n')

    save()
    try:
        for name, kind, color, x, pending in plans():
            folder, process = out / name, out / (name + '-process')
            process.mkdir()
            plan = [(800, SEED[0] + '\n'), (1400, SEED[1] + '\n'),
                    (2000, command(kind, color, x) + ('' if pending else '\n'))]
            phases = [(799, 'before'), (1999, 'seed'), (2799, 'pending' if pending else 'final')]
            cmd = [str(out / 'x1'), '--headless', '--rom-dir', str(out / 'assets'),
                   '--disk-a', str(disk), '--out', str(folder), '--stop-at-frame', '2799',
                   '--trace-io', 'io.csv', '--trace-from', '790', '--trace-to', '2799']
            for frame, _ in phases:
                cmd += ['--screenshot', str(frame)]
            for i, (frame, text) in enumerate(plan):
                keys, end = events(frame, text)
                assert end < (plan[i + 1][0] if i + 1 < len(plan) else 2799)
                cmd += keys
            case = dict(name=name, kind=kind, color=color, x=x, pending=pending, plan=plan,
                        phases=phases, command=cmd, status='running', checks={})
            report['cases'].append(case)
            save()
            (process / 'command.json').write_text(json.dumps(cmd, indent=2) + '\n')
            with (process / 'stdout.log').open('w') as so, (process / 'stderr.log').open('w') as se:
                run = subprocess.run(cmd, cwd=process, stdout=so, stderr=se, timeout=240)
            assert run.returncode == 0, 'process failure is not a rejecting control'
            final = json.loads((process / 'stdout.log').read_text().splitlines()[-1])
            assert final == dict(status='complete', model='x1', completed_frames=2800,
                                 scheduled_resets=0, psg_only=True, disks_protected=True,
                                 headless=True, cli_revision=4, disk_policy='protected_private_copy',
                                 writable_drives=[False, False])
            assert (folder / 'disk-a.d88').read_bytes() == protected_disk(disk.read_bytes())
            for frame, stage in phases:
                dims, rgb = rgb_png(folder / f'frame_{frame:06d}.png')
                case['checks'][str(frame)] = check(dims, rgb, (out / 'assets/ANK8.ROM').read_bytes(),
                                                  stage, kind, color, x)
            dims, rgb = rgb_png(folder / 'frame_002799.png')
            if pending or name.startswith('wrong-'):
                try:
                    check_window(dims, rgb, state(kind, 1, 400))
                except AssertionError as error:
                    assert error.args[0][0] == 'BASIC_COLOR_PIXEL'
                    case['unchanged_graphics_rejected'] = str(error)
                else:
                    raise AssertionError('Control passed unchanged final RGB')
            if pending:
                try:
                    check(dims, rgb, (out / 'assets/ANK8.ROM').read_bytes(), 'final', kind, color, x)
                except AssertionError as error:
                    case['unchanged_completion_rejected'] = str(error)
                else:
                    raise AssertionError('Missing Enter completed native operation')
            with (folder / 'io.csv').open() as stream:
                writes = [(int(r['address'], 16), int(r['data'], 16)) for r in csv.DictReader(stream)
                          if r['kind'] == 'W' and int(r['address'], 16) >= 0x4000]
            assert writes == expected_writes(kind, color, x, pending), ('native CPU GRAM writes', writes)
            case.update(status='pass', final=final, cpu_graphics_writes=len(writes),
                        artifacts={n.name: sha(n) for n in folder.iterdir()})
            save()
            print('PASS_NATIVE_BASIC_COLORS', name, flush=True)
        report['repeat_checks'] = []
        for name in [*(f'color-{c}' for c in range(8)), 'erase']:
            a, b = [next(c for c in report['cases'] if c['name'] == n) for n in (name, name + '-repeat')]
            # No clock/storage-dependent artifact normalization. Check PNGs and frame clocks only.
            fixed = [n for n in a['artifacts'] if n.endswith('.png') or n == 'frames.csv']
            assert all(a['artifacts'][n] == b['artifacts'][n] for n in fixed), 'native frame repeat differs'
            report['repeat_checks'].append(dict(name=name, exact_artifacts=fixed,
                other_raw_differences=[n for n in a['artifacts'] if a['artifacts'][n] != b['artifacts'][n]]))
        assert all(sha(n) == h for n, h in (q['sources'] | q['binaries'] | inputs).items())
        report.update(status='pass', exact_pixels=sum(v['checked_pixels'] for c in report['cases']
                      for stage in c['checks'].values() for v in stage.values()),
                      cpu_graphics_writes=sum(c['cpu_graphics_writes'] for c in report['cases']))
    except BaseException as error:
        report.update(status='fail', error=repr(error))
        raise
    finally:
        save()


if __name__ == '__main__':
    main()
