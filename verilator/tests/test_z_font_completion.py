#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Freeze cold CPU completion pixels and an unchanged-oracle failing IPL control."""
import csv
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import resource
import struct
import subprocess
import sys
import tempfile
import zlib
import test_z_external_font_machine as base
import z_kanji_machine_assets as assets

ROOT = Path(__file__).resolve().parents[2]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def program(columns, bad=False):
    image = bytearray(base.program(columns))
    # Physical RAM has no promised cold contents: always fill all three planes.
    warm = bytes.fromhex('3a40f0fea5ca')
    assert image.count(warm) == 1
    offset = image.index(warm)
    image[offset:offset+8] = bytes(8)
    # Preserve every comparison, table address and branch target in the base.
    success = bytes.fromhex('3e5a3200f03e503201f03e493202f03e583203f076c3')
    assert image.count(success) == 1
    offset = image.index(success)+20
    assert image[0x7f00:] == bytes(256)
    image[offset:offset+3] = bytes.fromhex('c3007f')
    # Only this post-check epilogue may publish the visible marker. Cell zero
    # starts with ATTR=0; white ink on its synthetic glyph is visibly different.
    epilogue = bytes.fromhex('0100203e07ed7976c3077f')
    image[0x7f00:0x7f00+len(epilogue)] = epilogue
    if bad:
        # Last original VRAM check: identical CPU bus traffic, one wrong CP n.
        needle = bytes.fromhex('01fe2fed78fe')+bytes([assets.cells(2046)[2]])
        assert image.count(needle) == 1
        image[image.index(needle)+6] ^= 1
    return bytes(image)


def expected_frame(columns, completed):
    # Full independent cell/raster oracle; raw font bits precede color lookup.
    image = bytearray()
    for y in range(400):
        for x in range(columns*8):
            cell = y//16*columns+x//8
            text, kan, attr = assets.cells(cell)
            if completed and cell == 0:
                attr = 7
            address = ((kan & 31) << 13) | (text << 5) | ((y % 16) << 1) | ((kan >> 6) & 1)
            ink = bool(assets.pattern(address) & (128 >> (x % 8)))
            color = (attr & 7 if ink else 0) ^ (7 if attr & 8 else 0)
            image.extend((255 if color & 2 else 0, 255 if color & 4 else 0, 255 if color & 1 else 0))
    return bytes(image)


def png(width, height, rgb):
    def chunk(tag, data):
        return struct.pack('>I', len(data))+tag+data+struct.pack('>I', zlib.crc32(tag+data) & 0xffffffff)
    rows = b''.join(b'\0'+rgb[y*width*3:(y+1)*width*3] for y in range(height))
    return (b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(rows))+chunk(b'IEND', b''))


