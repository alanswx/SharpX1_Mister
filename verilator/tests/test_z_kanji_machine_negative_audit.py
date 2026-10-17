#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Original, asset-free regression for three caller-bound negative folders.

Audit originals/copies, then fifteen exact bad-evidence controls. Never builds
or executes a machine runner; only disposable copies are changed. Logs, copies
and failures remain in a unique temporary directory. No native/hardware claim.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import resource
import shutil
import subprocess
import sys
import tempfile

if not __debug__:
    raise RuntimeError('Z_NEG_REGRESSION_OPTIMIZED_EXECUTION_FORBIDDEN')
sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[2]
AUDITOR = ROOT / 'verilator/tests/audit_z_kanji_machine_negative.py'
ROM = 'rtl/x1_z_kanji_rom.sv'
TB = 'verilator/tests/z_kanji_machine_tb.sv'
PROFILES = {'disabled': ('probe', 'Z_ORDERED_UPLOAD_ADMISSION'),
            'half-major': ('probe', 'Z_CPU_EXECUTED_DATA_ORACLE'),
            'display-miss': ('render80', 'Z_SUPPORTED_DISPLAY_MISS')}
# Independent literal diagnostics; do not import acceptance logic from auditor.
CONTROLS = [
    ('provenance', 'disabled', 'Z_NEG_AUDIT_FROZEN_SOURCE: rtl/x1_video_blink.sv'),
    ('source-order', 'disabled', 'Z_NEG_AUDIT_SOURCE_ORDER'),
    ('build-command', 'disabled', 'Z_NEG_AUDIT_BUILD_COMMAND'),
    ('run-command', 'disabled', 'Z_NEG_AUDIT_RUN_COMMAND'),
    ('mutation-matched-digest', 'display-miss', 'Z_NEG_AUDIT_MUTATION_BYTES'),
    ('mutation-roster', 'display-miss', 'Z_NEG_AUDIT_MUTATION_ROSTER'),
    ('font-hex-matched-digest', 'half-major', 'Z_NEG_AUDIT_FONT_HEX'),
    ('font-binary-matched-digest', 'disabled', 'Z_NEG_AUDIT_FONT_BINARY'),
    ('run-code-none', 'disabled', 'Z_NEG_AUDIT_RUN_CODE'),
    ('executable', 'disabled', 'Z_NEG_AUDIT_EXECUTABLE'),
    ('external-log', 'disabled', 'Z_NEG_AUDIT_LOG_CONTAINMENT'),
    ('wrong-marker', 'disabled', 'Z_NEG_AUDIT_FAILURE_MARKER'),
    ('wrong-terminal-source', 'disabled', 'Z_NEG_AUDIT_FAILURE_TERMINAL'),
    ('ipl-matched-digest', 'disabled', 'Z_NEG_AUDIT_IPL_PROGRAM'),
    ('optimized-python', 'disabled', 'Z_NEG_AUDIT_OPTIMIZED_EXECUTION_FORBIDDEN'),
]


