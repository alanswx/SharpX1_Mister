#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Freeze real hps_io upload/ACK/error-drain tests with a synthetic DDR sink.

Tests actual file framing and the source-checked sys_top ACK seam at SYS32.
No renderer, lifecycle coordinator, native font or physical timing claim.
"""
import hashlib
import json
from pathlib import Path
import re
import resource
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
FILES = (
    'verilator/tests/test_z_font_hps_upload.py',
    'verilator/tests/z_font_hps_upload_tb.sv',
    'verilator/tests/z_font_hps_upload_warnings.json',
    'rtl/x1_z_kanji_frontend.sv', 'rtl/x1_z_kanji_ddr.sv',
    'sys/hps_io.sv', 'sys/sys_top.v', 'rtl/x1_cdc_snapshot.sv',
)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    if not __debug__:
        raise SystemExit('Z_HPS_OPTIMIZED_PYTHON_REFUSED')
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    out = Path(tempfile.mkdtemp(prefix='x1-z-font-hps-'))
    print('EVIDENCE=' + str(out), flush=True)
    frozen = {n: (ROOT/n).read_bytes() for n in FILES}
    for n, data in frozen.items():
        p = out/'sources'/n
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(data)
    # Freeze the real framework seam, not an unrelated ACK approximation.
    source = frozen['sys/sys_top.v'].decode()
    fixture = frozen[FILES[1]].decode()
    ack = re.search(r'always @\(posedge clk_sys\) begin\s*if\(~\(io_wait \| vs_wait\) \| io_strobe\) begin.*?\nend', source, re.S)
    assert ack, 'framework ACK seam changed'
    body = re.sub(r'\s+', '', ack[0]).replace('posedgeclk_sys', 'posedgeclk')
    assert body in re.sub(r'\s+', '', fixture), 'test ACK differs from framework'
    assert 'wireio_strobe=~rack&io_clk;' in re.sub(r'\s+', '', source)
    assert 'assignio_strobe=~rack&io_clk;' in re.sub(r'\s+', '', fixture)
    expected = json.loads(frozen[FILES[2]])['warnings']
    report = {'status': 'running', 'scope': __doc__,
              'source_sha256': {n: sha(d) for n, d in frozen.items()},
              'tool': subprocess.check_output(['verilator', '--version'], text=True).strip(),
              'cases': []}

    def save():
        (out/'terminal.json').write_text(json.dumps(report, indent=2)+'\n')

    variants = [
        ('positive', None, None, None, None),
        ('sticky-error-wait', FILES[3], 'state!=IDLE || !wr_armed ||',
         'state!=IDLE || !wr_armed || upload_error ||', 'Z_HPS_ACK_FALL'),
        ('error-admits-later-write', FILES[3], '!upload_error && upload_count<',
         'upload_count<', 'Z_HPS_GAP_WRITE'),
        ('publishes-failed-full-image', FILES[3],
         'if(!upload_error && !abort_upload && !cold_reset) loaded<=1;',
         'if(!abort_upload && !cold_reset) loaded<=1;', 'Z_HPS_END_STATE'),
        ('host-ignores-wait', FILES[1], '~(io_wait | vs_wait)',
         "~(1'b0 | vs_wait)", 'Z_HPS_END_STATE'),
    ]
    save()
    try:
        for tag, changed, before, after, marker in variants:
            folder = out/tag
            folder.mkdir()
            selected = {n: out/'sources'/n for n in FILES}
            if changed:
                text = frozen[changed].decode()
                assert text.count(before) == 1, (tag, before)
                p = folder/Path(changed).name
                p.write_text(text.replace(before, after))
                selected[changed] = p
            obj = folder/'obj'
            inputs = [FILES[1], FILES[3], FILES[4], FILES[5], FILES[7]]
            cmd = ['verilator', '--binary', '--timing', '--assert',
                   '--top-module', 'z_font_hps_upload_tb', '--Mdir', str(obj),
                   '-j', '2', '-Wno-fatal', '-Wno-PINMISSING']
            cmd += [str(selected[n]) for n in inputs]
            case = {'name': tag, 'expected_rejection': marker, 'command': cmd,
                    'compiled_sources': {n: sha(selected[n].read_bytes()) for n in inputs}}
            report['cases'].append(case)
            save()
            log = folder/'build.log'
            with log.open('w') as f:
                result = subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT, timeout=180)
            case.update(build_exit=result.returncode, build_log_sha256=sha(log.read_bytes()))
            save()
            assert result.returncode == 0, 'compiler failure is not rejection'
            warnings = []
            for line in log.read_text().splitlines():
                m = re.match(r'%Warning-([^:]+): ([^:]+):(\d+):(\d+): (.*)', line)
                if m:
                    path = Path(m[2])
                    name = str(path.relative_to(out/'sources')) if path.is_relative_to(out/'sources') else str(path)
                    message = m[5].replace('z_font_hps_upload_tb.__Vcellinpt__hps__HPS_BUS', '<packed HPS_BUS inout>')
                    warnings.append({'kind': m[1], 'file': name, 'line': int(m[3]),
                                     'column': int(m[4]), 'message': message})
            assert warnings == expected, (tag, warnings)
            case['reviewed_warning_count'] = len(warnings)
            exe = obj/'Vz_font_hps_upload_tb'
            case['executable_sha256'] = sha(exe.read_bytes())
            log = folder/'run.log'
            with log.open('w') as f:
                result = subprocess.run([str(exe)], stdout=f, stderr=subprocess.STDOUT, timeout=120)
            text = log.read_text()
            case.update(run_exit=result.returncode, run_log_sha256=sha(log.read_bytes()))
            save()
            assert 'Z_HPS_GLOBAL_TIMEOUT' not in text, 'global timeout is not rejection'
            if marker:
                assert result.returncode != 0
                assert re.findall(r'Assertion failed[^\n]*?: (Z_HPS_\w+)', text) == [marker], text
            else:
                assert result.returncode == 0
                expected_line = ('PASS Z_HPS_UPLOAD writes=1048596 host_words=1048653 '
                                 'cycles=7690193 full=4 malformed=3 recovered=2')
                assert text.count(expected_line) == 1, text
                case['pass_line'] = expected_line
            case['verified'] = True
            save()
            print('PASS ' + tag, flush=True)
        report['status'] = 'pass'
    except BaseException as e:
        report.update(status='fail', error=repr(e))
        raise
    finally:
        report['unchanged'] = all((ROOT/n).read_bytes() == (out/'sources'/n).read_bytes() == data
                                  for n, data in frozen.items())
        if not report['unchanged']:
            report['status'] = 'fail'
        save()
        assert report['unchanged'], 'inputs changed during qualification'
    print('PASS Z_HPS_UPLOAD_FROZEN_GATE ' + str(out), flush=True)


if __name__ == '__main__':
    main()
