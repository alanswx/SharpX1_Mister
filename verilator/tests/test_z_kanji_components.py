#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Original frozen synthetic Z selector/store tests; no machine/board claim."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
FILES = (
    'rtl/x1_z_pcg_selector.sv', 'rtl/x1_z_kanji_rom.sv',
    'verilator/tests/z_pcg_selector_tb.sv', 'verilator/tests/z_kanji_rom_tb.sv',
    'verilator/tests/test_z_kanji_components.py',
)
ORDINARY = ('rtl/x1_pcg_selector.sv', 'rtl/x1_pcg_access.v', 'rtl/x1_kanji_rom.sv',
            'rtl/legacy/x1_vid.v')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    folder = Path(tempfile.mkdtemp(prefix='x1-z-kanji-components-')).resolve()
    print(f'EVIDENCE={folder}', flush=True)
    hashes = {name: sha(ROOT/name) for name in FILES}
    ordinary = {name: sha(ROOT/name) for name in ORDINARY}
    for name in FILES:
        target = folder/'sources'/name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT/name, target)
        assert sha(target) == hashes[name], f'freeze mutation: {name}'
    (folder/'sources.before.json').write_text(json.dumps(hashes, indent=2)+'\n')
    (folder/'ordinary.before.json').write_text(json.dumps(ordinary, indent=2)+'\n')
    status = {'phase': 'failed', 'scope': 'standalone-synthetic-not-machine-or-board',
              'cases': []}

    def build(top, source, fixture, tag):
        obj = folder/('obj-'+tag)
        command = ['verilator', '--binary', '--timing', '--assert', '-Wall', '-Wno-fatal',
                   '--top-module', top, '--Mdir', str(obj), '-j', '2',
                   str(source), str(folder/'sources'/fixture)]
        (folder/(tag+'.command.json')).write_text(json.dumps(command, indent=2)+'\n')
        with (folder/(tag+'.build.log')).open('w') as log:
            r = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=180)
        if r.returncode:
            raise RuntimeError(f'{tag}: build exit {r.returncode}; logs retained')
        warnings = [line for line in (folder/(tag+'.build.log')).read_text().splitlines()
                    if '%Warning' in line]
        # Reset is intentionally both an asynchronous response-valid flush and
        # a synchronous upload permission/commit condition. Retain its native
        # diagnostic; fail on every other warning rather than suppressing it.
        allowed = [] if top == 'z_pcg_selector_tb' else ['%Warning-SYNCASYNCNET:']
        assert all(any(line.startswith(prefix) for prefix in allowed)
                   for line in warnings), warnings
        (folder/(tag+'.warnings.json')).write_text(json.dumps(warnings, indent=2)+'\n')
        return obj/('V'+top)

    def run(exe, tag, marker, extra=(), negative=False):
        with (folder/(tag+'.run.log')).open('w') as log:
            r = subprocess.run([str(exe), *extra], stdout=log, stderr=subprocess.STDOUT,
                               timeout=120, cwd=folder)
        text = (folder/(tag+'.run.log')).read_text()
        if negative:
            assert r.returncode != 0 and marker in text and 'PASS Z' not in text, text
        else:
            assert r.returncode == 0 and marker in text, text
        status['cases'].append({'name': tag, 'exit': r.returncode,
                                'negative': negative, 'executable_sha256': sha(exe)})
        print(f'PASS {tag} exit={r.returncode}', flush=True)

    try:
        selector = folder/'sources'/FILES[0]
        rom = folder/'sources'/FILES[1]
        exe = build('z_pcg_selector_tb', selector, FILES[2], 'selector')
        run(exe, 'selector', 'PASS Z selector')
        exe = build('z_kanji_rom_tb', rom, FILES[3], 'rom')
        for half in (17500, 11640):
            run(exe, f'rom-{half}', 'PASS Z ROM', (f'+VIDEO_HALF_PS={half}',))
        # Disposable matched mutants only; the original/frozen good sources
        # stay untouched. Mutation specificity is checked before compiling.
        mutations = (
            ('selector-half-layout', selector,
             '{kan_level,kan_bank,text_cell,nibble,kan_half}',
             '{kan_level,kan_half,kan_bank,text_cell,nibble}',
             'z_pcg_selector_tb', FILES[2], 'Z selector source/address mismatch'),
            ('rom-level-bank-swap', rom,
             'cpu_address;',
             '{cpu_address[16],cpu_address[17],cpu_address[15:0]};',
             'z_kanji_rom_tb', FILES[3], 'Z ROM byte mismatch'),
            ('rom-reset-cancel', rom,
             'if(cpu_reset) cpu_selected<=0;',
             'if(cpu_reset) cpu_selected<=cpu_selected;',
             'z_kanji_rom_tb', FILES[3], 'stale valid after short reset'),
        )
        for tag, source, old, new, top, fixture, marker in mutations:
            text = source.read_text()
            assert text.count(old) == 1, (tag, text.count(old))
            mutant = folder/tag/source.name
            mutant.parent.mkdir()
            mutant.write_text(text.replace(old, new))
            exe = build(top, mutant, fixture, tag)
            run(exe, tag, marker, negative=True)
        status['phase'] = 'pass'
    finally:
        after = {name: sha(ROOT/name) for name in FILES}
        after_ordinary = {name: sha(ROOT/name) for name in ORDINARY}
        frozen = {name: sha(folder/'sources'/name) for name in FILES}
        (folder/'sources.after.json').write_text(json.dumps(after, indent=2)+'\n')
        (folder/'ordinary.after.json').write_text(json.dumps(after_ordinary, indent=2)+'\n')
        unchanged = after == hashes and frozen == hashes and after_ordinary == ordinary
        status['original_frozen_and_ordinary_unchanged'] = unchanged
        if not unchanged:
            status['phase'] = 'failed'
        (folder/'terminal.json').write_text(json.dumps(status, indent=2)+'\n')
        (folder/'evidence.sha256').write_text(''.join(
            f'{sha(p)}  {p.relative_to(folder)}\n' for p in sorted(folder.rglob('*'))
            if p.is_file() and p.name != 'evidence.sha256' and not p.parent.name.startswith('obj-')
            and not any(part.startswith('obj-') for part in p.relative_to(folder).parts)))
        assert unchanged, 'source mutation; evidence retained'
    print('PASS Z components; reviewed reset warnings only, raw logs/manifests retained; no integration/fit claim', flush=True)


if __name__ == '__main__':
    main()
