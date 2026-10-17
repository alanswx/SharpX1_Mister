#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Real keyboard-selected cold/retained boots; no-reset rejects the warm oracle."""
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
import test_z_font_completion as completion
from z80_fixture import Program

ROOT = Path(__file__).resolve().parents[2]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def program(columns, bad=False):
    image = bytearray(completion.program(columns))
    assert image[:4] == bytes.fromhex('f331ffff')
    assert image[4:7] == bytes.fromhex('01031a')
    assert image[0x4000:0x5800] == bytes(0x1800)
    assert image[0x7000:0x7f00] == bytes(0xf00)
    image[:3] = bytes.fromhex('c30070')
    shell = Program(0x7000)
    shell.emit(0xf3)
    shell.word(0x31, 0xffff)

    def out(p, port, value):
        p.word(0x01, port)
        p.emit(0x3e, value, 0xed, 0x79)

    out(shell, 0x1a03, 0x82)
    shell.word(0x01, 0x1a01)
    shell.emit(0xed, 0x78)
    out(shell, 0x1a02, 0x40 if columns == 40 else 0)
    shell.word(0x01, 0x1a01)
    shell.emit(0xed, 0x78)
    shell.label('poll')
    for i, value in enumerate((0xe4, 0, 0xe6)):
        shell.word(0x01, 0x1a01)
        shell.label(f'tx{i}')
        shell.emit(0xed, 0x78, 0xe6, 0x40)
        shell.jump(0xc2, f'tx{i}')
        out(shell, 0x1900, value)
    for i in range(2):
        shell.word(0x01, 0x1a01)
        shell.label(f'rx{i}')
        shell.emit(0xed, 0x78, 0xe6, 0x20)
        shell.jump(0xc2, f'rx{i}')
        shell.word(0x01, 0x1900)
        shell.emit(0xed, 0x78)
    shell.emit(0xe6, 0xdf, 0xfe, 0x46)  # Accept F/f, independent of Caps state.
    shell.word(0xca, 4)
    shell.emit(0xfe, 0x52)
    shell.word(0xca, 0x7200)
    shell.jump(0xc3, 'poll')
    code = shell.finish()
    assert len(code) < 0x200
    image[0x7000:0x7000+len(code)] = code
    warm = Program(0x7200)
    for i in range(4):
        warm.store(0xf000+i, 0)
    regs = [55 if columns == 40 else 111, columns, 46 if columns == 40 else 92,
            0x28, 27, 0, 25, 26, 0, 15, 0, 0, 0, 0, 0, 0]
    for r, v in enumerate(regs):
        out(warm, 0x1800, r)
        out(warm, 0x1801, v)
    for port in (0x1000, 0x1100, 0x1200, 0x1300):
        out(warm, port, 0)
    out(warm, 0x1fd0, 0x21)
    # No VRAM write is permitted until every retained byte has been read.
    for component, port in enumerate((0x3000, 0x3800, 0x2800)):
        warm.word(0x21, 0x4000+component*2048)
        warm.word(0x01, port)
        warm.word(0x11, 2048)
        warm.label(f'read{component}')
        warm.emit(0xed, 0x78, 0xbe)  # IN A,(C); CP (HL), real IPL table.
        warm.jump(0xc2, 'fail')
        warm.emit(0x23, 0x03, 0x1b, 0x7a, 0xb3)
        warm.jump(0xc2, f'read{component}')
    for i, value in enumerate(b'WARM'):
        warm.store(0xf000+i, value)
    out(warm, 0x2000, 3)
    warm.label('done')
    warm.emit(0x76)
    warm.jump(0xc3, 'done')
    warm.label('fail')
    warm.store(0xf000, 0xee)
    warm.emit(0x76)
    warm.jump(0xc3, 'fail')
    code = warm.finish()
    assert len(code) < 0xd00
    image[0x7200:0x7200+len(code)] = code
    for component in range(3):
        table = bytes(7 if component == 2 and c == 0 else completion.assets.cells(c)[component]
                      for c in range(2048))
        image[0x4000+component*2048:0x4800+component*2048] = table
    if bad:
        image[0x57ff] ^= 1  # Wrong last expected retained ATTR byte only.
    return bytes(image)


