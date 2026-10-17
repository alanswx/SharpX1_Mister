#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Independently audit generated-shim startup bus and descriptor observations."""
import argparse
import collections
import csv
import hashlib
import json
from pathlib import Path
import re


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    if not __debug__:
        raise SystemExit('assertions must be enabled')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    parser.add_argument('hardware', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    out = args.output.resolve()
    hardware = args.hardware.resolve()
    report = json.loads((out / 'report.json').read_text())
    assert report['status'] == 'observed' and all(report['repeat_equal'].values())
    assert all(sha(root / n) == sha(out / 'sources' / n) == h for n, h in report['sources'].items())
    assert all(sha(p) == h for p, h in (report['origins'] | report['assets']).items())
    base = (hardware / 'assets/base.rom').read_bytes()
    assert len(base) == 4096 and sha(hardware / 'assets/base.rom') == 'e6295a523008688421991b651ab61de392b28c67bec9efbf040b0004e4b70a2a'
    expected_tail = bytes.fromhex('f3 210000 010038 110008 ed61 03 1b 7a b3 20f8 c30600')
    for name in ('skip', 'initialize'):
        image = (out / 'assets' / (name + '.bin')).read_bytes()
        assert image == (hardware / 'assets' / (name + '.rom')).read_bytes()
        expected = bytearray(base + b'\xff' * 28672)
        expected[:3] = bytes.fromhex('c30010')
        expected[0x1000:0x1000 + len(expected_tail)] = expected_tail
        if name == 'skip':
            expected[0x100a:0x100c] = bytes(2)
        assert image == expected, 'generated entry shim differs from prescribed bytes'
    native_outs = [(0x1a03, 0x82), (0x1a02, 0x72)]
    for index, value in enumerate(base[0xb3e:0xb4c]):
        native_outs.extend(((0x1800, index), (0x1801, value)))
    native_outs += [(0x1000 + i * 0x100, 0) for i in range(4)] + [(0x1c00, 7), (0x1b00, 0x3f)]
    native_outs += [(0x2000 + i, 7) for i in range(1024)] + [(0x3000 + i, 0x20) for i in range(1024)]
    checks = []
    for case in report['cases']:
        folder = out / case['name']
        assert all(sha(folder / n) == h for n, h in case['artifacts'].items())
        initialize = case['name'].startswith('initialize')
        rows = list(csv.DictReader((folder / 'events.csv').open()))
        actual_outs = [(int(r['address'], 16), int(r['data'], 16)) for r in rows if r['event'] == 'out']
        expected_outs = ([(0x3800 + i, 0) for i in range(2048)] if initialize else []) + native_outs
        assert actual_outs == expected_outs, 'CPU writes differ from entry shim plus native IPL prefix'
        assert all(r['sampled'] == '1' for r in rows if r['event'] in ('m1', 'in'))
        image = (out / 'assets' / ('initialize.bin' if initialize else 'skip.bin')).read_bytes()
        fetches = [r for r in rows if r['event'] == 'm1']
        assert len(fetches) == 4096 and fetches[0]['address'] == '0000'
        assert all(int(r['address'], 16) < 32768 and int(r['data'], 16) == image[int(r['address'], 16)] for r in fetches)
        journal = list(csv.DictReader((folder / 'journal.csv').open()))
        assert len(journal) == 2048
        for i, row in enumerate(journal):
            assert int(row['cell']) == i
            expected = (0x07000720 if initialize else 0x03000720) if i < 1024 else (0x04000000 if initialize else 0)
            assert int(row['descriptor'], 16) == expected
            assert int(row['cache_visible']) == int(initialize or i < 1024)
        summary = case['summary']
        assert int(summary['cycles']) == 6400000 and int(summary['commits']) == (4096 if initialize else 2048)
        assert summary['wait_n'] == '1' and summary['core_reset'] == '0' and summary['writer_state'] == '0'
        assert (int(summary['packets_valid']) > 0) == initialize
        checks.append({'name': case['name'], 'exact_cpu_outs': len(actual_outs),
                       'exact_recorded_m1': len(fetches), 'descriptor_masks': dict(collections.Counter(r['descriptor'][:2] for r in journal)),
                       'valid_packet_phase_samples': int(summary['packets_valid'])})
    for i in (0, 1):
        a, b = report['cases'][i], report['cases'][i + 2]
        assert {n: h for n, h in a['artifacts'].items() if n != 'run.log'} == {n: h for n, h in b['artifacts'].items() if n != 'run.log'}
    warnings = collections.Counter(re.findall(r'^%Warning-([A-Z0-9_]+):', (out / 'build.log').read_text(), re.M))
    assert dict(warnings) == {'PINMISSING': 5, 'MISINDENT': 1, 'WIDTHTRUNC': 23, 'WIDTHEXPAND': 26, 'CASEINCOMPLETE': 1, 'CASEX': 4}
    assert not any('native_ipl_startup_tb.sv:' in line for line in report['warnings'])
    audit = {'status': 'pass', 'scope': '200-ms CPU/descriptor/packet observation, no rendered-pixel or hardware acceptance',
             'report_sha256': sha(out / 'report.json'), 'auditor_sha256': sha(Path(__file__)), 'cases': checks,
             'warnings': dict(warnings), 'cold_repeat_machine_artifacts_exact': True,
             'raw_performance_logs_preserved': True}
    with (out / 'independent-audit.json').open('x') as stream:
        stream.write(json.dumps(audit, indent=2) + '\n')
    print(json.dumps({'status': 'pass', 'audit_sha256': sha(out / 'independent-audit.json'), 'cases': checks}))


if __name__ == '__main__':
    main()
