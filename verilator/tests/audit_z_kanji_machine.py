#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Read-only independent audit of frozen original Z CPU/RGB diagnostics.

Requires a caller-bound inputs manifest and a terminal selected-case result.
Does not execute the frozen collector, trust its saved expected pixels, or
modify evidence. Not native-font, ASIC, savable or FPGA acceptance.
"""
import argparse
import csv
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys

# Assertions are intentional verification gates, never optional under -O.
if not __debug__:
    raise RuntimeError('Z_AUDIT_OPTIMIZED_EXECUTION_FORBIDDEN')
sys.dont_write_bytecode = True

CASES = {'probe': (5, 'probe', 80), 'render80': (1, 'render', 80),
         'render40': (1, 'render', 40), 'warm80': (2, 'render', 80),
         'pending': (3, 'probe', 80), 'exhaustive': (0, 'exhaustive', 80),
         'unsupported': (6, 'unsupported', 80), 'transition': (7, 'transition', 80),
         'nonraster': (8, 'nonraster', 80)}
CASES.update({f'loader{n}': (4, 'probe', 80) for n in range(8)})


def module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    sys.modules[name] = result
    spec.loader.exec_module(result)
    return result


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def pattern(address):
    level, remainder = divmod(address, 131072)
    bank, remainder = divmod(remainder, 8192)
    character, remainder = divmod(remainder, 32)
    row, half = divmod(remainder, 2)
    return (167 * level + 13 * bank + 37 * character + 29 * row + 83 * half) % 256


def rgb_pixels(columns, kind):
    height = 200 if kind == 'nonraster' else 400
    for y in range(height):
        for x in range(columns * 8):
            cell = (y // 16) * columns + x // 8
            character = (7 * cell + cell // 32) % 256
            bank, level, half = cell % 16, (cell // 16) % 2, (cell // 32) % 2
            attribute = (cell // 3) % 8 + 8 * ((cell // 11) % 2)
            address = level * 131072 + bank * 8192 + character * 32 + (y % 16) * 2 + half
            ink = bool(pattern(address) & (128 >> (x % 8)))
            color = (attribute % 8 if ink else 0) ^ (7 if attribute & 8 else 0)
            if kind in ('unsupported', 'nonraster') or (kind == 'transition' and cell % 2 == 0):
                color = 0
            yield bytes((255 if color & 2 else 0, 255 if color & 4 else 0, 255 if color & 1 else 0))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder', type=Path)
    parser.add_argument('--expected-inputs-sha256', required=True)
    parser.add_argument('--cases', nargs='+', required=True, choices=CASES)
    args = parser.parse_args()
    folder = args.folder.resolve()
    assert sha(folder / 'inputs.json') == args.expected_inputs_sha256, 'Z_AUDIT_INPUT_BINDING'
    before = {str(p.relative_to(folder)): sha(p) for p in folder.rglob('*')
              if p.is_file() and 'build' not in p.relative_to(folder).parts}
    state = json.loads((folder / 'status.json').read_text())
    assert state['phase'] == 'selected-cases-pass' and state['sources_unchanged'], 'Z_AUDIT_TERMINAL'
    assert state['negative'] is None
    assert [run['case'] for run in state['runs']] == args.cases, 'Z_AUDIT_ROSTER'
    inputs = json.loads((folder / 'inputs.json').read_text())
    root = Path(__file__).resolve().parents[2]
    for name, digest in inputs.items():
        assert sha(folder / 'sources' / name) == digest, ('Z_AUDIT_FROZEN_SOURCE', name)
        assert sha(root / name) == digest, ('Z_AUDIT_CURRENT_SOURCE', name)
    executable = folder / 'build/Vz_kanji_machine_tb'
    assert sha(executable) == state['executable_sha256'], 'Z_AUDIT_EXECUTABLE'
    assert state['build']['returncode'] == 0
    generated = json.loads((folder / 'generated.json').read_text())
    expected_assets = {'font.bin', 'font.hex', 'absent.hex'} | {
        name + suffix for name in args.cases for suffix in ('.ipl.bin', '.ipl.hex')}
    assert set(generated) == expected_assets, 'Z_AUDIT_GENERATED_ROSTER'
    for name, digest in generated.items():
        assert sha(folder / name) == digest, ('Z_AUDIT_GENERATED', name)
    # Reproduce the frozen CPU program, not just its self-reported digest.
    # Pixel/address oracles below remain separate arithmetic implementations.
    emitter = module(folder / 'sources/verilator/tests/z80_fixture.py', 'z_audit_emitter')
    assets = module(folder / 'sources/verilator/tests/z_kanji_machine_assets.py', 'z_audit_assets')
    absent = assets.program(emitter.Program, 'probe', absent=True)
    assert bytes(int(v, 16) for v in (folder / 'absent.hex').read_text().split()) == absent, 'Z_AUDIT_ABSENT_IPL'
    for name in args.cases:
        _, kind, columns = CASES[name]
        expected_ipl = assets.program(emitter.Program, kind, columns)
        assert (folder / (name + '.ipl.bin')).read_bytes() == expected_ipl, 'Z_AUDIT_IPL_PROGRAM'
        assert bytes(int(v, 16) for v in (folder / (name + '.ipl.hex')).read_text().split()) == expected_ipl, 'Z_AUDIT_IPL_HEX'
    font = (folder / 'font.bin').read_bytes()
    assert len(font) == 262144 and font == bytes(pattern(a) for a in range(262144)), 'Z_AUDIT_PHYSICAL_FONT'
    assert bytes(int(v, 16) for v in (folder / 'font.hex').read_text().split()) == font
    pixels_checked = reads_checked = frames_checked = 0
    for run in state['runs']:
        name = run['case']
        scenario, kind, columns = CASES[name]
        assert run['phase'] == 'accepted' and run['returncode'] == 0
        expected_command = [str(executable), f'+FONT={folder / "font.hex"}',
                            f'+IPL={folder / (name + ".ipl.hex")}',
                            f'+ABSENT_IPL={folder / "absent.hex"}',
                            f'+OUTPUT={folder / name}', f'+SCENARIO={scenario}',
                            f'+COLUMNS={columns}',
                            f'+LOAD_KIND={int(name[6:]) if name.startswith("loader") else 0}', '+DELAY=1']
        assert run['command'] == expected_command, 'Z_AUDIT_COMMAND_BINDING'
        assert Path(run['log']).resolve() == folder / (name + '.log'), 'Z_AUDIT_LOG_CONTAINMENT'
        log = (folder / (name + '.log')).read_text()
        terminal = re.findall(r'^PASS Z_MACHINE scenario=(\d+) reads=(\d+) frames=(\d+) halts=(\d+)$', log, re.M)
        assert len(terminal) == 1 and len(re.findall('PASS Z_MACHINE', log)) == 1, 'Z_AUDIT_TERMINAL_LOG'
        assert not re.search(r'FAIL|Error|Assertion|%Fatal|Z_MACHINE_TIMEOUT', log), 'Z_AUDIT_FAILURE_LOG'
        with (folder / name / 'events.csv').open() as f:
            events = list(csv.DictReader(f))
        assert events[-1]['event'] == 'complete', 'Z_AUDIT_COMPLETION_EVENT'
        assert sum(r['event'] == 'complete' for r in events) == 1, 'Z_AUDIT_COMPLETION_COUNT'
        assert all(r['event'] in ('read', 'halt', 'frame', 'complete') for r in events), 'Z_AUDIT_EVENT_KIND'
        times = [int(r['time_ps']) for r in events]
        assert times[0] >= 0 and all(a <= b for a, b in zip(times, times[1:])), 'Z_AUDIT_EVENT_CHRONOLOGY'
        reads = [r for r in events if r['event'] == 'read']
        frame_count = 3 if kind in ('render', 'unsupported', 'transition', 'nonraster') else 0
        assert len(run['frames']) == frame_count, 'Z_AUDIT_CASE_FRAME_COUNT'
        assert sum(r['event'] == 'frame' for r in events) == frame_count, 'Z_AUDIT_FRAME_EVENTS'
        assert int(events[-1]['value']) == frame_count, 'Z_AUDIT_COMPLETE_FRAMES'
        assert tuple(map(int, terminal[0])) == (scenario, len(reads), frame_count,
                    sum(r['event'] == 'halt' for r in events)), 'Z_AUDIT_TERMINAL_COUNTS'
        if name == 'exhaustive':
            addresses = [l * 131072 + b * 8192 + c * 32 + r * 2 + h
                         for l in range(2) for b in range(16) for h in range(2)
                         for c in range(256) for r in range(16)]
            assert len(set(addresses)) == 262144
        elif name == 'probe' or name == 'pending' or name.startswith('loader'):
            addresses = [l * 131072 + b * 8192 + 255 * 32 + r * 2 + h
                         for l, b, h in ((0, 0, 0), (1, 15, 1)) for r in range(16)]
            if name.startswith('loader'):
                addresses *= 2
        else:
            addresses = []
        assert [int(r['address']) for r in reads] == addresses, ('Z_AUDIT_CPU_ADDRESSES', name)
        for n, row in enumerate(reads):
            expected = 255 if name.startswith('loader') and n < 32 else pattern(int(row['address']))
            assert int(row['value']) == expected, ('Z_AUDIT_CPU_PAYLOAD', name, n)
        assert len(reads) == run['public_reads']
        assert int(events[-1]['address']) == len(reads)
        reads_checked += len(reads)
        if frame_count:
            height = 200 if kind == 'nonraster' else 400
            expected = b''.join(rgb_pixels(columns, kind))
            frame_events = [r for r in events if r['event'] == 'frame']
            assert len(frame_events) == len(run['frames']) == 3
            # R0=55/111, width40/80: exactly 1792 master edges per line.
            # R4=27, R9=7/15: 224/448 total lines, independent of active size.
            numerator = 1792 * 28 * (8 if height == 200 else 16) * 10**12
            period = (numerator + 42954540 // 2) // 42954540
            times = [int(r['time_ps']) for r in frame_events]
            assert all(abs(b - a - period) <= 1 for a, b in zip(times, times[1:])), 'Z_AUDIT_FRAME_PERIOD'
            for i, record in enumerate(run['frames']):
                pixels = bytearray()
                with (folder / name / f'frame-{i}.csv').open() as f:
                    for n, row in enumerate(csv.DictReader(f)):
                        assert (int(row['y']), int(row['x'])) == divmod(n, columns * 8), 'Z_AUDIT_RASTER_ORDER'
                        rgb = int(row['rgb12'], 16)
                        assert 0 <= rgb <= 4095
                        pixels.extend((((rgb >> 8) & 15) * 17, ((rgb >> 4) & 15) * 17, (rgb & 15) * 17))
                assert len(pixels) == columns * 8 * height * 3 and pixels == expected, 'Z_AUDIT_PIXEL'
                ppm = (folder / name / f'frame-{i}.ppm').read_bytes()
                assert ppm == f'P6\n{columns * 8} {height}\n255\n'.encode() + pixels, 'Z_AUDIT_PPM'
                assert record['pixels'] == len(pixels) // 3
                assert record['sha256'] == hashlib.sha256(pixels).hexdigest()
                pixels_checked += len(pixels) // 3
                frames_checked += 1
    after = {str(p.relative_to(folder)): sha(p) for p in folder.rglob('*')
             if p.is_file() and 'build' not in p.relative_to(folder).parts}
    assert before == after, 'Z_AUDIT_EVIDENCE_MUTATION'
    print(json.dumps({'scope': 'read-only frozen synthetic machine audit, not native/hardware',
                      'cases': len(state['runs']), 'reads': reads_checked,
                      'frames': frames_checked, 'pixels': pixels_checked,
                      'frame_periods_checked': True, 'evidence_unchanged': True}))


if __name__ == '__main__':
    main()
