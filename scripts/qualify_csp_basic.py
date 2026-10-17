#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Freeze native CZ-8FB01 CSP arithmetic, stored-program and reset checks.

Requires local private assets and a passing qualify_csp_x1.py output. It never
modifies that qualification, loads snapshots, injects RAM or mounts originals.
"""
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
from check_basic_reference import SEQUENCES, check_csp, check_rows

DISK_SHA = 'ef47f5df772f45d97be43646d8f8010d33eca8846913babfd1106e89a361ee6a'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def protected_disk(data):
    result = bytearray(data)
    offset = 0
    while offset < len(result):
        assert offset + 0x2b0 <= len(result)
        size = int.from_bytes(result[offset + 28:offset + 32], 'little')
        assert 0x2b0 <= size <= len(result) - offset
        result[offset + 0x1a] = 0x10
        offset += size
    assert offset
    return result


def main():
    assert __debug__, 'Assertions are required'
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--qualification', type=Path, required=True)
    parser.add_argument('--rom-dir', type=Path, required=True)
    parser.add_argument('--disk', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    qualification, rom, disk, out = (p.resolve() for p in
                                    (args.qualification, args.rom_dir, args.disk, args.output))
    qpath = qualification / 'terminal.json'
    q = json.loads(qpath.read_text())
    assert q['status'] == 'pass' and q['sources_unchanged'] and q['executables_unchanged']
    assert sha(disk) == DISK_SHA, 'Different BASIC release/container'
    executable = qualification / 'bin/x1'
    assert sha(executable) == q['executables']['x1']
    inputs = {str(p): sha(p) for p in (qpath, executable, disk, Path(__file__).resolve(),
              ROOT / 'verilator/tests/check_basic_reference.py', ROOT / 'scripts/compare_video_png.py')}
    for path, digest in q['sources'].items():
        assert sha(Path(path)) == digest, ('Qualified source changed', path)
        inputs[path] = digest
    for name in ('IPLROM.X1', 'ANK8.ROM', 'ANK16.ROM', 'KANJI.ROM'):
        inputs[str(rom / name)] = sha(rom / name)
    out.mkdir()
    (out / 'sources').mkdir()
    for path in inputs:
        p = Path(path)
        if p.suffix in ('.py', '.mm', '.cpp', '.h', '.txt') or p.is_relative_to(ROOT.parent / 'common_source_code'):
            target = out / 'sources' / p.relative_to(ROOT.parent)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(p, target)
    shutil.copy2(executable, out / 'x1')
    assets = out / 'assets'
    assets.mkdir()
    for name in ('IPLROM.X1', 'ANK8.ROM', 'ANK16.ROM', 'KANJI.ROM'):
        shutil.copyfile(rom / name, assets / name)
    frozen = {str(p): sha(p) for p in [out / 'x1', *assets.iterdir(), *filter(Path.is_file, (out / 'sources').rglob('*'))]}
    font = (assets / 'ANK8.ROM').read_bytes()
    report = {'status': 'running', 'inputs': inputs, 'frozen': frozen, 'cases': [],
              'scope': 'CSP pseudo-controller/PSG-only CZ-8FB01 native commands and retained reset; no general BASIC, save/load, Turbo or hardware claim'}

    def save():
        (out / 'terminal.json').write_text(json.dumps(report, indent=2) + '\n')

    def check(folder, frame, sequence):
        dimensions, pixels = rgb_png(folder / f'frame_{frame:06d}.png')
        return check_csp(dimensions, pixels, font, sequence)

    save()
    try:
        names = ('arithmetic', 'arithmetic-repeat', 'program', 'program-repeat',
                 'warm', 'warm-repeat', 'no-reset', 'no-enter')
        for name in names:
            folder = out / name
            process = out / (name + '-process')
            process.mkdir()
            program = name.startswith('program')
            warm = name.startswith('warm')
            late = warm or name == 'no-reset'
            command = [out / 'x1', '--headless', '--rom-dir', assets, '--disk-a', disk,
                       '--out', folder, '--stop-at-frame', 3099 if late else 1499,
                       '--trace-cpu', 'cpu.csv', '--trace-io', 'io.csv',
                       '--trace-from', 1599 if late else 0, '--trace-to', 1602 if late else 2,
                       '--dump-memory', 'memory.bin', '--screenshot', 1499]
            if program:
                command += ['--type', '800:10 PRINT 9{RETURN}', '--type', '1000:LIST{RETURN}',
                            '--type', '1200:RUN{RETURN}']
            else:
                command += ['--type', '800:PRINT 6{V6A}7' + ('' if name == 'no-enter' else '{RETURN}')]
            if late:
                command += ['--type', '2400:PRINT 9{V6A}9{RETURN}', '--screenshot', 3099]
            if warm:
                command += ['--reset-at', 1600]
            command = [str(a) for a in command]
            (process / 'command.json').write_text(json.dumps(command, indent=2) + '\n')
            case = {'name': name, 'command': command, 'status': 'running'}
            report['cases'].append(case)
            save()
            with (process / 'stdout.log').open('w') as so, (process / 'stderr.log').open('w') as se:
                result = subprocess.run(command, stdout=so, stderr=se, timeout=240)
            case['exit'] = result.returncode
            assert result.returncode == 0, 'Process failure is not a rejecting control'
            final = json.loads((process / 'stdout.log').read_text().splitlines()[-1])
            assert final['cli_revision'] == 3 and final['scheduled_resets'] == int(warm)
            assert final['completed_frames'] == (3100 if late else 1500)
            assert final['psg_only'] and final['disk_policy'] == 'protected_private_copy'
            assert (folder / 'disk-a.d88').read_bytes() == protected_disk(disk.read_bytes())
            case['final'] = final
            if name == 'no-enter':
                dimensions, pixels = rgb_png(folder / 'frame_001499.png')
                try:
                    check_csp(dimensions, pixels, font, 'arithmetic')
                except AssertionError as error:
                    case['unchanged_arithmetic_oracle_rejected'] = str(error)
                else:
                    raise AssertionError('No-Enter control completed arithmetic')
            else:
                case['before'] = check(folder, 1499, 'program' if program else 'arithmetic')
            if late:
                rows = list(csv.DictReader((folder / 'cpu.csv').open()))
                boots = [r for r in rows if r['pc'] == '0000' and r['opcode'] == 'c3']
                assert len(boots) == int(warm), 'Actual IPL instruction restart oracle'
                if warm:
                    assert boots[0]['frame'] == '1600'
                    case['after'] = check(folder, 3099, 'warm')
                else:
                    dimensions, pixels = rgb_png(folder / 'frame_003099.png')
                    case['appended_arithmetic'] = check_rows(dimensions, pixels, font, 16, SEQUENCES['warm'])
                    try:
                        check_csp(dimensions, pixels, font, 'warm')
                    except AssertionError as error:
                        case['unchanged_warm_oracle_rejected'] = str(error)
                    else:
                        raise AssertionError('No-reset control completed reboot oracle')
                case['traced_ipl_restarts'] = len(boots)
            case['artifacts'] = {p.name: sha(p) for p in folder.iterdir()}
            case['status'] = 'pass'
            save()
            print('PASS_CSP_BASIC', name, flush=True)
        for first in ('arithmetic', 'program', 'warm'):
            a, b = (next(c for c in report['cases'] if c['name'] == n) for n in (first, first + '-repeat'))
            assert a['artifacts'] == b['artifacts'], 'Native cold repeats differ'
        report['status'] = 'pass'
    except BaseException as error:
        report.update(status='fail', error=repr(error))
        raise
    finally:
        changed = []
        for path, digest in (inputs | frozen).items():
            try:
                equal = sha(Path(path)) == digest
            except OSError:
                equal = False
            if not equal:
                changed.append(path)
        report['changed_inputs_or_frozen_files'] = changed
        if changed:
            report.update(status='fail', error='Inputs or frozen files changed')
        save()
    assert report['status'] == 'pass'
    print('PASS_CSP_BASIC_GATE', out, flush=True)


if __name__ == '__main__':
    main()
