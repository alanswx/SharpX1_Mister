#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Audit exact snapshot bits/physical delays; retain unrelated timing failures."""
import argparse
import hashlib
import json
from pathlib import Path
import re

from audit_vsync_sys_reports import rows, SYS

VID = 'emu|turbo_video_pll|oscillator|general[0].gpll~PLL_OUTPUT_COUNTER|divclk'
PREFIX = 'emu:emu|hps_io:hps_io|video_calc:video_calc|x1_cdc_snapshot:coherent_measurements.dimensions_to_sys|'
CORNERS = [(model, t) for model in ('slow', 'fast') for t in (-40, 0, 85, 100)]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def summary(path, check):
    text = path.read_text()
    found = re.findall(rf'Report Timing: Found (\d+) {check} paths \((\d+) violated\)\.\s*Worst case slack is (-?[\d.]+)', text)
    assert len(found) == 1, ('missing/duplicate timing summary', path)
    count, violations, slack = found[0]
    parsed = rows(path)
    assert int(count) == len(parsed), ('incomplete summary table', path)
    assert int(violations) == sum(float(row[0]) < 0 for row in parsed)
    assert float(slack) == min(float(row[0]) for row in parsed)
    return parsed


def payload(path, check, positive):
    parsed = summary(path, check)
    expected = {(f'{PREFIX}held_data[{bit}]', f'{PREFIX}destination_data[{bit}]') for bit in range(2, 74)}
    assert len(parsed) == 72 and {(r[1], r[2]) for r in parsed} == expected, ('snapshot bit omission/alias', path)
    for row in parsed:
        assert row[3:5] == [VID, SYS], ('wrong snapshot clock domains', path)
        assert 0 <= float(row[7]) < 31.25, ('physical data delay exceeds stricter bound', path)
        if positive:
            assert float(row[0]) >= 0, ('selected snapshot timing violation', path)
    return dict(paths=72, minimum_slack_ns=min(float(row[0]) for row in parsed),
                maximum_data_delay_ns=max(float(row[7]) for row in parsed))


def main():
    assert __debug__
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--reports', type=Path, required=True)
    p.add_argument('--native-log', type=Path, required=True)
    p.add_argument('--reporter', type=Path, required=True)
    p.add_argument('--candidate', type=Path, required=True)
    p.add_argument('--integrated', action='store_true')
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    directory = args.reports.resolve()
    log = args.native_log.read_text()
    assert log.count('TimeQuest Timing Analyzer was successful. 0 errors, 0 warnings') == 1
    assert not re.search(r'^\s*(?:Error|Warning|Critical Warning)\b', log, re.M)
    assert log.count('FONT SNAPSHOT PROBE COMPLETE: selected bus remains timed; other violations remain open') == 1
    integrated_marker = 'FONT SNAPSHOT MODE integrated: original assigned SDC only, no added exceptions'
    assert log.count(integrated_marker) == int(args.integrated), 'wrong native timing mode'
    assert re.findall(r'^FONT SNAPSHOT CORNER (slow|fast) (-?\d+) 1100$', log, re.M) == [(m, str(t)) for m, t in CORNERS]
    clocks = {}
    for line in (directory / 'clocks.rpt').read_text().splitlines():
        fields = [f.strip() for f in line.split(';')]
        if len(fields) > 4 and fields[1] in (SYS, VID):
            assert fields[1] not in clocks
            clocks[fields[1]] = float(fields[3])
    assert clocks == {SYS: 31.25, VID: 23.28}, 'bound requires exact fitted SYS32/X3 clocks'
    inventory = (directory / 'inventory.txt').read_text().splitlines()
    expected_inventory = {'source': {f'{PREFIX}held_data[{i}]' for i in range(2, 74)},
                          'target': {f'{PREFIX}destination_data[{i}]' for i in range(2, 74)}}
    for label, offset in [('source', 0), ('target', 73)]:
        assert inventory[offset] == label + ' 72'
        assert len(inventory[offset + 1:offset + 73]) == 72
        assert {s.strip() for s in inventory[offset + 1:offset + 73]} == expected_inventory[label]
    assert len(inventory) == 146
    result = dict(status='running', integrated=args.integrated, reports=str(directory),
                  scope='Exact selected payload timing on one fitted database; not global timing, placement/MTBF or hardware acceptance',
                  clocks_ns=clocks, before={}, corners=[], files={})
    for check in ('setup', 'hold'):
        result['before'][check] = payload(directory / f'before_{check}.rpt', check, args.integrated)
        if not args.integrated:
            assert result['before'][check]['minimum_slack_ns'] < 0, 'missing original failing witness'
    selected = []
    for model, temp in CORNERS:
        record = dict(model=model, temperature_c=temp, selected={}, global_checks={})
        for check in ('setup', 'hold'):
            record['selected'][check] = payload(directory / f'{model}_{temp}_bundle_{check}.rpt', check, True)
            selected.append((check, record['selected'][check]))
        for check in ('setup', 'hold', 'recovery', 'removal'):
            parsed = summary(directory / f'{model}_{temp}_global_{check}.rpt', check)
            record['global_checks'][check] = dict(minimum_slack_ns=min(float(r[0]) for r in parsed),
                                                reported_paths=len(parsed),
                                                reported_violations=sum(float(r[0]) < 0 for r in parsed),
                                                scope='Worst 30 paths only; not exhaustive global coverage')
        assert record['global_checks']['setup']['minimum_slack_ns'] < 0, 'unrelated setup failures unexpectedly hidden'
        result['corners'].append(record)
    expected_files = {'clocks.rpt', 'before_setup.rpt', 'before_hold.rpt'}
    expected_files |= {f'{model}_{temp}_bundle_{check}.rpt' for model, temp in CORNERS for check in ('setup', 'hold')}
    expected_files |= {f'{model}_{temp}_global_{check}.rpt' for model, temp in CORNERS for check in ('setup', 'hold', 'recovery', 'removal')}
    assert {p.name for p in directory.glob('*.rpt')} == expected_files
    result.update(status='pass', selected_corner_paths=16 * 72,
                  minimum_setup_ns=min(r['minimum_slack_ns'] for c, r in selected if c == 'setup'),
                  minimum_hold_ns=min(r['minimum_slack_ns'] for c, r in selected if c == 'hold'),
                  maximum_data_delay_ns=max(r['maximum_data_delay_ns'] for _, r in selected),
                  reporter_sha256=sha(args.reporter), candidate_sha256=sha(args.candidate),
                  native_log_sha256=sha(args.native_log), auditor_sha256=sha(Path(__file__)))
    result['files'] = {p.name: sha(p) for p in directory.iterdir()}
    with args.output.open('x') as stream:
        stream.write(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k: result[k] for k in ('status', 'integrated', 'selected_corner_paths', 'minimum_setup_ns', 'minimum_hold_ns', 'maximum_data_delay_ns')}))


if __name__ == '__main__':
    main()
