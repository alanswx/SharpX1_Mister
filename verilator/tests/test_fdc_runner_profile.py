#!/usr/bin/env python3
"""Frozen Make dry-run FDC profile gate; no compilation or machine execution."""
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import shlex
import subprocess
import tempfile


class ProfileAssertion(AssertionError):
    """Only these exact verifier failures qualify a negative."""


def require(condition, diagnostic):
    if not condition:
        raise ProfileAssertion(diagnostic)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def groups(tokens, option):
    values = []
    for index, token in enumerate(tokens):
        if token == option:
            if index + 1 == len(tokens):
                raise ValueError(f'Missing argument to {option}')
            values.append(tokens[index + 1])
    return values


def verify(output, rate, dma):
    logical = re.sub(r'\\\r?\n', ' ', output)
    commands = [shlex.split(line) for line in logical.splitlines() if line.strip()]
    commands = [tokens for tokens in commands
                if tokens and Path(tokens[0]).name == 'verilator']
    require(len(commands) == 1, 'PROFILE: exactly one Verilator command')
    tokens = commands[0]
    expected = f'obj_dir_v17_fdc_timing_{rate}_dma{dma}'
    mdirs = groups(tokens, '--Mdir')
    require(mdirs == [expected], 'MDIR: exactly one expected rate/DMA directory')
    require([t for t in tokens if t.startswith('-GFDC_CLOCK_HZ=')] ==
            [f'-GFDC_CLOCK_HZ={rate}'], 'RATE: exactly one matching RTL parameter')
    require([t for t in tokens if t.startswith('-GTURBO_DMA=')] ==
            [f'-GTURBO_DMA={dma}'], 'DMA: exactly one matching RTL parameter')
    require([t for t in tokens if t.startswith('-GTURBO_FDC_TIMING=')] ==
            ['-GTURBO_FDC_TIMING=1'], 'TIMING: exactly one enabled RTL parameter')
    require([t for t in tokens if t.startswith('-GTURBO=')] ==
            ['-GTURBO=1'], 'TURBO: exactly one enabled RTL parameter')
    cflags = [token for group in groups(tokens, '-CFLAGS') for token in shlex.split(group)]
    # Aggregate ALL -CFLAGS groups, including the separate TURBO_DSW group.
    macros = [token for token in cflags if token.startswith('-D')]
    def definitions(name):
        return [token for token in macros
                if token == '-D' + name or token.startswith('-D' + name + '=')]
    require(definitions('X1_FDC_CLOCK_HZ') == [f'-DX1_FDC_CLOCK_HZ={rate}'],
            'CPP_RATE: exactly one matching C++ macro')
    require(definitions('X1_TURBO_DMA') == (['-DX1_TURBO_DMA'] if dma else []),
            'CPP_DMA: macro present exactly iff DMA=1')
    require(definitions('X1_FDC_TIMING_EXPERIMENT') == ['-DX1_FDC_TIMING_EXPERIMENT'],
            'CPP_TIMING: exactly one experiment macro')
    require(definitions('X1_TURBO_FOUNDATION') == ['-DX1_TURBO_FOUNDATION'],
            'CPP_TURBO: exactly one foundation macro')
    require(not definitions('X1_SAVABLE'), 'CPP_SAVABLE: FDC profile must not be savable')
    require('-UX1_TURBO_DMA' not in cflags and '-UX1_FDC_CLOCK_HZ' not in cflags,
            'CPP_UNDEFINE: profile macros must not be undone')
    makeflags = groups(tokens, '-MAKEFLAGS')
    require(len(makeflags) == 1 and shlex.split(makeflags[0]).count('-B') == 1,
            'MAKEFLAGS: exactly one group containing one -B')
    return {'rate': rate, 'dma': dma, 'mdir': expected,
            'verilator_tokens': tokens, 'cpp_macros': macros}


