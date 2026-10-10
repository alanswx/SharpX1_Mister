#!/usr/bin/env python3
"""Compare default generated state types/order and serializers to Git baseline.

Original standalone vendor check; does not certify a whole-machine v17 file.
No tracked outputs or baseline checkout changes. Requires local Verilator.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', default='3c34dd0')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    out = Path(tempfile.mkdtemp(prefix='x1-fdc-default-state-'))
    vendor = 'rtl/vendor/wd1793.sv'
    old = subprocess.check_output(['git', 'show', f'{args.baseline}:{vendor}'], cwd=root)
    new = (root / vendor).read_bytes()
    # Hold the ORIGINAL external interface fixed. The new unused top-level
    # input is itself savable when wd1793 is top; that is not internal state.
    header = old.decode().split('module wd1793', 1)[1].split(');', 1)[0]
    parameters = re.findall(r'\b(\w+)\s*=', header.split('(', 2)[1])
    inactive_hd = "wire hd_selected=1'b0;\n" if not re.search(r'\bhd_selected\b', header) else ''
    inactive_fdc = "wire fdc_ce=1'b0;\n" if not re.search(r'\bfdc_ce\b', header) else ''
    wrapper = ('module fdc_default_state_top' + header + ');\n' +
               inactive_hd + inactive_fdc + 'wd1793 #(' +
               ', '.join(f'.{p}({p})' for p in parameters) +
               ') dut(.*);\nendmodule\n')
    (out / 'wrapper.sv').write_text(wrapper)
    (out / 'original.sv').write_bytes(old)
    (out / 'current.sv').write_bytes(new)
    shutil.copyfile(root / 'rtl/vendor/x1_fdc_index_ram.v', out / 'x1_fdc_index_ram.v')
    manifest = {'baseline': args.baseline, 'old_sha256': hashlib.sha256(old).hexdigest(),
                'baseline_commit': subprocess.check_output(
                    ['git', 'rev-parse', args.baseline], cwd=root, text=True).strip(),
                'new_sha256': hashlib.sha256(new).hexdigest(),
                'wrapper_sha256': hashlib.sha256(wrapper.encode()).hexdigest(),
                'wrapper_parameters': parameters,
                'index_sha256': hashlib.sha256((out / 'x1_fdc_index_ram.v').read_bytes()).hexdigest(),
                'scope': 'default internal state through identical original-port wrapper; not new vendor top-port compatibility or whole-machine v17',
                'profiles': []}
    print(f'Default state comparison logs: {out}', flush=True)
    for name, options in [('ram-legacy', []), ('sd-legacy', ['-GRWMODE=1']),
                          ('sd-strict', ['-GRWMODE=1', '-GD88_ONLY=1']),
                          ('sd-no-index', ['-GRWMODE=1', '-GEDSK=0'])]:
        for version in ['original', 'current']:
            build = out / f'{name}-{version}'
            command = ['verilator', '--cc', '--savable', '-Wno-fatal',
                       '--top-module', 'fdc_default_state_top', '--Mdir', str(build), *options,
                       str(out / f'{version}.sv'), str(out / 'x1_fdc_index_ram.v'),
                       str(out / 'wrapper.sv')]
            (out / f'{name}-{version}.command.json').write_text(json.dumps(command, indent=2) + '\n')
            with (out / f'{name}-{version}.log').open('w') as log:
                subprocess.run(command, stdout=log, stderr=subprocess.STDOUT,
                               check=True, timeout=60)
        files = ['Vfdc_default_state_top___024root.h', 'Vfdc_default_state_top___024root__Slow.cpp',
                 'Vfdc_default_state_top__Syms.h', 'Vfdc_default_state_top__Syms__Slow.cpp']
        digests = {}
        for file in files:
            previous = (out / f'{name}-original' / file).read_bytes()
            current = (out / f'{name}-current' / file).read_bytes()
            if previous != current:
                raise AssertionError(f'Default state/serializer differs: {name}/{file}')
            digests[file] = hashlib.sha256(current).hexdigest()
        manifest['profiles'].append({'name': name, 'identical_files': digests})
        print(f'PASS {name}: identical generated state declarations and serializer/deserializer', flush=True)
    (out / 'comparison.json').write_text(json.dumps(manifest, indent=2) + '\n')
    if (root / vendor).read_bytes() != new:
        raise AssertionError('Vendor source changed during comparison')
    print('PASS default internal vendor state through original-port wrapper; whole-machine v17 remains separate')


if __name__ == '__main__':
    main()
