#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Observe base-IPL startup with explicit third-plane initialization controls.

The generated entry shims are diagnostics, not unmodified native firmware.
Original ROM/media and installed cores are preserved. No RTL change is made.
"""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import shlex
import shutil
import sys
import time
import urllib.parse
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / 'scripts'), str(ROOT / 'verilator/tests')]
from mister_basic_reset import DirectBridge
from compare_video_png import rgb_png
from check_basic_reference import BANNER, check_rows
from check_basic_print42 import font_bytes
import mister_x1


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def diagnostic_ipl(base, initialize):
    assert len(base) == 4096 and base[:3] == bytes.fromhex('c30600')
    image = bytearray(base + b'\xff' * 28672)
    image[:3] = bytes.fromhex('c30010')  # Generated shim at 1000, then native 0006.
    prefix = bytes.fromhex('f3 210000 010038 110008')
    loop = bytes.fromhex('ed61 03 1b 7a b3 20f8')
    if not initialize:
        loop = b'\x00\x00' + loop[2:]  # Omit only OUT (C),H; preserve loop/ports.
    shim = prefix + loop + bytes.fromhex('c30600')
    image[0x1000:0x1000 + len(shim)] = shim
    assert image[3:4096] == base[3:]
    assert image[0x1000 + len(shim):] == b'\xff' * (32768 - 0x1000 - len(shim))
    return bytes(image)


def main():
    if not __debug__:
        raise SystemExit('assertions must be enabled')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--host', default='mister14')
    args = parser.parse_args()
    parent = ROOT / 'output_files/BASIC_IPL_20261016T030331Z'
    prior_path = parent / 'restored-turbo/manifest.json'
    prior = json.loads(prior_path.read_text())
    compiler_path = ROOT / 'output_files/X1OSD_20261015T190610Z/manifest.json'
    compiler = json.loads(compiler_path.read_text())
    assert prior['status'] == 'pass'
    b = DirectBridge('', args.host)
    current = b.status()
    assert current == prior['final_status'], 'MiSTer ownership changed'
    assert b.hashes(list(prior['remote_files'])) == prior['remote_files']
    assert all(sha(ROOT / n) == h for n, h in compiler['compiler_inputs'].items())
    out = args.out.resolve()
    out.mkdir()
    assets = out / 'assets'
    assets.mkdir()
    origins = {n: parent / 'assets' / n for n in ('base.rom', 'physical.rom', 'basic.d88', 'core.rbf')}
    for name, path in origins.items():
        shutil.copyfile(path, assets / name)
    assert sha(assets / 'core.rbf') == compiler['rbf_sha256'] == 'fd9a085061a5fa5f6cc3c929a37f5b266d2391b5dd1b14752f3d8f794db83692'
    assert sha(assets / 'base.rom') == 'e6295a523008688421991b651ab61de392b28c67bec9efbf040b0004e4b70a2a'
    assert sha(assets / 'basic.d88') == 'ef47f5df772f45d97be43646d8f8010d33eca8846913babfd1106e89a361ee6a'
    for initialize, name in ((False, 'skip.rom'), (True, 'initialize.rom')):
        (assets / name).write_bytes(diagnostic_ipl((assets / 'base.rom').read_bytes(), initialize))
    sources = [Path(__file__).resolve(), ROOT / 'scripts/mister_basic_reset.py',
               ROOT / 'scripts/mister_x1.py', ROOT / 'scripts/mister_z_font_osd_reset.py',
               ROOT / 'scripts/compare_video_png.py', ROOT / 'verilator/tests/check_basic_reference.py',
               ROOT / 'verilator/tests/check_basic_print42.py', ROOT / 'rtl/legacy/x1_cg8.v']
    frozen = out / 'sources'
    frozen.mkdir()
    for path in sources:
        shutil.copyfile(path, frozen / path.name)
    inputs = {str(p): sha(p) for p in [*sources, *origins.values(), prior_path, compiler_path]}
    g = font_bytes(ROOT / 'rtl/legacy/x1_cg8.v')
    font = bytes(g[i] for i in range(2048))
    name = 'X1BMETA_' + datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    remote = '/media/fat/games/SharpX1/HWTest/' + name
    cores = '/media/fat/_Computer/' + name
    cases = []
    for repeat in range(2):
        for initialize in (False, True):
            title = f'{len(cases) + 1:02d}_' + ('InitializeKan' if initialize else 'SkipKan')
            setname = name + f'_{len(cases) + 1:02d}'
            folder = out / title
            folder.mkdir()
            tree = ET.Element('mistergamedescription')
            ET.SubElement(tree, 'rbf').text = cores.removeprefix('/media/fat/') + '/core'
            ET.SubElement(tree, 'setname', {'same_dir': '1'}).text = setname
            for index, filename in ((0, 'initialize.rom' if initialize else 'skip.rom'), (5, 'physical.rom')):
                ET.SubElement(tree, 'file', {'delay': '2', 'type': 'f', 'index': str(index), 'path': remote + '/' + filename})
            diskname = title + '.d88'
            shutil.copyfile(assets / 'basic.d88', out / diskname)
            ET.SubElement(tree, 'file', {'delay': '2', 'type': 's', 'index': '0', 'path': remote + '/' + diskname})
            ET.SubElement(tree, 'reset', {'delay': '1'})
            (folder / (title + '.mgl')).write_bytes(ET.tostring(tree) + b'\n')
            (folder / (setname + '.CFG')).write_bytes(bytes(16))
            cases.append({'title': title, 'repeat': repeat, 'initialize_kan': initialize,
                          'setname': setname, 'mgl': cores + '/' + title + '.mgl',
                          'disk': remote + '/' + diskname, 'status': 'planned', 'actions': [], 'screenshots': []})
    m = {'status': 'staging', 'scope': 'Generated diagnostic base-IPL entry shims, not unmodified native base acceptance; no RTL or timing change',
         'inputs': inputs, 'compiler_inputs': compiler['compiler_inputs'], 'main_sha256': compiler['main_sha256'],
         'asset_hashes': {p.name: sha(p) for p in assets.iterdir()}, 'initial_status': current,
         'restore_mgl': prior['mgl'], 'restore_status': current, 'cases': cases}

    def save():
        (out / 'manifest.json').write_text(json.dumps(m, indent=2) + '\n')

    def key(case, code):
        assert b.status()['CORENAME'] == case['setname']
        case['actions'].append({'key': code, 'utc': datetime.datetime.now(datetime.timezone.utc).isoformat()})
        save()
        b.key(code)

    def capture(case, phase):
        before = {s['path'] for s in json.loads(b.api('GET', 'screenshots'))}
        b.api('POST', 'controls/keyboard/raw_screenshot')
        time.sleep(3)
        fresh = [s for s in json.loads(b.api('GET', 'screenshots')) if s['path'] not in before]
        assert fresh
        for i, record in enumerate(fresh):
            path = out / case['title'] / f'{phase}-{i:02d}.png'
            path.open('xb').write(b.api('GET', 'screenshots/' + urllib.parse.quote(record['path'], safe='/')))
            dimensions, pixels = rgb_png(path)
            s = {'phase': phase, 'file': str(path.relative_to(out)), 'sha256': sha(path),
                 'mrext': record, 'completion': False, 'all_black': not any(pixels)}
            case['screenshots'].append(s)
            try:
                s['banner'] = check_rows(dimensions, pixels, font, 4, (BANNER,), 1)
                s['transcript'] = check_rows(dimensions, pixels, font, 13, (b'PRINT 6*7', b' 42', b'Ok'), 1)
            except AssertionError as error:
                s['oracle_rejection'] = str(error)
            else:
                s['completion'] = True
            if phase == 'no-enter':
                assert not s['completion']
            if phase == 'arithmetic':
                case['native_interpreter_completion'] = s['completion']
            save()

    save()
    try:
        mister_x1.ssh(args.host, 'test ! -e ' + shlex.quote(remote) + ' && test ! -e ' + shlex.quote(cores)
                      + ' && mkdir -p ' + shlex.quote(remote) + ' ' + shlex.quote(cores))
        remote_files = {}
        for filename in ('skip.rom', 'initialize.rom', 'physical.rom', 'core.rbf'):
            target = cores + '/core.rbf' if filename == 'core.rbf' else remote + '/' + filename
            mister_x1.put(args.host, assets / filename, target)
            remote_files[target] = sha(assets / filename)
        for case in cases:
            folder = out / case['title']
            for path, target in ((folder / (case['title'] + '.mgl'), case['mgl']),
                                 (out / (case['title'] + '.d88'), case['disk']),
                                 (folder / (case['setname'] + '.CFG'), '/media/fat/config/' + case['setname'] + '.CFG')):
                mister_x1.put(args.host, path, target)
                remote_files[target] = sha(path)
        m['remote_files'] = remote_files
        assert b.hashes(list(remote_files)) == remote_files
        m['status'] = 'running'
        save()
        for case in cases:
            assert b.status() == current, 'MiSTer ownership changed'
            case['status'] = 'running'
            save()
            b.load(case['mgl'])
            time.sleep(25)
            current = b.status()
            assert current['CORENAME'] == case['setname'] and current['RBFNAME'] == 'SharpX1'
            capture(case, 'before-F')
            key(case, 33)
            time.sleep(20)
            capture(case, 'after-F')
            for code in (14, 25, 19, 23, 49, 20, 57, 7, 55, 8):
                key(case, code)
            capture(case, 'no-enter')
            key(case, 28)
            capture(case, 'arithmetic')
            assert b.ddr_hash() == m['asset_hashes']['physical.rom']
            assert b.hashes([case['disk']])[case['disk']] == m['asset_hashes']['basic.d88']
            assert b.status() == current
            case.update(status='observed', post_test=current)
            save()
            print('BASIC_METADATA_OBSERVED', case['title'], case['native_interpreter_completion'], flush=True)
        expected_remote = {p: h for p, h in remote_files.items() if not p.endswith('.CFG')}
        expected_remote['/media/fat/MiSTer'] = m['main_sha256']
        assert b.hashes(list(expected_remote)) == expected_remote
        assert all(sha(p) == h for p, h in inputs.items())
        assert all(sha(ROOT / n) == h for n, h in m['compiler_inputs'].items())
        m.update(status='observed', final_status=current)
        save()
    except BaseException as error:
        m.update(status='fail', error=repr(error))
        save()
        raise


if __name__ == '__main__':
    main()
