#!/usr/bin/env python3
"""Frozen first-event/held-response FDC bus check; no native pin timing claim."""
import hashlib
import json
from pathlib import Path
import resource
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
out = Path(tempfile.mkdtemp(prefix='x1-fdc-bus-events-'))
sources = ['rtl/x1_fdc_bus_events.sv', 'verilator/tests/fdc_bus_events_tb.sv',
           'verilator/tests/test_fdc_bus_events.py']
digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
manifest = {}
for source in sources:
    dest = out / source
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(root / source, dest)
    manifest[source] = digest(dest)
(out / 'sources.json').write_text(json.dumps(manifest, indent=2) + '\n')
print('Frozen bus sources:', out, flush=True)
original = (out / sources[0]).read_text()
cases = [
    ('original', None, None, None),
    ('repeated-read', '&& !read_seen;', ';', 'bus acceptance mismatch'),
    ('live-response', 'read_seen ? held_response : response', 'response',
     'held response changed before edge'),
    ('stale-write', 'write_accept ? write_value : captured_write', 'captured_write',
     'same-edge write consumer mismatch'),
]
def no_core():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))

for name, search, replacement, diagnostic in cases:
    rtl = out / sources[0]
    if search:
        assert original.count(search) == 1, search
        rtl = out / (name + '.sv')
        rtl.write_text(original.replace(search, replacement))
    build = out / name
    cmd = ['verilator', '--binary', '--timing', '--assert',
           '--top-module', 'fdc_bus_events_tb', '--Mdir', str(build), '-j', '2',
           str(rtl), str(out / sources[1])]
    (out / (name + '.command.json')).write_text(json.dumps(cmd, indent=2) + '\n')
    with (out / (name + '.build.log')).open('w') as log:
        subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=120)
    result = subprocess.run([str(build / 'Vfdc_bus_events_tb')], text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            timeout=30, preexec_fn=no_core)
    (out / (name + '.run.log')).write_text(result.stdout)
    if diagnostic:
        assert result.returncode != 0 and diagnostic in result.stdout, result.stdout
        print('PASS matched bus negative:', name, flush=True)
    else:
        assert result.returncode == 0 and 'PASS FDC bus events:' in result.stdout, result.stdout
        print(result.stdout, end='', flush=True)
for source, expected in manifest.items():
    assert digest(root / source) == digest(out / source) == expected, source
print('PASS frozen bus qualification; no connected CPU/DMA/controller acceptance')
