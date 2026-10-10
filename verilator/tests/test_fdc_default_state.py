#!/usr/bin/env python3
"""Compare default generated state types/order and serializers to Git baseline.

Original standalone vendor check; does not certify a whole-machine v17 file.
No tracked outputs or baseline checkout changes. Requires local Verilator.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', default='HEAD')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    out = Path(tempfile.mkdtemp(prefix='x1-fdc-default-state-'))
    vendor = 'rtl/vendor/wd1793.sv'
    old = subprocess.check_output(['git', 'show', f'{args.baseline}:{vendor}'], cwd=root)
    new = (root / vendor).read_bytes()
    (out / 'original.sv').write_bytes(old)
    (out / 'current.sv').write_bytes(new)
    shutil.copyfile(root / 'rtl/vendor/x1_fdc_index_ram.v', out / 'x1_fdc_index_ram.v')
    manifest = {'baseline': args.baseline, 'old_sha256': hashlib.sha256(old).hexdigest(),
                'new_sha256': hashlib.sha256(new).hexdigest(), 'profiles': []}
    print(f'Default state comparison logs: {out}', flush=True)
    for name, options in [('ram-legacy', []), ('sd-legacy', ['-GRWMODE=1']),
                          ('sd-strict', ['-GRWMODE=1', '-GD88_ONLY=1']),
                          ('sd-no-index', ['-GRWMODE=1', '-GEDSK=0'])]:
        for version in ['original', 'current']:
            build = out / f'{name}-{version}'
            command = ['verilator', '--cc', '--savable', '-Wno-fatal',
                       '--top-module', 'wd1793', '--Mdir', str(build), *options,
                       str(out / f'{version}.sv'), str(out / 'x1_fdc_index_ram.v')]
            with (out / f'{name}-{version}.log').open('w') as log:
                subprocess.run(command, stdout=log, stderr=subprocess.STDOUT,
                               check=True, timeout=60)
        files = ['Vwd1793___024root.h', 'Vwd1793___024root__Slow.cpp',
                 'Vwd1793__Syms.h', 'Vwd1793__Syms__Slow.cpp']
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
    print('PASS default vendor state layout; whole-machine v17 identity remains main integration gate')


if __name__ == '__main__':
    main()
