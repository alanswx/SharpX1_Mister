#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Freeze real-CPU partial text, exact RGB, retained reset and rejecting modes."""
import csv
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import resource
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def program(Program, kind, columns):
    p = Program()
    p.emit(0xf3)
    p.word(0x31, 0xffff)

    def out(port, value):
        p.word(0x01, port)
        p.emit(0x3e, value, 0xed, 0x79)

    out(0x1a03, 0x82)
    p.word(0x01, 0x1a01)
    p.emit(0xed, 0x78)
    out(0x1a02, 0x40 if columns == 40 else 0)
    p.word(0x01, 0x1a01)
    p.emit(0xed, 0x78)
    for port in (0x1000, 0x1100, 0x1200, 0x1300):
        out(port, 0)
    regs = [55 if columns == 40 else 111, columns, 45 if columns == 40 else 92,
            0x34, 31, 2, 25, 28, 0, 7, 0x60, 7, 0, 0, 0, 0]
    for register, value in enumerate(regs):
        out(0x1800, register)
        out(0x1801, value)
    out(0x1fd0, {0: 0, 1: 0, 2: 1, 3: 0x80, 4: 4, 5: 0}[kind])
    # Kind 5: double-width (attribute bit 7) asymmetric 'P' in every cell.
    attribute, character = (0x8f, 80) if kind == 5 else (0x0f, 65)
    p.word(0x3a, 0xf040)
    p.emit(0xfe, 0xa5)
    p.jump(0xca, 'retained')
    for plane, value in [('attribute', attribute), *([] if kind == 1 else [('text', character)])]:
        p.word(0x01, 0x2800 if plane == 'attribute' else 0x3000)
        p.word(0x11, 2048)
        p.emit(0x26, value)
        p.label(plane)
        p.emit(0xed, 0x61, 0x03, 0x1b, 0x7a, 0xb3)
        p.jump(0xc2, plane)
    p.store(0xf040, 0xa5)
    p.store(0xf041, 1)
    p.jump(0xc3, 'readback')
    p.label('retained')
    p.store(0xf041, 2)
    p.label('readback')
    for cell in (0, 1023, 1999, 2047):
        for port, value in [(0x2800 | cell, attribute), *([] if kind == 1 else [(0x3000 | cell, character)])]:
            p.word(0x01, port)
            p.emit(0xed, 0x78, 0xfe, value)
            p.jump(0xc2, 'fail')
    p.store(0xf000, 0x90)
    p.emit(0x76)
    p.jump(0xc3, 'fail')
    p.label('fail')
    p.store(0xf000, 0xee)
    p.emit(0x76)
    image = p.finish()
    assert len(image) < 4096
    return image + bytes(32768 - len(image))


