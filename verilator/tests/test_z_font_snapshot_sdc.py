#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Stage/scope checks for the font loader; not native STA or physical evidence."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PREFIX = 'emu:emu|hps_io:hps_io|video_calc:video_calc|x1_cdc_snapshot:coherent_measurements.dimensions_to_sys|'


def main():
    assert __debug__
    out = Path(tempfile.mkdtemp(prefix='x1-font-snapshot-sdc-')).resolve()
    files = ['sharpx1_turbo_z_font.sdc', 'sharpx1_turbo_z_video.sdc',
             'verilator/tests/test_z_font_snapshot_sdc.py']
    inputs = {}
    for name in files:
        p = out / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes((ROOT / name).read_bytes())
        inputs[name] = hashlib.sha256(p.read_bytes()).hexdigest()
    script = '''proc get_registers {pattern} {
 if {[string match {*held_data*} $pattern]} {return $::sources}
 if {[string match {*destination_data*} $pattern]} {return $::targets}
 error "unexpected register query"
}
proc get_collection_size {collection} {llength $collection}
proc get_register_info {option node} {return $node}
proc foreach_in_collection {variable collection body} {uplevel 1 [list foreach $variable $collection $body]}
proc set_max_delay {args} {lappend ::bounds [list max $args]}
proc set_min_delay {args} {lappend ::bounds [list min $args]}
set bounds {}
set code [catch {source sharpx1_turbo_z_font.sdc} reason]
puts "RESULT $code [llength $bounds]"
foreach bound $bounds {puts "BOUND [lindex $bound 0] [llength [lindex $bound 1 1]] [llength [lindex $bound 1 3]] [lindex $bound 1 4]"}
if {$code} {puts "REASON $reason"}
'''
    plans = []
    for tool in ('quartus_map', 'quartus_fit', 'quartus_sta', None):
        plans.append((f'{tool}-72', tool, 72, None, True))
        plans.append((f'{tool}-74', tool, 74, None, tool == 'quartus_map'))
    plans += [(f'early-{kind}', 'quartus_map', 74, kind, False)
              for kind in ('missing-source', 'missing-target', 'duplicate-source', 'duplicate-target',
                           'wrong-source-owner', 'wrong-target-owner', 'extra-source-bit', 'extra-target-bit')]
    report = dict(status='running', source_sha256=inputs, cases=[], scope=__doc__)
    try:
        for name, tool, count, kind, positive in plans:
            first = 0 if count == 74 else 2
            sources = [f'{PREFIX}held_data[{i}]' for i in range(first, 74)]
            targets = [f'{PREFIX}destination_data[{i}]' for i in range(first, 74)]
            if kind:
                nodes = targets if 'target' in kind else sources
                if kind.startswith('missing'):
                    nodes.pop(8)
                elif kind.startswith('duplicate'):
                    nodes[8] = nodes[9]
                elif kind.startswith('wrong'):
                    nodes[8] = nodes[8].replace('emu:emu|', 'foreign:foreign|')
                else:
                    nodes[-1] = nodes[-1].replace('[73]', '[74]')
            setup = '' if tool is None else f'set ::quartus(nameofexecutable) {{{tool}}}\n'
            setup += 'set sources {' + ' '.join('{' + s + '}' for s in sources) + '}\n'
            setup += 'set targets {' + ' '.join('{' + s + '}' for s in targets) + '}\n'
            path = out / (name + '.tcl')
            path.write_text(setup + script)
            run = subprocess.run(['tclsh', str(path)], cwd=out, text=True, stdout=subprocess.PIPE,
                                 stderr=subprocess.STDOUT, timeout=10)
            (out / (name + '.log')).write_text(run.stdout)
            assert run.returncode == 0, 'mock process failure is not a scope rejection'
            if positive:
                assert 'RESULT 0 2' in run.stdout
                assert f'BOUND max {count} {count} 31.25' in run.stdout
                assert f'BOUND min {count} {count} 0' in run.stdout
            else:
                assert 'RESULT 1 0' in run.stdout and 'REASON ' in run.stdout
            report['cases'].append(dict(name=name, positive=positive, log=run.stdout))
        report['status'] = 'pass'
    except BaseException as error:
        report.update(status='failed', error=repr(error))
        raise
    finally:
        assert all(hashlib.sha256((ROOT / n).read_bytes()).hexdigest() == h for n, h in inputs.items())
        (out / 'terminal.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'PASS FONT_SNAPSHOT_SDC cases={len(plans)} evidence={out}; synthetic scope only')


if __name__ == '__main__':
    main()
