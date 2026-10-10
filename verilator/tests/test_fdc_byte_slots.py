#!/usr/bin/env python3
"""Frozen byte-slot scheduler oracle plus wrong-boundary negative; not FDC acceptance."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
out = Path(tempfile.mkdtemp(prefix='x1-fdc-byte-slots-'))
sources = ['rtl/x1_fdc_byte_slots.sv', 'verilator/tests/fdc_byte_slots_tb.sv',
           'verilator/tests/test_fdc_byte_slots.py']
digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
manifest = {}
for source in sources:
    dest = out / source
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(root / source, dest)
    manifest[source] = digest(dest)
(out / 'sources.json').write_text(json.dumps(manifest, indent=2) + '\n')
print('Frozen byte-slot sources:', out, flush=True)
for negative in [False, True]:
    name = 'wrong-boundary' if negative else 'original'
    rtl = out / sources[0]
    if negative:
        rtl = out / 'wrong_boundary.sv'
        original = (out / sources[0]).read_text()
        assert original.count("remaining == 7'd1 &&") == 1
        rtl.write_text(original.replace("remaining == 7'd1 &&", "remaining == 7'd2 &&"))
    build = out / name
    cmd = ['verilator', '--binary', '--timing', '--assert',
           '--top-module', 'fdc_byte_slots_tb', '--Mdir', str(build), '-j', '2',
           str(rtl), str(out / sources[1])]
    with (out / (name + '.build.log')).open('w') as log:
        subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=120)
    # Negative must fail the unchanged edge oracle, not compilation or timeout.
    import resource
    def no_core():
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    result = subprocess.run([str(build / 'Vfdc_byte_slots_tb')], text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            timeout=30, preexec_fn=no_core)
    (out / (name + '.run.log')).write_text(result.stdout)
    if negative:
        assert result.returncode != 0 and 'byte boundary mismatch' in result.stdout, result.stdout
        print('PASS wrong-boundary negative rejected by unchanged edge oracle', flush=True)
    else:
        assert result.returncode == 0 and 'PASS byte slots:' in result.stdout, result.stdout
        print(result.stdout, end='', flush=True)
for source, expected in manifest.items():
    assert digest(root / source) == digest(out / source) == expected, source
print('PASS frozen scheduler qualification; no connected FDC/native board timing claim')
