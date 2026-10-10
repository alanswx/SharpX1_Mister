#!/usr/bin/env python3
"""Independent read-only audit of the frozen reset-bypass Z diagnostic matrix."""
import argparse
import csv
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tarfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('frozen_root', type=Path, help='exact historical runner/oracle/emitter/font/archive folder')
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
frozen = args.frozen_root.resolve()
out = frozen / 'all-120'
bound = {
    'Vtop': 'f6eb69653a34db659ce253ad1fde8f09e5cfcb23aea2d86bde9a68197c0124a6',
    'test_machine_z_video.py': '1e03a9ecd39af3f049ef924db059c5bd5827c10879e479a593181da517009117',
    'z80_fixture.py': '8dcc3c61cf7127ef36e374f8926ac6face79f36e588506cc5c39f0c9e1fc5ee2',
    'test_z_combined_matrix.py': '638fd9ef33f6e316a5ff7435683362f2c5a92614f1eb13a92793d6e460e5f1df',
    'cg8_reference.v': '68aa689abd81c1a620980b5318b669b292a72d4877916ec43dc2461d713c831b',
    'source-at-launch.tar': 'd2bf1d0a82cbb9f3c8c8069231a48980500e3aeded119bfeec0db4a8189c6e2c',
}
def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()
def check_bound():
    assert {n: sha(frozen/n) for n in bound} == bound
check_bound()

# Independently reconstruct the prescribed case roster, rather than trusting
# the scheduler's completed list or importing its cases() function.
templates = []
for mode in ('full', 'dual64', 'wide64', 'tall64'):
    for screen in ((0, 1) if mode in ('full', 'dual64') else (0,)):
        templates.append(('graphics', mode, screen, 0x10, False, False))
for priority in (0x10, 0x18, 0x11, 0x19, 0x12, 0x1a):
    for text in (False, True):
        templates.append(('paired-text' if text else 'paired-graphics', 'paired64', 1, priority, text, False))
for mode in ('full', 'dual64'):
    for priority in (0, 1, 0xea, 0xeb):
        templates.append(('single-text', mode, 1, priority, True, False))
templates.append(('internal8', 'internal8', 0, 0x10, False, False))
for mode, priority in (('paired64', 0x1a), ('full', 1), ('dual64', 1)):
    templates.append(('reverse', mode, 1, priority, True, True))
cases = []
for group, mode, screen, priority, text, reverse in templates:
    for custom in (False, True):
        for warm in (False, True):
            name = f'{group}-{mode}-s{screen}-p{priority:02x}-{"custom" if custom else "identity"}-{"warm" if warm else "cold"}'
            flags = ['--mode', mode, '--screen', str(screen), '--priority', hex(priority)]
            flags += [f for f, on in (('--text',text),('--reverse',reverse),('--custom',custom),('--warm',warm)) if on]
            cases.append((dict(name=name, group=group, flags=flags), (mode,screen,priority,text,reverse,custom,warm)))
assert len(cases) == 120
assert json.loads((out/'cases.json').read_text()) == [c for c, _ in cases]
assert json.loads((out/'completed.json').read_text()) == [c['name'] for c, _ in cases], 'matrix not complete'
expected_inputs = {k:v for k,v in bound.items() if k not in ('test_z_combined_matrix.py','source-at-launch.tar')}
assert json.loads((out/'inputs.json').read_text()) == expected_inputs
assert json.loads((out/'final-inputs.json').read_text()) == expected_inputs

# Record all immutable evidence before independent regeneration.
evidence_before = {str(p.relative_to(out)): sha(p) for p in out.rglob('*') if p.is_file()}
sys.path.insert(0, str(frozen))
spec = importlib.util.spec_from_file_location('frozen_z_oracle', frozen/'test_machine_z_video.py')
oracle = importlib.util.module_from_spec(spec)
spec.loader.exec_module(oracle)
features = ('z_palette_cpu_experiment','z_video_experiment','z_multimode_experiment',
            'z_internal8_experiment','z_text_cpu_experiment','turbo_video_master','intra_assignment_delays')