def expected_frame(columns, warm):
    result = bytearray(completion.expected_frame(columns, True))
    if warm:
        for y in range(16):
            for x in range(8):
                # White marker becomes magenta: same raw glyph, G drops out.
                result[(y*columns*8+x)*3+1] = 0
    return bytes(result)


def main():
    global completion, Program
    if not __debug__:
        raise SystemExit('Z_WARM_OPTIMIZED_PYTHON_REFUSED')
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    out = Path(tempfile.mkdtemp(prefix='x1-z-font-warm-')).resolve()
    print('EVIDENCE='+str(out), flush=True)
    order = re.findall(r'^set_global_assignment -name (?:SYSTEMVERILOG_FILE|VERILOG_FILE) (\S+)\s*$',
                       (ROOT/'rtl/machine.qip').read_text(), re.M)
    own = ['verilator/tests/test_z_font_warm_reset.py', 'verilator/tests/z_font_warm_reset_tb.sv',
           'verilator/tests/test_z_font_completion.py', 'verilator/tests/test_z_external_font_machine.py',
           'verilator/tests/z80_fixture.py', 'verilator/tests/z_kanji_machine_assets.py',
           'rtl/machine.qip', 'bios/reference/fw_subcpu/verilog/X1SUB.BIN']
    hashes = {n: sha(ROOT/n) for n in dict.fromkeys(order+own)}
    for n in hashes:
        p = out/'sources'/n
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes((ROOT/n).read_bytes())

    def frozen(n, name):
        spec = importlib.util.spec_from_file_location(name, out/'sources'/n)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    Program = frozen(own[4], 'warm_z80').Program
    completion = frozen(own[2], 'warm_completion')
    completion.assets = frozen(own[5], 'warm_assets')
    completion.base = frozen(own[3], 'warm_original')
    completion.base.assets = completion.assets
    completion.base.Program = Program
    report = {'status': 'running', 'source_sha256': hashes, 'cases': [],
              'clock_period_ps': {'SYS': 31250, 'VID': 23280},
              'tool': subprocess.check_output(['verilator', '--version'], text=True).strip()}

    def save():
        (out/'terminal.json').write_text(json.dumps(report, indent=2)+'\n')

    save()
    try:
        exe = out/'obj/Vz_font_warm_reset_tb'
        cmd = ['verilator', '--binary', '--timing', '--assert', '-Wno-fatal',
               '--top-module', 'z_font_warm_reset_tb', '--Mdir', str(exe.parent), '-j', '2',
               str(out/'sources'/own[1])]+[str(out/'sources'/n) for n in order]
        with (out/'build.log').open('w') as log:
            r = subprocess.run(cmd, cwd=out/'sources', stdout=log, stderr=subprocess.STDOUT, timeout=240)
        report.update(build_exit=r.returncode, build_log_sha256=sha(out/'build.log'))
        save()
        assert r.returncode == 0, 'compile failure is not rejection'
        warnings = [s for s in (out/'build.log').read_text().splitlines() if s.startswith('%Warning')]
        report['warnings'] = warnings
        assert not any(re.search(r'%Warning-(IMPLICIT|MULTIDRIVEN|UNOPTFLAT|LATCH):', s) for s in warnings), warnings
        assert not any('z_font_warm_reset_tb.sv:' in s for s in warnings), warnings
        report['executable_sha256'] = sha(exe)
        save()
        for columns, bad in ((80, False), (40, False), (80, True)):
            folder = out/f'cols{columns}-bad{int(bad)}'
            folder.mkdir()
            rom = program(columns, bad)
            (folder/'diagnostic.rom').write_bytes(rom)
            (folder/'ipl.hex').write_text(''.join(f'{v:02x}\n' for v in rom))
            (folder/'font.hex').write_text(''.join(f'{completion.assets.pattern(a):02x}\n' for a in range(262144)))
            case = {'columns': columns, 'bad_last_retained_compare': bad, 'ipl_sha256': sha(folder/'diagnostic.rom')}
            report['cases'].append(case)
            save()
            with (folder/'run.log').open('w') as log:
                r = subprocess.run([str(exe), '+FONT='+str(folder/'font.hex'), '+IPL='+str(folder/'ipl.hex'),
                                    '+OUTPUT='+str(folder), '+COLUMNS='+str(columns), '+BAD='+str(int(bad))],
                                   cwd=out/'sources', stdout=log, stderr=subprocess.STDOUT, timeout=480)
            case.update(exit=r.returncode, run_log_sha256=sha(folder/'run.log'))
            save()
            text = (folder/'run.log').read_text()
            assert r.returncode == 0 and len(re.findall(r'^PASS Z_WARM_RESET ', text, re.M)) == 1, text[-3000:]
            rgbs = []
            for phase in range(3):
                actual = bytearray()
                for n, row in enumerate(csv.DictReader((folder/f'frame-{phase}.csv').open())):
                    assert (int(row['y']), int(row['x'])) == divmod(n, columns*8)
                    v = int(row['rgb12'], 16)
                    actual.extend(((v >> 8 & 15)*17, (v >> 4 & 15)*17, (v & 15)*17))
                assert len(actual) == columns*8*400*3
                warm_match = actual == expected_frame(columns, True)
                assert warm_match == (phase == 2 and not bad), 'Z_WARM_UNCHANGED_REBOOT_ORACLE'
                assert actual == expected_frame(columns, phase == 2 and not bad), 'Z_WARM_EXACT_FRAME'
                (folder/f'frame-{phase}.png').write_bytes(completion.png(columns*8, 400, actual))
                rgbs.append(hashlib.sha256(actual).hexdigest())
            assert rgbs[0] == rgbs[1] and (rgbs[1] == rgbs[2]) == bad
            events = list(csv.DictReader((folder/'events.csv').open()))
            reads = [r for r in events if r['event'] == 'read']
            a = completion.assets
            expected = [0x18, 0xa6]+[a.pattern(level*131072+bank*8192+255*32+row*2+half)
                       for level, bank, half in ((0, 0, 0), (1, 15, 1)) for row in range(16)]
            expected += [v for c in (0, 999, 1999, 2046) for v in a.cells(c)]
            expected += [7 if component == 2 and c == 0 else a.cells(c)[component]
                         for component in range(3) for c in range(2048)]
            ports = [0x1400, 0x1500]+list(range(0x1400, 0x1410))*2
            ports += [port | c for c in (0, 999, 1999, 2046) for port in (0x3000, 0x3800, 0x2800)]
            ports += [port+c for port in (0x3000, 0x3800, 0x2800) for c in range(2048)]
            assert [int(r['data']) for r in reads] == expected, 'Z_WARM_CPU_BYTES'
            assert [int(r['address']) for r in reads] == ports, 'Z_WARM_CPU_PORTS'
            assert [int(r['select']) for r in reads] == [0]*46+[1]*6144, 'Z_WARM_CPU_BOOTS'
            commits = [r for r in events if r['event'] == 'commit']
            assert len(commits) == 6154+int(not bad)
            if not bad:
                assert (commits[-1]['address'], commits[-1]['select'], commits[-1]['data']) == ('0', '2', '3')
                assert int(commits[-1]['cycle']) > int(reads[-1]['cycle']), 'Z_WARM_POST_CHECK_MARKER'
            for boot, ascii_key in ((0, 0x46), (1, 0x52)):
                commands = [int(r['data']) for r in events if r['event'] == 'command' and int(r['select']) == boot]
                assert commands and len(commands) % 3 == 0 and commands == [0xe4, 0, 0xe6]*(len(commands)//3)
                keys = [int(r['data']) for r in events if r['event'] == 'key' and int(r['select']) == boot]
                assert len(keys) % 2 == 0 and keys[-1] & 0xdf == ascii_key, 'Z_WARM_REAL_KEY_REPLY'
            case.update(verified=True, rgb_sha256=rgbs,
                        pass_line=re.findall(r'^PASS Z_WARM_RESET .+$', text, re.M)[0])
            case['artifacts'] = {p.name: sha(p) for p in folder.iterdir() if p.is_file()}
            save()
            print('PASS '+str(columns)+' bad='+str(int(bad)), flush=True)
        report['status'] = 'pass'
    except BaseException as e:
        report.update(status='fail', error=repr(e))
        raise
    finally:
        report['unchanged'] = all(sha(ROOT/n) == sha(out/'sources'/n) == v for n, v in hashes.items())
        if not report['unchanged']:
            report['status'] = 'fail'
        save()
        assert report['unchanged'], 'inputs changed during qualification'
    print('PASS Z_WARM_FROZEN_GATE '+str(out), flush=True)


if __name__ == '__main__':
    main()
