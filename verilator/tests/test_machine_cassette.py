#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Original generated Z80/MR16 public-machine cassette diagnostic.

No private IPL/tape, RAM injection, fake mailbox completion or native loader
claim. PB0 is the opt-in held BREAK route, not native read-cleared tape STOP.
All module imports used for asset generation come from captured input copies.
Default action prepares assets only; --build-only permits reviewed compilation;
--run explicitly executes the selected bounded cases and matching controls.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

CASES = {'transport': 0, 'ctrl-c': 1, 'plain-c': 2, 'reset': 3,
         'empty': 4, 'mount-play-tie': 5}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def program(case, Program):
    """Real PPI/1900 mailbox protocol, with CPU-executed store/check oracle."""
    p = Program()
    p.emit(0xF3)                 # DI: no synthetic Z80 host IRQ completion
    p.word(0x31, 0xFFFF)
    serial = 0

    def unique(prefix):
        nonlocal serial
        serial += 1
        return f'{prefix}-{serial}'

    def phase(value):
        p.store(0xF011, value)
        p.store(0xF010, value)

    def send(value):
        label = unique('tx')
        p.word(0x01, 0x1A01)
        p.label(label)
        p.emit(0xED, 0x78, 0xE6, 0x40)
        p.jump(0xC2, label)       # firmware mailbox space, PB6=0
        p.word(0x01, 0x1900)
        p.emit(0x3E, value, 0xED, 0x79)

    def read(command, count=1, address=0xF030):
        send(command)
        for offset in range(count):
            label = unique('rx')
            p.word(0x01, 0x1A01)
            p.label(label)
            p.emit(0xED, 0x78, 0xE6, 0x20)
            p.jump(0xC2, label)   # actual firmware response, PB5=0
            p.word(0x01, 0x1900)
            p.emit(0xED, 0x78)
            p.word(0x32, address + offset)

    def expect(command, value, wait=False):
        label = unique('expect')
        p.label(label)
        read(command)
        p.emit(0xFE, value)
        p.jump(0xC2, label if wait else 'fail')

    def command(value):
        send(0xE9)
        send(value)

    def delay(count):
        label = unique('delay')
        p.word(0x21, count)
        p.label(label)
        p.emit(0x2B, 0x7C, 0xB5) # DEC HL; LD A,H; OR L
        p.jump(0xC2, label)

    def break_pin(value, wait=False):
        label = unique('break')
        p.word(0x01, 0x1A01)
        p.label(label)
        p.emit(0xED, 0x78, 0xE6, 1, 0xFE, value)
        p.jump(0xC2, label if wait else 'fail')

    phase(1)
    for i in range(4):
        p.store(0xF000 + i, 0)
    p.word(0x01, 0x1A03)
    p.emit(0x3E, 0x82, 0xED, 0x79)  # PB input, existing mailbox convention
    p.word(0x01, 0x1A01)
    p.emit(0xED, 0x78)             # real IN releases DAM after mode-set
    phase(0x10)
    expect(0xEB, 2 if case == 4 else 3, wait=True) # public mount comes from TB
    expect(0xEA, 1)

    if case == 4:
        phase(0x20)
        command(2)
        expect(0xEA, 1)
        expect(0xEB, 2)
        command(0xFF)
        expect(0xEA, 1)
        command(1)
        command(0)
        expect(0xEA, 0)
        expect(0xEB, 0)
    elif case == 1:
        command(2)
        expect(0xEA, 2, wait=True)
        phase(0x50)
        expect(0xEA, 1, wait=True) # only actual PS2-triggered executed setter stops
        break_pin(0, wait=True)
        phase(0x60)
        break_pin(1, wait=True)
        phase(0x70)
        label = unique('recovered-key')
        p.label(label)
        read(0xE6, count=2, address=0xF040) # CTRL first, ASCII second (packed word)
        p.emit(0xFE, 0x41)       # source startup CAPS ON: actual A make
        p.jump(0xC2, label)
        phase(0x80)
        expect(0xEA, 1)
        expect(0xEB, 3)
    elif case == 2:
        command(2)
        expect(0xEA, 2, wait=True)
        phase(0x50)
        delay(4000)             # ~26ms, beyond complete plain-C make/release
        expect(0xEA, 2)
        expect(0xEB, 3)
        break_pin(1)
        command(1)
        expect(0xEA, 1)
    elif case == 3:
        command(2)
        expect(0xEA, 2, wait=True)
        phase(0x50)
        delay(4000)             # first boot reset externally; second executes stores
        expect(0xEA, 2)
        expect(0xEB, 3)
        command(1)
        expect(0xEA, 1)
    else:
        command(1)
        command(1)             # identical commands, distinct low/high commits
        expect(0xEA, 1)
        if case == 5:
            phase(0x15)
            command(2)         # public mount deliberately coincides with commit
            expect(0xEA, 1)    # mount drops PLAY; firmware must return applied STOP
            expect(0xEB, 3)
        command(2)
        expect(0xEA, 2, wait=True)
        phase(0x20)
        # Independent CPU PPI readback: E records presence of low and high.
        p.word(0x01, 0x1A01)
        p.word(0x21, 512)
        p.emit(0x1E, 0)         # LD E,0
        loop, low, next_sample = unique('wave'), unique('low'), unique('next')
        p.label(loop)
        p.emit(0xED, 0x78, 0xE6, 2)
        p.jump(0xCA, low)
        p.emit(0x7B, 0xF6, 2, 0x5F) # LD A,E; OR 2; LD E,A
        p.jump(0xC3, next_sample)
        p.label(low)
        p.emit(0x7B, 0xF6, 1, 0x5F)
        p.label(next_sample)
        p.emit(0x2B, 0x7C, 0xB5)
        p.jump(0xC2, loop)
        p.emit(0x7B)
        p.word(0x32, 0xF020)
        p.emit(0xFE, 3)
        p.jump(0xC2, 'fail')
        command(1)
        expect(0xEA, 1, wait=True)
        phase(0x30)
        delay(512)             # phase/sample held while stopped
        expect(0xEB, 3)
        command(2)
        expect(0xEA, 2, wait=True)
        phase(0x40)
        for unsupported in (3, 4, 5, 6, 0x0A, 0xFF):
            command(unsupported)
            expect(0xEA, 2)
        expect(0xEA, 1, wait=True) # live EOF, not cached requested PLAY
        expect(0xEB, 2)
        command(2)              # PLAY cannot resume past EOF
        expect(0xEA, 1)
        command(0)
        expect(0xEA, 0)
        expect(0xEB, 0)

    for i, value in enumerate(b'CASS'):
        p.store(0xF000 + i, value)
    phase(0x90)
    p.label('done')
    p.emit(0x76)
    p.jump(0xC3, 'done')
    p.label('fail')
    p.store(0xF000, 0xEE)
    p.emit(0x76)
    p.jump(0xC3, 'fail')
    data = p.finish()
    assert len(data) <= 4096, 'base IPL aperture exceeded'
    return data + bytes(8192 - len(data))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group()
    action.add_argument('--build-only', action='store_true')
    action.add_argument('--run', action='store_true')
    parser.add_argument('--cases', nargs='+', choices=CASES, default=list(CASES))
    parser.add_argument('--negative', choices=('missing-normalization', 'disabled', 'rtc-combo'))
    parser.add_argument('--output', type=Path)
    parser.add_argument('--wall-seconds', type=float, default=600)
    parser.add_argument('--jobs', type=int, default=2)
    parser.add_argument('--debug', action='store_true', help='read-only MR16 work-store trace; never state injection')
    args = parser.parse_args()
    if args.wall_seconds <= 0 or args.jobs < 1:
        parser.error('positive wall-seconds/jobs required')
    root = Path(__file__).resolve().parents[2]
    out = args.output.resolve() if args.output else Path(tempfile.mkdtemp(prefix='x1-machine-cassette-')).resolve()
    if args.output:
        allowed = (Path(tempfile.gettempdir()).resolve(), Path('/tmp').resolve(),
                   (root / 'output_files').resolve())
        if not any(out != base and out.is_relative_to(base) for base in allowed):
            parser.error('output must be a NEW subdirectory of disposable tmp or ignored output_files')
        out.mkdir(parents=True, exist_ok=False)
    print(f'FROZEN_FOLDER={out}', flush=True)
    order = re.findall(r'^set_global_assignment -name (?:SYSTEMVERILOG_FILE|VERILOG_FILE) (\S+)\s*$',
                       (root / 'rtl/machine.qip').read_text(), re.M)
    assert order and len(order) == len(set(order)), 'source order missing/duplicate'
    inputs = list(dict.fromkeys(order + ['rtl/machine.qip', 'verilator/Makefile',
        'verilator/tests/machine_cassette_tb.sv', 'verilator/tests/test_machine_cassette.py',
        'verilator/tests/z80_fixture.py', 'scripts/build_mr16_cassette_firmware.py',
        'scripts/assemble_mr16.py'] +
        [str(p.relative_to(root)) for p in sorted((root / 'bios/reference/fw_subcpu').glob('*.asm'))] +
        [str(p.relative_to(root)) for p in sorted((root / 'bios/reference/fw_subcpu').glob('*.inc'))] +
        ['bios/reference/fw_subcpu/verilog/X1SUB.BIN']))
    hashes = {rel: sha(root / rel) for rel in inputs}
    for rel in inputs:
        destination = out / 'sources' / rel
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(root / rel, destination)
        assert sha(destination) == hashes[rel] == sha(root / rel), f'input changed while freezing: {rel}'
    (out / 'inputs.json').write_text(json.dumps(hashes, indent=2) + '\n')
    (out / 'source-order.json').write_text(json.dumps(order, indent=2) + '\n')
    status = {'phase': 'captured', 'scope': 'original connected CPU/MR16 virtual readonly deck; not native tape loading',
              'driver_pid': __import__('os').getpid(), 'runs': [], 'negative': args.negative}

    def save():
        (out / 'status.json').write_text(json.dumps(status, indent=2) + '\n')

    def wait_child(child, record):
        """Clean up only this spawned child on timeout; never a global PID scan.

        Logs use regular files, so wait drains/reaps without pipe deadlock.
        A timeout remains an orchestration failure even if the child printed
        an expected negative assertion before termination.
        """
        record.update(pid=child.pid, timed_out=False)
        save()
        try:
            rc = child.wait(timeout=args.wall_seconds)
        except subprocess.TimeoutExpired:
            record.update(timed_out=True, cleanup='terminate')
            child.terminate()
            try:
                rc = child.wait(timeout=5)
            except subprocess.TimeoutExpired:
                record['cleanup'] = 'terminate-then-kill'
                child.kill()
                rc = child.wait()
            record.update(phase='timeout', returncode=rc, finished=time.time())
            save()
            raise TimeoutError(f'child {child.pid} timed out; reaped rc={rc}')
        record.update(phase='terminal', returncode=rc, finished=time.time())
        save()
        return rc

    def check_sources():
        for rel, digest in hashes.items():
            assert sha(root / rel) == digest, f'live input changed: {rel}'
            assert sha(out / 'sources' / rel) == digest, f'frozen input changed: {rel}'

    save()
    frozen = out / 'sources'
    mutated = None
    generated = {}
    try:
        check_sources()
        # Import frozen emitter/builder only AFTER successful input capture.
        emitter = load(frozen / 'verilator/tests/z80_fixture.py', 'cassette_frozen_emitter')
        sys.path.insert(0, str(frozen / 'scripts'))
        load(frozen / 'scripts/assemble_mr16.py', 'assemble_mr16')
        builder = load(frozen / 'scripts/build_mr16_cassette_firmware.py', 'cassette_frozen_builder')
        image, _, report = builder.build(receive_only=True, with_report=True)
        (out / 'firmware.report.json').write_text(json.dumps(report, indent=2) + '\n')
        if args.negative == 'missing-normalization':
            old = 'cassette_brk_ctrl:\n    shr r0,#8\n    and r0,#0ffh:8\n'
            assert builder.EXTENSION.count(old) == 1
            # Separate derived builder tree; primary frozen inputs remain intact.
            mutation_root = out / 'mutation'
            for rel in inputs:
                if rel.startswith(('scripts/', 'bios/reference/')):
                    dest = mutation_root / rel
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(frozen / rel, dest)
            mutated = mutation_root / 'scripts/build_mr16_cassette_firmware.py'
            text = mutated.read_text()
            assert text.count(old) == 1
            mutated.write_text(text.replace(old, 'cassette_brk_ctrl:\n'))
            mutation_hashes = {str(p.relative_to(mutation_root)): sha(p)
                               for p in mutation_root.rglob('*') if p.is_file()}
            for rel, digest in mutation_hashes.items():
                if rel != 'scripts/build_mr16_cassette_firmware.py':
                    assert digest == hashes[rel], f'unintended negative mutation: {rel}'
            (out / 'mutation.json').write_text(json.dumps(mutation_hashes, indent=2) + '\n')
            mutant = load(mutated, 'cassette_negative_builder')
            image, _, negative_report = mutant.build(receive_only=True, with_report=True)
            (out / 'negative-firmware.report.json').write_text(json.dumps(negative_report, indent=2) + '\n')
        rom = out / 'controller.hex'
        rom.write_text(''.join(f'{int.from_bytes(image[i:i+2], "little"):04x}\n' for i in range(0, len(image), 2)))
        generated[rom.name] = sha(rom)
        selected = ['ctrl-c'] if args.negative == 'missing-normalization' else \
                   ['transport'] if args.negative else args.cases
        for name in selected:
            path = out / f'{name}.ipl.hex'
            path.write_text(''.join(f'{b:02x}\n' for b in program(CASES[name], emitter.Program)))
            generated[path.name] = sha(path)
        (out / 'generated.json').write_text(json.dumps(generated, indent=2) + '\n')
        check_sources()
        if not (args.build_only or args.run):
            status['phase'] = 'prepared-not-built'
            print('PREPARED: generated assets only; no simulation executed', flush=True)
            return
        command = ['verilator', '--binary', '--timing', '--assert', '-Wno-fatal',
            '--top-module', 'machine_cassette_tb', '--Mdir', str(out / 'build'), '-j', str(args.jobs),
            f'-GCASSETTE_ENABLED={0 if args.negative == "disabled" else 1}',
            f'-GRTC_ENABLED={1 if args.negative == "rtc-combo" else 0}',
            *(str(frozen / rel) for rel in order), str(frozen / 'verilator/tests/machine_cassette_tb.sv')]
        (out / 'build.command.json').write_text(json.dumps(command, indent=2) + '\n')
        status.update(phase='building', started=time.time())
        save()
        with (out / 'build.log').open('w') as log:
            child = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
            status['build_pid'] = child.pid
            status['build'] = {'phase': 'running', 'log': str(out / 'build.log')}
            rc = wait_child(child, status['build'])
        assert rc == 0, f'build failed ({rc}): {out / "build.log"}'
        exe = out / 'build/Vmachine_cassette_tb'
        exe_sha = sha(exe)
        (out / 'executable.sha256').write_text(exe_sha + '\n')
        status.update(phase='built-not-run', build_returncode=rc)
        save()
        # Keep inherited warnings visible; this records, not suppresses, them.
        warning_lines = [line for line in (out / 'build.log').read_text().splitlines()
                         if line.startswith('%Warning')]
        (out / 'warnings.json').write_text(json.dumps(warning_lines, indent=2) + '\n')
        if not args.run:
            print(f'BUILT_NOT_RUN executable_sha256={exe_sha} warnings={len(warning_lines)}', flush=True)
            return
        rejection = {'missing-normalization': 'CASSETTE_CTRL_C_STOP_MISSING',
                     'disabled': 'CASSETTE_MOUNT_SENSOR_MISSING',
                     'rtc-combo': 'RTC and cassette controller GPIO profiles are exclusive'}.get(args.negative)
        for name in selected:
            command = [str(exe), f'+ROM={rom}', f'+IPL={out / (name + ".ipl.hex")}',
                       f'+CASE={CASES[name]}', f'+TRACE={out / (name + ".csv")}']
            if args.debug:
                command.append('+DEBUG')
            (out / f'{name}.command.json').write_text(json.dumps(command, indent=2) + '\n')
            record = {'case': name, 'phase': 'running', 'log': str(out / f'{name}.log'), 'started': time.time()}
            status['runs'].append(record)
            status['phase'] = 'running'
            with (out / f'{name}.log').open('w') as log:
                child = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
                rc = wait_child(child, record)
            text = (out / f'{name}.log').read_text()
            record.update(phase='terminal', returncode=rc, finished=time.time())
            save()
            print(text, end='', flush=True)
            if rejection:
                assert rc != 0 and rejection in text, 'exact simulation rejection absent; build/timeout is not a negative PASS'
            else:
                assert rc == 0 and f'PASS cassette machine case={CASES[name]}' in text, f'case failed: {name}'
            assert sha(exe) == exe_sha, 'executable changed during run'
            for rel, digest in generated.items():
                assert sha(out / rel) == digest, f'generated input changed: {rel}'
            check_sources()
        status['phase'] = 'passed'
        print('PASS driver: frozen input/executable/generated asset checks; exact case or rejecting-control assertions', flush=True)
    except BaseException as error:
        status.update(phase='failed', error=repr(error))
        raise
    finally:
        try:
            check_sources()
            if mutated:
                for rel, digest in mutation_hashes.items():
                    assert sha(out / 'mutation' / rel) == digest, f'negative input changed: {rel}'
            status['final_source_check'] = 'passed'
        except BaseException as error:
            status.update(phase='failed', final_source_check=repr(error))
            save()
            raise
        save()


if __name__ == '__main__':
    main()
