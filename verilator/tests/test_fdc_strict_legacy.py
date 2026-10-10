#!/usr/bin/env python3
"""Freeze/run existing default-off CRC/metadata tests; no state-format claim."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--vendor-sha', required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    sources = ['rtl/vendor/wd1793.sv', 'rtl/vendor/x1_fdc_index_ram.v',
               'verilator/tests/d88_crc_tb.sv', 'verilator/tests/d88_metadata_tb.sv',
               'verilator/tests/test_fdc_strict_legacy.py']
    digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    if digest(root / sources[0]) != args.vendor_sha:
        parser.error('vendor differs from approved source')
    out = Path(tempfile.mkdtemp(prefix='x1-fdc-strict-legacy-'))
    manifest = {}
    for source in sources:
        target = out / source
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(root / source, target)
        manifest[source] = digest(target)
    if manifest[sources[0]] != args.vendor_sha:
        raise RuntimeError('vendor changed during freeze')
    (out / 'sources.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Frozen default-off regression: {out}', flush=True)
    for fixture in sources[2:4]:
        top = Path(fixture).stem
        command = ['verilator', '--binary', '--timing', '--assert', '-Wno-fatal',
                   '--top-module', top, '--Mdir', str(out / top), '-j', '4',
                   *(str(out / s) for s in sources[:2]), str(out / fixture)]
        (out / f'{top}.command.json').write_text(json.dumps(command, indent=2) + '\n')
        with (out / f'{top}.build.log').open('w') as log:
            subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=180)
        for divider in [1, 8]:
            result = subprocess.run([str(out / top / f'V{top}'), f'+divider={divider}'],
                                    text=True, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, timeout=180)
            (out / f'{top}-{divider}.run.log').write_text(result.stdout)
            print(result.stdout, end='', flush=True)
            result.check_returncode()
            if 'PASS: D88 ' not in result.stdout:
                raise RuntimeError('missing legacy regression marker')
    for source, expected in manifest.items():
        if digest(root / source) != expected or digest(out / source) != expected:
            raise RuntimeError(f'Source changed during regression: {source}')
    print('PASS default-off existing CRC/metadata simulations; generated-state audit remains separate', flush=True)


if __name__ == '__main__':
    main()