pixels = 0
warm_cases = 0
for case, cfg in cases:
    mode, screen, priority, text, reverse, custom, warm = cfg
    path = out/case['name']
    log = (out/(case['name']+'.log')).read_text()
    records = [json.loads(line) for line in log.splitlines() if line.startswith('{')]
    metadata = records[0]
    assert metadata['runner_sha256'] == bound['Vtop']
    assert metadata['fixture_source_sha256'] == bound['test_machine_z_video.py']
    assert metadata['font8_source_sha256'] == (bound['cg8_reference.v'] if text else None)
    code = oracle.fixture(custom, mode, screen, priority, text, reverse)
    assert (path/'original.bin').read_bytes() == code
    assert metadata['program_sha256'] == hashlib.sha256(code).hexdigest()
    report = json.loads((path/'stdout.txt').read_text().splitlines()[-1])
    assert all(report[f] for f in features)
    assert report['sys_hz'] == 32000000 and report['video_hz'] == 42954540
    duration_ms = 5000 if custom else 4000
    assert report['time_ps'] == duration_ms*10**9 and report['sys_edges'] == duration_ms*32000
    assert report['video_edges'] == duration_ms*42954540//1000
    assert report['halted'] and report['peek'].startswith(b'ZVID'.hex()) and report['frames'] >= 3
    high = mode in ('tall64','internal8')
    width, height = (640 if mode in ('wide64','internal8') else 320), (400 if high else 200)
    line_edges = 1792 if high else 2688
    for field, edges in (('hs_period_ps',line_edges),('vs_period_ps',line_edges*(448 if high else 258))):
        assert abs(report[field] - round(edges*10**12/42954540)) <= 31251
    actual = (path/'actual.ppm').read_bytes()
    header = f'P6\n{width} {height}\n255\n'.encode()
    regenerated = header + b''.join(oracle.expected_pixel(x,y,custom,mode,screen,priority,text,reverse)
                                   for y in range(height) for x in range(width))
    assert actual == regenerated, f'actual pixels differ: {case["name"]}'
    assert (path/'expected.ppm').read_bytes() == regenerated
    assert f'PASS: {width*height} CPU-written {mode} pixels; screen={screen}; retained reset={warm}' in log
    if text:
        coverage = oracle.text_visibility_coverage(mode, screen, priority, reverse)
        oracle.require_text_visibility(coverage)
        assert any(r.get('text_visibility_coverage') == coverage for r in records)
        assert any(r.get('wrong_text_order_rejected_pixels',0)>100 for r in records)
    if reverse:
        assert any(r.get('missing_reverse_rejected_pixels',0)>100 for r in records)
    if warm:
        with (path/'warm-io.csv').open() as stream:
            writes = [r for r in csv.DictReader(stream) if r['wr_n']=='0']
        addresses = [int(r['address']) for r in writes]
        assert addresses.count(0x1800)==16 and addresses.count(0x1801)==16
        assert addresses.count(0x1a03)==1 and addresses.count(0x1a02)==(2 if mode in ('wide64','internal8') else 1)
        assert not any(a>=0x2000 or 0x1000<=a<0x1300 for a in addresses)
        if mode=='paired64' or text:
            assert addresses.count(0x1fc0)==1 and not any(0x1fb9<=a<=0x1fbf for a in addresses)
        warm_cases += 1
    pixels += width*height
    print('AUDIT PASS',case['name'],width*height,flush=True)

# Archived machine sources are bound to the actual historical RTL, not current
# cassette/FDC sources. Ignore AppleDouble filesystem metadata, not HDL.
with tarfile.open(frozen/'source-at-launch.tar') as archive:
    rtl = [m for m in archive.getmembers() if m.isfile() and m.name.startswith('rtl/')
           and not any(part.startswith('._') for part in m.name.split('/'))]
    assert len(rtl)==145
    for member in rtl:
        historical = subprocess.run(['git','show','aa05dd2:'+member.name],cwd=root,capture_output=True,check=True).stdout
        assert archive.extractfile(member).read()==historical, member.name
    for name in ('verilator/sim.v','verilator/Makefile'):
        historical = subprocess.run(['git','show','aa05dd2:'+name],cwd=root,capture_output=True,check=True).stdout
        assert archive.extractfile(name).read()==historical, name
    # Runner has the pre-commit fetch-option observer policy: explicitly record
    # its hash instead of falsely claiming complete aa05dd2 source identity.
    cpp_sha = hashlib.sha256(archive.extractfile('verilator/sim_headless.cpp').read()).hexdigest()
check_bound()
assert {str(p.relative_to(out)):sha(p) for p in out.rglob('*') if p.is_file()} == evidence_before
print(json.dumps(dict(result='passed',cases=120,pixels=pixels,warm_cases=warm_cases,
    archived_rtl_files=145,rtl_commit='aa05dd2',archived_cpp_sha256=cpp_sha,
    scope='bounded original CPU/pixel diagnostics; not current-source/native/FPGA acceptance',
    frozen_hashes=bound,auditor_sha256=sha(Path(__file__))),sort_keys=True))
