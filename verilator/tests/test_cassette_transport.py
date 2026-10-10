"""Freeze standalone cassette sources; synthetic transport checks, not loading."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
FILES = ('rtl/x1_cassette_transport.sv', 'verilator/tests/cassette_transport_tb.sv',
         'verilator/tests/test_cassette_transport.py')
folder = Path(tempfile.mkdtemp(prefix='x1-cassette-transport-'))
hashes = {}
for name in FILES:
    target = folder / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / name, target)
    hashes[name] = hashlib.sha256(target.read_bytes()).hexdigest()
(folder / 'sources.json').write_text(json.dumps(hashes, indent=2) + '\n')
print('Frozen cassette evidence:', folder, flush=True)


def run_case(hz, negative=False, sample_hz=8000, parameter_only=False, invalid=False, sum_negative=False):
    tag = str(hz) + ('-negative' if negative else '')
    if parameter_only or invalid:
        tag += '-sample' + str(sample_hz)
    if sum_negative:
        tag += '-carry-negative'
    source = folder / FILES[0]
    if negative or sum_negative:
        original = source.read_text()
        old = ("{1'b0, phase} + (PHASE_W+1)'(SAMPLE_HZ)" if sum_negative
               else 'applied_mode <= STOP; // UNDERFLOW_STOP')
        new = ("(PHASE_W+1)'(PHASE_W'(" + old + "))" if sum_negative
               else 'applied_mode <= PLAY; // MATCHED MUTANT')
        assert original.count(old) == 1
        source = folder / ('sum-mutant' if sum_negative else 'underflow-mutant') / 'x1_cassette_transport.sv'
        source.parent.mkdir()
        source.write_text(original.replace(old, new))
    obj = folder / ('obj-' + tag)
    cmd = ['verilator', '--binary', '--timing', '--top-module', 'cassette_transport_tb',
           '-Wall', '-GSYS_HZ=' + str(hz), '-GSAMPLE_HZ=' + str(sample_hz),
           '-GPARAMETER_ONLY=' + str(int(parameter_only)), '--Mdir', str(obj),
           str(source), str(folder / FILES[1])]
    (folder / (tag + '.command.json')).write_text(json.dumps(cmd) + '\n')
    build = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    (folder / (tag + '.build.log')).write_text(build.stdout + build.stderr)
    assert build.returncode == 0, build.stdout + build.stderr
    result = subprocess.run([str(obj / 'Vcassette_transport_tb')], capture_output=True,
                            text=True, timeout=60)
    text = result.stdout + result.stderr
    (folder / (tag + '.run.log')).write_text(text)
    if invalid:
        assert result.returncode != 0 and 'unsupported cassette sample/system rate' in text, text
        assert 'PASS cassette' not in text
    elif negative or sum_negative:
        marker = 'cassette widened sum lost carry' if sum_negative else 'cassette underflow must stop'
        assert result.returncode != 0 and marker in text, text
        assert 'PASS cassette transport' not in text
    else:
        assert result.returncode == 0 and 'PASS cassette' in text, text
    print('PASS', tag, 'parameter rejection' if invalid else 'matched underflow rejection' if negative else 'synthetic transport', flush=True)


for rate in (32000000, 28571428, 28636364):
    run_case(rate)
run_case(32000000, negative=True)
run_case(4294967295, sample_hz=4294967295, parameter_only=True)
run_case(4294967295, sample_hz=2147483648, parameter_only=True)
run_case(4294967295, sample_hz=2147483648, parameter_only=True, sum_negative=True)
for hz, sample_hz in ((32000000, 0), (0, 8000), (1, 8000), (7999, 8000)):
    run_case(hz, sample_hz=sample_hz, invalid=True)
for name, expected in hashes.items():
    assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == expected
    assert hashlib.sha256((folder / name).read_bytes()).hexdigest() == expected
print('PASS original/frozen sources unchanged; no machine integration or hardware acceptance')
