#!/usr/bin/env python3
"""Freeze actual machine inputs and compare default generated v17 state.

Base and Turbo use the actual machine.qip source order and unchanged sim top,
not a vendor wrapper. No C++ build, runner execution, restore or conversion.
Make/C++ runner changes are outside this generated-model audit.
"""
import argparse
from collections import Counter
import difflib
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import tarfile
import tempfile


MANIFEST = 'rtl/machine.qip'
TOP = 'verilator/sim.v'
FILES = ['Vtop___024root.h', 'Vtop___024root__Slow.cpp',
         'Vtop__Syms.h', 'Vtop__Syms__Slow.cpp']


def digest(data):
    return hashlib.sha256(data).hexdigest()


def sources(manifest):
    entries = re.findall(
        r'^set_global_assignment -name (?:SYSTEMVERILOG_FILE|VERILOG_FILE) (\S+)\s*$',
        manifest.decode(), re.M)
    if not entries or len(entries) != len(set(entries)):
        raise AssertionError('Empty or duplicate machine source list')
    for entry in entries:
        path = Path(entry)
        if path.is_absolute() or '..' in path.parts:
            raise AssertionError(f'Non-repository manifest path: {entry}')
    return [TOP, *entries]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', default='c744767')
    parser.add_argument('--vendor-sha', help='Optional expected current vendor SHA-256')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    baseline = subprocess.check_output(
        ['git', 'rev-parse', f'{args.baseline}^{{commit}}'], cwd=root, text=True).strip()
    current_manifest = (root / MANIFEST).read_bytes()
    current_sources = sources(current_manifest)
    frozen = {path: (root / path).read_bytes() for path in [MANIFEST, *current_sources]}
    # These machine inputs currently have no includes. Fail closed if that
    # changes: otherwise an unfrozen included dependency could escape hashes.
    for path, data in frozen.items():
        if re.search(rb'^\s*`include\b', data, re.M):
            raise AssertionError(f'Include dependency needs explicit freezing: {path}')
    vendor = 'rtl/vendor/wd1793.sv'
    if args.vendor_sha and digest(frozen[vendor]) != args.vendor_sha:
        parser.error('Vendor differs from expected SHA; no generation started')
    out = Path(tempfile.mkdtemp(prefix='x1-machine-fdc-default-state-'))
    original = out / 'original'
    current = out / 'current'
    # Immutable Git archive, no checkout or baseline source mutation.
    archive = subprocess.check_output(
        ['git', 'archive', baseline, 'rtl', 'references/chip-src', TOP], cwd=root)
    with tarfile.open(fileobj=io.BytesIO(archive)) as stream:
        stream.extractall(original, filter='data')
    original_sources = sources((original / MANIFEST).read_bytes())
    for path in original_sources:
        if re.search(rb'^\s*`include\b', (original / path).read_bytes(), re.M):
            raise AssertionError(f'Baseline include needs explicit freezing: {path}')
    for path, data in frozen.items():
        destination = current / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
    checker = out / Path(__file__).name
    checker.write_bytes(Path(__file__).read_bytes())
    report = {
        'baseline_commit': baseline,
        'tool': subprocess.check_output(['verilator', '--version'], text=True).strip(),
        'scope': __doc__, 'checker_sha256': digest(checker.read_bytes()),
        'current_sources': {path: digest(data) for path, data in frozen.items()},
        'baseline_sources': {path: digest((original / path).read_bytes())
                             for path in [MANIFEST, *original_sources]},
        'source_order': {'original': original_sources, 'current': current_sources},
        'profiles': [], 'status': 'running'}

    def save():
        (out / 'comparison.json').write_text(json.dumps(report, indent=2) + '\n')

    def stable():
        changed = [path for path, data in frozen.items()
                   if (root / path).read_bytes() != data or (current / path).read_bytes() != data]
        if Path(__file__).read_bytes() != checker.read_bytes():
            changed.append(str(Path(__file__)))
        if changed:
            raise AssertionError(f'Sources changed during audit: {changed}')

    print(f'Frozen machine sources/logs: {out}', flush=True)
    save()
    failures = []
    try:
        stable()
        for name, flags in [('base', []), ('turbo', ['-GTURBO=1', '-GTURBO_DSW=241'])]:
            profile = {'name': name, 'flags': flags, 'files': {}, 'warnings': {}}
            report['profiles'].append(profile)
            for version, tree, inputs in [('original', original, original_sources),
                                          ('current', current, current_sources)]:
                build = out / f'{name}-{version}'
                command = ['verilator', '--cc', '--no-skip-identical', '--savable',
                           '--no-timing', '--assert', '--trace-fst', '-Wno-fatal',
                           '--top-module', 'top', '--Mdir', str(build), *flags, *inputs]
                (out / f'{name}-{version}.command.json').write_text(
                    json.dumps(command, indent=2) + '\n')
                log_path = out / f'{name}-{version}.log'
                with log_path.open('w') as log:
                    result = subprocess.run(command, cwd=tree, stdout=log,
                                            stderr=subprocess.STDOUT, timeout=60)
                profile[version + '_exit_code'] = result.returncode
                profile['warnings'][version] = re.findall(
                    r'^%Warning-[^\n]+', log_path.read_text(), re.M)
                save()
                result.check_returncode()
            for filename in FILES:
                previous = (out / f'{name}-original' / filename).read_bytes()
                latest = (out / f'{name}-current' / filename).read_bytes()
                identical = previous == latest
                profile['files'][filename] = {'identical': identical,
                                             'original_sha256': digest(previous),
                                             'current_sha256': digest(latest)}
                if not identical:
                    failures.append(f'{name}/{filename}: state differs')
                    (out / f'{name}-{filename}.diff').write_text(''.join(difflib.unified_diff(
                        previous.decode().splitlines(True), latest.decode().splitlines(True),
                        fromfile='original/' + filename, tofile='current/' + filename)))
            # State equality is independent of this warning gate. Preserve
            # raw diagnostics; ignore only source line/column shifts and
            # reject newly introduced messages OR increased multiplicities.
            normalized = {version: Counter(re.sub(r':\d+:\d+:', ':LINE:COL:', warning)
                                           for warning in warnings)
                          for version, warnings in profile['warnings'].items()}
            added = normalized['current'] - normalized['original']
            profile['new_warnings'] = dict(added)
            if added:
                failures.append(f'{name}: new warnings: {dict(added)}')
            save()
            print(f'{name}: identical files={sum(v["identical"] for v in profile["files"].values())}/4; '
                  f'warnings old/new={len(profile["warnings"]["original"])}/'
                  f'{len(profile["warnings"]["current"])}; added={sum(added.values())}', flush=True)
        stable()
        report['live_and_frozen_inputs_stable'] = True
        if failures:
            raise AssertionError('; '.join(failures))
        report['status'] = 'pass'
        print('PASS all eight actual base/Turbo state headers/serializers; no new warnings. '
              'Generated default-model audit only; no snapshot conversion or runtime qualification.', flush=True)
    except Exception as error:
        report['status'] = 'fail'
        report['error'] = str(error)
        raise
    finally:
        save()


if __name__ == '__main__':
    main()
