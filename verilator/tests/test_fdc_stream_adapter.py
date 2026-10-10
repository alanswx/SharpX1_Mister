#!/usr/bin/env python3
"""Freeze standalone DR/DSR/slot oracle and targeted disposable negatives."""
import hashlib
import json
from pathlib import Path
import resource
import shutil
import subprocess
import tempfile


def main():
    root = Path(__file__).resolve().parents[2]
    out = Path(tempfile.mkdtemp(prefix='x1-fdc-stream-adapter-'))
    sources = ['rtl/x1_fdc_stream_adapter.sv', 'rtl/x1_fdc_byte_slots.sv',
               'verilator/tests/fdc_stream_adapter_tb.sv',
               'verilator/tests/test_fdc_stream_adapter.py']
    digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    manifest = {}
    for source in sources:
        destination = out / source
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(root / source, destination)
        manifest[source] = digest(destination)
    (out / 'sources.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Frozen stream sources/logs: {out}', flush=True)
    original = (out / sources[0]).read_text()
    mutations = [
        ('original', None, None, None),
        ('service-rephase', '.start(begin_read || (launch && have_write)),',
         '.start(begin_read || (launch && have_write) || service_read || service_write),',
         'stream slot/event mismatch'),
        ('live-din', 'write_byte <= have_write ? staged_write : 8\'d0;',
         'write_byte <= have_write ? write_value : 8\'d0;', 'captured write/zero/index mismatch'),
        ('release-ack', 'if (service_read) begin full <= 1\'b0; read_ack <= 1\'b1; end',
         'if (service_read || read_release) begin full <= 1\'b0; read_ack <= 1\'b1; end',
         'held response/generation mismatch'),
        ('stale-zero', 'write_byte <= have_write ? staged_write : 8\'d0;',
         'write_byte <= have_write ? staged_write : holding;', 'captured write/zero/index mismatch'),
        ('tail-refill', 'wire service_write = write_accept && writing && drq;',
         'wire service_write = write_accept && writing && (active || armed) && !full;',
         'DR/index mismatch'),
    ]

    def no_core():
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))

    for name, before, after, failure in mutations:
        rtl = out / sources[0]
        if before:
            assert original.count(before) == 1, name
            rtl = out / f'{name}.sv'
            rtl.write_text(original.replace(before, after))
        build = out / name
        command = ['verilator', '--binary', '--timing', '--assert',
                   '--top-module', 'fdc_stream_adapter_tb', '--Mdir', str(build), '-j', '2',
                   str(rtl), str(out / sources[1]), str(out / sources[2])]
        (out / f'{name}.command.json').write_text(json.dumps(command, indent=2) + '\n')
        with (out / f'{name}.build.log').open('w') as log:
            subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=180)
        for divider in ([16, 32] if not before else [16]):
            result = subprocess.run([str(build / 'Vfdc_stream_adapter_tb'), f'+divider={divider}'],
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                                    preexec_fn=no_core, timeout=120)
            (out / f'{name}-divider-{divider}.run.log').write_text(result.stdout)
            if before:
                assert result.returncode != 0 and failure in result.stdout, result.stdout
                print(f'PASS {name}: unchanged oracle rejected exact {failure}', flush=True)
            else:
                assert result.returncode == 0 and 'PASS stream adapter ' in result.stdout, result.stdout
                print(result.stdout, end='', flush=True)
    for source, expected in manifest.items():
        assert digest(root / source) == digest(out / source) == expected, source
    print('PASS frozen standalone stream adapter; no WD/SD/CPU/native timing integration claim', flush=True)


if __name__ == '__main__':
    main()
