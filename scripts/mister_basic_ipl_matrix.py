#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Observe matched native BASIC IPL/ANK16 cold boots on the qualified RBF.

Every case has a new setname/config/protected disk copy and the same complete
synthetic font. Missing native completion is an observation, not a regression
PASS or a hardware-defect diagnosis. Processes/transport errors fail the gate.
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

RBF_SHA = 'fd9a085061a5fa5f6cc3c929a37f5b266d2391b5dd1b14752f3d8f794db83692'
DISK_SHA = 'ef47f5df772f45d97be43646d8f8010d33eca8846913babfd1106e89a361ee6a'
ROWS = (b'PRINT 6*7', b' 42', b'Ok')
KEYS = (14, 25, 19, 23, 49, 20, 57, 7, 55, 8)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    if not __debug__:
        raise SystemExit('Assertions are required')
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--host', default='mister14')
    p.add_argument('--previous', type=Path, required=True)
    p.add_argument('--compiler-manifest', type=Path, required=True)
    p.add_argument('--base-ipl', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--repeats', type=int, choices=(1, 2), default=2)
    args = p.parse_args()
    previous = args.previous.resolve()
    old = json.loads((previous / 'manifest.json').read_text())
    deploy = Path(old['deployment'])
    d = json.loads((deploy / 'manifest.json').read_text())
    c = json.loads(args.compiler_manifest.read_text())
    assert old['status'] == 'pass' and d['rbf_sha256'] == c['rbf_sha256'] == RBF_SHA
    assert d['disk_sha256'] == DISK_SHA and old['final_status']['CORENAME'] == deploy.name
    b = DirectBridge('', args.host)
    current = b.status()
    assert current == old['final_status'], 'MiSTer ownership changed'
    assert b.hashes(list(old['remote_expected'])) == old['remote_expected']
    assert all(sha(ROOT / n) == h for n, h in c['compiler_inputs'].items())
    out = args.output.resolve()
    out.mkdir()
    assets = out / 'assets'
    assets.mkdir()
    base = args.base_ipl.resolve()
    assert len(base.read_bytes()) == 4096
    assert sha(base) == 'e6295a523008688421991b651ab61de392b28c67bec9efbf040b0004e4b70a2a'
    origins = {'base.rom': base, 'turbo.rom': deploy / 'ipl.rom',
               'ank16.rom': deploy / 'font16.rom', 'physical.rom': deploy / 'physical-font.rom',
               'basic.d88': Path(d['disk']), 'core.rbf': Path(d['rbf'])}
    for name, path in origins.items():
        shutil.copyfile(path, assets / name)
    assert sha(assets / 'core.rbf') == RBF_SHA and sha(assets / 'basic.d88') == DISK_SHA
    assert sha(assets / 'turbo.rom') == d['ipl_sha256']
    for index, name in ((4, 'ank16.rom'), (5, 'physical.rom')):
        assert sha(assets / name) == next(u['sha256'] for u in d['extra_uploads'] if u['index'] == index)
    sources = [Path(__file__).resolve(), ROOT / 'scripts/mister_basic_reset.py',
               ROOT / 'scripts/mister_x1.py', ROOT / 'scripts/mister_z_font_osd_reset.py',
               ROOT / 'scripts/compare_video_png.py', ROOT / 'verilator/tests/check_basic_reference.py',
               ROOT / 'verilator/tests/check_basic_print42.py', ROOT / 'rtl/legacy/x1_cg8.v']
    frozen = out / 'sources'
    frozen.mkdir()
    for path in sources:
        shutil.copyfile(path, frozen / path.name)
    inputs = {str(p): sha(p) for p in [*sources, *origins.values()]}
    g = font_bytes(ROOT / 'rtl/legacy/x1_cg8.v')
    font = bytes(g[i] for i in range(2048))
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    name = 'X1BIPL_' + stamp
    remote = '/media/fat/games/SharpX1/HWTest/' + name
    cores = '/media/fat/_Computer/' + name
    files = {'core.rbf': assets / 'core.rbf'}
    plans = []
    for repeat in range(args.repeats):
        for turbo, ank in ((False, False), (True, False), (False, True), (True, True)):
            number = len(plans) + 1
            title = f'{number:02d}_' + ('Turbo' if turbo else 'Base') + ('_ANK16' if ank else '_NoANK16')
            setname = name + f'_{number:02d}'
            folder = out / title
            folder.mkdir()
            uploads = [(0, 'turbo.rom' if turbo else 'base.rom')]
            if ank:
                uploads.append((4, 'ank16.rom'))
            uploads.append((5, 'physical.rom'))
            tree = ET.Element('mistergamedescription')
            ET.SubElement(tree, 'rbf').text = cores.removeprefix('/media/fat/') + '/core'
            ET.SubElement(tree, 'setname', {'same_dir': '1'}).text = setname
            for index, filename in uploads:
                ET.SubElement(tree, 'file', {'delay': '2', 'type': 'f', 'index': str(index),
                                           'path': remote + '/' + filename})
            # Every case has its own identical protected-status disk copy.
            diskname = title + '.d88'
            shutil.copyfile(assets / 'basic.d88', out / diskname)
            ET.SubElement(tree, 'file', {'delay': '2', 'type': 's', 'index': '0', 'path': remote + '/' + diskname})
            ET.SubElement(tree, 'reset', {'delay': '1'})
            mgl = folder / (title + '.mgl')
            mgl.write_bytes(ET.tostring(tree) + b'\n')
            cfg = folder / (setname + '.CFG')
            cfg.write_bytes(bytes(16))
            plans.append({'title': title, 'repeat': repeat, 'turbo': turbo, 'ank16': ank,
                          'setname': setname, 'mgl': cores + '/' + title + '.mgl', 'disk': remote + '/' + diskname,
                          'actions': [], 'screenshots': [], 'status': 'planned'})
    m = {'status': 'staging', 'name': name, 'previous': str(previous),
         'previous_manifest_sha256': sha(previous / 'manifest.json'), 'initial_status': current,
         'inputs': inputs, 'compiler_inputs': c['compiler_inputs'], 'main_sha256': c['main_sha256'],
         'asset_hashes': {p.name: sha(p) for p in assets.iterdir()}, 'cases': plans,
         'scope': 'Matched cold BASIC IPL/ANK16 upload observations; no measured hardware timing or general compatibility claim'}

    def save():
        (out / 'manifest.json').write_text(json.dumps(m, indent=2) + '\n')

    def key(case, code):
        assert b.status()['CORENAME'] == case['setname']
        case['actions'].append({'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'key': code})
        save()
        b.key(code)

    def capture(case, phase, completion=False, negative=False):
        before = {s['path'] for s in json.loads(b.api('GET', 'screenshots'))}
        b.api('POST', 'controls/keyboard/raw_screenshot')
        time.sleep(3)
        fresh = [s for s in json.loads(b.api('GET', 'screenshots')) if s['path'] not in before]
        assert fresh, 'No fresh raw mrext PNG'
        for i, record in enumerate(fresh):
            path = out / case['title'] / f'{phase}-{i:02d}.png'
            path.open('xb').write(b.api('GET', 'screenshots/' + urllib.parse.quote(record['path'], safe='/')))
            dimensions, pixels = rgb_png(path)
            observed = {'phase': phase, 'file': str(path.relative_to(out)), 'sha256': sha(path),
                        'mrext': record, 'dimensions': dimensions, 'completion': False}
            case['screenshots'].append(observed)
            save()
            try:
                banner = check_rows(dimensions, pixels, font, 4, (BANNER,), 1)
                result = check_rows(dimensions, pixels, font, 13, ROWS, 1)
            except AssertionError as error:
                observed['oracle_rejection'] = str(error)
            else:
                observed.update(completion=True, banner=banner, transcript=result)
            if negative:
                assert not observed['completion'], 'Missing-Enter control completed native arithmetic'
            if completion:
                case['native_completion'] = observed['completion']
            save()

    save()
    try:
        # Reuse no installed paths: all core/config/media/MGL files are unique.
        mister_x1.ssh(args.host, 'test ! -e ' + shlex.quote(remote) + ' && test ! -e ' +
                      shlex.quote(cores) + ' && mkdir -p ' + shlex.quote(remote) + ' ' + shlex.quote(cores))
        remote_files = {}
        for filename, path in [(p.name, p) for p in assets.iterdir() if p.name != 'basic.d88']:
            target = cores + '/core.rbf' if filename == 'core.rbf' else remote + '/' + filename
            mister_x1.put(args.host, path, target)
            remote_files[target] = sha(path)
        for case in plans:
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
        for case in plans:
            assert b.status() == current, 'MiSTer ownership changed'
            assert b.hashes([cores + '/core.rbf'])[cores + '/core.rbf'] == RBF_SHA
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
            # Identical public keys in all four profiles. Backspace removes
            # F if an auto-booting IPL had already reached the prompt.
            for code in KEYS:
                key(case, code)
            capture(case, 'no-enter', negative=True)
            key(case, 28)
            capture(case, 'arithmetic', completion=True)
            assert b.ddr_hash() == m['asset_hashes']['physical.rom']
            assert b.hashes([case['disk']])[case['disk']] == DISK_SHA
            case['status'] = 'observed'
            case['post_test'] = b.status()
            assert case['post_test'] == current
            save()
            print('BASIC_IPL_OBSERVED', case['title'], case['native_completion'], flush=True)
        assert b.hashes([p for p in remote_files if not p.endswith('.CFG')]) == {
            p: h for p, h in remote_files.items() if not p.endswith('.CFG')}
        assert all(sha(Path(p)) == h for p, h in inputs.items())
        assert all(sha(ROOT / n) == h for n, h in c['compiler_inputs'].items())
        assert b.hashes(['/media/fat/MiSTer'])['/media/fat/MiSTer'] == c['main_sha256']
        m['final_status'] = current
        m['status'] = 'observed'
    except BaseException as error:
        m.update(status='fail', error=repr(error))
        raise
    finally:
        save()


if __name__ == '__main__':
    main()
