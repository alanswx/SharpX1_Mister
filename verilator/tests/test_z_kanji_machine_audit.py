#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Regression controls for caller-bound, completed probe/render80 evidence.

Original asset-free orchestration: never builds or executes the machine runner.
Only disposable copies are mutated; failed copies and logs are retained.
This verifies the synthetic evidence auditor, not native fonts or hardware.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

if not __debug__:
    raise RuntimeError('Z_AUDIT_REGRESSION_OPTIMIZED_EXECUTION_FORBIDDEN')
sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[2]
AUDITOR = ROOT / 'verilator/tests/audit_z_kanji_machine.py'
ROSTER = ['probe', 'render80']


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def manifest(folder):
    result = {}
    for path in sorted(folder.rglob('*')):
        require(not path.is_symlink(), f'Z_REGRESSION_SYMLINK: {path}')
        if path.is_file():
            result[str(path.relative_to(folder))] = sha(path)
    return result


def save_json(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')


def csv_rows(path):
    with path.open(newline='') as stream:
        reader = csv.DictReader(stream)
        return reader.fieldnames, list(reader)


def save_rows(path, fields, rows):
    with path.open('w', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def mutate(label, folder, state, original):
    if label == 'cpu-payload':
        path = folder / 'probe/events.csv'
        fields, rows = csv_rows(path)
        row = next(row for row in rows if row['event'] == 'read')
        row['value'] = str(int(row['value']) ^ 1)
        save_rows(path, fields, rows)
    elif label == 'rgb-matched-ppm-status':
        path = folder / 'render80/frame-0.csv'
        fields, rows = csv_rows(path)
        rows[0]['rgb12'] = format(int(rows[0]['rgb12'], 16) ^ 0xf00, '03x')
        save_rows(path, fields, rows)
        path = folder / 'render80/frame-0.ppm'
        contents = bytearray(path.read_bytes())
        header = b'P6\n640 400\n255\n'
        require(contents.startswith(header), 'Z_REGRESSION_PPM_HEADER')
        contents[len(header)] ^= 255
        path.write_bytes(contents)
        state['runs'][1]['frames'][0]['sha256'] = hashlib.sha256(contents[len(header):]).hexdigest()
    elif label in ('frame-period', 'negative-completion-time'):
        path = folder / 'render80/events.csv'
        fields, rows = csv_rows(path)
        if label == 'frame-period':
            row = next(row for row in rows if row['event'] == 'frame')
            row['time_ps'] = str(int(row['time_ps']) + 1000)
        else:
            rows[-1]['time_ps'] = '-1'
        save_rows(path, fields, rows)
    elif label == 'terminal':
        state['phase'] = 'failed'
    elif label == 'frozen-source':
        # Literal independent target, not whichever manifest entry comes first.
        path = folder / 'sources/rtl/x1_video_blink.sv'
        path.write_bytes(path.read_bytes() + b'\n// disposable regression mutation\n')
    elif label in ('input-binding', 'executable'):
        path = folder / ('inputs.json' if label == 'input-binding' else 'build/Vz_kanji_machine_tb')
        path.write_bytes(path.read_bytes() + (b'\n' if label == 'input-binding' else b'changed'))
    elif label == 'omitted-frame-roster':
        state['runs'][1]['frames'] = []
    elif label == 'wrong-command-options':
        state['runs'][1]['command'] = [state['runs'][1]['command'][0],
                                      '+SCENARIO=5', '+LOAD_KIND=99', '+COLUMNS=40']
    elif label == 'generated-manifest-removed':
        save_json(folder / 'generated.json', {})
        (folder / 'render80.ipl.bin').write_bytes(b'not the original CPU program')
    elif label == 'external-log-matched-status':
        state['runs'][0]['log'] = str(original / 'probe.log')
        (folder / 'probe.log').write_text('FAILED disposable local log\n')
    elif label in ('failure-plus-pass-log', 'duplicate-pass-log'):
        path = folder / 'probe.log'
        suffix = ('FAIL Z_MACHINE contradictory failure' if label == 'failure-plus-pass-log'
                  else 'PASS Z_MACHINE duplicate')
        path.write_text(path.read_text() + '\n' + suffix + '\n')
    elif label in ('matched-ipl-program', 'matched-ipl-hex'):
        path = folder / ('render80.ipl.bin' if label == 'matched-ipl-program' else 'render80.ipl.hex')
        if label == 'matched-ipl-program':
            contents = bytearray(path.read_bytes())
            contents[0] ^= 1
            path.write_bytes(contents)
        else:
            values = path.read_text().split()
            values[0] = format(int(values[0], 16) ^ 1, '02x')
            path.write_text('\n'.join(values) + '\n')
        generated = json.loads((folder / 'generated.json').read_text())
        generated[path.name] = sha(path)
        save_json(folder / 'generated.json', generated)
    else:
        require(label in ('copy-baseline', 'optimized-python'), 'Z_REGRESSION_UNKNOWN_MUTATION')


# Exact diagnostics, independently literal rather than imported from the auditor.
CONTROLS = [
    ('cpu-payload', "AssertionError: ('Z_AUDIT_CPU_PAYLOAD', 'probe', 0)"),
    ('rgb-matched-ppm-status', 'AssertionError: Z_AUDIT_PIXEL'),
    ('frame-period', 'AssertionError: Z_AUDIT_FRAME_PERIOD'),
    ('terminal', 'AssertionError: Z_AUDIT_TERMINAL'),
    ('frozen-source', "AssertionError: ('Z_AUDIT_FROZEN_SOURCE', 'rtl/x1_video_blink.sv')"),
    ('input-binding', 'AssertionError: Z_AUDIT_INPUT_BINDING'),
    ('executable', 'AssertionError: Z_AUDIT_EXECUTABLE'),
    ('omitted-frame-roster', 'AssertionError: Z_AUDIT_CASE_FRAME_COUNT'),
    ('wrong-command-options', 'AssertionError: Z_AUDIT_COMMAND_BINDING'),
    ('negative-completion-time', 'AssertionError: Z_AUDIT_EVENT_CHRONOLOGY'),
    ('generated-manifest-removed', 'AssertionError: Z_AUDIT_GENERATED_ROSTER'),
    ('external-log-matched-status', 'AssertionError: Z_AUDIT_LOG_CONTAINMENT'),
    ('failure-plus-pass-log', 'AssertionError: Z_AUDIT_FAILURE_LOG'),
    ('duplicate-pass-log', 'AssertionError: Z_AUDIT_TERMINAL_LOG'),
    ('matched-ipl-program', 'AssertionError: Z_AUDIT_IPL_PROGRAM'),
    ('matched-ipl-hex', 'AssertionError: Z_AUDIT_IPL_HEX'),
    ('optimized-python', 'RuntimeError: Z_AUDIT_OPTIMIZED_EXECUTION_FORBIDDEN'),
]


def clone(original, target):
    # Copy real bytes, never hardlink or preserve write-through symlinks.
    shutil.copytree(original, target, ignore=lambda path, names:
                    ['build'] if Path(path) == original else [])
    (target / 'build').mkdir()
    shutil.copy2(original / 'build/Vz_kanji_machine_tb', target / 'build/Vz_kanji_machine_tb')
    state = json.loads((target / 'status.json').read_text())
    for run in state['runs']:
        run['command'] = [arg.replace(str(original), str(target)) for arg in run['command']]
        run['log'] = run['log'].replace(str(original), str(target))
    # No digest regeneration or input manifest changes during rebasing.
    save_json(target / 'status.json', state)
    return state


def invoke(label, folder, args, output, diagnostic=None):
    before = manifest(folder)
    command = [sys.executable, '-B']
    if label == 'optimized-python':
        command.append('-O')
    command += [str(AUDITOR), str(folder), '--expected-inputs-sha256',
                args.expected_inputs_sha256, '--cases', *ROSTER]
    record = {'case': label, 'command': command, 'timeout_seconds': args.timeout}
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=args.timeout)
        record.update(returncode=result.returncode, stdout=result.stdout, stderr=result.stderr,
                      timed_out=False)
    except subprocess.TimeoutExpired as exc:
        def decoded(value):
            return value.decode(errors='replace') if isinstance(value, bytes) else (value or '')
        record.update(returncode=None, stdout=decoded(exc.stdout), stderr=decoded(exc.stderr),
                      timed_out=True)
    finally:
        record['evidence_unchanged'] = before == manifest(folder)
        save_json(output / (label + '.result.json'), record)
    require(record['evidence_unchanged'], f'Z_REGRESSION_EVIDENCE_CHANGED: {label}')
    require(not record['timed_out'], f'Z_REGRESSION_TIMEOUT: {label}')
    if diagnostic is None:
        require(record['returncode'] == 0, f'Z_REGRESSION_BASELINE_FAILED: {label}')
        counts = json.loads(record['stdout'])
        require(all(counts.get(k) == v for k, v in {
            'cases': 2, 'reads': 32, 'frames': 3, 'pixels': 768000,
            'frame_periods_checked': True, 'evidence_unchanged': True}.items()),
            'Z_REGRESSION_BASELINE_COUNTS')
        record['counts'] = counts
    else:
        require(record['returncode'] == 1, f'Z_REGRESSION_MUTATION_NOT_REJECTED: {label}')
        require(record['stderr'].strip().splitlines()[-1] == diagnostic,
                f'Z_REGRESSION_WRONG_DIAGNOSTIC: {label}')
        record['expected_diagnostic'] = diagnostic
    print(json.dumps({'case': label, 'returncode': record['returncode'],
                      'evidence_unchanged': True, 'diagnostic': diagnostic}), flush=True)
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--folder', type=Path, required=True)
    parser.add_argument('--expected-inputs-sha256', required=True)
    parser.add_argument('--timeout', type=float, default=60,
                        help='per-audit subprocess timeout, seconds (0 < timeout <= 60)')
    args = parser.parse_args()
    require(0 < args.timeout <= 60, 'Z_REGRESSION_TIMEOUT_RANGE')
    require(re.fullmatch('[0-9a-f]{64}', args.expected_inputs_sha256) is not None,
            'Z_REGRESSION_INVALID_HASH')
    require(not args.folder.is_symlink(), 'Z_REGRESSION_FOLDER_SYMLINK')
    original = args.folder.resolve(strict=True)
    original_before = manifest(original)
    require(sha(original / 'inputs.json') == args.expected_inputs_sha256,
            'Z_REGRESSION_INPUT_BINDING')
    state = json.loads((original / 'status.json').read_text())
    require([run['case'] for run in state['runs']] == ROSTER, 'Z_REGRESSION_UNRECOGNIZED_ROSTER')
    inputs = json.loads((original / 'inputs.json').read_text())
    for name in inputs:
        relative = Path(name)
        require(not relative.is_absolute() and '..' not in relative.parts,
                'Z_REGRESSION_UNSAFE_SOURCE_PATH')
    monitored = set(inputs) | {str(AUDITOR.relative_to(ROOT)), str(Path(__file__).resolve().relative_to(ROOT))}
    source_before = {name: sha(ROOT / name) for name in sorted(monitored)}
    output = Path(tempfile.mkdtemp(prefix='x1-z-kanji-audit-regression-')).resolve()
    print(f'Z_AUDIT_REGRESSION_EVIDENCE={output}', flush=True)
    save_json(output / 'original.before.json', original_before)
    save_json(output / 'sources.before.json', source_before)
    report = {'phase': 'running', 'folder': str(original),
              'expected_inputs_sha256': args.expected_inputs_sha256, 'results': []}
    save_json(output / 'terminal.json', report)
    failure = None
    try:
        report['results'].append(invoke('original-baseline', original, args, output))
        for label, diagnostic in [('copy-baseline', None), *CONTROLS]:
            folder = output / label
            copied_state = clone(original, folder)
            mutate(label, folder, copied_state, original)
            save_json(folder / 'status.json', copied_state)
            report['results'].append(invoke(label, folder, args, output, diagnostic))
        report['phase'] = 'pass'
    except Exception as exc:
        failure = exc
        report.update(phase='failed', error=f'{type(exc).__name__}: {exc}')
    finally:
        original_after = manifest(original)
        source_after = {name: sha(ROOT / name) for name in sorted(monitored)}
        save_json(output / 'original.after.json', original_after)
        save_json(output / 'sources.after.json', source_after)
        report.update(original_unchanged=original_before == original_after,
                      sources_unchanged=source_before == source_after,
                      original_files=len(original_before), controls=len(CONTROLS),
                      auditor_sha256=source_before[str(AUDITOR.relative_to(ROOT))],
                      driver_sha256=source_before[str(Path(__file__).resolve().relative_to(ROOT))])
        if not report['original_unchanged'] or not report['sources_unchanged']:
            report.update(phase='failed', preservation_error='Z_REGRESSION_PRESERVATION_FAILED')
        save_json(output / 'terminal.json', report)
    require(report['phase'] == 'pass', f'Z_REGRESSION_FAILED: {output}; {failure}')
    print(json.dumps({'phase': 'pass', 'controls': len(CONTROLS), 'baseline_reads': 32,
                      'baseline_frames': 3, 'baseline_pixels': 768000,
                      'original_unchanged': True, 'sources_unchanged': True,
                      'evidence': str(output)}))


if __name__ == '__main__':
    main()
