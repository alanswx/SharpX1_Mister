#!/usr/bin/env python3
"""Independent frozen external-DR/raw-bus gate; original standalone fixtures."""
import hashlib
import json
from pathlib import Path
import resource
import shutil
import subprocess
import tempfile


def main():
    root = Path(__file__).resolve().parents[2]
    out = Path(tempfile.mkdtemp(prefix='x1-fdc-external-dr-'))
    sources = ['rtl/x1_fdc_stream_adapter.sv', 'rtl/x1_fdc_byte_slots.sv',
               'rtl/x1_fdc_bus_events.sv', 'verilator/tests/fdc_stream_external_dr_tb.sv',
               'verilator/tests/test_fdc_stream_external_dr.py']
    digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    manifest = {}
    for source in sources:
        dest = out / source
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(root / source, dest)
        manifest[source] = digest(dest)
    (out / 'sources.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Frozen external-DR sources/logs: {out}', flush=True)
    original = (out / sources[0]).read_text()
    variants = [
        ('original', None, None, None),
        ('private-dr', 'EXTERNAL_DR ? physical_dr : holding', 'EXTERNAL_DR ? holding : holding', 'authoritative physical DR mismatch'),
        ('late-arrival', 'remaining != 0 && !reset && !stop && !begin_read && !arm_write;',
         "remaining != 0 && arrival && !reset && !stop && !begin_read && !arm_write;", 'same-edge physical DR load intent/value mismatch'),
        ('stale-din', 'service_write ? write_value : current_dr', 'service_write ? physical_dr : current_dr', 'external captured DSR/zero mismatch'),
    ]

    def no_core():
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))

    for name, before, after, failure in variants:
        rtl = out / sources[0]
        if before:
            assert original.count(before) == 1, name
            rtl = out / f'{name}.sv'
            rtl.write_text(original.replace(before, after))
        build = out / name
        command = ['verilator', '--binary', '--timing', '--assert',
                   '--top-module', 'fdc_stream_external_dr_tb', '--Mdir', str(build), '-j', '2',
                   str(rtl), *(str(out / s) for s in sources[1:4])]
        (out / f'{name}.command.json').write_text(json.dumps(command, indent=2)+'\n')
        with (out / f'{name}.build.log').open('w') as log:
            subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=180)
        for divider in ([16, 32] if not before else [16]):
            result = subprocess.run([str(build / 'Vfdc_stream_external_dr_tb'), f'+divider={divider}'],
                                    text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                    timeout=120, preexec_fn=no_core)
            (out / f'{name}-divider-{divider}.run.log').write_text(result.stdout)
            if before:
                assert result.returncode != 0 and failure in result.stdout, result.stdout
                print(f'PASS {name}: unchanged oracle rejects {failure}', flush=True)
            else:
                assert result.returncode == 0 and 'PASS external DR raw-bus ' in result.stdout, result.stdout
                print(result.stdout, end='', flush=True)
    for source, expected in manifest.items():
        assert digest(root / source) == digest(out / source) == expected, source
    print('PASS frozen external DR/shared raw-bus gate; no WD/CPU/SD/native tie claim', flush=True)


if __name__ == '__main__':
    main()