def require(condition, marker):
    if not condition:
        raise RuntimeError(marker)


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def save(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')


def artifacts(folder):
    require(folder.is_dir() and not folder.is_symlink(), 'Z_NEG_REGRESSION_FOLDER')
    result = {}
    for path in sorted(folder.rglob('*')):
        require(not path.is_symlink(), 'Z_NEG_REGRESSION_SYMLINK')
        if path.is_file():
            result[str(path.relative_to(folder))] = sha(path)
    return result


def clone(original, folder):
    # No hardlinks or write-through symlinks. Copy the executable as inert
    # evidence; never execute it. Omit unrelated generated build intermediates.
    shutil.copytree(original, folder, ignore=lambda path, names:
                    ['build'] if Path(path) == original else [])
    (folder / 'build').mkdir()
    shutil.copy2(original / 'build/Vz_kanji_machine_tb', folder / 'build/Vz_kanji_machine_tb')
    state = json.loads((folder / 'status.json').read_text())
    for record in [state['build'], *state['runs']]:
        record['command'] = [arg.replace(str(original), str(folder)) for arg in record['command']]
        record['log'] = record['log'].replace(str(original), str(folder))
    # Structured failure lines contain the frozen-source absolute path too.
    for name in ['build.log', state['runs'][0]['case'] + '.log']:
        path = folder / name
        path.write_text(path.read_text().replace(str(original), str(folder)))
    save(folder / 'status.json', state)
    return state


def mutate(label, folder, state, original):
    if label == 'provenance':
        path = folder / 'sources/rtl/x1_video_blink.sv'
        path.write_bytes(path.read_bytes() + b'\n// disposable regression mutation\n')
    elif label == 'source-order':
        path = folder / 'source-order.json'
        save(path, list(reversed(json.loads(path.read_text()))))
    elif label == 'build-command':
        index = state['build']['command'].index('-GENABLED=0')
        state['build']['command'][index] = '-GENABLED=1'
    elif label == 'run-command':
        state['runs'][0]['command'][-1] = '+DELAY=0'
    elif label == 'mutation-matched-digest':
        path = folder / 'mutation' / ROM
        path.write_bytes(path.read_bytes() + b'\n// unauthorized extra mutation\n')
        save(folder / 'mutation.json', {ROM: sha(path)})
    elif label == 'mutation-roster':
        (folder / 'mutation/extra.sv').write_text('// unexpected mutant\n')
    elif label in ('font-hex-matched-digest', 'font-binary-matched-digest', 'ipl-matched-digest'):
        name = {'font-hex-matched-digest': 'font.hex', 'font-binary-matched-digest': 'font.bin',
                'ipl-matched-digest': 'probe.ipl.bin'}[label]
        path = folder / name
        if name.endswith('.hex'):
            values = path.read_text().split()
            values[0] = format(int(values[0], 16) ^ 1, '02x')
            path.write_text('\n'.join(values) + '\n')
        else:
            data = bytearray(path.read_bytes())
            data[0] ^= 1
            path.write_bytes(data)
        generated = json.loads((folder / 'generated.json').read_text())
        generated[name] = sha(path)
        save(folder / 'generated.json', generated)
    elif label == 'run-code-none':
        state['runs'][0]['returncode'] = None
    elif label == 'executable':
        path = folder / 'build/Vz_kanji_machine_tb'
        path.write_bytes(path.read_bytes() + b'changed')
    elif label == 'external-log':
        state['runs'][0]['log'] = str(original / 'probe.log')
    elif label in ('wrong-marker', 'wrong-terminal-source'):
        path = folder / 'probe.log'
        text = path.read_text()
        if label == 'wrong-marker':
            text = text.replace('Z_ORDERED_UPLOAD_ADMISSION', 'Z_SOMETHING_ELSE')
        else:
            text = text.replace(str(folder / 'sources' / TB), str(folder / 'wrong-source.sv'))
        path.write_text(text)
    else:
        require(label == 'optimized-python', 'Z_NEG_REGRESSION_UNKNOWN_CONTROL')
    save(folder / 'status.json', state)


def run(label, folder, negative, binding, timeout, output, marker=None):
    command = [sys.executable, '-B']
    if label == 'optimized-python':
        command.append('-O')
    command += [str(AUDITOR), '--folder', str(folder), '--expected-inputs-sha256', binding,
                '--negative', negative]
    before = artifacts(folder)
    record = {'case': label, 'command': command, 'timeout_seconds': timeout}
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=timeout)
        record.update(returncode=result.returncode, stdout=result.stdout, stderr=result.stderr, timed_out=False)
    except subprocess.TimeoutExpired as exc:
        def text(value):
            return value.decode(errors='replace') if isinstance(value, bytes) else (value or '')
        record.update(returncode=None, stdout=text(exc.stdout), stderr=text(exc.stderr), timed_out=True)
    finally:
        record['evidence_unchanged'] = before == artifacts(folder)
        save(output / (label + '.result.json'), record)
    require(record['evidence_unchanged'], 'Z_NEG_REGRESSION_EVIDENCE_CHANGED: ' + label)
    require(not record['timed_out'], 'Z_NEG_REGRESSION_TIMEOUT: ' + label)
    if marker:
        require(record['returncode'] == 1 and record['stderr'].strip().splitlines()[-1] ==
                'RuntimeError: ' + marker, 'Z_NEG_REGRESSION_WRONG_REJECTION: ' + label)
        record['expected_diagnostic'] = marker
    else:
        require(record['returncode'] == 0, 'Z_NEG_REGRESSION_BASELINE_FAILED: ' + label)
        audited = json.loads(record['stdout'])
        require(audited.get('negative') == negative and audited.get('case') == PROFILES[negative][0] and
                audited.get('exact_rejection') == PROFILES[negative][1] and
                audited.get('inputs_sha256') == binding and audited.get('sources_unchanged') is True and
                audited.get('artifacts_unchanged') is True, 'Z_NEG_REGRESSION_BASELINE_BINDING')
    print(json.dumps({'case': label, 'returncode': record['returncode'],
                      'diagnostic': marker, 'evidence_unchanged': True}), flush=True)
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in PROFILES:
        parser.add_argument('--' + name + '-folder', type=Path, required=True)
    parser.add_argument('--expected-inputs-sha256', required=True)
    parser.add_argument('--timeout', type=float, default=60)
    args = parser.parse_args()
    require(0 < args.timeout <= 60, 'Z_NEG_REGRESSION_TIMEOUT_RANGE')
    require(re.fullmatch('[0-9a-f]{64}', args.expected_inputs_sha256) is not None, 'Z_NEG_REGRESSION_HASH_FORMAT')
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    originals = {}
    for name in PROFILES:
        folder = getattr(args, name.replace('-', '_') + '_folder')
        require(not folder.is_symlink(), 'Z_NEG_REGRESSION_SYMLINK')
        originals[name] = folder.resolve(strict=True)
    require(len(set(originals.values())) == 3, 'Z_NEG_REGRESSION_DISTINCT_FOLDERS')
    before = {name: artifacts(folder) for name, folder in originals.items()}
    for name, folder in originals.items():
        require(sha(folder / 'inputs.json') == args.expected_inputs_sha256, 'Z_NEG_REGRESSION_INPUT_BINDING')
        state = json.loads((folder / 'status.json').read_text())
        require(state.get('negative') == name and [run['case'] for run in state['runs']] == [PROFILES[name][0]],
                'Z_NEG_REGRESSION_UNRECOGNIZED_ROSTER')
    inputs = json.loads((originals['disabled'] / 'inputs.json').read_text())
    for name in inputs:
        relative = Path(name)
        require(not relative.is_absolute() and '..' not in relative.parts and
                (ROOT / name).resolve().is_relative_to(ROOT), 'Z_NEG_REGRESSION_SOURCE_PATH')
    monitored = set(inputs) | {str(AUDITOR.relative_to(ROOT)), str(Path(__file__).resolve().relative_to(ROOT)),
                              'verilator/tests/run_z_kanji_machine_suite.py',
                              'verilator/tests/audit_z_kanji_machine.py',
                              'verilator/tests/test_z_kanji_machine_audit.py'}
    sources = {name: sha(ROOT / name) for name in sorted(monitored)}
    output = Path(tempfile.mkdtemp(prefix='x1-z-kanji-negative-audit-regression-')).resolve()
    print(f'Z_NEGATIVE_AUDIT_REGRESSION_FOLDER={output}', flush=True)
    save(output / 'original.before.json', before)
    save(output / 'sources.before.json', sources)
    report = {'phase': 'running', 'scope': __doc__, 'folders': {k: str(v) for k, v in originals.items()},
              'expected_inputs_sha256': args.expected_inputs_sha256, 'results': []}
    save(output / 'terminal.json', report)
    try:
        for negative, original in originals.items():
            report['results'].append(run('original-' + negative, original, negative,
                                         args.expected_inputs_sha256, args.timeout, output))
            folder = output / ('copy-' + negative)
            clone(original, folder)
            report['results'].append(run('copy-' + negative, folder, negative,
                                         args.expected_inputs_sha256, args.timeout, output))
        for label, negative, marker in CONTROLS:
            folder = output / label
            state = clone(originals[negative], folder)
            mutate(label, folder, state, originals[negative])
            report['results'].append(run(label, folder, negative, args.expected_inputs_sha256,
                                         args.timeout, output, marker))
        report['phase'] = 'pass'
    except BaseException as exc:
        report.update(phase='failed', error=f'{type(exc).__name__}: {exc}')
        raise
    finally:
        after = {name: artifacts(folder) for name, folder in originals.items()}
        source_after = {name: sha(ROOT / name) for name in sorted(monitored)}
        save(output / 'original.after.json', after)
        save(output / 'sources.after.json', source_after)
        report.update(original_unchanged=before == after, sources_unchanged=sources == source_after,
                      controls=len(CONTROLS), original_files={name: len(value) for name, value in before.items()},
                      auditor_sha256=sources[str(AUDITOR.relative_to(ROOT))],
                      driver_sha256=sources[str(Path(__file__).resolve().relative_to(ROOT))])
        if not report['original_unchanged'] or not report['sources_unchanged']:
            report.update(phase='failed', preservation_error='Z_NEG_REGRESSION_PRESERVATION_FAILED')
        save(output / 'terminal.json', report)
    require(report['phase'] == 'pass', 'Z_NEG_REGRESSION_FAILED: ' + str(output))
    print(json.dumps({'phase': 'pass', 'controls': len(CONTROLS), 'original_unchanged': True,
                      'sources_unchanged': True, 'evidence': str(output)}))


if __name__ == '__main__':
    main()
