#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Frozen native point/LINE cold repeats, CPU writes and rejecting controls."""
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
from check_basic_reference import BANNER, check_rows
from check_basic_graphics import command, check_window, check_completion, expected_writes
from qualify_csp_basic import protected_disk


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def events(text):
    result, frame = [], 800
    for c in text:
        vk, shift = {',': (0xbc, False), '(': (ord('8'), True), ')': (ord('9'), True),
                     '-': (0xbd, False), '\n': (13, False)}.get(c, (ord(c), False))
        if shift:
            result += ['--key-down', f'{frame}:16']
        result += ['--key-down', f'{frame}:{vk}', '--key-up', f'{frame + 16}:{vk}']
        if shift:
            result += ['--key-up', f'{frame + 16}:16']
        frame += 32
    assert frame < 1999
    return result


def main():
    assert __debug__
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    prior = ROOT / 'output_files/CSPBasic_20261015T234906Z/accepted-csp'
    q = json.loads((prior / 'terminal.json').read_text())
    assert q['status'] == 'pass'
    assert all(sha(p) == h for p, h in (q['inputs'] | q['frozen']).items())
    out = args.output.resolve()
    out.mkdir()
    shutil.copyfile(prior / 'x1', out / 'x1')
    (out / 'x1').chmod(0o755)
    shutil.copytree(prior / 'assets', out / 'assets')
    own = [Path(__file__).resolve(), ROOT / 'verilator/tests/check_basic_graphics.py',
           ROOT / 'verilator/tests/check_basic_reference.py', ROOT / 'scripts/compare_video_png.py']
    frozen = out / 'sources'
    frozen.mkdir()
    for path in own:
        shutil.copyfile(path, frozen / path.name)
    inputs = {str(p): sha(p) for p in [*own, prior / 'terminal.json', out / 'x1', *(out / 'assets').iterdir()]}
    font = (out / 'assets/ANK8.ROM').read_bytes()
    disk = ROOT / 'software/basic-unpacked/zzz-unk-hubasic-11a5077cf724/disk-0-ef47f5df772f.d88'
    inputs[str(disk)] = sha(disk)
    report = dict(status='running', scope='CSP pseudo-controller/PSG-only unmodified base IPL HuBASIC PSET/LINE; cold repeats, no Enter and wrong-coordinate controls; not hardware or broad BASIC graphics',
                  inputs=inputs, qualified_inputs=q['inputs'], cases=[])

    def save():
        (out / 'terminal.json').write_text(json.dumps(report, indent=2) + '\n')

    save()
    try:
        plans = [('point', 'point', 400, False), ('line', 'line', 400, False),
                 ('point-repeat', 'point', 400, False), ('line-repeat', 'line', 400, False),
                 ('point-no-enter', 'point', 400, True), ('line-no-enter', 'line', 400, True),
                 ('wrong-point', 'point', 401, False)]
        for name, kind, x, no_enter in plans:
            folder, process = out / name, out / (name + '-process')
            process.mkdir()
            text = command(kind, x) + ('' if no_enter else '\n')
            cmd = [str(out / 'x1'), '--headless', '--rom-dir', str(out / 'assets'),
                   '--disk-a', str(disk), '--out', str(folder), '--stop-at-frame', '1999',
                   '--screenshot', '799', '--screenshot', '1999', '--trace-io', 'io.csv',
                   '--trace-from', '790', '--trace-to', '1999', *events(text)]
            case = dict(name=name, kind=kind, x=x, no_enter=no_enter, command=cmd, status='running')
            report['cases'].append(case)
            save()
            (process / 'command.json').write_text(json.dumps(cmd, indent=2) + '\n')
            with (process / 'stdout.log').open('w') as so, (process / 'stderr.log').open('w') as se:
                result = subprocess.run(cmd, cwd=process, stdout=so, stderr=se, timeout=240)
            assert result.returncode == 0, 'process failure is not a negative'
            final = json.loads((process / 'stdout.log').read_text().splitlines()[-1])
            assert final['completed_frames'] == 2000 and final['scheduled_resets'] == 0
            assert final['cli_revision'] == 3 and final['disk_policy'] == 'protected_private_copy'
            assert (folder / 'disk-a.d88').read_bytes() == protected_disk(disk.read_bytes())
            dimensions, pixels = rgb_png(folder / 'frame_000799.png')
            case['before'] = dict(banner=check_rows(dimensions, pixels, font, 4, (BANNER,)),
                                  prompt=check_rows(dimensions, pixels, font, 12, (b'Ok',)),
                                  graphics=check_window(dimensions, pixels, vertical=2))
            dimensions, pixels = rgb_png(folder / 'frame_001999.png')
            if no_enter:
                case['after'] = dict(banner=check_rows(dimensions, pixels, font, 4, (BANNER,)),
                                     graphics=check_window(dimensions, pixels, vertical=2))
                try:
                    check_completion(dimensions, pixels, font, kind, vertical=2, lower=True)
                except AssertionError as error:
                    case['unchanged_completion_rejected'] = str(error)
                else:
                    raise AssertionError('Missing Enter completed graphics')
            else:
                case['after'] = check_completion(dimensions, pixels, font, kind, x, 2, True)
                if x != 400:
                    try:
                        check_window(dimensions, pixels, kind, vertical=2)
                    except AssertionError as error:
                        assert error.args[0][0] == 'BASIC_GRAPHICS_PIXEL'
                        case['unchanged_graphics_rejected'] = str(error)
                    else:
                        raise AssertionError('Wrong coordinate passed unchanged graphics')
            rows = list(csv.DictReader((folder / 'io.csv').open()))
            writes = [(int(r['address'], 16), int(r['data'], 16)) for r in rows
                      if r['kind'] == 'W' and int(r['address'], 16) >= 0x4000]
            assert writes == ([] if no_enter else expected_writes(kind, x)), 'native CPU GRAM write sequence'
            case.update(status='pass', cpu_graphics_writes=len(writes), final=final,
                        artifacts={p.name: sha(p) for p in folder.iterdir()})
            save()
            print('PASS_CSP_BASIC_GRAPHICS', name, flush=True)
        for kind in ('point', 'line'):
            a, b = [next(c for c in report['cases'] if c['name'] == n) for n in (kind, kind + '-repeat')]
            assert a['artifacts'] == b['artifacts'], 'cold repeat differs'
        assert all(sha(p) == h for p, h in (q['inputs'] | q['frozen'] | inputs).items())
        report.update(status='pass', exact_pixels=sum(v['checked_pixels'] for c in report['cases']
                      for stage in ('before', 'after') for v in c[stage].values()),
                      cpu_graphics_writes=sum(c['cpu_graphics_writes'] for c in report['cases']))
    except BaseException as error:
        report.update(status='fail', error=repr(error))
        raise
    finally:
        save()


if __name__ == '__main__':
    main()
