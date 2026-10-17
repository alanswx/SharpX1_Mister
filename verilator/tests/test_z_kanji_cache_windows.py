#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Freeze real cache windows at three ratios and reject three runtime mutants."""
import hashlib
import json
from pathlib import Path
import re
import resource
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    assert __debug__
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    out = Path(tempfile.mkdtemp(prefix='x1-cache-windows-')).resolve()
    print('EVIDENCE=' + str(out), flush=True)
    files = ['rtl/x1_z_kanji_cache.sv', 'verilator/tests/x1_z_kanji_cache_windows_tb.sv',
             'verilator/tests/test_z_kanji_cache_windows.py']
    inputs = {}
    for name in files:
        p = out / 'sources' / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes((ROOT / name).read_bytes())
        inputs[name] = sha(p)
    report = dict(status='running', source_sha256=inputs, cases=[],
                  scope='Standalone synthetic cache lease windows/payload; no physical CDC, machine or hardware qualification')

    def save():
        (out / 'terminal.json').write_text(json.dumps(report, indent=2) + '\n')

    source = out / 'sources' / files[0]
    fixture = out / 'sources' / files[1]
    plans = [('sys32-x3', 15625, 11640, source, None),
             ('sys32-slowvid', 15625, 20000, source, None),
             ('sys100-vid50', 5000, 10000, source, None)]
    text = source.read_text()
    for name, old, new, marker in [
        ('early-commit', 'wire commit_packet=req_sync!=request_seen',
         'wire commit_packet=req_meta!=request_seen', 'Z_CACHE_PUBLICATION_WINDOW'),
        ('early-release', 'PUBLISH: if(ack_sync==request_toggle)',
         'PUBLISH: if(ack_meta==request_toggle)', 'Z_CACHE_ACK_WINDOW'),
        ('unheld-payload', 'PUBLISH: if(ack_sync==request_toggle)',
         'PUBLISH: begin held_descriptor<=update_descriptor; if(ack_sync==request_toggle)', 'Z_CACHE_HELD_BUNDLE')]:
        assert text.count(old) == 1
        mutated = text.replace(old, new)
        if name == 'unheld-payload':
            assert mutated.count('            DONE: begin') == 1
            mutated = mutated.replace('            DONE: begin', '            end\n            DONE: begin')
        path = out / 'mutants' / name / source.name
        path.parent.mkdir(parents=True)
        path.write_text(mutated)
        plans.append((name, 15625, 11640, path, marker))
    save()
    try:
        for name, sys_half, vid_half, rtl, marker in plans:
            obj = out / ('obj-' + name)
            cmd = ['verilator', '--binary', '--timing', '--assert', '-Wall',
                   '--top-module', 'x1_z_kanji_cache_windows_tb', '--Mdir', str(obj), '-j', '2',
                   f'-GSYS_HALF_PS={sys_half}', f'-GVID_HALF_PS={vid_half}', str(rtl), str(fixture)]
            case = dict(name=name, command=cmd, rtl_sha256=sha(rtl), expected_rejection=marker)
            report['cases'].append(case)
            save()
            with (out / (name + '.build.log')).open('w') as log:
                build = subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT, timeout=180)
            warnings = re.findall(r'^%Warning[^\n]*', (out / (name + '.build.log')).read_text(), re.M)
            case.update(build_exit=build.returncode, warnings=warnings)
            save()
            assert build.returncode == 0 and not warnings, 'compile failure is not a rejecting control'
            exe = obj / 'Vx1_z_kanji_cache_windows_tb'
            case['executable_sha256'] = sha(exe)
            with (out / (name + '.run.log')).open('w') as log:
                run = subprocess.run([str(exe)], stdout=log, stderr=subprocess.STDOUT, timeout=60, cwd=out)
            log = (out / (name + '.run.log')).read_text()
            case.update(run_exit=run.returncode, run_log_sha256=sha(out / (name + '.run.log')))
            assert 'Z_CACHE_WINDOW_TIMEOUT' not in log
            if marker:
                assert run.returncode != 0 and re.findall(r'Assertion failed[^\n]*?: (Z_CACHE_\w+)', log) == [marker]
                assert 'PASS Z_CACHE_WINDOWS' not in log
            else:
                expected = f'PASS Z_CACHE_WINDOWS publications=19 commits=19 acks=19 releases=19 completions=19 sys_half={sys_half} vid_half={vid_half}'
                assert run.returncode == 0 and log.count(expected) == 1
            case['verified'] = True
            save()
            print('PASS_CACHE_WINDOWS', name, marker or 'positive', flush=True)
        report['status'] = 'pass'
    except BaseException as error:
        report.update(status='failed', error=repr(error))
        raise
    finally:
        assert all(sha(ROOT / name) == h == sha(out / 'sources' / name) for name, h in inputs.items())
        save()


if __name__ == '__main__':
    main()
