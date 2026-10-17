#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Prepare, or explicitly run, the frozen synthetic Z Kanji machine suite.

Default: freeze repository inputs and describe commands, without building.
--run: early/full positives, independent audits, seventeen auditor controls,
and three matched machine negatives. No private assets or native/hardware claim.
No retries: observation intervals never restart a running child. Failed evidence
is retained. Repository inputs must remain frozen for the entire invocation.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import resource
import shutil
import signal
import subprocess
import sys
import tempfile
import time

if not __debug__:
    raise RuntimeError('Z_KANJI_SUITE_OPTIMIZED_EXECUTION_FORBIDDEN')
sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[2]
COLLECTOR = 'verilator/tests/test_machine_z_kanji.py'
AUDITOR = 'verilator/tests/audit_z_kanji_machine.py'
NEGATIVE_AUDITOR = 'verilator/tests/audit_z_kanji_machine_negative.py'
REGRESSION = 'verilator/tests/test_z_kanji_machine_audit.py'
SUITE = 'verilator/tests/run_z_kanji_machine_suite.py'
EARLY = ['probe', 'render80']
FULL = ['render40', 'warm80', 'pending', 'unsupported', 'transition', 'nonraster',
        *[f'loader{n}' for n in range(8)], 'exhaustive']
NEGATIVES = {'disabled': 'Z_ORDERED_UPLOAD_ADMISSION',
             'half-major': 'Z_CPU_EXECUTED_DATA_ORACLE',
             'display-miss': 'Z_SUPPORTED_DISPLAY_MISS'}
OWN_INPUTS = ['verilator/tests/z_kanji_machine_tb.sv',
              'verilator/tests/z_kanji_machine_assets.py', COLLECTOR,
              'verilator/tests/z80_fixture.py']
