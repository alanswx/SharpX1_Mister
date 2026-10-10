#!/usr/bin/env python3
"""Frozen standalone strict-D88 timing qualification; no CPU/board/native-gap claim."""
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
               'rtl/x1_fdc_byte_slots.sv', 'rtl/x1_fdc_stream_adapter.sv',
               'rtl/x1_fdc_bus_events.sv', 'rtl/x1_fdc_completion.sv',
               'verilator/tests/fdc_strict_timing_tb.sv',
               'verilator/tests/test_fdc_strict_timing.py']
    digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    if digest(root / sources[0]) != args.vendor_sha:
        parser.error('vendor not the approved frozen source')
    out = Path(tempfile.mkdtemp(prefix='x1-fdc-strict-timing-'))
    manifest = {}
    for source in sources:
        destination = out / source
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(root / source, destination)
        manifest[source] = digest(destination)
    if manifest[sources[0]] != args.vendor_sha:
        raise RuntimeError('vendor changed during freeze')
    (out / 'sources.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Frozen sources/logs: {out}', flush=True)
    for divider in [16, 32]:
        for high in [0, 1]:
            name = f'chip-{divider}-high-{high}'
            build = out / name
            command = ['verilator', '--binary', '--timing', '--assert', '-Wno-fatal',
                       '--top-module', 'fdc_strict_timing_tb', '--Mdir', str(build), '-j', '4',
                       f'-GCHIP_DIV={divider}', f'-GHIGH={high}',
                       *(str(out / s) for s in sources[:-1])]
            (out / f'{name}.command.json').write_text(json.dumps(command, indent=2) + '\n')
            with (out / f'{name}.build.log').open('w') as log:
                subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=180)
            result = subprocess.run([str(build / 'Vfdc_strict_timing_tb')], text=True,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
            (out / f'{name}.run.log').write_text(result.stdout)
            print(result.stdout, end='', flush=True)
            result.check_returncode()
            if 'PASS strict D88 timing cases=102 ' not in result.stdout:
                raise RuntimeError('missing coverage marker')
    # Disposable source-only mutations, SAME unchanged oracle. Preserve all
    # failing executions; require an exact relevant assertion, not any crash.
    mutations = [
        ('prefill-31', 'rtl/vendor/wd1793.sv',
         "prefill_left <= 6'd32;", "prefill_left <= 6'd31;",
         'initial prefill not 32 future chip edges'),
        ('ce-buffer', 'rtl/vendor/wd1793.sv',
         'assign timing_buffer_store = write_emit &&',
         'assign timing_buffer_store = ce && write_emit &&',
         'full-medium corruption'),
        ('no-metadata-store', 'rtl/vendor/wd1793.sv',
         '.wren_b(cpu_buffer_write || metadata_edit || zero_write_byte || timing_buffer_store)',
         '.wren_b(cpu_buffer_write || zero_write_byte || timing_buffer_store)',
         'full-medium corruption'),
        ('underrun-dr-mirror', 'rtl/vendor/wd1793.sv',
         'if (timing_read_load) begin',
         'if (timing_buffer_store) wdreg_data <= timing_write_byte;\n        if (timing_read_load) begin',
         'DSR underrun zero overwrote physical DR'),
        ('cancel-taken', 'rtl/x1_fdc_completion.sv',
         'valid && consume && !reset && !cancel', 'valid && consume && !reset',
         'command replacement consumed stale completion/store/arrival'),
        ('live-held-read', 'rtl/vendor/wd1793.sv',
         'assign dout      = STRICT_D88_TIMING ? timing_bus_value : q;',
         'assign dout      = q;', 'held STATUS response changed'),
        ('raw-repeat-read', 'rtl/x1_fdc_bus_events.sv',
         '!reset && bus_ce && selected && rd && !wr && !read_seen',
         '!reset && bus_ce && selected && rd && !wr', 'held STATUS response changed'),
        ('service-paced-read', 'rtl/x1_fdc_stream_adapter.sv',
         '.start(begin_read || (launch && have_write))',
         '.start(begin_read || (launch && have_write) || (read_accept && active))',
         'read cadence rephased by bus/CE'),
        ('stopped-initial-abort-completion-drop', 'rtl/vendor/wd1793.sv',
         '.complete(done)', '.complete(done && !(initial_abort && !ce))',
         'stopped CE completion not held'),
    ]
    for name, source, original, replacement, assertion in mutations:
        negative = out / f'negative-{name}'
        for relative in sources:
            target = negative / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(out / relative, target)
        target = negative / source
        body = target.read_text()
        if body.count(original) != 1:
            raise RuntimeError(f'Non-unique mutation target: {name}')
        target.write_text(body.replace(original, replacement))
        build = negative / 'build'
        command = ['verilator', '--binary', '--timing', '--assert', '-Wno-fatal',
                   '--top-module', 'fdc_strict_timing_tb', '--Mdir', str(build), '-j', '4',
                   '-GCHIP_DIV=16', '-GHIGH=0',
                   *(str(negative / s) for s in sources[:-1])]
        (negative / 'command.json').write_text(json.dumps(command, indent=2) + '\n')
        with (negative / 'build.log').open('w') as log:
            subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=180)
        result = subprocess.run([str(build / 'Vfdc_strict_timing_tb')], text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
        (negative / 'run.log').write_text(result.stdout)
        if result.returncode == 0 or assertion not in result.stdout:
            raise RuntimeError(f'Mutation {name} escaped relevant oracle: {result.stdout}')
        print(f'PASS negative {name}: {assertion}', flush=True)
    for source, expected in manifest.items():
        if digest(root / source) != expected or digest(out / source) != expected:
            raise RuntimeError(f'Source changed during qualification: {source}')
    print('PASS frozen strict-D88 timing; standalone only', flush=True)


if __name__ == '__main__':
    main()
