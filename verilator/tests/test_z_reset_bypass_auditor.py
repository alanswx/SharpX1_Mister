#!/usr/bin/env python3
"""Rejecting evidence controls; requires the original synthetic frozen matrix.

This does not rerun RTL, alter original evidence, or imply hardware acceptance.
All edits are confined to disposable test copies of generated diagnostics.
"""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('frozen_root', type=Path)
args = parser.parse_args()
original = args.frozen_root.resolve()
auditor = Path(__file__).with_name('audit_z_reset_bypass_matrix.py').resolve()
assert (original/'all-120/final-inputs.json').is_file(), 'completed synthetic matrix required'
names = ('Vtop','test_machine_z_video.py','z80_fixture.py',
         'test_z_combined_matrix.py','cg8_reference.v','source-at-launch.tar')
controls = ('runner-hash','missing-completion','reordered-roster','changed-input-manifest',
            'changed-program','changed-actual-pixel','changed-saved-expected-pixel','refill-on-warm-reset')

for control in controls:
    with tempfile.TemporaryDirectory(prefix='x1-z-audit-negative-') as temporary:
        frozen = Path(temporary)
        for name in names:
            (frozen/name).symlink_to(original/name)
        output = frozen/'all-120'
        output.mkdir()
        for source in (original/'all-120').iterdir():
            (output/source.name).symlink_to(source, target_is_directory=source.is_dir())

        def replace(path, data):
            # Unlink OUR symlink only, then create a disposable mutated copy.
            assert path.is_symlink()
            path.unlink()
            path.write_bytes(data)

        def copy_case(name):
            directory = output/name
            assert directory.is_symlink()
            directory.unlink()
            directory.mkdir()
            for source in (original/'all-120'/name).iterdir():
                assert source.is_file()
                (directory/source.name).symlink_to(source)
            return directory

        roster = json.loads((output/'cases.json').read_text())
        if control == 'runner-hash':
            replace(frozen/'Vtop', b'not the qualified executable')
        elif control == 'missing-completion':
            completion = json.loads((output/'completed.json').read_text())[:-1]
            replace(output/'completed.json', json.dumps(completion).encode())
        elif control == 'reordered-roster':
            roster[0],roster[1] = roster[1],roster[0]
            replace(output/'cases.json', json.dumps(roster).encode())
        elif control == 'changed-input-manifest':
            manifest = json.loads((output/'inputs.json').read_text())
            manifest['Vtop'] = '0'*64
            replace(output/'inputs.json', json.dumps(manifest).encode())
        elif control == 'refill-on-warm-reset':
            directory = copy_case(roster[1]['name'])
            path = directory/'warm-io.csv'
            lines = path.read_text().splitlines()
            columns = lines[0].split(',')
            row = lines[1].split(',')
            row[columns.index('wr_n')] = '0'
            row[columns.index('address')] = str(0x2000)
            replace(path, ('\n'.join(lines+[','.join(row)])+'\n').encode())
        else:
            directory = copy_case(roster[0]['name'])
            name = {'changed-program':'original.bin','changed-actual-pixel':'actual.ppm',
                    'changed-saved-expected-pixel':'expected.ppm'}[control]
            path = directory/name
            data = bytearray(path.read_bytes())
            data[-1] ^= 1
            replace(path, data)
        result = subprocess.run([sys.executable,str(auditor),str(frozen)],capture_output=True,
                                text=True,timeout=120)
        assert result.returncode == 1 and 'AssertionError' in result.stderr, (control,result.stderr)
        assert '"result": "passed"' not in result.stdout, control
        if control == 'missing-completion':
            assert 'matrix not complete' in result.stderr
        if control == 'changed-actual-pixel':
            assert 'actual pixels differ' in result.stderr
        print('PASS rejecting evidence control:',control,flush=True)
print('PASS eight disposable evidence controls; original matrix never modified')