def main():
    if not __debug__:
        raise SystemExit('PARTIAL_MACHINE_OPTIMIZED_PYTHON')
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    out = Path(tempfile.mkdtemp(prefix='x1-partial-machine-')).resolve()
    print('EVIDENCE=' + str(out), flush=True)
    order = re.findall(r'^set_global_assignment -name (?:SYSTEMVERILOG_FILE|VERILOG_FILE) (\S+)\s*$', (ROOT / 'rtl/machine.qip').read_text(), re.M)
    own = ['rtl/machine.qip', 'verilator/tests/z_partial_ank_machine_tb.sv',
           'verilator/tests/test_z_partial_ank_machine.py', 'verilator/tests/z80_fixture.py',
           'verilator/tests/z_kanji_machine_assets.py', 'verilator/tests/check_basic_print42.py',
           'bios/reference/fw_subcpu/verilog/X1SUB.BIN']
    hashes = {n: sha(ROOT / n) for n in dict.fromkeys(order + own)}
    for name in hashes:
        path = out / 'sources' / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes((ROOT / name).read_bytes())

    def module(path, name):
        spec = importlib.util.spec_from_file_location(name, out / 'sources' / path)
        value = importlib.util.module_from_spec(spec)
        sys.modules[name] = value
        spec.loader.exec_module(value)
        return value

    Program = module('verilator/tests/z80_fixture.py', 'partial_frozen_program').Program
    pattern = module('verilator/tests/z_kanji_machine_assets.py', 'partial_frozen_assets').pattern
    font_bytes = module('verilator/tests/check_basic_print42.py', 'partial_frozen_ank').font_bytes
    assets = out / 'assets'
    assets.mkdir()
    (assets / 'font.hex').write_text(''.join(f'{pattern(a):02x}\n' for a in range(262144)))
    glyphs = font_bytes(out / 'sources/rtl/legacy/x1_cg8.v')
    ank = bytes(glyphs[i] for i in range(2048))
    (assets / 'ank.hex').write_text(''.join(f'{v:02x}\n' for v in ank))
    report = {'status': 'running', 'sources': hashes, 'cases': [], 'scope': __doc__}

    def save():
        (out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')

    save()
    try:
        cases = [(0, 80, 'base80', None), (0, 40, 'base40', None),
                 (1, 80, 'missing-text', None), (2, 80, 'high-scan', None),
                 (3, 80, 'underline', None), (4, 80, 'expanded', None),
                 (5, 80, 'double-width80', None), (5, 40, 'double-width40', None),
                 (0, 80, 'no-reset', 'PARTIAL_MACHINE_REBOOT'),
                 (0, 80, 'skip-partial-rebuild', 'PARTIAL_MACHINE_PIXELS'),
                 (3, 80, 'unsafe-mode-permission', 'PARTIAL_MACHINE_PIXELS')]
        for kind, columns, name, rejection in cases:
            folder = out / name
            folder.mkdir()
            (folder / 'ipl.hex').write_text(''.join(f'{v:02x}\n' for v in program(Program, kind, columns)))
            substitutions = {}
            if name == 'skip-partial-rebuild':
                path = 'rtl/x1_z_kanji_machine.sv'
                original = (out / 'sources' / path).read_text()
                before, after = "journal_read[31:24]==8'h03", "journal_read[31:24]==8'h02"
                assert original.count(before) == 1
                variant = folder / Path(path).name
                variant.write_text(original.replace(before, after))
                substitutions[path] = variant
            if name == 'unsafe-mode-permission':
                path = 'rtl/sharpx1.v'
                original = (out / 'sources' / path).read_text()
                before = 'wire font_partial_ank_allowed = !turbo_scrn_video[0] && !turbo_scrn_video[2] && !turbo_scrn_video[7];'
                assert original.count(before) == 1
                variant = folder / Path(path).name
                variant.write_text(original.replace(before, "wire font_partial_ank_allowed = 1'b1;"))
                substitutions[path] = variant
            obj = folder / 'obj'
            command = ['verilator', '--binary', '--timing', '--assert', '-Wno-fatal',
                       '--top-module', 'z_partial_ank_machine_tb', '--Mdir', str(obj), '-j', '4',
                       f'-GKIND={kind}', f'-GCOLUMNS={columns}', f'-GOMIT_RESET={int(name == "no-reset")}',
                       str(out / 'sources/verilator/tests/z_partial_ank_machine_tb.sv'),
                       *[str(substitutions.get(n, out / 'sources' / n)) for n in order]]
            case = {'name': name, 'kind': kind, 'columns': columns, 'expected_rejection': rejection, 'command': command}
            report['cases'].append(case)
            save()
            with (folder / 'build.log').open('w') as log:
                result = subprocess.run(command, cwd=out / 'sources', stdout=log, stderr=subprocess.STDOUT, timeout=240)
            assert result.returncode == 0, 'compile failure is not a rejection'
            warnings = re.findall(r'^%Warning[^\n]+', (folder / 'build.log').read_text(), re.M)
            assert not any('z_partial_ank_machine_tb.sv:' in line for line in warnings), warnings
            assert not any(re.search(r'%Warning-(IMPLICIT|MULTIDRIVEN|UNOPTFLAT|LATCH):', line) for line in warnings)
            case['warnings'] = warnings
            exe = obj / 'Vz_partial_ank_machine_tb'
            case['executable_sha256'] = sha(exe)
            save()
            command = [str(exe), '+FONT=' + str(assets / 'font.hex'), '+ANK=' + str(assets / 'ank.hex'),
                       '+IPL=' + str(folder / 'ipl.hex'), '+OUTPUT=' + str(folder)]
            with (folder / 'run.log').open('w') as log:
                result = subprocess.run(command, cwd=out / 'sources', stdout=log, stderr=subprocess.STDOUT, timeout=240)
            text = (folder / 'run.log').read_text()
            assert 'PARTIAL_MACHINE_TIMEOUT' not in text, 'timeout is not qualification'
            if rejection:
                assert result.returncode != 0 and re.findall(r'Assertion failed[^\n]*?: (PARTIAL_\w+)', text) == [rejection], text[-2000:]
            else:
                assert result.returncode == 0 and len(re.findall(r'^PASS PARTIAL_MACHINE ', text, re.M)) == 1, text[-2000:]
                for number in range(2):
                    count = 0
                    for count, row in enumerate(csv.DictReader((folder / f'frame-{number}.csv').open()), 1):
                        y, x = divmod(count - 1, columns * 8)
                        assert (int(row['y']), int(row['x'])) == (y, x)
                        if kind == 5:
                            ink = bool(ank[80 * 8 + y % 8] & (128 >> ((x % 16) // 2)))
                        else:
                            ink = bool(ank[65 * 8 + y % 8] & (128 >> (x % 8)))
                        assert int(row['rgb12'], 16) == (0xfff if kind in (0, 5) and not ink else 0)
                    assert count == columns * 8 * 200
                case['exact_pixels'] = columns * 8 * 200 * 2
                events = list(csv.DictReader((folder / 'events.csv').open()))
                assert [r['event'] for r in events] == ['boot', 'halt', 'boot', 'halt']
                reads = [(int(r['address'], 16), int(r['data'], 16)) for r in csv.DictReader((folder / 'reads.csv').open())]
                attribute, character = (0x8f, 80) if kind == 5 else (0x0f, 65)
                expected = [(p, v) for cell in (0, 1023, 1999, 2047)
                            for p, v in [(0x2800 | cell, attribute), *([] if kind == 1 else [(0x3000 | cell, character)])]]
                assert reads == expected * 2
                case['cpu_reads'] = len(reads)
            case.update(verified=True, artifacts={p.name: sha(p) for p in folder.iterdir() if p.is_file()})
            save()
            print('PASS PARTIAL_MACHINE', name, flush=True)
        assert all(sha(ROOT / n) == sha(out / 'sources' / n) == h for n, h in hashes.items())
        report['status'] = 'pass'
        save()
    except BaseException as error:
        report.update(status='fail', error=repr(error))
        save()
        raise


if __name__ == '__main__':
    main()