def main():
    root = Path(__file__).resolve().parents[1]
    live_make = root / 'Makefile'
    live_manifest = root.parent / 'rtl/machine.qip'
    make_bytes = live_make.read_bytes()
    manifest_bytes = live_manifest.read_bytes()
    checker_bytes = Path(__file__).read_bytes()
    out = Path(tempfile.mkdtemp(prefix='x1-fdc-runner-profile-'))
    frozen_make = out / 'Makefile'
    frozen_make.write_bytes(make_bytes)
    frozen_manifest = out / 'machine.qip'
    frozen_manifest.write_bytes(manifest_bytes)
    (out / Path(__file__).name).write_bytes(checker_bytes)
    report = {'scope': __doc__, 'make_sha256': sha(make_bytes),
              'machine_manifest_sha256': sha(manifest_bytes),
              'checker_sha256': sha(checker_bytes),
              'make_version': subprocess.check_output(['make', '--version'], text=True).splitlines()[0],
              'positive': [], 'negative': [], 'status': 'running'}
    def save():
        (out / 'comparison.json').write_text(json.dumps(report, indent=2) + '\n')
    def stable():
        require(live_make.read_bytes() == make_bytes and frozen_make.read_bytes() == make_bytes,
                'SOURCE_STABILITY: Makefile changed')
        require(live_manifest.read_bytes() == manifest_bytes and
                frozen_manifest.read_bytes() == manifest_bytes,
                'SOURCE_STABILITY: machine manifest changed')
        require(Path(__file__).read_bytes() == checker_bytes,
                'SOURCE_STABILITY: checker changed')
    def dry_run(path, name, rate, dma):
        command = ['make', '-n', '-B', '-f', str(path), 'turbo-fdc-timing',
                   f'FDC_CLOCK_HZ={rate}', f'FDC_TIMING_DMA={dma}',
                   f'MACHINE_MANIFEST={frozen_manifest}']
        (out / f'{name}.command.json').write_text(json.dumps(command, indent=2) + '\n')
        result = subprocess.run(command, cwd=root, text=True, capture_output=True, timeout=30)
        (out / f'{name}.log').write_text(result.stdout + result.stderr)
        # Parse errors, process failures and timeouts NEVER count as negatives.
        result.check_returncode()
        return result.stdout
    print(f'Frozen dry-run sources/logs: {out}', flush=True)
    save()
    try:
        stable()
        for rate in (1000000, 2000000):
            for dma in (0, 1):
                name = f'positive-{rate}-dma{dma}'
                result = verify(dry_run(frozen_make, name, rate, dma), rate, dma)
                report['positive'].append(result)
                print('PASS', name, flush=True)
        require(len({p['mdir'] for p in report['positive']}) == 4,
                'DIRECTORIES: four distinct expanded profile paths')
        # Modify ONLY the new recipe/declaration in disposable copies.
        text = make_bytes.decode()
        start = text.index('FDC_CLOCK_HZ ?=')
        end = text.index('.PHONY: turbo-fdc-timing', start)
        block = text[start:end]
        mutations = [
            ('remove-B', '-MAKEFLAGS "-B"', '-MAKEFLAGS ""', 1000000, 0,
             'MAKEFLAGS: exactly one group containing one -B'),
            ('alias-rate', 'obj_dir_v17_fdc_timing_$(FDC_CLOCK_HZ)_dma$(FDC_TIMING_DMA)',
             'obj_dir_v17_fdc_timing_dma$(FDC_TIMING_DMA)', 2000000, 0,
             'MDIR: exactly one expected rate/DMA directory'),
            ('alias-dma', 'obj_dir_v17_fdc_timing_$(FDC_CLOCK_HZ)_dma$(FDC_TIMING_DMA)',
             'obj_dir_v17_fdc_timing_$(FDC_CLOCK_HZ)', 1000000, 1,
             'MDIR: exactly one expected rate/DMA directory'),
            ('shared-Mdir', '--Mdir $(@D)', '--Mdir obj_dir_fdc_shared', 1000000, 0,
             'MDIR: exactly one expected rate/DMA directory'),
            ('hardcode-rate', '-GFDC_CLOCK_HZ=$(FDC_CLOCK_HZ)', '-GFDC_CLOCK_HZ=1000000',
             2000000, 0, 'RATE: exactly one matching RTL parameter'),
            ('unconditional-CPP-DMA', '$(if $(filter 1,$(FDC_TIMING_DMA)),-DX1_TURBO_DMA,)',
             '-DX1_TURBO_DMA', 1000000, 0, 'CPP_DMA: macro present exactly iff DMA=1'),
            ('missing-CPP-DMA', '$(if $(filter 1,$(FDC_TIMING_DMA)),-DX1_TURBO_DMA,)',
             '', 1000000, 1, 'CPP_DMA: macro present exactly iff DMA=1'),
            ('duplicate-G-rate', '-GFDC_CLOCK_HZ=$(FDC_CLOCK_HZ)',
             '-GFDC_CLOCK_HZ=$(FDC_CLOCK_HZ) -GFDC_CLOCK_HZ=2000000', 1000000, 0,
             'RATE: exactly one matching RTL parameter'),
            ('duplicate-G-DMA', '-GTURBO_DMA=$(FDC_TIMING_DMA)',
             '-GTURBO_DMA=$(FDC_TIMING_DMA) -GTURBO_DMA=1', 1000000, 0,
             'DMA: exactly one matching RTL parameter'),
            ('mismatched-CPP-rate', '-DX1_FDC_CLOCK_HZ=$(FDC_CLOCK_HZ)',
             '-DX1_FDC_CLOCK_HZ=1000000', 2000000, 0,
             'CPP_RATE: exactly one matching C++ macro'),
        ]
        for name, before, after, rate, dma, diagnostic in mutations:
            require(block.count(before) == 1, f'MUTATION_TARGET: {name} must be unique')
            mutant = (text[:start] + block.replace(before, after) + text[end:]).encode()
            path = out / f'Makefile.{name}'
            path.write_bytes(mutant)
            output = dry_run(path, name, rate, dma)
            try:
                verify(output, rate, dma)
            except ProfileAssertion as error:
                if str(error) != diagnostic:
                    raise AssertionError(f'{name}: wrong verifier failure: {error}') from error
            else:
                raise AssertionError(f'{name}: mutation escaped verifier')
            require(path.read_bytes() == mutant, f'MUTATION_STABILITY: {name}')
            report['negative'].append({'name': name, 'sha256': sha(mutant),
                                       'diagnostic': diagnostic, 'make_exit_code': 0})
            save()
            print('PASS negative', name, diagnostic, flush=True)
        stable()
        report['inputs_stable'] = True
        report['status'] = 'pass'
        print('PASS four expanded FDC profiles and ten specific mutation rejections; dry-run only', flush=True)
    except Exception as error:
        report['status'] = 'fail'
        report['error'] = str(error)
        raise
    finally:
        save()


if __name__ == '__main__':
    main()
