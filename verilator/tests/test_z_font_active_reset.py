#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""CPU font/VRAM traffic, exact owned reset drains and retained-byte recovery."""
import csv
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import resource
import subprocess
import tempfile
import test_z_font_warm_reset as warm
from z80_fixture import Program

ROOT = Path(__file__).resolve().parents[2]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def program(columns, bad=False):
    image = bytearray(warm.program(columns, bad))
    # Keep the original cold CPU comparisons and its post-check white marker.
    assert image[0x7f07:0x7f0b] == bytes.fromhex('76c3077f')
    image[0x7f07:0x7f0a] = bytes.fromhex('c3007d')
    assert image[0x7d00:0x7f00] == bytes(512)
    p = Program(0x7d00)

    def out(port, value):
        p.word(0x01, port)
        p.emit(0x3e, value, 0xed, 0x79)

    p.emit(0x16, 0)  # D records first checked iteration, independent of cold RAM.
    p.label('loop')
    for port, value in zip((0x37ff, 0x3fff, 0x27ff), warm.completion.assets.cells(2047)):
        out(port, value)  # Idempotent real writes: all retained bytes stay exact.
    text, kan, _ = warm.completion.assets.cells(2047)
    for row in range(16):
        address = ((kan & 31) << 13) | (text << 5) | (row << 1) | (kan >> 6 & 1)
        p.word(0x01, 0x1400+row)
        p.emit(0xed, 0x78, 0xfe, warm.completion.assets.pattern(address))
        p.jump(0xc2, 'fail')
    p.emit(0x7a, 0xb7)  # LD A,D; OR A
    p.jump(0xc2, 'verified')
    out(0x2000, 6)  # Yellow only after the first sixteen checked font reads.
    p.emit(0x16, 1)
    p.label('verified')
    p.store(0xf050, 0xa5)  # Actual CPU store witnesses a fully checked iteration.
    p.jump(0xc3, 'loop')
    p.label('fail')
    p.store(0xf000, 0xee)
    p.emit(0x76)
    p.jump(0xc3, 'fail')
    code = p.finish()
    assert len(code) < 512
    image[0x7d00:0x7d00+len(code)] = code
    assert image[0x5000] == 7
    image[0x5000] = 6  # Warm reader must verify the exact active marker too.
    return bytes(image)


def expected_frame(columns, recovered):
    image = bytearray(warm.expected_frame(columns, recovered))
    if not recovered:
        # Existing cell-zero glyph, white -> yellow (blue removed).
        for y in range(16):
            for x in range(8):
                image[(y*columns*8+x)*3+2] = 0
    return bytes(image)


