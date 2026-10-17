#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Exercise suite preservation/deadlines with disposable synthetic child drivers.

No HDL build or machine evidence is produced. The real suite's source capture,
child ownership, seals, final inventory and failure handling are exercised.
"""
if not __debug__:
    raise SystemExit('Z_SUITE_REGRESSION_OPTIMIZED_EXECUTION_FORBIDDEN')

import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
from unittest.mock import patch

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
DRIVER = ROOT/'verilator/tests/run_z_kanji_machine_suite.py'
FILES = ('verilator/tests/test_z_kanji_machine_suite.py',
         'verilator/tests/run_z_kanji_machine_suite.py')
spec = importlib.util.spec_from_file_location('z_suite_under_test', DRIVER)
suite = importlib.util.module_from_spec(spec)
spec.loader.exec_module(suite)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run_case(base, name, expected=None, mutation='', broken_counts=False,
             child_failure=False, timeout=False, execute=True, interrupt=False):
    root = base/(name+'-source')
    root.mkdir()
    # Source capture uses the real graph parser with a tiny, separate graph.
    paths = {'rtl/machine.qip': 'set_global_assignment -name SYSTEMVERILOG_FILE rtl/mock.sv\n',
             'rtl/mock.sv': '// SYNTHETIC suite driver input\n',
             'bios/reference/fw_subcpu/verilog/X1SUB.BIN': 'synthetic controller only'}
    for relative in (suite.SUITE, suite.AUDITOR, suite.NEGATIVE_AUDITOR, suite.REGRESSION):
        paths[relative] = '// SYNTHETIC orchestration source binding\n'
    for relative, text in paths.items():
        path = root/relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
    out = base/name
    summaries = [dict(cases=2, reads=32, frames=3, pixels=768000),
                 dict(cases=15, reads=262688, frames=15, pixels=3072000)]
    for summary in summaries:
        summary.update(evidence_unchanged=True, frame_periods_checked=True)

    def plan(output, binding):
        result = []
        for index, summary in enumerate(summaries):
            evidence = output/f'child-evidence-{index}'
            code = ('from pathlib import Path\nimport json, time, sys\n'
                    f'p=Path({str(evidence)!r}); p.mkdir()\n'
                    "(p/'status.json').write_text('SYNTHETIC nested status\\n')\n")
            if index == 0:
                if broken_counts:
                    summary = dict(summary, reads=31)
                if child_failure:
                    code += 'sys.exit(7)\n'
                if timeout or interrupt:
                    code += 'time.sleep(30)\n'
            if index == 1:
                code += mutation.replace('OUTPUT', repr(str(output))).replace('SOURCE', repr(str(root))) + '\n'
            code += f'print(json.dumps({summary!r}))\n'
            result.append({'name': 'early-audit' if index == 0 else 'full-audit', 'kind': 'audit',
                           'folder': str(evidence), 'command': [sys.executable, '-B', '-c', code],
                           'timeout_seconds': 0.05 if timeout and index == 0 else 10})
        return result

    stream = io.StringIO()
    failure = None
    popen = suite.subprocess.Popen

    def interrupted_popen(*args, **kwargs):
        process = popen(*args, **kwargs)
        real_wait = process.wait
        first = True

        def wait(*args, **kwargs):
            nonlocal first
            if first:
                first = False
                raise KeyboardInterrupt('synthetic interruption of owned child')
            return real_wait(*args, **kwargs)

        process.wait = wait
        return process

    try:
        with patch.multiple(suite, ROOT=root, OWN_INPUTS=[]), patch.object(suite, 'phases', plan), \
             patch.object(sys, 'argv', ['suite', '--output', str(out), *(['--run'] if execute else [])]), \
             (patch.object(suite.subprocess, 'Popen', interrupted_popen) if interrupt
              else contextlib.nullcontext()), \
             contextlib.redirect_stdout(stream):
            suite.main()
    except (RuntimeError, TimeoutError, KeyboardInterrupt) as error:
        failure = f'{type(error).__name__}: {error}'
    (base/(name+'.log')).write_text(stream.getvalue() + (failure or '') + '\n')
    state = json.loads((out/'status.json').read_text())
    if expected:
        assert failure and expected in failure, (name, failure, expected)
        assert state['phase'] == 'failed', (name, state)
        if expected == 'Z_SUITE_INPUT_MUTATION':
            assert state['sources_unchanged'] is False
        elif expected == 'Z_SUITE_PHASE_ARTIFACT_CHANGED':
            assert state['sources_unchanged'] is True and state['artifacts_unchanged'] is False
        else:
            assert state['sources_unchanged'] is True and state['artifacts_unchanged'] is True
        if timeout or interrupt:
            child = state['runs'][0]
            assert child['state'] == 'failed' and child['returncode'] is not None
            assert child['returncode'] != 0 and child['elapsed_seconds'] < 10
        assert stream.getvalue().count('Z_SUITE_CHILD ') <= 2
    else:
        assert failure is None, (name, failure)
        assert state['phase'] == ('pass' if execute else 'prepared-not-run')
        assert state['sources_unchanged'] is True and state['artifacts_unchanged'] is True
        manifest = out/'artifact-manifest.json'
        assert sha(manifest) == state['artifact_manifest_sha256']
        listing = json.loads(manifest.read_text())
        expected_listing = {str(path.relative_to(out)): sha(path) for path in out.rglob('*')
                            if path.is_file() and path.name not in ('artifact-manifest.json',)
                            and path != out/'status.json'}
        assert listing['files'] == expected_listing
        if execute:
            assert 'child-evidence-0/status.json' in listing['files']
            assert 'phase-artifacts/early-audit.state.json' in listing['files']
            assert all(record['verified'] for record in state['runs'])
        else:
            assert not state['runs'] and not (out/'early-audit.log').exists()
    print(f'PASS Z_SUITE_DRIVER {name}', flush=True)
    return {'name': name, 'expected_rejection': expected, 'status': state['phase']}


def main():
    frozen = {name: sha(ROOT/name) for name in FILES}
    base = Path(tempfile.mkdtemp(prefix='x1-z-kanji-suite-driver-')).resolve()
    print(f'EVIDENCE={base}', flush=True)
    results = []
    try:
        results.append(run_case(base, 'positive'))
        results.append(run_case(base, 'prepared', execute=False))
        for name, mutation in (
            ('original-source', "(Path(SOURCE)/'rtl/mock.sv').write_text('changed')"),
            ('frozen-source', "(Path(OUTPUT)/'sources/rtl/mock.sv').write_text('changed')"),
            ('orchestration-source', f"(Path(SOURCE)/{suite.AUDITOR!r}).write_text('changed')"),
        ):
            results.append(run_case(base, name, 'Z_SUITE_INPUT_MUTATION', mutation))
        for name, mutation in (
            ('earlier-log', "(Path(OUTPUT)/'early-audit.log').write_text('changed')"),
            ('phase-state', "(Path(OUTPUT)/'phase-artifacts/early-audit.state.json').write_text('{}')"),
            ('phase-manifest', "(Path(OUTPUT)/'phase-artifacts/early-audit.sha256.json').write_text('{}')"),
            ('nested-status', "(Path(OUTPUT)/'child-evidence-0/status.json').write_text('changed')"),
            ('nested-roster', "(Path(OUTPUT)/'child-evidence-0/added').write_text('changed')"),
        ):
            results.append(run_case(base, name, 'Z_SUITE_PHASE_ARTIFACT_CHANGED', mutation))
        results.append(run_case(base, 'wrong-counts', 'Z_SUITE_AUDIT_COUNTS', broken_counts=True))
        results.append(run_case(base, 'child-failure', 'Z_SUITE_CHILD_FAILED', child_failure=True))
        results.append(run_case(base, 'deadline', 'Z_SUITE_HARD_DEADLINE', timeout=True))
        results.append(run_case(base, 'interruption', 'KeyboardInterrupt', interrupt=True))
        result = {'phase': 'pass', 'scope': __doc__, 'cases': results, 'source_sha256': frozen}
    except BaseException as error:
        result = {'phase': 'failed', 'cases': results, 'error': repr(error), 'source_sha256': frozen}
        raise
    finally:
        unchanged = frozen == {name: sha(ROOT/name) for name in FILES}
        result['sources_unchanged'] = unchanged
        if not unchanged:
            result['phase'] = 'failed'
        (base/'terminal.json').write_text(json.dumps(result, indent=2)+'\n')
        assert unchanged
    print(f'PASS Z_SUITE_DRIVER cases={len(results)} synthetic only', flush=True)


if __name__ == '__main__':
    main()
