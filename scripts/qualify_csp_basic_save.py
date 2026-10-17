#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Frozen native SAVE/NEW/LOAD and cold disk reopen, with matched controls."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / 'scripts'), str(ROOT / 'verilator/tests')]
from compare_video_png import rgb_png
from check_basic_reference import BANNER, check_rows
from check_basic_save import MARKER, MUTANT, PROGRAM, SAVE, LOAD, check, result, sectors, disk_changes
from qualify_csp_basic import protected_disk


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def events(frame, text):
    args = []
    for c in text:
        vk, shift = {'"': (ord('2'), True), '\n': (13, False)}.get(c, (ord(c), False))
        if shift:
            args += ['--key-down', f'{frame}:16']
        args += ['--key-down', f'{frame}:{vk}', '--key-up', f'{frame + 16}:{vk}']
        if shift:
            args += ['--key-up', f'{frame + 16}:16']
        frame += 32
    return args


def main():
    assert __debug__
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--cli-qualification', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    qpath = args.cli_qualification.resolve()
    q = json.loads(qpath.read_text())
    assert q['status'] == 'pass' and len(q['cases']) == 22
    assert all(sha(n) == h for n, h in (q['sources'] | q['binaries']).items())
    out = args.output.resolve()
    out.mkdir()
    shutil.copy2(qpath.parent / 'bin/x1', out / 'x1')
    shutil.copytree(ROOT / 'output_files/CSPBasic_20261015T234906Z/accepted-csp/assets', out / 'assets')
    original = ROOT / 'software/basic-unpacked/zzz-unk-hubasic-11a5077cf724/disk-0-ef47f5df772f.d88'
    assert sha(original) == q['original_sha256']
    assert MARKER not in original.read_bytes() and MUTANT not in original.read_bytes()
    own = [Path(__file__).resolve(), ROOT / 'verilator/tests/check_basic_save.py',
           ROOT / 'verilator/tests/check_basic_reference.py', ROOT / 'scripts/compare_video_png.py',
           ROOT / 'scripts/qualify_csp_basic.py']
    for n in own:
        target = out / 'sources' / n.relative_to(ROOT)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(n, target)
    inputs = {str(n): sha(n) for n in [*own, qpath, out / 'x1', original, *(out / 'assets').iterdir()]}
    report = dict(status='running', inputs=inputs, qualified_sources=q['sources'], cases=[],
                  scope='Native CZ-8FB01 CSP base pseudo-controller/PSG-only SAVE/NEW/LOAD and cold reopen on private copies; not hardware or general filesystem acceptance')

    def save():
        (out / 'terminal.json').write_text(json.dumps(report, indent=2) + '\n')

    def screenshot(folder, frame, kind, mutant=False):
        dims, pixels = rgb_png(folder / f'frame_{frame:06d}.png')
        return check(dims, pixels, (out / 'assets/ANK8.ROM').read_bytes(), kind, mutant=mutant)

    def reject(folder, frame, cold=False, saved=False):
        dims, pixels = rgb_png(folder / f'frame_{frame:06d}.png')
        font = (out / 'assets/ANK8.ROM').read_bytes()
        try:
            check(dims, pixels, font, 'saved') if saved else result(dims, pixels, font, cold)
        except AssertionError as error:
            return str(error)
        raise AssertionError('Control passed unchanged completion oracle')

    save()
    try:
        names = ['save-load', 'save-load-repeat', 'protected', 'no-save-enter', 'no-load',
                 'cold-load', 'cold-load-repeat', 'cold-no-load', 'cold-mutant']
        for name in names:
            folder, process = out / name, out / (name + '-process')
            process.mkdir()
            cold = name.startswith('cold')
            source = out / 'save-load/writable.d88' if cold else original
            if name == 'cold-load-repeat':
                source = out / 'save-load-repeat/writable.d88'
            if name == 'cold-mutant':
                data = source.read_bytes()
                assert data.count(MARKER) == 1
                offset = data.index(MARKER)
                assert any(start <= offset and offset + len(MARKER) <= end for _, _, _, start, end in sectors(data))
                variant = bytearray(data)
                variant[offset + 7] = MUTANT[-1]
                assert sum(a != b for a, b in zip(data, variant)) == 1
                source = out / 'mutant-source.d88'
                source.write_bytes(variant)
                report['mutation'] = dict(source=str(source), sha256=sha(source), offset=offset + 7,
                                           before=MARKER[-1], after=MUTANT[-1], scope='one literal byte in saved program sector payload')
                save()
            source_hash = sha(source)
            writable = not cold and name != 'protected'
            short = name in ('protected', 'no-save-enter')
            end = 2199 if cold else 2399 if short else 4499
            phases = [(799, 'before')]
            if cold:
                if name != 'cold-no-load':
                    phases.append((1499, 'cold-loaded'))
                phases.append((2199, 'cold-no-load' if name == 'cold-no-load' else 'cold-final'))
                plan = ([] if name == 'cold-no-load' else [(800, LOAD.decode() + '\n')]) + [(1600, 'LIST\nRUN\n')]
            else:
                phases += [(1499, 'program'), (2399, 'protected' if name == 'protected' else 'pending' if name == 'no-save-enter' else 'saved')]
                plan = [(800, PROGRAM.decode() + '\n'), (1600, SAVE.decode() + ('' if name == 'no-save-enter' else '\n'))]
                if not short:
                    plan += [(2500, 'NEW\n'), (2800, 'LIST\n')]
                    phases.append((3099, 'cleared'))
                    if name != 'no-load':
                        plan.append((3200, LOAD.decode() + '\n'))
                        phases.append((3899, 'loaded'))
                    plan.append((4000, 'LIST\nRUN\n'))
                    phases.append((4499, 'no-load' if name == 'no-load' else 'final'))
            cmd = [str(out / 'x1'), '--headless', '--rom-dir', str(out / 'assets'), '--disk-a', str(source),
                   '--out', str(folder), '--stop-at-frame', str(end), '--dump-memory', 'memory.bin']
            if writable:
                cmd += ['--disk-output-a', 'writable.d88']
            for frame, _ in phases:
                cmd += ['--screenshot', str(frame)]
            for frame, text in plan:
                cmd += events(frame, text)
            case = dict(name=name, source=str(source), source_sha256=source_hash, command=cmd, phases=phases,
                        plan=plan, writable=writable, status='running', checks={})
            report['cases'].append(case)
            save()
            (process / 'command.json').write_text(json.dumps(cmd, indent=2) + '\n')
            with (process / 'stdout.log').open('w') as so, (process / 'stderr.log').open('w') as se:
                run = subprocess.run(cmd, cwd=process, stdout=so, stderr=se, timeout=240)
            assert run.returncode == 0, 'process failure is not a rejecting control'
            final = json.loads((process / 'stdout.log').read_text().splitlines()[-1])
            assert final['cli_revision'] == 4 and final['completed_frames'] == end + 1 and final['scheduled_resets'] == 0
            assert final['disk_policy'] == ('explicit_writable_copy' if writable else 'protected_private_copy')
            for frame, kind in phases:
                dims, pixels = rgb_png(folder / f'frame_{frame:06d}.png')
                font = (out / 'assets/ANK8.ROM').read_bytes()
                if kind == 'before':
                    checked = dict(banner=check_rows(dims, pixels, font, 4, (BANNER,)),
                                   prompt=check_rows(dims, pixels, font, 12, (b'Ok',)))
                elif kind == 'pending':
                    checked = screenshot(folder, frame, 'program')
                else:
                    checked = screenshot(folder, frame, kind, name == 'cold-mutant')
                case['checks'][str(frame)] = checked
            if name in ('protected', 'no-save-enter', 'no-load', 'cold-no-load', 'cold-mutant'):
                case['unchanged_completion_rejected'] = reject(folder, end, cold, name in ('protected', 'no-save-enter'))
            image = folder / ('writable.d88' if writable else 'disk-a.d88')
            if cold or name == 'protected':
                assert image.read_bytes() == protected_disk(source.read_bytes())
            elif name == 'no-save-enter':
                assert image.read_bytes() == original.read_bytes()
            else:
                case['observed_sector_changes'] = disk_changes(original.read_bytes(), image.read_bytes())
                assert image.read_bytes().count(MARKER) == 1
            assert sha(source) == source_hash and sha(original) == q['original_sha256']
            case.update(status='pass', final=final, artifacts={n.name: sha(n) for n in folder.iterdir()})
            save()
            print('PASS_NATIVE_BASIC_SAVE', name, flush=True)
        report['repeat_checks'] = []
        for name in ('save-load', 'cold-load'):
            a, b = [next(c for c in report['cases'] if c['name'] == n) for n in (name, name + '-repeat')]
            deterministic = [n for n in a['artifacts'] if n == 'frames.csv' or n.endswith('.png')]
            assert all(a['artifacts'][n] == b['artifacts'][n] for n in deterministic), 'native frame/RGB repeats differ'
            report['repeat_checks'].append(dict(name=name, exact_frame_artifacts=deterministic,
                raw_nonidentical_artifacts=[n for n in a['artifacts'] if a['artifacts'][n] != b['artifacts'][n]],
                scope='Exact native RGB/frame-clock artifacts. Raw disk/RAM hashes retained unchanged; host-initialized calendar may differ. No byte-identity claim for those artifacts.'))
        assert all(sha(n) == h for n, h in (q['sources'] | q['binaries'] | inputs).items())
        report.update(status='pass', exact_pixels=sum(v['checked_pixels'] for c in report['cases'] for stage in c['checks'].values() for v in stage.values()))
    except BaseException as error:
        report.update(status='fail', error=repr(error))
        raise
    finally:
        save()


if __name__ == '__main__':
    main()