def main():
    global warm, Program
    if not __debug__:
        raise SystemExit('Z_ACTIVE_OPTIMIZED_PYTHON_REFUSED')
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    out = Path(tempfile.mkdtemp(prefix='x1-z-font-active-')).resolve()
    print('EVIDENCE='+str(out), flush=True)
    order = re.findall(r'^set_global_assignment -name (?:SYSTEMVERILOG_FILE|VERILOG_FILE) (\S+)\s*$',
                       (ROOT/'rtl/machine.qip').read_text(), re.M)
    own = ['verilator/tests/test_z_font_active_reset.py', 'verilator/tests/z_font_active_reset_tb.sv',
           'verilator/tests/test_z_font_warm_reset.py', 'verilator/tests/test_z_font_completion.py',
           'verilator/tests/test_z_external_font_machine.py', 'verilator/tests/z80_fixture.py',
           'verilator/tests/z_kanji_machine_assets.py', 'rtl/machine.qip',
           'bios/reference/fw_subcpu/verilog/X1SUB.BIN']
    hashes = {n: sha(ROOT/n) for n in dict.fromkeys(order+own)}
    for n in hashes:
        path = out/'sources'/n
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes((ROOT/n).read_bytes())

    def frozen(n, name):
        spec = importlib.util.spec_from_file_location(name, out/'sources'/n)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    Program = frozen(own[5], 'active_z80').Program
    warm = frozen(own[2], 'active_warm')
    warm.Program = Program
    warm.completion = frozen(own[3], 'active_completion')
    warm.completion.assets = frozen(own[6], 'active_assets')
    warm.completion.base = frozen(own[4], 'active_original')
    warm.completion.base.assets = warm.completion.assets
    warm.completion.base.Program = Program
    report = {'status': 'running', 'source_sha256': hashes, 'cases': [],
              'clock_period_ps': {'SYS': 31250, 'VID': 23280}, 'scope': __doc__,
              'tool': subprocess.check_output(['verilator', '--version'], text=True).strip()}

    def save():
        (out/'terminal.json').write_text(json.dumps(report, indent=2)+'\n')

    save()
    try:
        exe = out/'obj/Vz_font_active_reset_tb'
        cmd = ['verilator', '--binary', '--timing', '--assert', '-Wno-fatal',
               '--top-module', 'z_font_active_reset_tb', '--Mdir', str(exe.parent), '-j', '2',
               str(out/'sources'/own[1])]+[str(out/'sources'/n) for n in order]
        with (out/'build.log').open('w') as log:
            r = subprocess.run(cmd, cwd=out/'sources', stdout=log, stderr=subprocess.STDOUT, timeout=240)
        report.update(build_exit=r.returncode, build_log_sha256=sha(out/'build.log'))
        save()
        assert r.returncode == 0, 'compile failure is not rejection'
        warnings = [s for s in (out/'build.log').read_text().splitlines() if s.startswith('%Warning')]
        report['warnings'] = warnings
        assert not any(re.search(r'%Warning-(IMPLICIT|MULTIDRIVEN|UNOPTFLAT|LATCH):', s) for s in warnings), warnings
        assert not any('z_font_active_reset_tb.sv:' in s for s in warnings), warnings
        report['executable_sha256'] = sha(exe)
        save()
        for columns, owner, bad in ((80, 'write', False), (80, 'read', False),
                                    (40, 'write', False), (80, 'write', True)):
            folder = out/f'cols{columns}-{owner}-bad{int(bad)}'
            folder.mkdir()
            rom = program(columns, bad)
            (folder/'diagnostic.rom').write_bytes(rom)
            (folder/'ipl.hex').write_text(''.join(f'{v:02x}\n' for v in rom))
            (folder/'font.hex').write_text(''.join(f'{warm.completion.assets.pattern(a):02x}\n' for a in range(262144)))
            case = {'columns': columns, 'reset_owner': owner, 'bad_last_retained_compare': bad,
                    'ipl_sha256': sha(folder/'diagnostic.rom')}
            report['cases'].append(case)
            save()
            with (folder/'run.log').open('w') as log:
                r = subprocess.run([str(exe), '+FONT='+str(folder/'font.hex'), '+IPL='+str(folder/'ipl.hex'),
                                    '+OUTPUT='+str(folder), '+COLUMNS='+str(columns), '+BAD='+str(int(bad)),
                                    '+READ_RESET='+str(int(owner == 'read'))], cwd=out/'sources',
                                   stdout=log, stderr=subprocess.STDOUT, timeout=480)
            case.update(exit=r.returncode, run_log_sha256=sha(folder/'run.log'))
            save()
            text = (folder/'run.log').read_text()
            assert r.returncode == 0 and len(re.findall(r'^PASS Z_ACTIVE_RESET ', text, re.M)) == 1, text[-3000:]
            rgbs = []
            for phase in range(3):
                actual = bytearray()
                for n, row in enumerate(csv.DictReader((folder/f'frame-{phase}.csv').open())):
                    assert (int(row['y']), int(row['x'])) == divmod(n, columns*8)
                    v = int(row['rgb12'], 16)
                    actual.extend(((v >> 8 & 15)*17, (v >> 4 & 15)*17, (v & 15)*17))
                assert len(actual) == columns*8*400*3
                match = actual == expected_frame(columns, True)
                assert match == (phase == 2 and not bad), 'Z_ACTIVE_UNCHANGED_RECOVERY_ORACLE'
                assert actual == expected_frame(columns, phase == 2 and not bad), 'Z_ACTIVE_EXACT_FRAME'
                (folder/f'frame-{phase}.png').write_bytes(warm.completion.png(columns*8, 400, actual))
                rgbs.append(hashlib.sha256(actual).hexdigest())
            events = list(csv.DictReader((folder/'events.csv').open()))
            reads = [r for r in events if r['event'] == 'read']
            cold = [r for r in reads if r['select'] == '0']
            active = [r for r in reads if r['select'] == '1']
            retained = [r for r in reads if r['select'] == '2']
            a = warm.completion.assets
            cold_values = [0x18, 0xa6]+[a.pattern(level*131072+bank*8192+255*32+row*2+half)
                          for level, bank, half in ((0, 0, 0), (1, 15, 1)) for row in range(16)]
            cold_values += [v for c in (0, 999, 1999, 2046) for v in a.cells(c)]
            assert [int(r['data']) for r in cold] == cold_values
            text_byte, kan, _ = a.cells(2047)
            active_values = [a.pattern(((kan & 31) << 13) | (text_byte << 5) | (row << 1) | (kan >> 6 & 1)) for row in range(16)]
            assert len(active) >= 32
            assert [int(r['data']) for r in active] == [active_values[i % 16] for i in range(len(active))]
            assert [int(r['address']) for r in active] == [0x1400+i % 16 for i in range(len(active))]
            assert [int(r['data']) for r in retained] == [6 if c == 0 and component == 2 else a.cells(c)[component]
                                                       for component in range(3) for c in range(2048)]
            assert [int(r['address']) for r in retained] == [p+c for p in (0x3000, 0x3800, 0x2800) for c in range(2048)]
            commits = [r for r in events if r['event'] == 'commit']
            reset = [r for r in events if r['event'] == 'reset']
            drain = [r for r in events if r['event'] == 'drained']
            assert len(reset) == len(drain) == 1
            during = [r for r in commits if int(reset[0]['cycle']) <= int(r['cycle']) < int(drain[0]['cycle'])]
            assert len(during) == int(owner == 'write'), 'Z_ACTIVE_ONE_OWNED_COMMIT'
            cancelled = [r for r in events if r['event'] == 'cancelled-read']
            assert len(cancelled) == int(owner == 'read'), 'Z_ACTIVE_EXACT_CANCEL'
            if cancelled:
                assert int(cancelled[0]['address']) == 0x1400+len(active) % 16
            if not bad:
                assert tuple(int(commits[-1][k]) for k in ('address', 'select', 'data')) == (0, 2, 3)
                assert int(commits[-1]['cycle']) > int(retained[-1]['cycle'])
            case.update(verified=True, rgb_sha256=rgbs, active_completed_reads=len(active),
                        total_completed_reads=len(reads), exact_pixels=columns*8*400*3,
                        owned_drain_commits=len(during), cancelled_reads=len(cancelled),
                        pass_line=re.findall(r'^PASS Z_ACTIVE_RESET .+$', text, re.M)[0])
            case['artifacts'] = {p.name: sha(p) for p in folder.iterdir() if p.is_file()}
            save()
            print('PASS '+str(columns)+' '+owner+' bad='+str(int(bad)), flush=True)
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
    print('PASS Z_ACTIVE_FROZEN_GATE '+str(out), flush=True)


if __name__ == '__main__':
    main()
