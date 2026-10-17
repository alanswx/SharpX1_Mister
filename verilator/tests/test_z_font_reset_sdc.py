#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Exact raw VID reset pin scope only; no native timing/physical acceptance."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PREFIX = 'emu|sharpx1|video_reset_domain.release_reset|release_pipe'


def main():
    if not __debug__:
        raise RuntimeError('scope checks require Python assertions')
    out = Path(tempfile.mkdtemp(prefix='x1-font-reset-sdc-')).resolve()
    names = ['sharpx1_turbo_z_font_reset.sdc', 'verilator/tests/test_z_font_reset_sdc.py']
    hashes = {}
    for name in names:
        path = out / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes((ROOT / name).read_bytes())
        hashes[name] = hashlib.sha256(path.read_bytes()).hexdigest()
    valid = [f'{PREFIX}[{i}]|clrn' for i in (0, 1)]
    plans = [('valid', valid, True), ('reordered', valid[::-1], True),
             ('missing', valid[:1], False), ('empty', [], False),
             ('duplicate', [valid[0]] * 2, False), ('extra', valid + valid[:1], False)]
    changes = {
        'd-pin': ('|clrn', '|d'), 'clock-pin': ('|clrn', '|clk'),
        'output-pin': ('|clrn', '|q'), 'wrong-stage': ('[0]', '[2]'),
        'wrong-owner': ('emu|', 'foreign|'),
        'wrong-machine': ('|sharpx1|', '|foreign|'),
        'cpu-release': ('video_reset_domain.release_reset', 'cpu_reset_domain.release_reset'),
        'palette-release': ('video_reset_domain.release_reset', 'local_release.video_release'),
        'replica': ('[0]', '[0]~DUPLICATE'),
    }
    for name, (old, new) in changes.items():
        plans.append((name, [valid[0].replace(old, new), valid[1]], False))
    mock = '''proc get_pins {args} {
 if {$args ne [list -compatibility_mode {*|video_reset_domain.release_reset|release_pipe*|clrn}]} {error "unexpected scope query"}
 return $::pins
}
proc get_pin_info {option node} {if {$option ne "-name"} {error "unexpected pin query"}; return $node}
proc get_collection_size {nodes} {llength $nodes}
proc foreach_in_collection {variable nodes body} {uplevel 1 [list foreach $variable $nodes $body]}
proc set_false_path {args} {
 if {$args ne [list -to $::pins]} {error "exception escaped raw input pins"}
 lappend ::exceptions $args
}
set exceptions {}
set code [catch {source sharpx1_turbo_z_font_reset.sdc} message]
puts "RESULT $code [llength $exceptions]"
if {$code} {puts "REASON $message"}
'''
    report = dict(status='running', inputs=hashes, cases=[], scope=__doc__)
    try:
        for name, pins, positive in plans:
            script = out / f'{name}.tcl'
            script.write_text('set pins {' + ' '.join('{' + p + '}' for p in pins) + '}\n' + mock)
            run = subprocess.run(['tclsh', str(script)], cwd=out, text=True,
                                 stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=10)
            (out / f'{name}.log').write_text(run.stdout)
            assert run.returncode == 0, 'mock process failure is not scope rejection'
            expected = 'RESULT 0 1' if positive else 'RESULT 1 0'
            assert expected in run.stdout, (name, run.stdout)
            if not positive:
                assert 'expected precisely the two external-font raw VID reset pins' in run.stdout
            report['cases'].append(dict(name=name, positive=positive, log=run.stdout))
        report['status'] = 'pass'
    except BaseException as error:
        report.update(status='failed', error=repr(error))
        raise
    finally:
        assert all(hashlib.sha256((ROOT / n).read_bytes()).hexdigest() == h for n, h in hashes.items())
        (out / 'terminal.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'PASS FONT_RESET_SDC cases={len(plans)} evidence={out}; synthetic scope only')


if __name__ == '__main__':
    main()
