#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Source-bound unmodified base/Turbo IPL cold and retained-reset BASIC gate."""
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
from mister_basic_reset import DirectBridge, ARITHMETIC, WARM_R, WARM_T, PROGRAM, KEYS
from compare_video_png import rgb_png
from check_basic_reference import BANNER, check_rows
from check_basic_print42 import font_bytes
import mister_x1


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    assert __debug__, 'Assertions are required'
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--host', default='mister14')
    p.add_argument('--build-audit', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    audit = json.loads(args.build_audit.read_text())
    assert audit['status'] == 'pass' and audit['build_exit_status'] == 0
    assert len(audit['compiler_inputs']) == 428
    assert all(sha(ROOT / n) == h for n, h in audit['compiler_inputs'].items())
    assert sha(audit['rbf']) == audit['rbf_sha256']
    prior_path = ROOT / 'output_files/BASIC_METADATA_20261016T1435/restored-native-turbo/manifest.json'
    prior = json.loads(prior_path.read_text())
    b = DirectBridge('', args.host)
    current = b.status()
    assert prior['status'] == 'pass' and current == prior['final_status'], 'MiSTer ownership changed'
    assert b.hashes(list(prior['remote_checks'])) == prior['remote_checks']
    out = args.output.resolve()
    out.mkdir()
    assets = out / 'assets'
    assets.mkdir()
    old_assets = ROOT / 'output_files/BASIC_IPL_20261016T030331Z/assets'
    origins = {n: old_assets / n for n in ('base.rom', 'turbo.rom', 'ank16.rom', 'physical.rom', 'basic.d88')}
    origins['core.rbf'] = Path(audit['rbf'])
    for name, path in origins.items():
        shutil.copyfile(path, assets / name)
    assert len((assets / 'base.rom').read_bytes()) == 4096
    assert sha(assets / 'base.rom') == 'e6295a523008688421991b651ab61de392b28c67bec9efbf040b0004e4b70a2a'
    assert sha(assets / 'turbo.rom') == '212895703175665be8544daa55b65da1aebcf1e9a2db65bcc1622e564b802b71'
    assert sha(assets / 'basic.d88') == 'ef47f5df772f45d97be43646d8f8010d33eca8846913babfd1106e89a361ee6a'
    sources = [Path(__file__).resolve(), ROOT / 'scripts/mister_basic_reset.py',
               ROOT / 'scripts/mister_x1.py', ROOT / 'scripts/mister_z_font_osd_reset.py',
               ROOT / 'scripts/compare_video_png.py', ROOT / 'verilator/tests/check_basic_reference.py',
               ROOT / 'verilator/tests/check_basic_print42.py', ROOT / 'rtl/legacy/x1_cg8.v']
    frozen = out / 'sources'
    frozen.mkdir()
    for path in sources:
        shutil.copyfile(path, frozen / path.name)
    inputs = {str(path.resolve()): sha(path) for path in [*sources, *origins.values(), prior_path, args.build_audit]}
    g = font_bytes(ROOT / 'rtl/legacy/x1_cg8.v')
    font = bytes(g[i] for i in range(2048))
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    name = 'X1BTEXT_' + stamp
    remote = '/media/fat/games/SharpX1/HWTest/' + name
    cores = '/media/fat/_Computer/' + name
    cases = []
    for repeat in range(2):
        for turbo in (True, False):
            number = len(cases) + 1
            title = f'{number:02d}_' + ('Turbo' if turbo else 'Base')
            setname = name + f'_{number:02d}'
            folder = out / title
            folder.mkdir()
            tree = ET.Element('mistergamedescription')
            ET.SubElement(tree, 'rbf').text = cores.removeprefix('/media/fat/') + '/core'
            ET.SubElement(tree, 'setname', {'same_dir': '1'}).text = setname
            for index, filename in ((0, 'turbo.rom' if turbo else 'base.rom'), (4, 'ank16.rom'), (5, 'physical.rom')):
                ET.SubElement(tree, 'file', {'delay': '2', 'type': 'f', 'index': str(index), 'path': remote + '/' + filename})
            diskname = title + '.d88'
            shutil.copyfile(assets / 'basic.d88', out / diskname)
            ET.SubElement(tree, 'file', {'delay': '2', 'type': 's', 'index': '0', 'path': remote + '/' + diskname})
            ET.SubElement(tree, 'reset', {'delay': '1'})
            (folder / (title + '.mgl')).write_bytes(ET.tostring(tree) + b'\n')
            (folder / (setname + '.CFG')).write_bytes(bytes(16))
            cases.append(dict(title=title, repeat=repeat, turbo=turbo, setname=setname,
                              mgl=cores + '/' + title + '.mgl', disk=remote + '/' + diskname,
                              status='planned', actions=[], screenshots=[]))
    m = dict(status='staging', scope='Unmodified native base/Turbo IPL arithmetic cold repeats and base Main R/T retained resets; synthetic full font, no timing/native Kanji/SAVE/LOAD acceptance',
             build_audit=str(args.build_audit.resolve()), inputs=inputs, compiler_inputs=audit['compiler_inputs'],
             rbf_sha256=audit['rbf_sha256'], asset_hashes={p.name: sha(p) for p in assets.iterdir()},
             initial_status=current, main_sha256=prior['remote_checks']['/media/fat/MiSTer'], cases=cases)

    def save():
        (out / 'manifest.json').write_text(json.dumps(m, indent=2) + '\n')

    def key(case, code):
        assert b.status() == current, 'MiSTer ownership changed'
        case['actions'].append(dict(key=code, utc=datetime.datetime.now(datetime.timezone.utc).isoformat()))
        save()
        b.key(code)

    def type_text(case, text):
        for character in text:
            key(case, KEYS[character])

    def capture(case, phase, rows=None, first=13, reject=None, banner=True):
        before = {s['path'] for s in json.loads(b.api('GET', 'screenshots'))}
        b.api('POST', 'controls/keyboard/raw_screenshot')
        time.sleep(3)
        fresh = [s for s in json.loads(b.api('GET', 'screenshots')) if s['path'] not in before]
        assert fresh, 'No fresh raw mrext PNG'
        for i, record in enumerate(fresh):
            path = out / case['title'] / f'{phase}-{i:02d}.png'
            path.open('xb').write(b.api('GET', 'screenshots/' + urllib.parse.quote(record['path'], safe='/')))
            dimensions, pixels = rgb_png(path)
            s = dict(phase=phase, file=str(path.relative_to(out)), sha256=sha(path), mrext=record,
                     dimensions=dimensions)
            case['screenshots'].append(s)
            save()
            if banner:
                s['banner'] = check_rows(dimensions, pixels, font, 4, (BANNER,), 1)
            if rows is not None:
                s['transcript'] = check_rows(dimensions, pixels, font, first, rows, 1)
            if reject is not None:
                try:
                    check_rows(dimensions, pixels, font, 13, reject, 1)
                except AssertionError as error:
                    s['unchanged_completion_rejected'] = str(error)
                else:
                    raise AssertionError('Control satisfied unchanged completion oracle')
            save()
        print('PASS_BASE_TEXT_HARDWARE', case['title'], phase, flush=True)

    def navigate(case, up, select):
        key(case, 88)
        for _ in range(up):
            key(case, 103)
        key(case, 28 if select else 88)

    save()
    try:
        mister_x1.ssh(args.host, 'test ! -e ' + shlex.quote(remote) + ' && test ! -e ' +
                      shlex.quote(cores) + ' && mkdir -p ' + shlex.quote(remote) + ' ' + shlex.quote(cores))
        remote_files = {}
        for path in assets.iterdir():
            if path.name == 'basic.d88':
                continue
            target = cores + '/core.rbf' if path.name == 'core.rbf' else remote + '/' + path.name
            mister_x1.put(args.host, path, target)
            remote_files[target] = sha(path)
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
            b.load(case['mgl'])
            time.sleep(25)
            current = b.status()
            assert current == dict(CORENAME=case['setname'], RBFNAME='SharpX1', ACTIVEGAME='')
            capture(case, 'before-F', banner=False)
            key(case, 33)
            time.sleep(20)
            capture(case, 'after-F')
            key(case, 14)
            type_text(case, 'PRINT 6*7')
            capture(case, 'no-enter', reject=ARITHMETIC)
            key(case, 28)
            capture(case, 'arithmetic', ARITHMETIC)
            assert b.ddr_hash() == m['asset_hashes']['physical.rom']
            assert b.hashes([case['disk']])[case['disk']] == m['asset_hashes']['basic.d88']
            case.update(status='pass', post_test=b.status())
            assert case['post_test'] == current
            save()
        # No subsequent core load, remount or asset upload: Main performs both resets.
        case = cases[-1]
        navigate(case, 2, False)
        capture(case, 'menu-no-selection', ARITHMETIC, reject=WARM_R)
        type_text(case, 'PRINT 9*9\n')
        capture(case, 'no-reset', WARM_R, 16, WARM_R)
        navigate(case, 2, True)
        time.sleep(18)
        type_text(case, 'PRINT 9*9\n')
        capture(case, 'R-reset-and-close', WARM_R)
        navigate(case, 3, True)
        time.sleep(18)
        key(case, 88)
        type_text(case, 'PRINT 8*8\n')
        capture(case, 'T-reset', WARM_T)
        type_text(case, '10 PRINT 9\nLIST\nRUN\n')
        capture(case, 'stored-program', PROGRAM, 16)
        expected = {p: h for p, h in remote_files.items() if not p.endswith('.CFG')}
        expected['/media/fat/MiSTer'] = m['main_sha256']
        assert b.hashes(list(expected)) == expected
        assert b.ddr_hash() == m['asset_hashes']['physical.rom']
        assert all(sha(p) == h for p, h in inputs.items())
        assert all(sha(ROOT / n) == h for n, h in m['compiler_inputs'].items())
        assert b.status() == current
        m.update(status='pass', final_status=current,
                 exact_pixels=sum(s[k]['checked_pixels'] for c in cases for s in c['screenshots']
                                  for k in ('banner', 'transcript') if k in s))
    except BaseException as error:
        m.update(status='fail', error=repr(error))
        raise
    finally:
        save()


if __name__ == '__main__':
    main()
