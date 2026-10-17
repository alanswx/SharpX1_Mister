#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Freeze and compare the local macOS Common Source X1 CLI with shared RTL."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'verilator/tests'))
import csp_reference_fixture as fixture


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    if not __debug__:
        raise SystemExit('Assertions are required')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', type=Path, required=True)
    parser.add_argument('--rtl', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    build, rtl, out = args.build.resolve(), args.rtl.resolve(), args.output.resolve()
    out.mkdir()
    source = ROOT.parent / 'common_source_code'
    inputs = {source / 'CMakeLists.txt', source / 'tool/generate_cmake.py'}
    for d in build.rglob('*.o.d'):
        inputs.update(Path(p) for p in re.findall(re.escape(str(source)) + r'/[^\s\\]+', d.read_text()))
    inputs.update((Path(__file__).resolve(), ROOT / 'verilator/tests/csp_reference_fixture.py',
                   ROOT / 'verilator/tests/z80_fixture.py'))
    hashes = {}
    for p in sorted(inputs):
        assert p.is_file(), p
        hashes[str(p)] = sha(p)
        relative = p.relative_to(source) if p.is_relative_to(source) else p.relative_to(ROOT)
        dest = out / 'sources' / ('common_source_code' if p.is_relative_to(source) else 'SharpX1_Mister') / relative
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(p, dest)
    (out / 'bin').mkdir()
    for model in ('x1', 'x1turbo', 'x1turboz'):
        shutil.copy2(build / f'{model}.app/Contents/MacOS/{model}', out / 'bin' / model)
    shutil.copy2(rtl, out / 'bin/rtl')
    binaries = {p.name: sha(p) for p in (out / 'bin').iterdir()}
    report = {'status': 'running', 'sources': hashes, 'executables': binaries, 'cases': [],
              'scope': 'Generated CPU/RAM/overlay/PSG semantics and frontend qualification; no native WAIT/pin or combined-device claim.'}

    def save():
        (out / 'terminal.json').write_text(json.dumps(report, indent=2) + '\n')

    def run(command, folder):
        folder.mkdir()
        (folder / 'command.json').write_text(json.dumps([str(a) for a in command], indent=2) + '\n')
        with (folder / 'stdout.log').open('w') as stdout, (folder / 'stderr.log').open('w') as stderr:
            p = subprocess.run([str(a) for a in command], stdout=stdout, stderr=stderr, timeout=240)
        return p.returncode

    def assets(name, model='x1', bad=False):
        d = out / name
        d.mkdir()
        image = fixture.program(bad)
        filename = 'IPLROM.X1' if model == 'x1' else 'IPLROM.X1T'
        (d / filename).write_bytes(image if model == 'x1' else image + bytes([255]) * (32768-len(image)))
        for n, size in (('ANK8.ROM', 2048), ('ANK16.ROM', 4096), ('KANJI.ROM', 306176)):
            (d / n).write_bytes(bytes(size))
        return d

    def io_rows(path, csp):
        rows = list(csv.DictReader(path.open()))
        if csp:
            return [(r['kind'], int(r['address'], 16), int(r['data'], 16)) for r in rows]
        return [('W' if r['wr_n'] == '0' else 'R', int(r['address']),
                 int(r['data_out'] if r['wr_n'] == '0' else r['data_in'])) for r in rows]

    save()
    try:
        good, bad = assets('good-assets'), assets('bad-assets', bad=True)
        assert sum(a != b for a, b in zip(fixture.program(), fixture.program(True))) == 1
        asset_hashes = {str(p): sha(p) for d in (good, bad) for p in d.iterdir()}
        expected = fixture.expected_io()
        pattern = bytes((a >> 8) ^ (a & 255) for a in range(0x8000, 0x8400))
        for name, is_bad, warm in (('cold', False, False), ('cold-repeat', False, False),
                                   ('bad', True, False), ('warm', False, True)):
            folder = out / name
            folder.mkdir()
            data = bad if is_bad else good
            cli = [out / 'bin/x1', '--headless', '--rom-dir', data, '--out', folder / 'csp',
                   '--stop-at-frame', 14 if warm else 5, '--trace-cpu', 'cpu.csv', '--trace-io', 'io.csv',
                   '--dump-memory', 'memory.bin', '--screenshot', 14 if warm else 5]
            if warm:
                cli += ['--reset-at', 7]
            assert run(cli, folder / 'csp-run') == 0, 'CSP failure is not an accepted negative'
            rcli = [out / 'bin/rtl', '--rom', data / 'IPLROM.X1', '--cycles', 9000000 if warm else 3000000,
                    '--dump', folder / 'rtl', '--peek', '0xf000', '--bus-trace', folder / 'rtl-io.csv',
                    '--io-only', '--bus-events']
            if warm:
                rcli += ['--reset-at', 120, '--reset-for-us', 20]
            assert run(rcli, folder / 'rtl-run') == 0, 'RTL failure is not an accepted negative'
            csp_mem, rtl_mem = (folder / 'csp/memory.bin').read_bytes(), (folder / 'rtl.ram').read_bytes()
            status = bytes.fromhex('ee000000') if is_bad else b'X1OK'
            assert csp_mem[0xf000:0xf004] == rtl_mem[0xf000:0xf004] == status
            assert (csp_mem[0xf000:0xf004] == b'X1OK') == (not is_bad), 'Unchanged completion oracle'
            assert csp_mem[0x8000:0x8400] == rtl_mem[0x8000:0x8400] == pattern
            rows = expected[:-2] if is_bad else expected * (2 if warm else 1)
            csp_io, rtl_io = io_rows(folder / 'csp/io.csv', True), io_rows(folder / 'rtl-io.csv', False)
            assert csp_io == rtl_io == rows, 'Exact ordered public I/O intents and completed values'
            assert (csp_io == expected * 2) == warm, 'No-reset control must reject two-boot oracle'
            cli_report = json.loads((folder / 'csp-run/stdout.log').read_text().splitlines()[-1])
            rtl_report = json.loads((folder / 'rtl-run/stdout.log').read_text().splitlines()[-1])
            assert cli_report['completed_frames'] == (15 if warm else 6)
            assert cli_report['cli_revision'] == 3 and cli_report['disk_policy'] == 'protected_private_copy'
            assert cli_report['scheduled_resets'] == int(warm)
            assert rtl_report['halted'] and rtl_report['download_bytes'] == 4096
            # The CSP dump is the CPU-visible map; the RTL .ram is physical.
            assert csp_mem[0] == 0xf3 and rtl_mem[0] == 0xa5
            report['cases'].append({'name': name, 'status': 'pass', 'io_transactions': len(rows),
                                    'pattern_bytes': 1024, 'bad_rom_rejects_completion': is_bad,
                                    'csp_final': cli_report, 'rtl_final': rtl_report})
            save()
            print('PASS_REFERENCE', name, len(rows), flush=True)
        for filename in ('cpu.csv', 'io.csv', 'frames.csv', 'memory.bin', 'frame_000005.png'):
            assert sha(out / 'cold/csp' / filename) == sha(out / 'cold-repeat/csp' / filename), 'Cold deterministic repeat: ' + filename
        keyboard = assets('keyboard-assets')
        (keyboard / 'IPLROM.X1').write_bytes(fixture.keyboard_program())
        for typed in (False, True):
            name = 'keyboard-typed' if typed else 'keyboard-absent'
            command = [out / 'bin/x1', '--headless', '--rom-dir', keyboard,
                       '--out', out / name, '--stop-at-frame', 15,
                       '--trace-io', 'io.csv', '--dump-memory', 'memory.bin']
            if typed:
                command += ['--type', '1:F', '--type', '8:R']
            assert run(command, out / (name + '-process')) == 0
            memory = (out / name / 'memory.bin').read_bytes()
            assert (memory[0xf000:0xf004] == b'KEYS') == typed, 'Unchanged CPU mailbox completion oracle'
            if typed:
                assert memory[0xf010:0xf012] == b'FR'
                replies = [data & 0xdf for kind, port, data in io_rows(out / name / 'io.csv', True)
                           if kind == 'R' and port == 0x1900]
                assert 0x46 in replies and 0x52 in replies
            report['cases'].append({'name': name, 'status': 'pass',
                                    'completion_hex': memory[0xf000:0xf004].hex(),
                                    'scope': 'CPU-polled real CSP mailbox, no RTL keyboard equivalence claim'})
            save()
            print('PASS_KEYBOARD', name, flush=True)
        for model in ('x1turbo', 'x1turboz'):
            data = assets(model + '-assets', model)
            command = [out / 'bin' / model, '--headless', '--rom-dir', data, '--out', out / (model + '-run'),
                       '--stop-at-frame', 5, '--trace-io', 'io.csv', '--dump-memory', 'memory.bin', '--screenshot', 5]
            assert run(command, out / (model + '-process')) == 0
            assert (out / (model + '-run/memory.bin')).read_bytes()[0xf000:0xf004] == b'X1OK'
            assert io_rows(out / (model + '-run/io.csv'), True) == expected
            report['cases'].append({'name': model, 'status': 'pass', 'scope': 'same synthetic CPU/PSG fixture, not Turbo/Z compatibility'})
            save()
        invalid = [('--unknown', '1'), ('--stop-at-frame', '-1'), ('--screenshot', '7'),
                   ('--type', '0:{UNKNOWN}'), ('--key-down', '7:32'), ('--type-rate', '0:4')]
        rejected = []
        for i, extra in enumerate(invalid):
            target = out / f'reject-output-{i}'
            command = [out / 'bin/x1', '--headless', '--rom-dir', good, '--out', target, '--stop-at-frame', 5, *extra]
            assert run(command, out / f'reject-process-{i}') == 2
            assert not target.exists(), 'CLI rejected after creating outputs'
            rejected.append(list(extra))
        report['cli_rejections'] = rejected
        # Original generated one-sector container: exercise the actual disk
        # loader/close path while the diagnostic itself leaves the FDC idle.
        disk = bytearray(0x2b0 + 16 + 128)
        disk[:8] = b'CSP test'
        struct.pack_into('<I', disk, 28, len(disk))
        struct.pack_into('<I', disk, 32, 0x2b0)
        disk[0x2b0:0x2b4] = bytes((0, 0, 1, 0))
        struct.pack_into('<H', disk, 0x2b4, 1)
        struct.pack_into('<H', disk, 0x2be, 128)
        disk[0x2c0:] = bytes(range(128))
        disk_path = out / 'generated.d88'
        disk_path.write_bytes(disk)
        command = [out / 'bin/x1', '--headless', '--rom-dir', good, '--out', out / 'disk-copy-run',
                   '--stop-at-frame', 5, '--disk-a', disk_path, '--dump-memory', 'memory.bin']
        assert run(command, out / 'disk-copy-process') == 0
        expected_disk = bytearray(disk)
        expected_disk[0x1a] = 0x10
        assert disk_path.read_bytes() == disk, 'Caller disk was modified'
        assert (out / 'disk-copy-run/disk-a.d88').read_bytes() == expected_disk
        assert (out / 'disk-copy-run/memory.bin').read_bytes()[0xf000:0xf004] == b'X1OK'
        report['protected_disk_copy'] = {'original_unchanged': True, 'copy_differs_only_at': [0x1a],
                                        'copy_unchanged_after_real_open_close': True}
        malformed = out / 'zero-length-volume.d88'
        malformed.write_bytes(bytes(0x2b0))
        command = [out / 'bin/x1', '--headless', '--rom-dir', good, '--out', out / 'bad-disk-run',
                   '--stop-at-frame', 5, '--disk-a', malformed]
        assert run(command, out / 'bad-disk-process') == 2
        assert not (out / 'bad-disk-run').exists()
        report['malformed_d88_zero_length_rejected_before_emulation'] = True
        report['asset_hashes_unchanged'] = all(sha(Path(p)) == v for p, v in asset_hashes.items())
        assert report['asset_hashes_unchanged']
        report['cold_repeat_byte_identical'] = True
        report['status'] = 'pass'
    except BaseException as error:
        report.update(status='fail', error=repr(error))
        raise
    finally:
        report['sources_unchanged'] = all(sha(Path(p)) == v for p, v in hashes.items())
        report['executables_unchanged'] = all(sha(out / 'bin' / n) == v for n, v in binaries.items())
        if not report['sources_unchanged'] or not report['executables_unchanged']:
            report['status'] = 'fail'
        save()
    assert report['status'] == 'pass'
    print('PASS_CSP_RTL_GATE', out, flush=True)


if __name__ == '__main__':
    main()
