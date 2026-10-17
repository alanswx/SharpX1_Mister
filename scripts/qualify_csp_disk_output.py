#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Freeze CLI v4; compare default execution and reject destructive disk outputs."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / 'scripts'), str(ROOT / 'verilator/tests')]
from qualify_csp_basic import protected_disk


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    assert __debug__
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--build', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    out, build = args.output.resolve(), args.build.resolve()
    out.mkdir()
    source = ROOT.parent / 'common_source_code'
    prior = ROOT / 'output_files/CSPMac_20261015T225930Z/qualification-v3'
    sources = {source / 'CMakeLists.txt', source / 'tool/generate_cmake.py',
               Path(__file__).resolve(), ROOT / 'scripts/qualify_csp_basic.py'}
    for dep in build.rglob('*.o.d'):
        sources.update(Path(n).resolve() for n in re.findall(re.escape(str(source)) + r'/[^\s\\]+', dep.read_text()))
    hashes = {str(n): sha(n) for n in sorted(sources)}
    for name in hashes:
        n = Path(name)
        target = out / 'sources' / n.relative_to(ROOT.parent)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(n, target)
    (out / 'bin').mkdir()
    for model in ('x1', 'x1turbo', 'x1turboz'):
        shutil.copy2(build / f'{model}.app/Contents/MacOS/{model}', out / 'bin' / model)
    binaries = {str(n): sha(n) for n in (out / 'bin').iterdir()}
    original = ROOT / 'software/basic-unpacked/zzz-unk-hubasic-11a5077cf724/disk-0-ef47f5df772f.d88'
    original_hash = sha(original)
    assert original_hash == 'ef47f5df772f45d97be43646d8f8010d33eca8846913babfd1106e89a361ee6a'
    report = dict(status='running', sources=hashes, binaries=binaries, original=str(original),
                  original_sha256=original_hash, cases=[], scope=__doc__)

    def save():
        (out / 'terminal.json').write_text(json.dumps(report, indent=2) + '\n')

    def run(name, arguments, model='x1', old=False, expect=0):
        process = out / (name + '-process')
        process.mkdir()
        exe = prior / 'bin' / model if old else out / 'bin' / model
        cmd = [str(exe), '--headless', *map(str, arguments)]
        (process / 'command.json').write_text(json.dumps(cmd, indent=2) + '\n')
        with (process / 'stdout.log').open('w') as so, (process / 'stderr.log').open('w') as se:
            result = subprocess.run(cmd, stdout=so, stderr=se, cwd=process, timeout=240)
        assert result.returncode == expect, (name, result.returncode)
        text = (process / 'stdout.log').read_text()
        final = json.loads(text.splitlines()[-1]) if expect == 0 else None
        if final:
            assert final['cli_revision'] == (3 if old else 4)
        else:
            assert '"status":"complete"' not in text
        return dict(name=name, exit=result.returncode, final=final,
                    stderr=(process / 'stderr.log').read_text() if expect else None)

    def files(folder):
        return {n.name: sha(n) for n in folder.iterdir() if n.is_file()}

    save()
    try:
        # Identical VM artifacts against the frozen qualified v3 executable.
        for name, model, asset, extra, stop in [
            ('base', 'x1', 'good-assets', [], 5),
            ('warm', 'x1', 'good-assets', ['--reset-at', '7'], 14),
            ('keyboard', 'x1', 'keyboard-assets', ['--type', '1:F', '--type', '8:R'], 15),
            ('turbo', 'x1turbo', 'x1turbo-assets', [], 5),
            ('z', 'x1turboz', 'x1turboz-assets', [], 5),
        ]:
            for old in (True, False):
                label = name + ('-v3' if old else '-v4')
                folder = out / label
                case = run(label, ['--rom-dir', prior / asset, '--out', folder, '--stop-at-frame', stop,
                           '--trace-cpu', 'cpu.csv', '--trace-io', 'io.csv', '--dump-memory', 'memory.bin',
                           '--screenshot', stop, *extra], model, old)
                assert case['final']['disk_policy'] == 'protected_private_copy'
                case['artifacts'] = files(folder)
                report['cases'].append(case)
            assert report['cases'][-1]['artifacts'] == report['cases'][-2]['artifacts'], name
            save()
            print('PASS_CSP_DISK_DEFAULT', name, flush=True)
        rom = ROOT / 'output_files/CSPBasic_20261015T234906Z/accepted-csp/assets'
        for name, arguments, protected, drives in [
            ('protected', [], True, [False, False]),
            ('writable-a', ['--disk-output-a', 'written-a.d88'], False, [True, False]),
            ('mixed', ['--disk-b', original, '--disk-output-a', 'written-a.d88'], False, [True, False]),
            ('writable-both', ['--disk-b', original, '--disk-output-a', 'written-a.d88', '--disk-output-b', 'written-b.d88'], False, [True, True]),
        ]:
            folder = out / name
            case = run(name, ['--rom-dir', rom, '--out', folder, '--disk-a', original,
                              '--stop-at-frame', 5, *arguments])
            assert case['final']['disks_protected'] == protected
            assert case['final']['writable_drives'] == drives
            assert case['final']['disk_policy'] == ('protected_private_copy' if protected else 'explicit_writable_copy')
            for drv in range(2 if name in ('mixed', 'writable-both') else 1):
                n = ('written-' if drives[drv] else 'disk-') + ('a' if drv == 0 else 'b') + '.d88'
                expected = original.read_bytes() if drives[drv] else protected_disk(original.read_bytes())
                assert (folder / n).read_bytes() == expected
            case['artifacts'] = files(folder)
            report['cases'].append(case)
            save()
            print('PASS_CSP_DISK_COPY', name, flush=True)
        sentinel = out / 'existing.d88'
        sentinel.write_bytes(b'preserve-existing-output')
        link = out / 'source-link.d88'
        link.symlink_to(original)
        hardlink = out / 'source-hardlink.d88'
        hardlink.hardlink_to(original)
        guard_hashes = {str(n): sha(n) for n in (original, sentinel, link, hardlink)}
        rejected = [
            ('existing', ['--disk-output-a', sentinel], 'disk output must not exist'),
            ('original', ['--disk-output-a', original], 'disk output must not exist'),
            ('symlink', ['--disk-output-a', link], 'disk output must not exist'),
            ('hardlink', ['--disk-output-a', hardlink], 'disk output must not exist'),
            ('directory', ['--disk-output-a', out], 'disk output must not exist'),
            ('duplicate-drive', ['--disk-b', original, '--disk-output-a', 'same.d88', '--disk-output-b', 'same.d88'], 'disk outputs must be distinct'),
            ('duplicate-option', ['--disk-output-a', 'one.d88', '--disk-output-a', 'two.d88'], 'duplicate disk output option'),
            ('missing-drive', ['--disk-output-b', 'b.d88'], 'disk output requires its disk input'),
        ]
        for name, arguments, reason in rejected:
            folder = out / ('reject-' + name)
            case = run('reject-' + name, ['--rom-dir', rom, '--out', folder, '--disk-a', original,
                       '--stop-at-frame', 5, *arguments], expect=2)
            assert reason in case['stderr'], case
            assert all(sha(n) == h for n, h in guard_hashes.items())
            assert not any(folder.glob('*.d88'))
            case['reason'] = reason
            report['cases'].append(case)
            save()
            print('PASS_CSP_DISK_REJECT', name, flush=True)
        assert all(sha(n) == h for n, h in (hashes | binaries).items())
        assert sha(original) == original_hash
        report['status'] = 'pass'
    except BaseException as error:
        report.update(status='fail', error=repr(error))
        raise
    finally:
        save()


if __name__ == '__main__':
    main()
