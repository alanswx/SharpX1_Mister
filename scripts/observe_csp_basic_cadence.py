#!/usr/bin/env python3
"""Observe native Turbo HuBASIC input at two explicit host key cadences.

This collector preserves failures. It does not change VM timing or turn a
missing transcript into acceptance. Inputs and collectors are frozen first.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    if not __debug__:
        raise SystemExit('assertions must be enabled')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    sys.path[:0] = [str(root / 'scripts'), str(root / 'verilator/tests')]
    from compare_video_png import rgb_png
    from check_basic_reference import check_csp
    out = args.out.resolve()
    out.mkdir()
    qualified_dir = root / 'output_files/CSPMac_20261015T225930Z/qualification-v3'
    qualified_path = qualified_dir / 'terminal.json'
    qualified = json.loads(qualified_path.read_text())
    assert qualified['status'] == 'pass'
    inputs = dict(qualified['sources'])
    exe = qualified_dir / 'bin/x1turbo'
    assert sha(exe) == qualified['executables']['x1turbo']
    origin = root / 'output_files/CSPMac_20261015T225930Z/native-v3-arcus/assets'
    disk = root / 'software/basic-unpacked/zzz-unk-hubasic-11a5077cf724/disk-0-ef47f5df772f.d88'
    helpers = [Path(__file__).resolve(), root / 'scripts/compare_video_png.py',
               root / 'verilator/tests/check_basic_reference.py']
    for path in [exe, disk, qualified_path, *helpers,
                 *(origin / n for n in ('IPLROM.X1T', 'ANK8.ROM', 'ANK16.ROM', 'KANJI.ROM'))]:
        inputs[str(path)] = sha(path)
    assert all(sha(path) == value for path, value in inputs.items())
    assets = out / 'assets'
    assets.mkdir()
    for name in ('IPLROM.X1T', 'ANK8.ROM', 'ANK16.ROM', 'KANJI.ROM'):
        shutil.copyfile(origin / name, assets / name)
    shutil.copy2(exe, out / 'x1turbo')
    sources = out / 'sources'
    sources.mkdir()
    for path in helpers:
        shutil.copyfile(path, sources / path.name)
    frozen = {str(p): sha(p) for p in [out / 'x1turbo', *assets.iterdir(), *sources.iterdir()]}
    report = {'status': 'running', 'inputs': inputs, 'frozen': frozen, 'cases': [],
              'scope': 'CSP Turbo IPL, pseudo-controller, PSG, zero virtual Kanji; host input cadence observation only'}

    def save():
        (out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')

    save()
    try:
        for name, rate, enter in [('fast-trace', '4:4', True), ('slow', '8:8', True),
                                  ('slow-repeat', '8:8', True), ('slow-no-enter', '8:8', False)]:
            command = [str(out / 'x1turbo'), '--headless', '--rom-dir', str(assets),
                       '--disk-a', str(disk), '--out', str(out / name), '--stop-at-frame', '1499',
                       '--type-rate', rate, '--type', '800:PRINT 6{V6A}7' + ('{RETURN}' if enter else ''),
                       '--screenshot', '749', '--screenshot', '1499', '--trace-io', 'io.csv',
                       '--trace-from', '790', '--trace-to', '1000', '--dump-memory', 'memory.bin']
            (out / (name + '-command.json')).write_text(json.dumps(command, indent=2) + '\n')
            with (out / (name + '.stdout')).open('w') as stdout, (out / (name + '.stderr')).open('w') as stderr:
                result = subprocess.run(command, stdout=stdout, stderr=stderr, timeout=240)
            assert result.returncode == 0
            final = json.loads((out / (name + '.stdout')).read_text().splitlines()[-1])
            assert final['cli_revision'] == 3 and final['model'] == 'x1turbo' and final['completed_frames'] == 1500
            dimensions, pixels = rgb_png(out / name / 'frame_001499.png')
            case = {'name': name, 'rate': rate, 'enter': enter, 'final': final,
                    'native_completion': False,
                    'artifacts': {p.name: sha(p) for p in (out / name).iterdir()}}
            try:
                case['pixels'] = check_csp(dimensions, pixels, (assets / 'ANK8.ROM').read_bytes(), 'arithmetic')
            except AssertionError as error:
                case['oracle_rejection'] = str(error)
            else:
                case['native_completion'] = True
            report['cases'].append(case)
            save()
            print('CSP_BASIC_CADENCE_OBSERVED', name, case['native_completion'], flush=True)
        assert all(sha(path) == value for path, value in (inputs | frozen).items())
        report['all_inputs_unchanged'] = True
        report['slow_repeat_identical'] = report['cases'][1]['artifacts'] == report['cases'][2]['artifacts']
        report['status'] = 'observed'
        save()
    except BaseException as error:
        report.update(status='fail', error=repr(error))
        save()
        raise


if __name__ == '__main__':
    main()