def main():
    global base, assets
    if not __debug__:
        raise SystemExit('Z_COMPLETION_OPTIMIZED_PYTHON_REFUSED')
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    out = Path(tempfile.mkdtemp(prefix='x1-z-font-completion-')).resolve()
    print('EVIDENCE='+str(out), flush=True)
    order = re.findall(r'^set_global_assignment -name (?:SYSTEMVERILOG_FILE|VERILOG_FILE) (\S+)\s*$',
                       (ROOT/'rtl/machine.qip').read_text(), re.M)
    own = ['verilator/tests/test_z_font_completion.py', 'verilator/tests/z_font_completion_tb.sv',
           'verilator/tests/test_z_external_font_machine.py', 'verilator/tests/z80_fixture.py',
           'verilator/tests/z_kanji_machine_assets.py', 'rtl/machine.qip',
           'bios/reference/fw_subcpu/verilog/X1SUB.BIN']
    hashes = {n: sha(ROOT/n) for n in dict.fromkeys(order+own)}
    for n, digest in hashes.items():
        p = out/'sources'/n
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes((ROOT/n).read_bytes())
        assert sha(p) == digest

    def frozen(relative, name):
        spec = importlib.util.spec_from_file_location(name, out/'sources'/relative)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    assets = frozen(own[4], 'completion_assets')
    base = frozen(own[2], 'completion_base')
    base.assets = assets
    base.Program = frozen(own[3], 'completion_z80').Program
    report = {'status': 'running', 'source_sha256': hashes, 'cases': [],
              'clocks': {'SYS_period_ps': 31250, 'VID_period_ps': 23280},
              'scope': __doc__, 'tool': subprocess.check_output(['verilator', '--version'], text=True).strip()}

    def save():
        (out/'terminal.json').write_text(json.dumps(report, indent=2)+'\n')

    save()
    try:
        obj = out/'obj'
        cmd = ['verilator', '--binary', '--timing', '--assert', '-Wno-fatal',
               '--top-module', 'z_font_completion_tb', '--Mdir', str(obj), '-j', '2',
               str(out/'sources'/own[1])]+[str(out/'sources'/n) for n in order]
        with (out/'build.log').open('w') as log:
            result = subprocess.run(cmd, cwd=out/'sources', stdout=log, stderr=subprocess.STDOUT, timeout=240)
        report['build_exit'] = result.returncode
        report['build_log_sha256'] = sha(out/'build.log')
        save()
        assert result.returncode == 0, 'compile failure is not rejection'
        warnings = [s for s in (out/'build.log').read_text().splitlines() if s.startswith('%Warning')]
        report['warnings'] = warnings
        assert not any(re.search(r'%Warning-(IMPLICIT|MULTIDRIVEN|UNOPTFLAT|LATCH):', s) for s in warnings), warnings
        assert not any('z_font_completion_tb.sv:' in s for s in warnings), warnings
        exe = obj/'Vz_font_completion_tb'
        report['executable_sha256'] = sha(exe)
        save()
        for columns, bad in ((80, False), (80, True), (40, False), (40, True)):
            folder = out/f'cols{columns}-bad{int(bad)}'
            folder.mkdir()
            rom = program(columns, bad)
            (folder/'diagnostic.rom').write_bytes(rom)
            (folder/'ipl.hex').write_text(''.join(f'{v:02x}\n' for v in rom))
            (folder/'font.hex').write_text(''.join(f'{assets.pattern(a):02x}\n' for a in range(262144)))
            case = {'columns': columns, 'bad_final_compare': bad, 'ipl_sha256': sha(folder/'diagnostic.rom')}
            report['cases'].append(case)
            save()
            cmd = [str(exe), '+FONT='+str(folder/'font.hex'), '+IPL='+str(folder/'ipl.hex'),
                   '+OUTPUT='+str(folder), '+COLUMNS='+str(columns), '+BAD='+str(int(bad))]
            with (folder/'run.log').open('w') as log:
                result = subprocess.run(cmd, cwd=out/'sources', stdout=log, stderr=subprocess.STDOUT, timeout=180)
            case.update(exit=result.returncode, log_sha256=sha(folder/'run.log'))
            save()
            log = (folder/'run.log').read_text()
            assert result.returncode == 0 and len(re.findall(r'^PASS Z_COMPLETION ', log, re.M)) == 1, log[-2500:]
            actual = bytearray()
            for n, row in enumerate(csv.DictReader((folder/'frame-0.csv').open())):
                assert (int(row['y']), int(row['x'])) == divmod(n, columns*8)
                v = int(row['rgb12'], 16)
                actual.extend(((v >> 8 & 15)*17, (v >> 4 & 15)*17, (v & 15)*17))
            assert len(actual) == columns*8*400*3
            completion_oracle = expected_frame(columns, True)
            matched = actual == completion_oracle
            assert matched != bad, 'Z_COMPLETION_UNCHANGED_PIXEL_ORACLE'
            assert actual == expected_frame(columns, not bad), 'Z_COMPLETION_EXACT_CONTROL_PIXELS'
            (folder/'frame.png').write_bytes(png(columns*8, 400, actual))
            events = list(csv.DictReader((folder/'events.csv').open()))
            reads = [r for r in events if r['event'] == 'read']
            expected_data = [0x18, 0xa6]+[assets.pattern(level*131072+bank*8192+255*32+row*2+half)
                         for level, bank, half in ((0, 0, 0), (1, 15, 1)) for row in range(16)]
            expected_data += [v for c in (0, 999, 1999, 2046) for v in assets.cells(c)]
            expected_ports = [0x1400, 0x1500]+list(range(0x1400, 0x1410))*2
            expected_ports += [port | c for c in (0, 999, 1999, 2046) for port in (0x3000, 0x3800, 0x2800)]
            assert [int(r['data']) for r in reads] == expected_data, 'Z_COMPLETION_CPU_READ_VALUES'
            assert [int(r['address']) for r in reads] == expected_ports, 'Z_COMPLETION_CPU_READ_PORTS'
            commits = [r for r in events if r['event'] == 'commit']
            assert len(commits) == 6153+int(not bad)
            if not bad:
                assert (commits[-1]['address'], commits[-1]['select'], commits[-1]['data']) == ('0', '2', '7')
                assert int(commits[-1]['cycle']) > int(reads[-1]['cycle']), 'Z_COMPLETION_MARKER_ORDER'
            case.update(positive_completion_oracle_matched=matched, exact_pixels=len(actual)//3,
                        pass_line=re.findall(r'^PASS Z_COMPLETION .+$', log, re.M)[0],
                        rgb_sha256=hashlib.sha256(actual).hexdigest(), verified=True)
            case['artifacts'] = {p.name: sha(p) for p in folder.iterdir() if p.is_file()}
            save()
            print('PASS '+str(columns)+' bad='+str(int(bad)), flush=True)
        report['status'] = 'pass'
    except BaseException as error:
        report.update(status='fail', error=repr(error))
        raise
    finally:
        report['unchanged'] = all(sha(ROOT/n) == sha(out/'sources'/n) == digest for n, digest in hashes.items())
        if not report['unchanged']:
            report['status'] = 'fail'
        save()
        assert report['unchanged'], 'qualification inputs changed'
    print('PASS Z_COMPLETION_FROZEN_GATE '+str(out), flush=True)


if __name__ == '__main__':
    main()
