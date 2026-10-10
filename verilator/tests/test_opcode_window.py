"""Actual CPU JP-0000 fetch windows, checked against independent full bus samples."""
import csv
import hashlib
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile

source = pathlib.Path(sys.argv[1]).resolve()
folder = pathlib.Path(tempfile.mkdtemp(prefix='opcode-window-', dir=source.parent))
runner = folder / 'Vtop'
runner_hash = hashlib.sha256(source.read_bytes()).hexdigest()
shutil.copy2(source, runner)
assert hashlib.sha256(runner.read_bytes()).hexdigest() == runner_hash
rom = folder / 'original-jp.bin'
# Operand reads are at 1 and 2; only instruction M1 reads have address 0.
# No interrupts are enabled, no RAM injection, no force or patched state.
rom.write_bytes(bytes((0xc3, 0, 0)))

def run(name, start=0, end=0, trace=False, explicit=False):
    prefix = folder / name
    command = [str(runner), '--cycles', '320000', '--rom', str(rom),
               '--video-dump', str(prefix), '--dump', str(prefix)]
    if start or end or explicit:
        command += ['--fetch-start-ms', str(start), '--fetch-end-ms', str(end)]
    if trace:
        command += ['--bus-trace', str(prefix) + '.csv']
    result = subprocess.run(command, capture_output=True, text=True, timeout=180)
    prefix.with_suffix('.stdout').write_text(result.stdout)
    prefix.with_suffix('.stderr').write_text(result.stderr)
    assert result.returncode == 0, result.stderr
    report = json.loads(result.stdout.splitlines()[-1])
    with prefix.with_suffix('.cpu-fetches').open() as stream:
        counts = {int(row['address']): int(row['fetches']) for row in csv.DictReader(stream)}
    assert set(counts) <= {0}, counts
    return prefix, report, counts.get(0, 0)

baseline, reference, full_count = run('full', trace=True)
assert reference['sys_hz'] == 32000000 and reference['time_ps'] == 10000000000
assert not reference['turbo_dma'] and not reference['turbo_foundation']
period = 31250
windows = []
first = last = None
with baseline.with_suffix('.csv').open() as stream:
    for row in csv.DictReader(stream):
        time = int(row['time_ps'])
        selected = (int(row['address']) == 0 and int(row['mreq_n']) == 0
                    and int(row['rd_n']) == 0 and int(row['iorq_n']) == 1)
        if selected:
            if last is not None and time != last + period:
                windows.append((first, last + period))
                first = None
            if first is None:
                first = time
            last = time
        elif first is not None:
            windows.append((first, last + period))
            first = last = None
if first is not None and last + period <= reference['time_ps']:
    windows.append((first, last + period))
assert len(windows) == full_count and full_count > 1000, (len(windows), full_count)
assert any(a < 2000000000 < b or a < 5000000000 < b for a, b in windows), 'fixture must exercise a partial boundary'

for name, start, end in (('early', 0, 2), ('middle', 2, 5),
                          ('late', 5, 0), ('after', 20, 0), ('explicit-full', 0, 0)):
    prefix, report, count = run(name, start, end, explicit=True)
    expected = sum(a >= start * 1000000000 and (not end or b < end * 1000000000)
                   for a, b in windows)
    assert count == expected, (name, count, expected)
    assert report.pop('fetch_start_ms') == start
    assert report.pop('fetch_end_ms') == end
    assert report.pop('fetch_window_policy') == 'whole_completed_m1_half_open'
    assert report == reference, 'observation window altered machine results'
    for suffix in ('.ram', '.cpu', '.subram', '.text', '.attr', '.crtc',
                   '.gram-b', '.gram-r', '.gram-g', '.pcg-b', '.pcg-r', '.pcg-g',
                   '.video-palette', '.video-samples'):
        assert pathlib.Path(str(prefix) + suffix).read_bytes() == pathlib.Path(str(baseline) + suffix).read_bytes(), suffix

for arguments, marker in ((['--fetch-start-ms', '2'], 'require --video-dump'),
                          (['--fetch-end-ms', '0'], 'require --video-dump'),
                          (['--video-dump', str(folder / 'invalid'), '--fetch-start-ms', '5', '--fetch-end-ms', '5'], 'fetch-start-ms <'),
                          (['--video-dump', str(folder / 'invalid'), '--fetch-end-ms', '1000000001'], 'fetch-start-ms <')):
    result = subprocess.run([str(runner), '--cycles', '128'] + arguments,
                            capture_output=True, text=True, timeout=30)
    assert result.returncode == 2 and marker in result.stderr, result.stderr
assert hashlib.sha256(runner.read_bytes()).hexdigest() == runner_hash
print('PASS actual CPU opcode windows: full bus oracle, partial boundaries, unchanged machine outputs and rejecting CLI controls')
print('Evidence:', folder, 'runner SHA256:', runner_hash)
