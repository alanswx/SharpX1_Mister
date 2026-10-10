#!/usr/bin/env python3
"""Original synthetic width qualification; no downloaded/private media.

Builds frozen copies in a unique temporary directory, never tracked outputs.
ADDRESS_BITS is an addressing experiment, not HD geometry/rate acceptance.
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
    parser.add_argument('--widths', nargs='+', type=int, default=[20, 21, 22, 23, 24])
    parser.add_argument('--default-regressions', action='store_true')
    parser.add_argument('--capacities', nargs='+', type=int, default=[1992, 4095])
    parser.add_argument('--edsk-only', action='store_true')
    parser.add_argument('--edsk-capacity', action='store_true',
                        help='include the wide EDSK 1993-entry overflow regression')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    out = Path(tempfile.mkdtemp(prefix='x1-fdc-address-width-'))
    sources = ['rtl/vendor/wd1793.sv', 'rtl/vendor/x1_fdc_index_ram.v',
               'verilator/tests/fdc_address_width_tb.sv',
               'verilator/tests/fdc_edsk_width_tb.sv',
               'verilator/tests/fdc_edsk_capacity_tb.sv']
    if args.default_regressions:
        sources += ['verilator/tests/d88_scanner_tb.sv',
                    'verilator/tests/d88_metadata_tb.sv',
                    'verilator/tests/d88_crc_tb.sv']
    manifest = {}
    for source in sources:
        original = root / source
        destination = out / source
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(original, destination)
        manifest[source] = hashlib.sha256(destination.read_bytes()).hexdigest()
    (out / 'sources.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Frozen sources/logs/output: {out}', flush=True)

    def run(top, name, options=(), runtime=()):
        build = out / name
        command = ['verilator', '--binary', '--timing', '--assert', '-Wno-fatal',
                   '--top-module', top, '--Mdir', str(build), '-j', '4',
                   *options, str(out / sources[0]), str(out / sources[1]),
                   str(out / f'verilator/tests/{top}.sv')]
        (out / f'{name}.command.json').write_text(json.dumps(command, indent=2) + '\n')
        with (out / f'{name}.build.log').open('w') as log:
            subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=180)
        result = subprocess.run([str(build / f'V{top}'), *runtime], text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=240)
        (out / f'{name}.run.log').write_text(result.stdout)
        print(result.stdout, end='', flush=True)
        result.check_returncode()

    for width in ([] if args.edsk_only else args.widths):
        if not 20 <= width <= 24:
            parser.error('widths must be in 20..24')
        for capacity in args.capacities:
            if not 1 <= capacity <= 4095:
                parser.error('capacities must be in 1..4095')
            run('fdc_address_width_tb', f'width-{width}-capacity-{capacity}',
                [f'-GADDRESS_BITS={width}', f'-GMAX_SECTORS={capacity}'])
    for width in [21, 24]:
        run('fdc_edsk_width_tb', f'edsk-width-{width}', [f'-GADDRESS_BITS={width}'])
    if args.edsk_capacity:
        run('fdc_edsk_capacity_tb', 'edsk-capacity-overflow')
    if args.default_regressions:
        run('d88_scanner_tb', 'default-scanner')
        run('d88_crc_tb', 'default-crc')
        run('d88_metadata_tb', 'default-metadata')
        run('d88_crc_tb', 'default-crc-div1', runtime=['+divider=1'])
        run('d88_metadata_tb', 'default-metadata-div1', runtime=['+divider=1'])
    for source, expected in manifest.items():
        if hashlib.sha256((root / source).read_bytes()).hexdigest() != expected:
            raise RuntimeError(f'Source changed during qualification: {source}')
    print('PASS frozen-source standalone width qualification (no hardware claims)', flush=True)


if __name__ == '__main__':
    main()
