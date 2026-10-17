#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Freeze/qualify the standalone public CPU/ordered-upload frontend.

Synthetic synchronous DDR responder only, outside the machine manifest. No
display cache, CDC, native, FPGA allocation or physical-persistence claim.
Default: all 32/100-MHz lifecycle profiles and exact rejecting RTL mutants.
"""
if not __debug__:
    raise SystemExit('Z_FRONTEND_PYTHON_OPTIMIZATION_REFUSED')

import argparse
import hashlib
import json
from pathlib import Path
import re
import resource
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
FILES = ('rtl/x1_z_kanji_ddr.sv', 'rtl/x1_z_kanji_frontend.sv',
         'verilator/tests/x1_z_kanji_frontend_tb.sv',
         'verilator/tests/test_z_kanji_frontend.py')
BACKEND = '638861b6a6b06c0307e8bc045d239c766079b1875d6b8c3ab21fe4ea6248558d'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--review-smoke', action='store_true', help='one profile only')
    parser.add_argument('--reset-case', type=int, choices=range(8), default=0)
    parser.add_argument('--preempt-phase', type=int, choices=range(4), default=0)
    args = parser.parse_args()
    if not args.review_smoke and (args.reset_case or args.preempt_phase):
        parser.error('Individual selection requires --review-smoke')
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    frozen = {name: (ROOT/name).read_bytes() for name in FILES}
    assert sha(frozen[FILES[0]]) == BACKEND, 'Backend changed'
    out = Path(tempfile.mkdtemp(prefix='x1-z-kanji-frontend-')).resolve()
    print(f'EVIDENCE={out}', flush=True)
    report = {'scope': __doc__, 'status': 'running', 'review_smoke': args.review_smoke,
              'tool': subprocess.check_output(['verilator', '--version'], text=True).strip(),
              'source_sha256': {name: sha(data) for name, data in frozen.items()},
              'builds': [], 'cases': []}
    for name, data in frozen.items():
        path = out/'sources'/name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    def save():
        (out/'terminal.json').write_text(json.dumps(report, indent=2)+'\n')

    def build(tag, source, half_ps):
        directory = out/('obj-'+tag)
        command = ['verilator', '--binary', '--timing', '--assert', '-Wall',
                   '--top-module', 'x1_z_kanji_frontend_tb', '--Mdir', str(directory),
                   '-j', '2', f'-GHALF_PERIOD_PS={half_ps}',
                   str(out/'sources'/FILES[0]), str(source), str(out/'sources'/FILES[2])]
        record = {'name': tag, 'command': command, 'source_sha256': sha(source.read_bytes())}
        report['builds'].append(record)
        save()
        log = out/(tag+'.build.log')
        with log.open('w') as stream:
            result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT, timeout=180)
        record['exit'] = result.returncode
        record['warnings'] = [line for line in log.read_text().splitlines() if '%Warning' in line]
        save()
        assert result.returncode == 0, f'{tag}: compiler failure, not behavioral rejection; {log}'
        assert not record['warnings'], record['warnings']
        exe = directory/'Vx1_z_kanji_frontend_tb'
        record['executable_sha256'] = sha(exe.read_bytes())
        save()
        return exe

    def qualify(tag, exe, half_ps=15625, reset=0, preempt=0, marker=None, hold_cancel=0):
        command = [str(exe), f'+RESET_CASE={reset}', f'+PREEMPT_PHASE={preempt}',
                   f'+HOLD_CANCEL={hold_cancel}']
        record = {'name': tag, 'command': command, 'half_period_ps': half_ps,
                  'clock_hz': 1000000000000 // (2 * half_ps), 'reset_case': reset,
                  'preempt_phase': preempt, 'hold_cancel': hold_cancel, 'expected_rejection': marker,
                  'executable_sha256': sha(exe.read_bytes())}
        report['cases'].append(record)
        save()
        log = out/(tag+'.run.log')
        with log.open('w') as stream:
            result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT,
                                    timeout=180, cwd=out)
        record['exit'] = result.returncode
        record['run_log_sha256'] = sha(log.read_bytes())
        text = log.read_text()
        save()
        assert 'Z_FRONTEND_TEST_TIMEOUT' not in text, f'{tag}: timeout is not acceptance'
        if marker:
            failures = re.findall(r'Assertion failed[^\n]*?: (Z_FRONTEND_\w+)', text)
            assert result.returncode != 0 and failures == [marker], f'{tag}: wrong rejection: {text}'
            assert 'PASS Z_FRONTEND' not in text
        else:
            lines = re.findall(r'^PASS Z_FRONTEND (.+)$', text, re.M)
            assert result.returncode == 0 and len(lines) == 1, f'{tag}: {text}'
            counts = {key: int(value) for key, value in re.findall(r'(\w+)=(\d+)', lines[0])}
            expected = {'reset': reset, 'half_ps': half_ps, 'preempt': preempt, 'hold_cancel': hold_cancel,
                        'full_uploads': 2, 'full_reads': 262144 if reset >= 4 else 524288,
                        'cases': 5 if reset >= 4 else (6 if reset else 16),
                        'writes': 524288 if reset else 524291,
                        'accepted': 524288 if reset else 524295,
                        'reads': (262144 if reset >= 4 else 524289) if reset else 524292,
                        'consumed': (262144 if reset >= 4 else 524288) if reset else 524290}
            assert counts.keys() == (expected.keys() | {'cycles'}), f'{tag}: unexpected fields: {counts}'
            assert {key: counts[key] for key in expected} == expected, f'{tag}: {counts} != {expected}'
            assert 0 < counts['cycles'] < 30000000, counts
            record['counts'] = counts
            record['simulation_seconds'] = counts['cycles'] * 2 * half_ps / 1e12
        record['verified'] = True
        save()
        print(f'PASS {tag} exit={result.returncode} cause={marker or "full-font-positive"}', flush=True)

    save()
    try:
        refusal = subprocess.run([sys.executable, '-O', '-B', str(out/'sources'/FILES[3])],
                                 stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=10)
        (out/'optimized-python-refusal.log').write_text(refusal.stdout)
        assert refusal.returncode != 0 and 'Z_FRONTEND_PYTHON_OPTIMIZATION_REFUSED' in refusal.stdout
        assert 'EVIDENCE=' not in refusal.stdout
        report['optimized_python_refusal'] = {'exit': refusal.returncode, 'output': refusal.stdout}
        source = out/'sources'/FILES[1]
        if args.review_smoke:
            exe = build('review-32mhz', source, 15625)
            qualify('review', exe, reset=args.reset_case, preempt=args.preempt_phase)
            report['status'] = 'review-smoke-pass'
        else:
            for half_ps, clock in ((15625, '32mhz'), (5000, '100mhz')):
                exe = build('positive-'+clock, source, half_ps)
                for preempt in range(4):
                    qualify(f'{clock}-preempt-{preempt}', exe, half_ps=half_ps, preempt=preempt)
                qualify(f'{clock}-held-consumer-reset', exe, half_ps=half_ps, hold_cancel=1)
                for reset in range(1, 8):
                    qualify(f'{clock}-reset-{reset}', exe, half_ps=half_ps, reset=reset)
            original = source.read_text()
            mutations = (
                ('unloaded-read', 'cpu_armed && loaded && !upload_active',
                 'cpu_armed && (loaded || !loaded) && !upload_active', 'Z_FRONTEND_UNLOADED', 0),
                ('start-without-wait', '(!upload_active || state!=IDLE',
                 '((!upload_active && !start_upload) || state!=IDLE', 'Z_FRONTEND_START_WAIT', 0),
                ('terminal-count-blocks-end', '!upload_permitted || cold_reset);',
                 "!upload_permitted || cold_reset || upload_count==19'd262144);",
                 'Z_FRONTEND_END_COMMAND_WAIT', 0),
                ('wrong-cpu-address', 'address_latched<=cpu_address;',
                 "address_latched<=cpu_address ^ 18'd1;", 'Z_FRONTEND_CPU_BYTE', 0),
                ('wrong-cpu-high-address', 'address_latched<=cpu_address;',
                 "address_latched<=cpu_address ^ 18'h08000;", 'Z_FRONTEND_READ_METADATA', 0),
                ('wrong-upload-data', 'data_latched<=ioctl_data;',
                 "data_latched<=ioctl_data ^ 8'd1;", 'Z_FRONTEND_WRITE_METADATA', 0),
                ('early-publication', 'loaded<=0; upload_active<=1;',
                 'loaded<=1; upload_active<=1;', 'Z_FRONTEND_EMPTY_UPLOAD', 0),
                ('cancelled-result-leaks', 'state==RETURN)) discard<=1;',
                 'state==RETURN)) discard<=0;', 'Z_FRONTEND_COLD_CPU_DRAIN', 2),
                ('stale-ack', '(cpu_response_ack && ack_armed)',
                 '(cpu_response_ack && (ack_armed || !ack_armed))', 'Z_FRONTEND_STALE_ACK_OWNER', 0),
                ('cpu-level-replay', 'state<=IDLE;\n                ack_armed<=0;',
                 'state<=IDLE;\n                cpu_armed<=1;\n                ack_armed<=0;',
                 'Z_FRONTEND_READ_REPLAY', 0),
                ('held-wr-replay', 'state!=IDLE || !wr_armed ||',
                 'state!=IDLE || (!wr_armed && wr_armed) ||', 'Z_FRONTEND_STIMULUS_ORDER', 0),
                ('overflow-truncates', "ioctl_address!={6'd0,upload_count}",
                 "ioctl_address!={6'd0,upload_count} && ioctl_address<25'd262144",
                 'Z_FRONTEND_OVERFLOW_REJECTION', 0),
                ('permission-error-lost', 'if(abort_upload) upload_error<=1;',
                 'if(abort_upload && upload_permitted) upload_error<=1;', 'Z_FRONTEND_LAST_ACK_CANCEL', 5),
                ('excess-byte-ignored', 'if(upload_active && upload_count==',
                 "if(1'b0 && upload_active && upload_count==", 'Z_FRONTEND_EXCESS_REJECTION', 7),
                ('backend-reset-loses-owner', ".clk(clk), .reset(1'b0),", '.clk(clk), .reset(cold_reset),',
                 'Z_FRONTEND_UPLOAD_READY', 2),
            )
            for tag, old, new, marker, reset in mutations:
                assert original.count(old) == 1, (tag, original.count(old))
                mutated = out/'mutants'/tag/source.name
                mutated.parent.mkdir(parents=True)
                mutated.write_text(original.replace(old, new))
                exe = build(tag, mutated, 15625)
                qualify(tag, exe, reset=reset, marker=marker)
            report['status'] = 'pass'
    except BaseException as error:
        report.update(status='fail', error=f'{type(error).__name__}: {error}')
        raise
    finally:
        after = {name: sha((ROOT/name).read_bytes()) for name in FILES}
        copies = {name: sha((out/'sources'/name).read_bytes()) for name in FILES}
        report['after_source_sha256'] = after
        report['unchanged'] = after == copies == report['source_sha256']
        if not report['unchanged']:
            report['status'] = 'fail'
        save()
        assert report['unchanged'], 'Original or frozen source changed during qualification'
    print(f"PASS Z_FRONTEND {report['status']} profiles={len(report['cases'])}; standalone synthetic only", flush=True)


if __name__ == '__main__':
    main()
