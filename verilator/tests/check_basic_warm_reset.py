"""Qualify the frozen CZ-8FB01 RTL idle-prompt warm/reset-control matrix.

This reads terminal captures; it does not execute or patch the machine. The
historical executable hash identifies a checkpoint, not current build provenance.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path

from check_basic_reference import BANNER, SEQUENCES, check_rows
from check_basic_print42 import font_bytes

RUNNER_SHA = 'c244826e3f9da196276431ceb4e3ce7b7f8a1d0d849b4e8af977c99c27ca76cc'
DISK_SHA = 'ef47f5df772f45d97be43646d8f8010d33eca8846913babfd1106e89a361ee6a'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check_terminal(text, ppm, font, sequence):
    magic, size, maximum, pixels = ppm.split(b'\n', 3)
    assert (magic, size, maximum) == (b'P6', b'640 200', b'255')
    assert len(text) == 2048
    for row, value in [(4, BANNER), *enumerate(SEQUENCES[sequence], 13)]:
        assert text[row * 80:(row + 1) * 80] == value.ljust(80, b' '), ('native text mismatch', row)
    return {'banner': check_rows((640, 200), pixels, font, 4, (BANNER,), 1),
            'transcript': check_rows((640, 200), pixels, font, 13, SEQUENCES[sequence], 1)}


def main():
    assert __debug__
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('evidence', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    folder = args.evidence.resolve()
    report = json.loads((folder / 'report.json').read_text())
    assert report['status'] == 'executed-awaiting-oracle', 'matrix is not terminal'
    assert sha(folder / 'Vtop') == RUNNER_SHA
    assert len(report['runs']) == 3
    for path, digest in report['inputs'].items():
        assert sha(Path(path)) == digest, ('native input changed', path)
    source = Path(__file__).resolve().parents[2] / 'rtl/legacy/x1_cg8.v'
    glyphs = font_bytes(source)
    font = bytes(glyphs[i] for i in range(2048))
    results = []
    for name, run in zip(('warm', 'warm-repeat', 'no-reset'), report['runs']):
        assert run['name'] == name and run['exit'] == 0
        path = folder / name
        for filename, digest in run['sha256'].items():
            assert sha(path / filename) == digest, ('native artifact changed', name, filename)
        command = json.loads((path / 'command.json').read_text())
        assert command[0] == str(folder / 'Vtop')
        assert not any(flag in command for flag in ('--restore-state', '--ram', '--disk-output', '--disk-b-output'))
        for flag in ('--rom', '--disk', '--keys'):
            assert command.count(flag) == 1 and command[command.index(flag) + 1] in report['inputs']
        assert sha(Path(command[command.index('--disk') + 1])) == DISK_SHA
        warm = name != 'no-reset'
        assert command.count('--reset-at') == int(warm)
        if warm:
            assert command[command.index('--reset-at') + 1] == '14000'
            assert command[command.index('--reset-for-us') + 1] == '20'
        r = run['report']
        assert r['machine'] == 'sharpx1' and r['turbo_foundation'] and not r['turbo_dma']
        assert r['intra_assignment_delays'] and r['fdc_timing_experiment'] and r['fdc_clock_hz'] == 1000000
        assert (r['sys_hz'], r['video_hz'], r['time_ps']) == (32000000, 28571428, 26000000000000)
        assert r['disk_writes'] == 0 and r['download_bytes'] == 4095 and r['ps2_bytes_sent'] == 72
        text, ppm = (path / 'final.text').read_bytes(), (path / 'final.ppm').read_bytes()
        check = {'name': name}
        if warm:
            check['pixels'] = check_terminal(text, ppm, font, 'warm')
        else:
            check['initial_arithmetic_retained'] = check_terminal(text, ppm, font, 'arithmetic')
            try:
                check_terminal(text, ppm, font, 'warm')
            except AssertionError as error:
                check['unchanged_reboot_oracle_rejected'] = str(error)
            else:
                raise AssertionError('No-reset control satisfied reboot oracle')
        rows = csv.DictReader((path / 'reset-bus.csv').open())
        reads = [r for r in rows if 14000020000000 <= int(r['time_ps']) < 14030000000000
                 and int(r['address']) == 0 and r['mreq_n'] == '0' and r['iorq_n'] == '1' and r['rd_n'] == '0']
        assert bool(reads) == warm, 'Native reset/CPU IPL read control'
        if warm:
            assert all(int(r['data_in']) == 0xc3 for r in reads)
        check['post_reset_ipl_reads'] = len(reads)
        results.append(check)
    a, b, control = report['runs']
    assert a['report'] == b['report']
    for name in ('final.ram', 'final.text', 'final.attr', 'final.subram', 'final.cpu', 'final.ppm', 'reset-bus.csv'):
        assert a['sha256'][name] == b['sha256'][name], ('warm repeat differs', name)
    assert a['report']['reset_edges'] - control['report']['reset_edges'] == 640
    acceptance = {'status': 'pass', 'scope': 'CZ-8FB01 idle-prompt retained-asset reset and new arithmetic; no active DMA/FDC, save/load or hardware claim',
                  'report_sha256': sha(folder / 'report.json'), 'font_source_sha256': sha(source),
                  'checker_sha256': sha(Path(__file__)), 'runs': results}
    with args.output.open('x') as f:
        json.dump(acceptance, f, indent=2)
        f.write('\n')
    print('PASS_BASIC_RTL_WARM_RESET', json.dumps(results))


if __name__ == '__main__':
    main()
