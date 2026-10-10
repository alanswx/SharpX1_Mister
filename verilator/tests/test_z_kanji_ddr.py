#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Freeze/run the original standalone full-font DDR backend and exact mutants.

Synthetic Avalon responder only. No manifest, machine, native, fit or hardware
claim. All generated builds and mutants live under a new temporary directory.
"""
if not __debug__:
    raise SystemExit('Z_DDR_PYTHON_OPTIMIZATION_REFUSED: assertions must be enabled')

import hashlib
import json
from pathlib import Path
import resource
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
FILES = ('rtl/x1_z_kanji_ddr.sv', 'verilator/tests/x1_z_kanji_ddr_tb.sv',
         'verilator/tests/test_z_kanji_ddr.py')


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    out = Path(tempfile.mkdtemp(prefix='x1-z-kanji-ddr-')).resolve()
    frozen = {p: (ROOT/p).read_bytes() for p in FILES}
    print(f'EVIDENCE={out}', flush=True)
    for name, data in frozen.items():
        target = out/'sources'/name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    report = {'scope': __doc__, 'source_sha256': {p: sha(d) for p, d in frozen.items()},
              'tool': subprocess.check_output(['verilator', '--version'], text=True).strip(),
              'cases': [], 'status': 'running'}

    def save():
        (out/'terminal.json').write_text(json.dumps(report, indent=2)+'\n')

    def qualify(tag, source, marker=None, half_ps=15625, base=0x06123400):
        build = out/('obj-'+tag)
        cmd = ['verilator', '--binary', '--timing', '--assert', '-Wall',
               '--top-module', 'x1_z_kanji_ddr_tb', '--Mdir', str(build), '-j', '2',
               f'-GHALF_PERIOD_PS={half_ps}',
               f"-GBASE=29'h{base:08x}",
               str(source), str(out/'sources'/FILES[1])]
        case = {'name': tag, 'command': cmd, 'source_sha256': sha(source.read_bytes()),
                'half_period_ps': half_ps, 'clock_hz': 1000000000000 // (2 * half_ps),
                'base_word_address': base}
        report['cases'].append(case)
        save()
        log = out/(tag+'.build.log')
        with log.open('w') as stream:
            result = subprocess.run(cmd, stdout=stream, stderr=subprocess.STDOUT, timeout=180)
        case['build_exit'] = result.returncode
        case['warnings'] = [s for s in log.read_text().splitlines() if '%Warning' in s]
        save()
        assert result.returncode == 0, f'{tag}: compiler failure, not a matched negative; {log}'
        assert not case['warnings'], case['warnings']
        exe = build/'Vx1_z_kanji_ddr_tb'
        case['executable_sha256'] = sha(exe.read_bytes())
        runlog = out/(tag+'.run.log')
        with runlog.open('w') as stream:
            result = subprocess.run([str(exe)], stdout=stream, stderr=subprocess.STDOUT,
                                    timeout=180, cwd=out)
        case['run_exit'] = result.returncode
        text = runlog.read_text()
        case['run_log_sha256'] = sha(runlog.read_bytes())
        case['expected_failure'] = marker
        save()
        if marker:
            assert result.returncode != 0 and marker in text, f'{tag}: wrong failure: {text}'
            assert 'PASS Z_DDR' not in text and 'Z_DDR_TEST_TIMEOUT' not in text
        else:
            assert result.returncode == 0 and text.count('PASS Z_DDR full_writes=262144 full_reads=262144 lanes=8 reset_cases=11') == 1, text
            assert f'half_ps={half_ps}' in text, 'Wrong physical clock profile'
            assert f'base={base:08x}' in text, 'Wrong base address profile'
            assert text.count('PASS Z_DDR_FOCUSED queued_second=1 always_ready=3 cancelled_new_write=1 reset_held_valid=1') == 1, text
        print(f'PASS {tag} exit={result.returncode} cause={marker or "full-font-positive"}', flush=True)

    try:
        source = out/'sources'/FILES[0]
        # Run the frozen checker with optimization: must refuse before it can
        # allocate evidence or build anything, not silently disable asserts.
        refusal = subprocess.run([sys.executable, '-O', '-B', str(out/'sources'/FILES[2])],
                                 stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                 text=True, timeout=10)
        (out/'optimized-python-refusal.log').write_text(refusal.stdout)
        assert refusal.returncode != 0 and 'Z_DDR_PYTHON_OPTIMIZATION_REFUSED' in refusal.stdout
        assert 'EVIDENCE=' not in refusal.stdout
        report['optimized_python_refusal'] = {'exit': refusal.returncode, 'output': refusal.stdout}
        save()
        qualify('positive-32mhz', source, half_ps=15625)
        qualify('positive-100mhz', source, half_ps=5000)
        qualify('positive-max-base-32mhz', source, base=0x1fff8000)
        qualify('negative-overflow-base', source, marker='Z_DDR_BASE_OVERFLOW', base=0x1fff8001)
        original = source.read_text()
        mutations = (
            ('wrong-read-lane', '{address_latched[2:0],3\'b000} +: 8',
             '{(address_latched[2:0] ^ 3\'d1),3\'b000} +: 8', 'Z_DDR_BYTE_RESULT', 1),
            ('wrong-write-lane', "(8'd1 << address_latched[2:0])", "(8'd1 << (address_latched[2:0] ^ 3'd1))", 'Z_DDR_BYTE_ENABLE', 1),
            ('reset-loses-cancel', 'if(reset) cancelled<=1;', 'if(reset) cancelled<=0;', 'Z_DDR_STALE_AFTER_RESET', 2),
            ('reset-withdraws-command', 'state==COMMAND && !write_latched;',
             'state==COMMAND && !write_latched && !reset;', 'Z_DDR_PAYLOAD_NOT_HELD', 1),
            ('zero-edge-response-lost', 'else if(DDRAM_DOUT_READY) begin',
             "else if(DDRAM_DOUT_READY && 1'b0) begin", 'Z_DDR_RESPONSE_DEADLINE', 1),
            ('consumer-stopped-response-lost', 'if(reset || response_ready) state<=IDLE;',
             'if(reset || response_ready || !response_ready) state<=IDLE;', 'Z_DDR_RESPONSE_NOT_HELD', 1),
            ('replayed-write-command', 'state==COMMAND && write_latched;',
             '(state==COMMAND || state==RESPONSE) && write_latched;', 'Z_DDR_COMMAND_REPLAY', 1),
            ('ready-during-readwait', 'state==IDLE && !reset;',
             '(state==IDLE || state==READ_WAIT) && !reset;', 'Z_DDR_REQUEST_READY_WHILE_OWNED', 1),
            ('already-ready-drops-response', '(reset || cancelled) ? IDLE : RESPONSE;',
             '(reset || cancelled || response_ready) ? IDLE : RESPONSE;', 'Z_DDR_ALREADY_READY_COMPLETION', 3),
        )
        for tag, old, new, marker, occurrences in mutations:
            assert original.count(old) == occurrences, (tag, original.count(old))
            mutated = out/'mutants'/tag/source.name
            mutated.parent.mkdir(parents=True)
            mutated.write_text(original.replace(old, new))
            qualify(tag, mutated, marker)
        report['status'] = 'pass'
    except Exception as error:
        report['status'] = 'fail'
        report['error'] = str(error)
        raise
    finally:
        after = {p: sha((ROOT/p).read_bytes()) for p in FILES}
        copies = {p: sha((out/'sources'/p).read_bytes()) for p in FILES}
        report['after_source_sha256'] = after
        report['original_and_frozen_unchanged'] = after == copies == report['source_sha256']
        if not report['original_and_frozen_unchanged']:
            report['status'] = 'fail'
        save()
        assert report['original_and_frozen_unchanged'], 'Sources changed during run'
    print('PASS Z_DDR full font at 32/100MHz/max-base, focused public lifecycle, nine exact mutations, overflow rejection and optimized-Python refusal; no integration/native claim', flush=True)


if __name__ == '__main__':
    main()
