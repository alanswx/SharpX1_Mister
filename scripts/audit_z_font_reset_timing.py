#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Audit raw-input exclusion and retained reset timing; physical gates stay open."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re

from audit_vsync_sys_reports import rows
from audit_z_font_snapshot_timing import CORNERS, VID, summary

PIPE = 'emu:emu|sharpx1:sharpx1|x1_reset_release:video_reset_domain.release_reset|release_pipe'
PIPES = [f'{PIPE}[{bit}]' for bit in (0, 1)]
PIN = 'emu|sharpx1|video_reset_domain.release_reset|release_pipe'
PINS = [f'{PIN}[{bit}]|clrn' for bit in (0, 1)]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def audit(directory, log_path, integrated):
    log = log_path.read_text()
    assert log.count('TimeQuest Timing Analyzer was successful. 0 errors, 0 warnings') == 1
    assert not re.search(r'^\s*(?:Error|Warning|Critical Warning)\b', log, re.M)
    assert log.count('FONT RESET REPORT COMPLETE: raw asynchronous inputs are not physical acceptance') == 1
    phases = ['integrated'] if integrated else ['before', 'after']
    expected_corners = [(phase, m, str(t)) for phase in phases for m, t in CORNERS]
    assert re.findall(r'^FONT RESET CORNER (\w+) (slow|fast) (-?\d+) 1100$', log, re.M) == expected_corners
    inventory = (directory / 'inventory.txt').read_text().splitlines()
    assert inventory[0] == 'register 2' and sorted(s.strip() for s in inventory[1:3]) == PIPES
    assert inventory[3] == 'pin 2' and sorted(s.strip() for s in inventory[4:6]) == PINS
    connections = []
    for line in inventory[6:]:
        match = re.fullmatch(r'(fanins|fanouts) (\S+) (\S+) \((\S+)\)', line)
        assert match, ('unrecognized connectivity record', line)
        connections.append(tuple(match.groups()))
    assert len(set(connections)) == len(connections), 'duplicate native connection'
    assert [c for c in connections if c[:2] == ('fanouts', PIPES[0])] == [
        ('fanouts', PIPES[0], PIPES[1], 'reg')], 'first stage has a consumer outside second stage'
    assert [c for c in connections if c[:2] == ('fanins', PIPES[1])] == [
        ('fanins', PIPES[1], PIPES[0], 'reg')], 'second stage does not have exact stage-zero D owner'
    fanouts = {c[2] for c in connections if c[:2] == ('fanouts', PIPES[1])}
    assert fanouts and all(c[3] == 'reg' for c in connections), 'unexpected output connectivity type'
    result = dict(status='running', integrated=integrated, reports=str(directory),
                  scope=__doc__, native_release_fanouts=len(fanouts), corners=[])
    expected_files = {'clocks.rpt'}
    retained = {}
    reference = {}
    for phase in phases:
        for model, temp in CORNERS:
            prefix = f'{phase}_{model}_{temp}'
            record = dict(phase=phase, model=model, temperature_c=temp, checks={})
            for kind, checks in [('chain', ('setup', 'hold')), ('output', ('recovery', 'removal')),
                                 ('raw', ('recovery', 'removal')),
                                 ('global', ('setup', 'hold', 'recovery', 'removal'))]:
                for check in checks:
                    name = f'{prefix}_{kind}_{check}.rpt'
                    expected_files.add(name)
                    path = directory / name
                    text = path.read_text()
                    native_model = f'{model.capitalize()} 1100mV {temp}C Model'
                    if kind == 'raw' and phase != 'before':
                        assert rows(path, allow_excluded=True) == [], 'raw exception did not bind'
                        assert 'Nothing to report.' in text
                        record['checks'][f'{kind}_{check}'] = dict(excluded=True, timing_pass=False)
                        continue
                    parsed = summary(path, check)
                    assert f'    {native_model}' in text, ('wrong actual corner', name)
                    minimum = min(float(r[0]) for r in parsed)
                    record['checks'][f'{kind}_{check}'] = dict(paths=len(parsed), minimum_slack_ns=minimum)
                    if kind == 'chain':
                        assert len(parsed) == 1 and parsed[0][1:5] == PIPES + [VID, VID]
                    elif kind == 'output':
                        assert all(r[1] == PIPES[1] and r[2] in fanouts and r[3:5] == [VID, VID]
                                   for r in parsed), ('wrong released reset consumer/domain', name)
                    elif kind == 'raw':
                        assert {r[2] for r in parsed} == set(PIPES) and all(r[4] == VID for r in parsed)
                        assert len(parsed) >= 2
                    if kind in ('chain', 'output'):
                        assert minimum >= 0, ('retained synchronous timing failure', name)
                        key = (kind, check)
                        endpoints = Counter(tuple(r[1:5]) for r in parsed)
                        reference.setdefault(key, endpoints)
                        assert endpoints == reference[key], ('corner coverage changed', name)
                        retained[(phase, model, temp, kind, check)] = sorted(parsed)
                    if kind == 'global' and check in ('setup', 'recovery'):
                        assert minimum < 0, ('unrelated failures unexpectedly hidden', name)
            result['corners'].append(record)
    if not integrated:
        for model, temp in CORNERS:
            for kind, check in [('chain', 'setup'), ('chain', 'hold'),
                                ('output', 'recovery'), ('output', 'removal')]:
                assert retained[('before', model, temp, kind, check)] == retained[('after', model, temp, kind, check)], 'raw-only exception altered retained timing'
            for check in ('setup', 'hold'):
                assert summary(directory / f'before_{model}_{temp}_global_{check}.rpt', check) == summary(
                    directory / f'after_{model}_{temp}_global_{check}.rpt', check), 'raw-only exception altered global data timing'
    assert {p.name for p in directory.glob('*.rpt')} == expected_files, 'missing/extra reports'
    final_phase = phases[-1]
    result['retained'] = {}
    for kind, check in [('chain', 'setup'), ('chain', 'hold'),
                        ('output', 'recovery'), ('output', 'removal')]:
        selected = [retained[(final_phase, m, t, kind, check)] for m, t in CORNERS]
        result['retained'][f'{kind}_{check}'] = dict(
            paths_per_corner=len(selected[0]), total_paths=sum(map(len, selected)),
            minimum_slack_ns=min(float(r[0]) for case in selected for r in case))
    result.update(status='pass-selected-reset-timing', raw_inputs_excluded=2,
                  physical_pulse_placement_mtbf='open', global_timing='fail', hardware='unexecuted')
    return result


def main():
    if not __debug__:
        raise RuntimeError('timing audit requires Python assertions')
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--reports', type=Path, required=True)
    p.add_argument('--native-log', type=Path, required=True)
    p.add_argument('--reporter', type=Path, required=True)
    p.add_argument('--candidate', type=Path, required=True)
    p.add_argument('--integrated', action='store_true')
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    result = audit(args.reports, args.native_log, args.integrated)
    result.update(reporter_sha256=sha(args.reporter), candidate_sha256=sha(args.candidate),
                  auditor_sha256=sha(Path(__file__)), native_log_sha256=sha(args.native_log))
    result['files'] = {p.name: sha(p) for p in args.reports.iterdir()}
    with args.output.open('x') as stream:
        stream.write(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k: result[k] for k in ('status', 'retained', 'global_timing')}))


if __name__ == '__main__':
    main()
