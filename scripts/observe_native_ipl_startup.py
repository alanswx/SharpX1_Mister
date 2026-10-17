#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Freeze the shared external-font machine and observe early native IPL I/O.

No disk is attached. These traces diagnose startup; process completion is
not native game/BASIC acceptance. Existing timed-out collections are untouched.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    if not __debug__:
        raise SystemExit('assertions must be enabled')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--metadata-controls', type=Path,
                        help='frozen output of the generated hardware shim collector')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    out = args.out.resolve()
    out.mkdir()
    reference = root / 'output_files/BASIC_IPL_20261016T030331Z'
    origins = {'base-ff': reference / 'tail-inputs/base-ff-tail-32k.rom',
               'turbo': reference / 'assets/turbo.rom',
               'font': reference / 'assets/physical.rom'}
    expected = {'base-ff': 'f0f3e3e07c268fd001eebbd4c841711688e23b5ca85a6ddaba4a79b980a0f836',
                'turbo': '212895703175665be8544daa55b65da1aebcf1e9a2db65bcc1622e564b802b71',
                'font': 'd18c7cb9c91d05b3d70e9061ce0ef36d2976960e1bb74984f3ef85fd17d7032b'}
    assert all(sha(origins[name]) == value for name, value in expected.items())
    if args.metadata_controls:
        import importlib.util
        controls = args.metadata_controls.resolve()
        emitter = controls / 'sources/mister_basic_metadata_control.py'
        spec = importlib.util.spec_from_file_location('frozen_metadata_emitter', emitter)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        base = (controls / 'assets/base.rom').read_bytes()
        origins = {name: controls / 'assets' / (name + '.rom') for name in ('skip', 'initialize')}
        for name, initialize in (('skip', False), ('initialize', True)):
            assert origins[name].read_bytes() == module.diagnostic_ipl(base, initialize)
        origins['font'] = reference / 'assets/physical.rom'
    manifest = root / 'rtl/machine.qip'
    order = re.findall(r'^set_global_assignment -name (?:SYSTEMVERILOG_FILE|VERILOG_FILE) (\S+)\s*$', manifest.read_text(), re.M)
    own = ['rtl/machine.qip', 'verilator/tests/native_ipl_startup_tb.sv',
           'scripts/observe_native_ipl_startup.py', 'bios/reference/fw_subcpu/verilog/X1SUB.BIN']
    sources = {name: sha(root / name) for name in dict.fromkeys(order + own)}
    for name, value in sources.items():
        path = out / 'sources' / name
        path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(root / name, path)
        assert sha(path) == value
    assets = out / 'assets'
    assets.mkdir()
    for name, path in origins.items():
        data = path.read_bytes()
        assert len(data) == (262144 if name == 'font' else 32768)
        (assets / (name + '.bin')).write_bytes(data)
        (assets / (name + '.hex')).write_text(''.join(f'{value:02x}\n' for value in data))
    frozen_assets = {str(p): sha(p) for p in assets.iterdir()}
    report = {'status': 'running', 'sources': sources,
              'origins': {str(p): sha(p) for p in origins.values()}, 'assets': frozen_assets,
              'scope': 'delay-aware SYS32/X3 rounded 23280-ps video, full external font, no disk or keys; startup observations only',
              'observation_cycles': 6400000, 'cases': [],
              'tool': subprocess.check_output(['verilator', '--version'], text=True).strip()}

    def save():
        (out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')

    save()
    try:
        obj = out / 'obj'
        command = ['verilator', '--binary', '--timing', '--assert', '-Wno-fatal',
                   '--top-module', 'native_ipl_startup_tb', '--Mdir', str(obj), '-j', '4',
                   str(out / 'sources/verilator/tests/native_ipl_startup_tb.sv'),
                   *[str(out / 'sources' / n) for n in order]]
        report['build_command'] = command
        save()
        with (out / 'build.log').open('w') as log:
            result = subprocess.run(command, cwd=out / 'sources', stdout=log, stderr=subprocess.STDOUT, timeout=240)
        report['build_exit'] = result.returncode
        save()
        assert result.returncode == 0, 'build failure is not a native observation'
        warnings = [line for line in (out / 'build.log').read_text().splitlines() if line.startswith('%Warning')]
        report['warnings'] = warnings
        assert not any(re.search(r'%Warning-(IMPLICIT|MULTIDRIVEN|UNOPTFLAT|LATCH):', line) for line in warnings)
        exe = obj / 'Vnative_ipl_startup_tb'
        report['executable_sha256'] = sha(exe)
        save()
        pair = [name for name in origins if name != 'font']
        assert len(pair) == 2
        for name in [*pair, *(name + '-repeat' for name in pair)]:
            asset = name.removesuffix('-repeat')
            folder = out / name
            folder.mkdir()
            command = [str(exe), '+FONT=' + str(assets / 'font.hex'),
                       '+IPL=' + str(assets / (asset + '.hex')), '+OUTPUT=' + str(folder),
                       '+CYCLES=' + str(report['observation_cycles'])]
            case = {'name': name, 'command': command, 'status': 'running'}
            report['cases'].append(case)
            save()
            assert sha(exe) == report['executable_sha256']
            with (folder / 'run.log').open('w') as log:
                result = subprocess.run(command, cwd=out / 'sources', stdout=log, stderr=subprocess.STDOUT, timeout=240)
            assert result.returncode == 0, 'process failure is not native rejection'
            assert 'OBSERVED NATIVE_STARTUP ' in (folder / 'run.log').read_text()
            summary = list(csv.DictReader((folder / 'summary.csv').open()))
            assert len(summary) == 1 and int(summary[0]['cycles']) == report['observation_cycles']
            case.update(status='observed', summary=summary[0],
                        artifacts={p.name: sha(p) for p in folder.iterdir()})
            save()
            print('NATIVE_STARTUP_OBSERVED', name, summary[0], flush=True)
        assert all(sha(root / n) == sha(out / 'sources' / n) == value for n, value in sources.items())
        assert all(sha(p) == value for p, value in (report['origins'] | frozen_assets).items())
        assert sha(exe) == report['executable_sha256']
        report['repeat_equal'] = {
            name: {n: h for n, h in report['cases'][i]['artifacts'].items() if n != 'run.log'} ==
                  {n: h for n, h in report['cases'][i + 2]['artifacts'].items() if n != 'run.log'}
            for i, name in enumerate(pair)}
        report['repeat_policy'] = 'Exact machine artifacts; raw run.log retained separately with host performance footer'
        report['status'] = 'observed'
        save()
    except BaseException as error:
        report.update(status='fail', error=repr(error))
        save()
        raise


if __name__ == '__main__':
    main()