WALL_SECONDS = 1800


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def save(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def artifact_files(roots, files=()):
    """Exact byte/roster inventory; no write-through symlinks permitted."""
    result = {}
    for root in roots:
        require(root.is_dir() and not root.is_symlink(), 'Z_SUITE_ARTIFACT_ROOT')
        for path in sorted(root.rglob('*')):
            require(not path.is_symlink(), 'Z_SUITE_ARTIFACT_SYMLINK')
            if path.is_file():
                result[str(path)] = sha(path)
    for path in files:
        require(path.is_file() and not path.is_symlink(), 'Z_SUITE_ARTIFACT_FILE')
        result[str(path)] = sha(path)
    return result


def suite_artifacts(output):
    # Only these two ROOT-level files are excluded. Nested collector status,
    # phase state snapshots, logs and phase manifests are all included.
    result = {}
    for path in sorted(output.rglob('*')):
        require(not path.is_symlink(), 'Z_SUITE_ARTIFACT_SYMLINK')
        if path.is_file() and path not in (output / 'status.json', output / 'artifact-manifest.json'):
            result[str(path.relative_to(output))] = sha(path)
    return result


def input_names(root):
    order = re.findall(r'^set_global_assignment -name (?:SYSTEMVERILOG_FILE|VERILOG_FILE) (\S+)\s*$',
                       (root / 'rtl/machine.qip').read_text(), re.M)
    require(order and len(order) == len(set(order)), 'Z_SUITE_SOURCE_ORDER')
    # Deliberately mirror the collector's ordered list and JSON encoding.
    names = list(dict.fromkeys(order + OWN_INPUTS +
                               ['rtl/machine.qip', 'bios/reference/fw_subcpu/verilog/X1SUB.BIN']))
    for name in names:
        path = Path(name)
        require(not path.is_absolute() and '..' not in path.parts, 'Z_SUITE_UNSAFE_SOURCE_NAME')
        require((root / path).resolve().is_relative_to(root), 'Z_SUITE_SOURCE_OUTSIDE_ROOT')
    return order, names


def new_output(requested):
    if requested is None:
        return Path(tempfile.mkdtemp(prefix='x1-z-kanji-machine-suite-')).resolve()
    path = requested.resolve()
    temporary = [Path('/tmp').resolve(), Path(tempfile.gettempdir()).resolve()]
    safe_tmp = any(path != base and path.is_relative_to(base) for base in temporary)
    ignored = ROOT / 'output_files'
    safe_repo = path != ignored and path.is_relative_to(ignored)
    if safe_repo:
        result = subprocess.run(['git', 'check-ignore', '-q', '--no-index', str(path)],
                                cwd=ROOT, timeout=10)
        safe_repo = result.returncode == 0
    require(safe_tmp or safe_repo, 'Z_SUITE_OUTPUT_MUST_BE_NEW_TMP_OR_IGNORED')
    path.mkdir(parents=True, exist_ok=False)
    return path


def phases(output, bound):
    def collector(tag, cases, negative=None):
        command = [sys.executable, '-B', str(ROOT / COLLECTOR), '--output', str(output / tag),
                   '--run', '--jobs', '2', '--wall-seconds', str(WALL_SECONDS), '--cases', *cases]
        if negative:
            command += ['--negative', negative]
        # Collector has a per-build/per-case deadline. Bound its complete phase
        # generously, without mistaking an observation interval for failure.
        return {'name': tag, 'kind': 'collector', 'cases': cases, 'negative': negative,
                'folder': str(output / tag), 'command': command,
                'timeout_seconds': (len(cases) + 1) * WALL_SECONDS + 60}

    def auditor(tag, cases):
        return {'name': tag + '-audit', 'kind': 'audit',
                'command': [sys.executable, '-B', str(ROOT / AUDITOR), str(output / tag),
                            '--expected-inputs-sha256', bound, '--cases', *cases],
                'timeout_seconds': 300}

    def negative_auditor(name):
        return {'name': 'negative-' + name + '-audit', 'kind': 'negative-audit',
                'negative': name, 'folder': str(output / ('negative-' + name)),
                'inputs_sha256': bound,
                'command': [sys.executable, '-B', str(ROOT / NEGATIVE_AUDITOR),
                            '--folder', str(output / ('negative-' + name)),
                            '--expected-inputs-sha256', bound, '--negative', name],
                'timeout_seconds': 300}

    return [collector('early', EARLY), auditor('early', EARLY),
            {'name': 'audit-regression', 'kind': 'regression',
             'command': [sys.executable, '-B', str(ROOT / REGRESSION),
                         '--folder', str(output / 'early'), '--expected-inputs-sha256', bound,
                         '--timeout', '60'], 'timeout_seconds': 19 * 60 + 60},
            collector('full', FULL), auditor('full', FULL),
            *[phase for name in NEGATIVES for phase in
              (collector('negative-' + name, ['render80'] if name == 'display-miss' else ['probe'], name),
               negative_auditor(name))]]


def stop_owned_process_group(process):
    # Called only for a suite-owned child on hard deadline or interruption.
    if process.poll() is None:
        os.killpg(process.pid, signal.SIGTERM)
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait(timeout=5)


def child(phase, log, update):
    with log.open('w') as stream:
        process = subprocess.Popen(phase['command'], cwd=ROOT, stdout=stream,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        record = dict(phase, pid=process.pid, process_group=process.pid,
                      started_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
                      log=str(log), state='running')
        update(record)
        print(f"Z_SUITE_CHILD name={phase['name']} pid={process.pid} log={log}", flush=True)
        start = time.monotonic()
        try:
            while True:
                remaining = phase['timeout_seconds'] - (time.monotonic() - start)
                if remaining <= 0:
                    raise TimeoutError(f"Z_SUITE_HARD_DEADLINE: {phase['name']}")
                try:
                    process.wait(timeout=min(30, remaining))
                    break
                except subprocess.TimeoutExpired:
                    record['elapsed_seconds'] = time.monotonic() - start
                    update(record)
                    print(f"Z_SUITE_LIVE name={phase['name']} pid={process.pid} elapsed={record['elapsed_seconds']:.1f}",
                          flush=True)
        except BaseException as exc:
            stop_owned_process_group(process)
            record.update(state='failed', error=f'{type(exc).__name__}: {exc}')
            raise
        finally:
            record.update(returncode=process.poll(), elapsed_seconds=time.monotonic() - start,
                          ended_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()))
            if record['state'] == 'running':
                record['state'] = 'terminal'
            update(record)
    require(record['returncode'] == 0, f"Z_SUITE_CHILD_FAILED: {phase['name']}")
    return record


def check_collector(phase, bound):
    folder = Path(phase['folder'])
    require(sha(folder / 'inputs.json') == bound, 'Z_SUITE_COLLECTOR_INPUT_BINDING')
    state = json.loads((folder / 'status.json').read_text())
    require(state.get('sources_unchanged') is True, 'Z_SUITE_COLLECTOR_SOURCE_CHANGED')
    require(state.get('negative') == phase['negative'], 'Z_SUITE_NEGATIVE_BINDING')
    require([run['case'] for run in state['runs']] == phase['cases'], 'Z_SUITE_CASE_ROSTER')
    require(state['build']['returncode'] == 0, 'Z_SUITE_BUILD_FAILURE_IS_NOT_NEGATIVE')
    if not phase['negative']:
        require(state['phase'] == 'selected-cases-pass', 'Z_SUITE_POSITIVE_TERMINAL')
        require(all(run['phase'] == 'accepted' and run['returncode'] == 0 for run in state['runs']),
                'Z_SUITE_POSITIVE_RUN_FAILURE')
    else:
        require(state['phase'] == 'exact-negative-pass', 'Z_SUITE_NEGATIVE_TERMINAL')
        marker = NEGATIVES[phase['negative']]
        for run in state['runs']:
            require(type(run['returncode']) is int and run['returncode'] != 0 and
                    run.get('exact_rejection') == marker,
                    'Z_SUITE_NEGATIVE_DIAGNOSTIC')
            log = folder / (run['case'] + '.log')
            require(Path(run['log']).resolve() == log, 'Z_SUITE_NEGATIVE_LOG_CONTAINMENT')
            text = log.read_text()
            require(marker in text and 'PASS Z_MACHINE' not in text and 'Z_MACHINE_TIMEOUT' not in text,
                    'Z_SUITE_NEGATIVE_LOG')


def check_audit(phase, log):
    text = log.read_text()
    if phase['kind'] == 'audit':
        counts = json.loads(text)
        expected = ((2, 32, 3, 768000) if phase['name'] == 'early-audit'
                    else (15, 262688, 15, 3072000))
        require(tuple(counts.get(key) for key in ('cases', 'reads', 'frames', 'pixels')) == expected,
                'Z_SUITE_AUDIT_COUNTS')
        require(counts.get('evidence_unchanged') is True and counts.get('frame_periods_checked') is True,
                'Z_SUITE_AUDIT_PRESERVATION')
        return counts
    elif phase['kind'] == 'regression':
        terminal = json.loads(text.strip().splitlines()[-1])
        require(terminal.get('phase') == 'pass' and terminal.get('controls') == 17 and
                terminal.get('original_unchanged') is True and terminal.get('sources_unchanged') is True,
                'Z_SUITE_REGRESSION_TERMINAL')
        evidence = Path(terminal['evidence'])
        require(evidence == evidence.resolve() and any(evidence != base and evidence.is_relative_to(base)
                for base in (Path('/tmp').resolve(), Path(tempfile.gettempdir()).resolve())),
                'Z_SUITE_REGRESSION_EVIDENCE_PATH')
        return terminal
    elif phase['kind'] == 'negative-audit':
        result = json.loads(text)
        name = phase['negative']
        require(result.get('negative') == name and result.get('case') ==
                ('render80' if name == 'display-miss' else 'probe') and
                result.get('exact_rejection') == NEGATIVES[name] and
                result.get('inputs_sha256') == phase['inputs_sha256'], 'Z_SUITE_NEGATIVE_AUDIT_BINDING')
        require(result.get('artifacts_unchanged') is True and result.get('sources_unchanged') is True,
                'Z_SUITE_NEGATIVE_AUDIT_PRESERVATION')
        folder = Path(phase['folder'])
        current = {str(Path(path).relative_to(folder)): digest
                   for path, digest in artifact_files([folder]).items()}
        require(result.get('artifact_sha256') == current and result.get('artifact_files') == len(current),
                'Z_SUITE_NEGATIVE_AUDIT_ARTIFACTS')
        return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', action='store_true', help='explicitly authorize synthetic builds/runs')
    parser.add_argument('--output', type=Path, help='new tmp or ignored output directory; never reused')
    args = parser.parse_args()
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    order, names = input_names(ROOT)
    hashes = {name: sha(ROOT / name) for name in names}
    tools = {name: sha(ROOT / name) for name in (SUITE, AUDITOR, NEGATIVE_AUDITOR, REGRESSION)}
    output = new_output(args.output)
    print(f'Z_KANJI_SUITE_FOLDER={output}', flush=True)
    state = {'phase': 'capturing', 'scope': 'generated synthetic CPU/RGB, not native/FPGA acceptance',
             'driver_pid': os.getpid(), 'execute_requested': args.run,
             'collector_inputs': hashes, 'orchestration_inputs': tools, 'runs': []}
    seals = {}
    preparation = {}

    def save_state():
        save(output / 'status.json', state)

    def verify():
        for name, digest in {**hashes, **tools}.items():
            require(sha(ROOT / name) == sha(output / 'sources' / name) == digest,
                    f'Z_SUITE_INPUT_MUTATION: {name}')

    def verify_artifacts():
        require(all(sha(Path(path)) == digest for path, digest in preparation.items()),
                'Z_SUITE_PREPARATION_ARTIFACT_CHANGED')
        for name, seal in seals.items():
            require(sha(seal['manifest']) == seal['manifest_sha256'] and
                    artifact_files(seal['roots'], seal['files']) == seal['hashes'],
                    f'Z_SUITE_PHASE_ARTIFACT_CHANGED: {name}')

    def seal_phase(phase, log, record):
        directory = output / 'phase-artifacts'
        directory.mkdir(exist_ok=True)
        snapshot = directory / (phase['name'] + '.state.json')
        save(snapshot, record)
        roots = [Path(phase['folder'])] if 'folder' in phase else []
        if phase['kind'] == 'regression':
            roots.append(Path(record['audit_summary']['evidence']))
        files = [log, snapshot]
        hashes_at_seal = artifact_files(roots, files)
        manifest = directory / (phase['name'] + '.sha256.json')
        save(manifest, {'phase': phase['name'], 'files': hashes_at_seal})
        seals[phase['name']] = {'manifest': manifest, 'manifest_sha256': sha(manifest),
                               'roots': roots, 'files': files, 'hashes': hashes_at_seal}
        state['runs'][-1]['artifact_manifest'] = str(manifest)
        state['runs'][-1]['artifact_manifest_sha256'] = seals[phase['name']]['manifest_sha256']

    save_state()
    try:
        for name, digest in {**hashes, **tools}.items():
            target = output / 'sources' / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, target)
            require(sha(target) == sha(ROOT / name) == digest, f'Z_SUITE_CAPTURE_RACE: {name}')
        save(output / 'inputs.json', hashes)
        save(output / 'orchestration-inputs.json', tools)
        save(output / 'source-order.json', order)
        bound = sha(output / 'inputs.json')
        state['expected_inputs_sha256'] = bound
        plan = phases(output, bound)
        save(output / 'plan.json', plan)
        preparation = artifact_files([], [output / name for name in
                                     ('inputs.json', 'orchestration-inputs.json', 'source-order.json', 'plan.json')])
        verify()
        if not args.run:
            state['phase'] = 'prepared-not-run'
        else:
            for phase in plan:
                verify()
                verify_artifacts()
                slot = len(state['runs'])
                state['runs'].append({})
                def update(record):
                    state['runs'][slot] = dict(record)
                    state['phase'] = phase['name']
                    if record.get('state') in ('terminal', 'failed'):
                        directory = output / 'phase-artifacts'
                        directory.mkdir(exist_ok=True)
                        save(directory / (phase['name'] + '.state.json'), record)
                    save_state()
                log = output / (phase['name'] + '.log')
                child(phase, log, update)
                verify()
                verify_artifacts()
                if phase['kind'] == 'collector':
                    check_collector(phase, bound)
                else:
                    state['runs'][slot]['audit_summary'] = check_audit(phase, log)
                state['runs'][slot]['verified'] = True
                seal_phase(phase, log, state['runs'][slot])
                save_state()
            state['phase'] = 'pass'
    except BaseException as exc:
        state.update(phase='failed', error=f'{type(exc).__name__}: {exc}')
        if state['runs'] and not state['runs'][-1].get('verified'):
            state['runs'][-1]['verification_error'] = state['error']
            directory = output / 'phase-artifacts'
            directory.mkdir(exist_ok=True)
            save(directory / (state['runs'][-1]['name'] + '.state.json'), state['runs'][-1])
        raise
    finally:
        try:
            verify()
            state['sources_unchanged'] = True
        except Exception as exc:
            state.update(phase='failed', sources_unchanged=False,
                         preservation_error=f'{type(exc).__name__}: {exc}')
        try:
            verify_artifacts()
            state['artifacts_unchanged'] = True
        except Exception as exc:
            state.update(phase='failed', artifacts_unchanged=False,
                         artifact_preservation_error=f'{type(exc).__name__}: {exc}')
        try:
            # child() has returned and closed its log before any phase is
            # sealed. No children are running when this final inventory is
            # taken. Recheck after writing the excluded manifest, before PASS.
            inventory = suite_artifacts(output)
            manifest = output / 'artifact-manifest.json'
            save(manifest, {'excluded_root_files': ['status.json', 'artifact-manifest.json'],
                            'files': inventory,
                            'preparation_files': preparation,
                            'phase_manifests': {name: seal['manifest_sha256'] for name, seal in seals.items()}})
            state.update(artifact_manifest=str(manifest), artifact_manifest_sha256=sha(manifest))
            require(inventory == suite_artifacts(output), 'Z_SUITE_FINAL_ARTIFACT_CHANGED')
        except Exception as exc:
            state.update(phase='failed', artifacts_unchanged=False,
                         artifact_manifest_error=f'{type(exc).__name__}: {exc}')
        save_state()
    require(state['phase'] in ('pass', 'prepared-not-run'), 'Z_SUITE_FINAL_PRESERVATION_FAILED')
    print(json.dumps({'phase': state['phase'], 'expected_inputs_sha256': state['expected_inputs_sha256'],
                      'sources_unchanged': True, 'artifacts_unchanged': True,
                      'artifact_manifest_sha256': state['artifact_manifest_sha256'], 'folder': str(output)}))


if __name__ == '__main__':
    main()
