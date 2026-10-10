#!/usr/bin/env python3
"""Freeze original standalone media-class tests; no boards or native timing claims."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--vendor-sha', required=True, help='Main-approved stable vendor SHA-256')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    sources = ['rtl/vendor/wd1793.sv', 'rtl/vendor/x1_fdc_index_ram.v',
               'verilator/tests/fdc_capacity_class_tb.sv',
               'verilator/tests/test_fdc_capacity_class.py']
    digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    if digest(root / sources[0]) != args.vendor_sha:
        parser.error('vendor differs from approved stable SHA; no build started')
    out = Path(tempfile.mkdtemp(prefix='x1-fdc-capacity-class-'))
    manifest = {}
    for source in sources:
        destination = out / source
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(root / source, destination)
        manifest[source] = digest(destination)
    if manifest[sources[0]] != args.vendor_sha:
        raise RuntimeError('vendor changed while freezing')
    (out / 'sources.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Frozen sources/logs: {out}', flush=True)
    for check in [1, 0]:
        for divider in [1, 8]:
            name = f'check-{check}-divider-{divider}'
            build = out / name
            command = ['verilator', '--binary', '--timing', '--assert', '-Wno-fatal',
                       '--top-module', 'fdc_capacity_class_tb', '--Mdir', str(build), '-j', '4',
                       f'-GCAPACITY_CHECK={check}', f'-GDIVIDER={divider}',
                       *(str(out / s) for s in sources[:3])]
            (out / f'{name}.command.json').write_text(json.dumps(command, indent=2) + '\n')
            with (out / f'{name}.build.log').open('w') as log:
                subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=180)
            result = subprocess.run([str(build / 'Vfdc_capacity_class_tb')], text=True,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
            (out / f'{name}.run.log').write_text(result.stdout)
            print(result.stdout, end='', flush=True)
            result.check_returncode()
            if 'PASS standalone D88 capacity class cases=35 ' not in result.stdout:
                raise RuntimeError('missing complete fixture coverage marker')
    for source, expected in manifest.items():
        if digest(root / source) != expected or digest(out / source) != expected:
            raise RuntimeError(f'Source changed during qualification: {source}')
    print('PASS frozen media-class qualification; no busy-toggle/rate/geometry/hardware claim', flush=True)


if __name__ == '__main__':
    main()
