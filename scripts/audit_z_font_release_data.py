#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Check reported synchronous release fanout; disclose unclassified endpoints."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re

from audit_z_font_reset_timing import PIPES
from audit_z_font_snapshot_timing import CORNERS, VID, summary


def main():
    if not __debug__:
        raise RuntimeError('timing audit requires Python assertions')
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--reports', type=Path, required=True)
    p.add_argument('--reset-reports', type=Path, required=True)
    p.add_argument('--native-log', type=Path, required=True)
    p.add_argument('--reporter', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
    log = args.native_log.read_text()
    assert log.count('TimeQuest Timing Analyzer was successful. 0 errors, 0 warnings') == 1
    assert not re.search(r'^\s*(?:Error|Warning|Critical Warning)\b', log, re.M)
    assert log.count('FONT RELEASE DATA COMPLETE: assigned SDC only; not physical fanout acceptance') == 1
    assert re.findall(r'^FONT RELEASE DATA CORNER (slow|fast) (-?\d+) 1100$', log, re.M) == [(m, str(t)) for m, t in CORNERS]
    lines = (args.reports / 'inventory.txt').read_text().splitlines()
    assert lines and len(set(lines)) == len(lines)
    assert all(s.endswith(' (reg)') for s in lines)
    fanouts = {s.removesuffix(' (reg)') for s in lines}
    original_fanouts = set()
    for line in (args.reset_reports / 'inventory.txt').read_text().splitlines():
        prefix = f'fanouts {PIPES[1]} '
        if line.startswith(prefix):
            original_fanouts.add(line.removeprefix(prefix).removesuffix(' (reg)'))
    assert fanouts == original_fanouts, 'reset/data native fanout inventories differ'
    result = dict(status='running', scope=__doc__, corners=[])
    references = {}
    selected = []
    for model, temp in CORNERS:
        record = dict(model=model, temperature_c=temp, checks={})
        for check in ('setup', 'hold'):
            path = args.reports / f'{model}_{temp}_{check}.rpt'
            parsed = summary(path, check)
            assert f'    {model.capitalize()} 1100mV {temp}C Model' in path.read_text()
            assert all(r[1] == PIPES[1] and r[2] in fanouts and r[3:5] == [VID, VID] for r in parsed), 'unexpected release data endpoint/domain'
            assert all(float(r[0]) >= 0 for r in parsed), 'reported release data timing fails'
            assert all(0 <= float(r[7]) < 23.28 for r in parsed), 'release data physical delay exceeds VID period'
            endpoints = Counter(tuple(r[1:5]) for r in parsed)
            references.setdefault(check, endpoints)
            assert references[check] == endpoints, 'corner endpoint coverage changed'
            record['checks'][check] = dict(paths=len(parsed), minimum_slack_ns=min(float(r[0]) for r in parsed))
            selected.extend((check, float(r[0])) for r in parsed)
        result['corners'].append(record)
    async_rows = summary(args.reset_reports / 'integrated_slow_-40_output_recovery.rpt', 'recovery')
    async_targets = {r[2] for r in async_rows}
    setup_targets = {r[1] for r in references['setup']}
    hold_targets = {r[1] for r in references['hold']}
    assert setup_targets == hold_targets
    uncovered = sorted(fanouts - setup_targets - async_targets)
    expected = {f'{m}_{t}_{c}.rpt' for m, t in CORNERS for c in ('setup', 'hold')}
    assert {f.name for f in args.reports.glob('*.rpt')} == expected
    result.update(status='pass-reported-release-data', native_fanouts=len(fanouts),
                  synchronous_targets=len(setup_targets), asynchronous_targets=len(async_targets),
                  unclassified_fanouts=uncovered, union_coverage_complete=not uncovered,
                  total_reported_paths=len(selected),
                  minimum_setup_ns=min(v for c, v in selected if c == 'setup'),
                  minimum_hold_ns=min(v for c, v in selected if c == 'hold'),
                  native_log_sha256=sha(args.native_log), reporter_sha256=sha(args.reporter),
                  auditor_sha256=sha(Path(__file__)), global_timing='fail', physical_acceptance='open')
    result['files'] = {f.name: sha(f) for f in args.reports.iterdir()}
    with args.output.open('x') as stream:
        stream.write(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k: result[k] for k in ('status', 'native_fanouts', 'synchronous_targets',
                     'asynchronous_targets', 'union_coverage_complete', 'minimum_setup_ns', 'minimum_hold_ns')}))


if __name__ == '__main__':
    main()
