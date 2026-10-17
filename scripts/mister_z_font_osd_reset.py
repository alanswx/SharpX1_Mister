#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Source-bound external-font OSD reset qualification through Main and mrext.

Stage from an accepted active-reset manifest, then run the matrix and audit.
Each case loads a unique MGL once; subsequent actions are keyboard taps,
raw screenshots and read-only observations. No Main configuration is changed.
"""
import argparse
import base64
import datetime
import hashlib
import html
import io
import json
from pathlib import Path
import shlex
import shutil
import subprocess
import tarfile
import time
import urllib.parse
import xml.etree.ElementTree as ET

from compare_video_png import rgb_png

ROOT = Path(__file__).resolve().parents[1]
SELF = Path(__file__).resolve()
DECODER = ROOT / 'scripts/compare_video_png.py'
RBF_SHA256 = 'fd9a085061a5fa5f6cc3c929a37f5b266d2391b5dd1b14752f3d8f794db83692'
MAIN_NAMES = ('menu.cpp', 'user_io.cpp', 'input.cpp')


def digest(data):
    return hashlib.sha256(data).hexdigest()


def sha(path):
    return digest(path.read_bytes())


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def save(out, manifest):
    (out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')


class Bridge:
    def __init__(self, builder, host):
        self.builder, self.host = builder, host

    def shell(self, command):
        return subprocess.run(['ssh', '-o', 'BatchMode=yes', self.builder, command],
                              check=True, capture_output=True, timeout=55).stdout

    def python(self, code):
        return self.shell(shlex.join(['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=8',
                                     'root@' + self.host, shlex.join(['python3', '-c', code])]))

    def status(self):
        return json.loads(self.python(
            "import pathlib,json; print(json.dumps({n:pathlib.Path('/tmp/'+n).read_text() "
            "if pathlib.Path('/tmp/'+n).exists() else None "
            "for n in ['CORENAME','RBFNAME','ACTIVEGAME']}))"))

    def api(self, method, path):
        url = 'http://127.0.0.1:8182/api/' + path
        code = ('import urllib.request,base64; '
                'r=urllib.request.urlopen(urllib.request.Request(' + repr(url) + ',method=' +
                repr(method) + '),timeout=35); print(base64.b64encode(r.read()).decode())')
        return base64.b64decode(self.python(code))

    def key(self, code):
        self.api('POST', 'controls/keyboard-raw/' + str(code))
        time.sleep(0.25)

    def load(self, mgl):
        self.python("with open('/dev/MiSTer_cmd','w') as f: f.write(" + repr('load_core ' + mgl + '\n') + ')')

    def hashes(self, paths):
        return json.loads(self.python('import pathlib,hashlib,json; names=' + repr(paths) +
                                     '; print(json.dumps({n:hashlib.sha256(pathlib.Path(n).read_bytes()).hexdigest() for n in names}))'))

    def ddr_hash(self):
        # This font reservation is outside the installed Linux mem=511M map.
        return self.python("import os,mmap,hashlib; f=os.open('/dev/mem',os.O_RDONLY|os.O_SYNC); "
                           "m=mmap.mmap(f,262144,flags=mmap.MAP_SHARED,prot=mmap.PROT_READ,offset=0x30000000); "
                           "print(hashlib.sha256(m[:]).hexdigest());m.close();os.close(f)").decode().strip()


def check_inputs(m):
    assert sha(SELF) == m['driver_sha256'] and sha(DECODER) == m['decoder_sha256']
    assert all(sha(ROOT / n) == value for n, value in m['source_sha256'].items())
    assert all(sha(ROOT / n) == value for n, value in m['compiler_inputs'].items())
    assert all(sha(Path(n)) == value for n, value in m['local_main_reference_sha256'].items())


def stage(args, bridge):
    previous = args.previous.resolve()
    old = json.loads(previous.read_text())
    old_audit = json.loads((previous.parent / 'final-audit.json').read_text())
    assert old['status'] == old_audit['status'] == 'pass'
    assert sha(previous) == old_audit['manifest_sha256']
    assert old['rbf_sha256'] == RBF_SHA256
    expected_current = old['final_status']
    rejected = None
    if args.previous_attempt is not None:
        rejected_path = args.previous_attempt.resolve()
        rejected_manifest = json.loads(rejected_path.read_text())
        assert rejected_manifest['status'] == 'fail'
        assert sha(rejected_path.parent / 'hardware_driver.py') == rejected_manifest['driver_sha256']
        assert rejected_manifest['source_sha256'] == old['source_sha256']
        assert rejected_manifest['compiler_inputs'] == old['compiler_inputs']
        assert rejected_manifest['qualification_terminal_sha256'] == old['qualification_terminal_sha256']
        assert rejected_manifest['rbf_sha256'] == RBF_SHA256
        attempted = [t for t in rejected_manifest['tests'] if t['actions']]
        assert attempted and attempted[-1]['status'] == 'fail'
        expected_current = attempted[-1]['post_load']
        rejected = {'manifest': str(rejected_path), 'sha256': sha(rejected_path),
                    'scope': 'Rejected prior attempt, preserved unchanged; not an accepted control.'}
    assert bridge.status() == expected_current, 'MiSTer ownership changed'
    assert bridge.hashes([old['rbf']])[old['rbf']] == RBF_SHA256
    q = Path(old['qualification'])
    qr = json.loads((q / 'terminal.json').read_text())
    assert qr['status'] == 'pass' and qr['unchanged'] and len(qr['cases']) == 4
    assert sha(q / 'terminal.json') == old['qualification_terminal_sha256']
    assert sha(previous.parent / 'qualification-evidence.tar.gz') == old_audit['qualification_archive_sha256']
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    name = 'X1OSD_' + stamp
    out = ROOT / 'output_files' / name
    out.mkdir()
    cores, media = '/media/fat/_Computer/' + name, '/media/fat/games/SharpX1/HWTest/' + name
    references = {str(ROOT.parent / 'Main_MiSTer' / n): sha(ROOT.parent / 'Main_MiSTer' / n) for n in MAIN_NAMES}
    wrapper = (ROOT / 'sharpx1.sv').read_text()
    assert '"T[0],Reset;"' in wrapper and '"R[0],Reset and close OSD;"' in wrapper
    menu = (ROOT.parent / 'Main_MiSTer/menu.cpp').read_text()
    assert 'user_io_status_set(opt, 1, ex);' in menu and 'user_io_status_set(opt, 0, ex);' in menu
    m = {'name': name, 'created_utc': utc(), 'builder': args.builder, 'host': args.host,
         'pre_load': bridge.status(), 'rbf': old['rbf'], 'rbf_sha256': RBF_SHA256,
         'source_sha256': old['source_sha256'], 'compiler_inputs': old['compiler_inputs'],
         'qualification': str(q), 'qualification_terminal_sha256': sha(q / 'terminal.json'),
         'previous_manifest': str(previous), 'previous_manifest_sha256': sha(previous),
         'rejected_previous_attempt': rejected,
         'qualification_archive_sha256': old_audit['qualification_archive_sha256'],
         'driver_sha256': sha(SELF), 'decoder_sha256': sha(DECODER),
         'local_main_reference_sha256': references,
         'reference_scope': 'Local Main source explains navigation; it is not established as the installed binary source.',
         'main_sha256': bridge.hashes(['/media/fat/MiSTer'])['/media/fat/MiSTer'],
         'mrext_sysinfo': json.loads(bridge.api('GET', 'sysinfo')),
         'core_directory': cores, 'media_directory': media, 'tests': [], 'status': 'staging',
         'scope': 'Actual Main OSD T[0]/R[0] dispatch during the qualified CPU font/VRAM loop. '
                  'No-selection and wrong-last-byte controls share the retained-readback pixel oracle. '
                  'T requires F12 to close OSD before R; R must close OSD automatically. '
                  'Raw PNGs contain core video, not the OSD overlay. Physical owned phase, pins and timing are untraced.'}
    check_inputs(m)
    files = {}
    cases = {('good80', 80, False): 'cols80-write-bad0', ('good40', 40, False): 'cols40-write-bad0',
             ('bad80', 80, True): 'cols80-write-bad1'}
    for (label, columns, bad), folder in cases.items():
        case = next(c for c in qr['cases'] if c['columns'] == columns and c['reset_owner'] == 'write'
                    and c['bad_last_retained_compare'] == bad)
        rom = q / folder / 'diagnostic.rom'
        assert sha(rom) == case['ipl_sha256'] == case['artifacts']['diagnostic.rom']
        files['media/' + label + '.rom'] = rom.read_bytes()
    font_hex = q / 'cols80-write-bad0/font.hex'
    assert sha(font_hex) == qr['cases'][0]['artifacts']['font.hex']
    font = bytes(int(v, 16) for v in font_hex.read_text().splitlines())
    assert len(font) == 262144 and digest(font) == old['final_ddr_sha256']
    files['media/synthetic-g0.rom'] = font
    for i, (path, columns, bad) in enumerate([(path, cols, bad) for path in ('T', 'R')
                                            for cols, bad in ((80, False), (40, False), (80, True))], 1):
        label = 'bad80' if bad else 'good' + str(columns)
        title = f'{i:02}_{path}_{label}'
        setname = name + f'_{i:02}'
        assert len(setname) <= 31
        tree = ET.Element('mistergamedescription')
        ET.SubElement(tree, 'rbf').text = old['rbf'].removeprefix('/media/fat/').removesuffix('.rbf')
        ET.SubElement(tree, 'setname', {'same_dir': '1'}).text = setname
        for index, filename in ((0, label + '.rom'), (5, 'synthetic-g0.rom')):
            ET.SubElement(tree, 'file', {'delay': '2', 'type': 'f', 'index': str(index), 'path': media + '/' + filename})
        ET.SubElement(tree, 'reset', {'delay': '1'})
        contents = ET.tostring(tree) + b'\n'
        files['cores/' + title + '.mgl'] = contents
        files['configs/' + setname + '.CFG'] = bytes(16)
        (out / (title + '.mgl')).write_bytes(contents)
        t = {'title': title, 'path': path, 'columns': columns, 'bad_last_retained_compare': bad,
             'setname': setname, 'mgl': cores + '/' + title + '.mgl', 'up_taps': 3 if path == 'T' else 2,
             'screenshots': [], 'actions': []}
        # Reuse both the frozen simulation PNG and independently saved old RGB.
        old_test = next(t for t in old['tests'] if t['columns'] == columns and not t['bad_last_retained_compare'])
        for phase, number in (('cold', 0), ('warm', 2)):
            old_name = old_test['title'] + '-' + phase + '-expected.rgb'
            expected = (previous.parent / old_name).read_bytes()
            assert digest(expected) == old['oracle_sha256'][old_name]
            png = q / f'cols{columns}-write-bad0' / f'frame-{number}.png'
            positive = next(c for c in qr['cases'] if c['columns'] == columns and c['reset_owner'] == 'write'
                            and not c['bad_last_retained_compare'])
            assert sha(png) == positive['artifacts'][png.name]
            dimensions, rgb = rgb_png(png)
            assert dimensions == (columns * 8, 400) and rgb == expected
            (out / (title + '-' + phase + '-expected.rgb')).write_bytes(expected)
        m['tests'].append(t)
    m['oracle_sha256'] = {p.name: sha(p) for p in out.glob('*-expected.rgb')}
    m['files'] = {n: {'sha256': digest(data), 'bytes': len(data)} for n, data in files.items()}
    shutil.copyfile(SELF, out / 'hardware_driver.py')
    shutil.copyfile(DECODER, out / 'compare_video_png.py')
    shutil.copyfile(q / 'terminal.json', out / 'qualification-terminal.json')
    shutil.copyfile(previous, out / 'previous-manifest.json')
    shutil.copyfile(previous.parent / 'qualification-evidence.tar.gz', out / 'qualification-evidence.tar.gz')
    for n in MAIN_NAMES:
        dest = out / 'reference' / n
        dest.parent.mkdir(exist_ok=True)
        shutil.copyfile(ROOT.parent / 'Main_MiSTer' / n, dest)
    if rejected is not None:
        dest = out / 'rejected-previous-attempt'
        dest.mkdir()
        rejected_folder = Path(rejected['manifest']).parent
        for filename in ('manifest.json', 'hardware_driver.py', 'compare_video_png.py'):
            shutil.copyfile(rejected_folder / filename, dest / filename)
        for png in rejected_folder.glob('*.png'):
            shutil.copyfile(png, dest / png.name)
    save(out, m)
    bundle = out / 'deployment.tar.gz'
    with tarfile.open(bundle, 'w:gz') as tf:
        for n, data in files.items():
            entry = tarfile.TarInfo(n)
            entry.size, entry.mode = len(data), 0o644
            tf.addfile(entry, io.BytesIO(data))
    remote = '/tmp/' + name
    bridge.shell(shlex.join(['mkdir', remote]))
    subprocess.run(['scp', '-q', str(bundle), args.builder + ':' + remote + '/deployment.tar.gz'], check=True, timeout=55)
    bridge.shell(shlex.join(['scp', '-q', remote + '/deployment.tar.gz', 'root@' + args.host + ':' + remote + '.tar.gz']))
    code = '''import pathlib,tarfile,hashlib
roots=ROOTS
for k in ('cores','media'):pathlib.Path(roots[k]).mkdir(parents=True,exist_ok=False)
with tarfile.open(ARCHIVE) as tf:
 for t in tf:
  parts=pathlib.PurePosixPath(t.name).parts
  assert t.isfile() and len(parts)==2 and parts[0] in roots and parts[1] not in ('.','..')
  data=tf.extractfile(t).read();p=pathlib.Path(roots[parts[0]])/parts[1]
  with p.open('xb') as f:f.write(data)
  assert hashlib.sha256(p.read_bytes()).hexdigest()==EXPECTED[t.name]['sha256']
print('ALL_STAGED_HASHES_MATCH')
'''.replace('ROOTS', repr({'cores': cores, 'media': media, 'configs': '/media/fat/config'})).replace(
        'ARCHIVE', repr(remote + '.tar.gz')).replace('EXPECTED', repr(m['files']))
    print(bridge.python(code).decode(), end='')
    m['status'] = 'staged'
    save(out, m)
    print('EVIDENCE=' + str(out), flush=True)


def action(out, m, t, description):
    t['actions'].append({'utc': utc(), 'action': description})
    save(out, m)


def key(out, m, t, bridge, code, description):
    action(out, m, t, 'mrext Linux key ' + str(code) + ': ' + description)
    bridge.key(code)


def capture(out, m, t, bridge, phase, accept):
    before = {v['path'] for v in json.loads(bridge.api('GET', 'screenshots'))}
    action(out, m, t, 'mrext raw capture: ' + phase)
    bridge.api('POST', 'controls/keyboard/raw_screenshot')
    time.sleep(3)
    fresh = [v for v in json.loads(bridge.api('GET', 'screenshots')) if v['path'] not in before]
    assert fresh, 'No fresh raw screenshot'
    warm = (out / (t['title'] + '-warm-expected.rgb')).read_bytes()
    cold = (out / (t['title'] + '-cold-expected.rgb')).read_bytes()
    expected = warm if accept else cold
    for i, record in enumerate(fresh):
        data = bridge.api('GET', 'screenshots/' + urllib.parse.quote(record['path'], safe='/'))
        p = out / (t['title'] + '-' + phase + f'-{i:02}.png')
        p.open('xb').write(data)
        dimensions, rgb = rgb_png(p)
        observed = {'phase': phase, 'file': p.name, 'sha256': digest(data), 'mrext': record,
                    'dimensions': dimensions, 'warm_oracle_accepted': rgb == warm,
                    'expected_warm_acceptance': accept, 'exact_control_pixels':
                    sum(rgb[i:i+3] == expected[i:i+3] for i in range(0, min(len(rgb), len(expected)), 3))}
        t['screenshots'].append(observed)
        save(out, m)
        assert dimensions == (t['columns'] * 8, 400) and rgb == expected, 'Exact control pixels'
        assert (rgb == warm) == accept, 'Unchanged recovery oracle'
    print('PASS_PHASE', t['title'], phase, flush=True)


def navigate(out, m, t, bridge, select):
    key(out, m, t, bridge, 88, 'F12 open OSD; first selectable entry')
    for _ in range(t['up_taps']):
        key(out, m, t, bridge, 103, 'Up; wrap through Exit and final reset entries')
    key(out, m, t, bridge, 28 if select else 88,
        'Enter selects ' + t['path'] + '[0]' if select else 'F12 closes OSD without selecting anything')


def run_case(out, m, t, bridge):
    assert not t['actions'] and 'status' not in t, 'A prior attempt is not automatically retried'
    check_inputs(m)
    assert all(sha(out / n) == value for n, value in m['oracle_sha256'].items())
    position = m['tests'].index(t)
    previous = m['pre_load'] if position == 0 else m['tests'][position-1]['post_test']
    assert bridge.status() == previous, 'MiSTer ownership changed'
    assert bridge.hashes([m['rbf']])[m['rbf']] == m['rbf_sha256']
    try:
        action(out, m, t, 'Single MGL/RBF load, qualified IPL/font and startup reset')
        bridge.load(t['mgl'])
        time.sleep(18)
        t['post_load'] = bridge.status()
        save(out, m)
        assert t['post_load']['CORENAME'] == t['setname']
        key(out, m, t, bridge, 33, 'F initializes VRAM and enters checked font/VRAM loop')
        time.sleep(5)
        capture(out, m, t, bridge, 'active', False)
        navigate(out, m, t, bridge, False)
        key(out, m, t, bridge, 19, 'R after OSD navigation without Enter; no reset/reload/upload')
        time.sleep(5)
        capture(out, m, t, bridge, 'no-selection', False)
        navigate(out, m, t, bridge, True)
        time.sleep(5)
        assert bridge.status() == t['post_load']
        if t['path'] == 'T':
            key(out, m, t, bridge, 88, 'F12 closes the retained Reset menu')
        key(out, m, t, bridge, 19, 'R after OSD reset; retained 6,144-byte check, no asset reupload')
        time.sleep(5)
        capture(out, m, t, bridge, 'warm', not t['bad_last_retained_compare'])
        t['post_test'] = bridge.status()
        t['post_test_ddr_sha256'] = bridge.ddr_hash()
        assert t['post_test'] == t['post_load']
        assert t['post_test_ddr_sha256'] == m['files']['media/synthetic-g0.rom']['sha256']
        t['status'] = 'pass'
        save(out, m)
        print('CASE_PASS', t['title'], flush=True)
    except BaseException as exc:
        t.update(status='fail', error=repr(exc))
        m['status'] = 'fail'
        save(out, m)
        raise


def audit(out, m, bridge):
    assert all(t.get('status') == 'pass' for t in m['tests'])
    check_inputs(m)
    roots = {'cores': m['core_directory'], 'media': m['media_directory'], 'configs': '/media/fat/config'}
    paths = {n: roots[n.split('/')[0]] + '/' + n.split('/')[1] for n in m['files']}
    hashes = bridge.hashes(list(paths.values()) + [m['rbf'], '/media/fat/MiSTer'])
    m['post_test_hashes'] = {n: hashes[p] for n, p in paths.items()}
    assert all(value == m['files'][n]['sha256'] for n, value in m['post_test_hashes'].items())
    assert hashes[m['rbf']] == m['rbf_sha256'] and hashes['/media/fat/MiSTer'] == m['main_sha256']
    assert sha(out / 'qualification-evidence.tar.gz') == m['qualification_archive_sha256']
    m['final_ddr_sha256'] = bridge.ddr_hash()
    assert m['final_ddr_sha256'] == m['files']['media/synthetic-g0.rom']['sha256']
    m['final_status'] = bridge.status()
    assert m['final_status'] == m['tests'][-1]['post_test']
    count = pixels = accepted = 0
    for t in m['tests']:
        phases = ['active', 'no-selection', 'warm']
        assert list(dict.fromkeys(s['phase'] for s in t['screenshots'])) == phases
        for s in t['screenshots']:
            assert sha(out / s['file']) == s['sha256']
            dimensions, rgb = rgb_png(out / s['file'])
            warm = (out / (t['title'] + '-warm-expected.rgb')).read_bytes()
            cold = (out / (t['title'] + '-cold-expected.rgb')).read_bytes()
            accept = s['phase'] == 'warm' and not t['bad_last_retained_compare']
            assert dimensions == (t['columns'] * 8, 400) and rgb == (warm if accept else cold)
            assert s['warm_oracle_accepted'] == accept
            count += 1
            pixels += len(rgb) // 3
            accepted += int(accept)
    m.update(status='pass', finalized_utc=utc(), screenshots_verified=count, exact_control_pixels=pixels)
    save(out, m)
    summary = {'status': 'pass', 'manifest_sha256': sha(out / 'manifest.json'), 'cases': len(m['tests']),
               'screenshots': count, 'exact_control_pixels': pixels, 'positive_warm_frames': accepted,
               'staged_files': len(paths), 'qualification_inputs': len(m['source_sha256']),
               'compiler_inputs': len(m['compiler_inputs']), 'rbf_sha256': m['rbf_sha256'],
               'qualification_archive_sha256': m['qualification_archive_sha256'],
               'driver_sha256': m['driver_sha256'], 'final_ddr_sha256': m['final_ddr_sha256']}
    (out / 'final-audit.json').write_text(json.dumps(summary, indent=2) + '\n')
    rows = ['<!doctype html><meta charset="utf-8"><title>X1 OSD reset controls</title>',
            '<style>body{background:#222;color:#ddd;font-family:sans-serif}img{image-rendering:pixelated;max-width:100%}</style>',
            '<h1>Main OSD reset — fd9a0850</h1><p>F starts the checked traffic loop (yellow). '
            'Menu navigation without Enter must not reboot. T Reset needs F12 before R; '
            'R Reset-and-close lets R select retained readback immediately. Only successful readback gives magenta. '
            'Raw PNGs show core video, not the OSD overlay.</p>']
    for t in m['tests']:
        rows.append('<h2>' + html.escape(t['title']) + '</h2>')
        for s in t['screenshots']:
            rows.append('<figure><a href="' + s['file'] + '"><img src="' + s['file'] + '"></a><figcaption>' +
                        html.escape(s['phase']) + ' — ' + str(s['exact_control_pixels']) +
                        ' exact control pixels; recovery oracle ' + ('accepts' if s['warm_oracle_accepted'] else 'rejects') +
                        '</figcaption></figure>')
    rows.append('<p>Synthetic font and normal-size high scan 80/40 columns only. Exact physical owned phase, '
                'stopped clocks, native fonts, broader devices and timing closure remain open.</p>')
    (out / 'screenshots.html').write_text('\n'.join(rows))
    print(json.dumps(summary, indent=2), flush=True)


def main():
    if not __debug__:
        raise SystemExit('Optimized Python is refused: qualification assertions must run')
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('action', choices=('stage', 'matrix', 'audit'))
    p.add_argument('evidence', nargs='?', type=Path)
    p.add_argument('--previous', type=Path)
    p.add_argument('--previous-attempt', type=Path, help='Preserved failed manifest identifying the currently owned test core')
    p.add_argument('--builder', default='misterubuntu')
    p.add_argument('--host', default='10.0.2.14')
    args = p.parse_args()
    if args.action == 'stage':
        if args.previous is None or args.evidence is not None:
            p.error('stage requires --previous accepted_manifest.json and no evidence argument')
        stage(args, Bridge(args.builder, args.host))
    else:
        if args.evidence is None or args.previous is not None or args.previous_attempt is not None:
            p.error('matrix/audit require an evidence directory and no prior-manifest options')
        out = args.evidence.resolve()
        m = json.loads((out / 'manifest.json').read_text())
        bridge = Bridge(m['builder'], m['host'])
        if args.action == 'matrix':
            assert m['status'] == 'staged'
            for t in m['tests']:
                run_case(out, m, t, bridge)
            print('OSD_MATRIX_TERMINAL', flush=True)
        else:
            audit(out, m, bridge)


if __name__ == '__main__':
    main()
