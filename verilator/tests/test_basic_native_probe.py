"""Asset-free orchestration checks; no native BASIC compatibility claims."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


COLLECTOR = Path(__file__).with_name('probe_basic_native.py')
SUFFIXES = ('.ram', '.text', '.attr', '.subram', '.cpu', '.ppm')
FAKE = r'''
import json
import os
from pathlib import Path
import sys
import time

args = sys.argv[1:]
def option(name):
    return args[args.index(name) + 1]
prefix = Path(option('--dump'))
mode = os.environ.get('BASIC_PROBE_FAKE_MODE', 'stable')
repeat = prefix.name == 'repeat'
assert int(option('--cycles')) == 32000000
assert '--disk-output' not in args
for flag in ('--rom', '--disk', '--keys'):
    assert Path(option(flag)).is_file()
assert option('--frame') == str(prefix) + '.ppm'
for suffix in ('.ram', '.text', '.attr', '.subram', '.cpu', '.ppm'):
    payload = b'synthetic fixture output\n'
    if mode == 'payload-difference' and repeat and suffix == '.ram':
        payload += b'changed repeat payload\n'
    Path(str(prefix) + suffix).write_bytes(payload)
print('synthetic runner diagnostic', flush=True)
if mode == 'nonzero' and repeat:
    print('synthetic runner failure', file=sys.stderr, flush=True)
    sys.exit(7)
if mode == 'timeout' and repeat:
    print('synthetic timeout evidence', file=sys.stderr, flush=True)
    time.sleep(30)
if mode.startswith('mutate-') and repeat:
    target = Path(sys.argv[0]) if mode == 'mutate-runner' else Path(option('--' + mode[7:]))
    target.write_bytes(target.read_bytes() + b'\nsynthetic mutation\n')
report = {'disk_writes': 0, 'cycles': int(option('--cycles')), 'observed': 12}
if mode == 'report-difference' and repeat:
    report['observed'] = 13
if mode == 'disk-write':
    report['disk_writes'] = 1
print(json.dumps(report), flush=True)
'''


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class BasicNativeProbeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='basic-probe-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.exe = self.root / 'fake-runner'
        self.exe.write_text('#!' + sys.executable + '\n' + FAKE)
        self.exe.chmod(0o700)
        self.disk = self.root / 'synthetic.disk'
        self.archive = self.root / 'synthetic.archive'
        self.rom = self.root / 'synthetic.hex'
        self.keys = self.root / 'synthetic.keys'
        for path in (self.disk, self.archive, self.rom, self.keys):
            path.write_bytes(b'original synthetic fixture: ' + path.name.encode())
        self.manifest = self.root / 'manifest.json'
        self.manifest.write_text(json.dumps({
            'archive': str(self.archive), 'archive_sha256': sha(self.archive),
            'records': [{'image': str(self.disk), 'sha256': sha(self.disk)}],
        }))
        self.originals = {p: p.read_bytes() for p in
                          (self.exe, self.disk, self.archive, self.rom, self.keys, self.manifest)}
        self.output = self.root / 'evidence'
        self.runner_sha = sha(self.exe)

    def run_probe(self, mode='stable', timeout=10):
        env = dict(os.environ, BASIC_PROBE_FAKE_MODE=mode)
        return subprocess.run([
            sys.executable, str(COLLECTOR), str(self.exe),
            '--runner-sha', self.runner_sha, '--manifest', str(self.manifest),
            '--rom', str(self.rom), '--keys', str(self.keys), '--seconds', '1',
            '--timeout', str(timeout), '--output', str(self.output),
        ], env=env, capture_output=True, text=True, timeout=20)

    def evidence(self):
        return json.loads((self.output / 'evidence.json').read_text())

    def assert_originals_unchanged(self):
        for path, data in self.originals.items():
            self.assertEqual(path.read_bytes(), data, str(path))

    def assert_preserved_runs(self):
        for name in ('cold', 'repeat'):
            for suffix in SUFFIXES:
                self.assertTrue((self.output / (name + suffix)).is_file())
            for suffix in ('.stdout', '.stderr', '.command.json'):
                self.assertTrue((self.output / (name + suffix)).is_file())
        self.assertTrue((self.output / 'probe_basic_native.py').is_file())

    def test_repeat_is_observational_not_compatibility(self):
        result = self.run_probe()
        self.assertEqual(result.returncode, 0, result.stderr)
        evidence = self.evidence()
        self.assertEqual(evidence['phase'], 'repeatable')
        self.assertIn('not BASIC acceptance', evidence['scope'])
        self.assertIn('screen/commands require separate acceptance', result.stdout)
        self.assertEqual(len(evidence['runs']), 2)
        first, second = evidence['runs']
        self.assertEqual(first['report'], second['report'])
        self.assertEqual(first['artifacts'], second['artifacts'])
        self.assertEqual(set(first['artifacts']), set(SUFFIXES))
        self.assertTrue(evidence['unchanged_inputs'])
        self.assertTrue(evidence['unchanged_runner'])
        self.assertEqual(sha(self.output / 'Vtop'), self.runner_sha)
        self.assert_preserved_runs()
        self.assert_originals_unchanged()

    def test_runner_mismatch_refused_before_output(self):
        self.runner_sha = '0' * 64
        result = self.run_probe()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('runner differs', result.stderr)
        self.assertFalse(self.output.exists())
        self.assert_originals_unchanged()

    def test_media_mismatches_refused_before_output(self):
        for field in ('disk', 'archive'):
            with self.subTest(field=field):
                metadata = json.loads(self.originals[self.manifest])
                if field == 'disk':
                    metadata['records'][0]['sha256'] = '0' * 64
                else:
                    metadata['archive_sha256'] = '0' * 64
                self.manifest.write_text(json.dumps(metadata))
                result = self.run_probe()
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('private media differs', result.stderr)
                self.assertFalse(self.output.exists())
        self.manifest.write_bytes(self.originals[self.manifest])
        self.assert_originals_unchanged()

    def test_repeat_payload_and_report_differences_preserve_failure(self):
        for mode in ('payload-difference', 'report-difference'):
            with self.subTest(mode=mode):
                self.output = self.root / mode
                result = self.run_probe(mode)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn('PASS', result.stdout)
                evidence = self.evidence()
                self.assertEqual(evidence['phase'], 'failed')
                self.assertIn('native probe differs', evidence['error'])
                self.assertEqual(len(evidence['runs']), 2)
                self.assertTrue(evidence['unchanged_inputs'])
                self.assertTrue(evidence['unchanged_runner'])
                self.assert_preserved_runs()
                self.assert_originals_unchanged()

    def test_nonzero_and_timeout_record_failure_without_pass(self):
        for mode in ('nonzero', 'timeout'):
            with self.subTest(mode=mode):
                self.output = self.root / mode
                result = self.run_probe(mode, timeout=0.5 if mode == 'timeout' else 10)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn('PASS', result.stdout)
                evidence = self.evidence()
                self.assertEqual(evidence['phase'], 'failed')
                self.assertIn('TimeoutExpired' if mode == 'timeout' else 'CalledProcessError', evidence['error'])
                if mode == 'nonzero':
                    self.assertEqual(evidence['runs'][1]['returncode'], 7)
                else:
                    self.assertEqual(len(evidence['runs']), 1)
                self.assertIn('synthetic', (self.output / 'repeat.stderr').read_text())
                self.assertTrue(evidence['unchanged_inputs'])
                self.assertTrue(evidence['unchanged_runner'])
                self.assert_preserved_runs()
                self.assert_originals_unchanged()

    def test_disk_write_report_refused(self):
        result = self.run_probe('disk-write')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('PASS', result.stdout)
        self.assertEqual(self.evidence()['phase'], 'failed')
        self.assertIn('unexpected disk write', self.evidence()['error'])
        self.assert_originals_unchanged()

    def test_changed_inputs_or_frozen_runner_cannot_pass(self):
        for mode in ('mutate-keys', 'mutate-disk', 'mutate-runner'):
            with self.subTest(mode=mode):
                self.output = self.root / mode
                result = self.run_probe(mode)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn('PASS', result.stdout)
                self.assertIn('probe inputs changed', result.stderr)
                evidence = self.evidence()
                if mode == 'mutate-runner':
                    self.assertFalse(evidence['unchanged_runner'])
                    self.assertTrue(evidence['unchanged_inputs'])
                else:
                    self.assertFalse(evidence['unchanged_inputs'])
                    self.assertTrue(evidence['unchanged_runner'])
                self.assert_preserved_runs()
                changed_original = {'mutate-keys': self.keys, 'mutate-disk': self.disk}.get(mode)
                for path, data in self.originals.items():
                    if path != changed_original:
                        self.assertEqual(path.read_bytes(), data)
                # Restore only disposable synthetic inputs for the next case.
                self.disk.write_bytes(self.originals[self.disk])
                self.keys.write_bytes(self.originals[self.keys])


if __name__ == '__main__':
    unittest.main()
