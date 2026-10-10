#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Original generated-asset checks, not a native software loading qualification.

Explicit --build-only freezes sources/builds only; --run additionally executes
synthetic IPL/controller/waveforms. Never reads private software. No Make edits.
Evidence and failed logs are retained. No automatic retries.
"""
import argparse
import csv
import hashlib
import importlib.util
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


def generated_ipl(Program, play):
    """CPU executes real PPI/mailbox writes; host supplies no responses."""
    p = Program()
    p.emit(0xF3)
    p.word(0x31, 0xFFFF)
    p.word(0x01, 0x1A03)
    p.emit(0x3E, 0x82, 0xED, 0x79)  # PB input
    p.word(0x01, 0x1A01)
    p.emit(0xED, 0x78)             # IN clears actual DAM
    if play:
        for idx, value in enumerate((0xE9, 2)):
            p.word(0x01, 0x1A01)
            p.label(f'send-{idx}')
            p.emit(0xED, 0x78, 0xE6, 0x40)
            p.jump(0xC2, f'send-{idx}')
            p.word(0x01, 0x1900)
            p.emit(0x3E, value, 0xED, 0x79)
    p.store(0xF010, 0x5A)
    p.emit(0x76)
    data = p.finish()
    assert len(data) <= 4096
    return data + bytes(4096 - len(data))


def tap(bits, start=0, rate=8000, flag=1):
    header = bytearray(40)
    header[:4] = b'TAPE'
    header[27] = flag
    for at, n in ((28, rate), (32, len(bits)), (36, start)):
        header[at:at+4] = n.to_bytes(4, 'little')
    payload = bytearray((len(bits)+7)//8)
    for i, bit in enumerate(bits):
        if bit:
            payload[i//8] |= 0x80 >> (i%8)
    return bytes(header+payload)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    actions = parser.add_mutually_exclusive_group(required=True)
    actions.add_argument('--build-only', action='store_true')
    actions.add_argument('--run', action='store_true')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--jobs', type=int, default=2)
    parser.add_argument('--wall-seconds', type=float, default=600)
    args = parser.parse_args()
    if args.jobs < 1 or args.wall_seconds <= 0:
        parser.error('positive jobs/wall-seconds required')
    root = Path(__file__).resolve().parents[2]
    out = args.output.resolve() if args.output else Path(tempfile.mkdtemp(prefix='x1-cassette-runner-')).resolve()
    if args.output:
        allowed = (Path(tempfile.gettempdir()).resolve(), (root/'output_files').resolve())
        if not any(out != base and out.is_relative_to(base) for base in allowed):
            parser.error('output must be new tmp/ignored-output subdirectory')
        out.mkdir(parents=True, exist_ok=False)
    print(f'EVIDENCE={out}', flush=True)
    order = re.findall(r'^set_global_assignment -name (?:SYSTEMVERILOG_FILE|VERILOG_FILE) (\S+)\s*$',
                       (root/'rtl/machine.qip').read_text(), re.M)
    if not order or len(order) != len(set(order)):
        raise RuntimeError('machine manifest missing/duplicate sources')
    inputs = list(dict.fromkeys(order + [
        'rtl/machine.qip', 'verilator/sim_cassette.v', 'verilator/cassette_main.cpp',
        'verilator/frame_capture.h', 'verilator/x1_tap_image.h',
        'verilator/tests/test_cassette_runner.py', 'verilator/tests/z80_fixture.py',
        'scripts/build_mr16_cassette_firmware.py', 'scripts/assemble_mr16.py',
    ] + [str(p.relative_to(root)) for p in sorted((root/'bios/reference/fw_subcpu').rglob('*'))
         if p.is_file() and p.suffix.lower() in ('.asm', '.inc', '.bin')]))
    hashes = {rel: sha(root/rel) for rel in inputs}
    frozen = out/'sources'
    for rel in inputs:
        dest = frozen/rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes((root/rel).read_bytes())
        if sha(dest) != hashes[rel]:
            raise RuntimeError(f'input changed during freeze: {rel}')
    def verify():
        for rel, digest in hashes.items():
            if sha(root/rel) != digest or sha(frozen/rel) != digest:
                raise RuntimeError(f'source mutation: {rel}')
    def manifest(name):
        (out/name).write_text(''.join(f'{hashes[rel]}  {rel}\n' for rel in inputs))
    manifest('source.before.sha256')
    terminal = {'phase': 'failed', 'scope': 'generated-assets-only', 'checks': 0}
    try:
        command = ['verilator', '--cc', '--exe', '--build', '--timing',
                   '--top-module', 'cassette_top', '--Mdir', str(out/'obj'),
                   '-j', str(args.jobs), '-CFLAGS', '-std=c++20 -O2',
                   '-MAKEFLAGS', '-B', '-Wno-fatal', 'verilator/sim_cassette.v',
                   *order, str(frozen/'verilator/cassette_main.cpp'), '-o', 'cassette_runner']
        (out/'build-command.json').write_text(json.dumps(command, indent=2)+'\n')
        with (out/'build.log').open('w') as log:
            result = subprocess.run(command, cwd=frozen, stdout=log, stderr=subprocess.STDOUT,
                                    timeout=args.wall_seconds, check=False)
        if result.returncode:
            raise RuntimeError(f'build exit {result.returncode}; see build.log')
        warnings = [line for line in (out/'build.log').read_text().splitlines()
                    if 'warning' in line.lower()]
        (out/'warnings.json').write_text(json.dumps(warnings, indent=2)+'\n')
        terminal['warning_lines'] = len(warnings)
        verify()
        exe = out/'obj/cassette_runner'
        executable_hash = sha(exe)
        terminal['executable_sha256'] = executable_hash
        if args.run:
            sys.path.insert(0, str(frozen/'scripts'))
            load(frozen/'scripts/assemble_mr16.py', 'assemble_mr16')
            builder = load(frozen/'scripts/build_mr16_cassette_firmware.py', 'cassette_runner_builder')
            emitter = load(frozen/'verilator/tests/z80_fixture.py', 'cassette_runner_emitter')
            controller, _, report = builder.build(receive_only=True, with_report=True)
            assets = out/'generated'
            assets.mkdir()
            (assets/'controller.bin').write_bytes(controller)
            (assets/'controller-source-report.json').write_text(json.dumps(report, indent=2)+'\n')
            (assets/'play.bin').write_bytes(generated_ipl(emitter.Program, True))
            (assets/'stop.bin').write_bytes(generated_ipl(emitter.Program, False))
            (assets/'play8.bin').write_bytes((assets/'play.bin').read_bytes()+bytes([0xA5])*4096)
            bits = [0, 1, 1, 0, 1, 0, 0, 1, 0, 1, 1, 0, 1]
            (assets/'tape.tap').write_bytes(tap(bits, start=3))
            original_assets = {str(p): sha(p) for p in assets.iterdir() if p.is_file()}
            def invoke(name, ipl='play.bin', data=None, extra=(), ok=True, cycles=3000000, rejection=None):
                tape_path = assets/'tape.tap'
                if data is not None:
                    tape_path = assets/(name+'.tap')
                    tape_path.write_bytes(data)
                    original_assets[str(tape_path)] = sha(tape_path)
                destination = out/name
                cmd = [str(exe), '--ipl', str(assets/ipl), '--controller', str(assets/'controller.bin'),
                       '--tape', str(tape_path), '--cycles', str(cycles), '--output', str(destination),
                       '--marker-address', '0xf010', *extra]
                (out/(name+'.command.json')).write_text(json.dumps(cmd, indent=2)+'\n')
                with (out/(name+'.log')).open('w') as log:
                    r = subprocess.run(cmd, cwd=frozen, stdout=log, stderr=subprocess.STDOUT,
                                       timeout=args.wall_seconds, check=False)
                if ok:
                    if r.returncode:
                        raise AssertionError(f'{name} exit {r.returncode}')
                    result = json.loads((destination/'report.json').read_text())
                    assert result['inputs_unchanged'] and result['terminal_exit'] == 0
                    assert result['executable_sha256'] == executable_hash
                    assert result['controller_sha256'] == sha(assets/'controller.bin')
                    assert result['ipl_sha256'] == sha(assets/ipl)
                    assert result['tape_sha256'] == sha(tape_path)
                    assert result['time_ps'] == cycles*31250
                    assert result['marker_value'] == 0x5A
                    terminal['checks'] += 1
                    return result
                assert rejection is not None, 'negative requires an exact diagnostic'
                assert r.returncode == 1 and not destination.exists(), name
                assert rejection in (out/(name+'.log')).read_text(), name
                terminal['checks'] += 1
            for name, data, rejection in (
                ('truncated', b'TAPE', 'truncated new header'),
                ('bad-rate', tap(bits, rate=44100), 'only 8000 Hz supported'),
                ('format-zero', tap(bits, flag=0), 'format-zero waveform semantics unresolved'),
                ('unknown-format', tap(bits, flag=2), 'unknown encoding flags'),
                ('bad-position', tap(bits, start=14), 'position exceeds sample count'),
                ('bad-count', tap(bits)[:-1], 'declared bit count does not match payload length')):
                invoke(name, data=data, ok=False, rejection=rejection)
            invoke('short-duration', ok=False, cycles=12352,
                   rejection='cycles must exceed 12352 startup cycles')
            invoke('snapshot-refused', ok=False, extra=('--restore', 'unused'),
                   rejection='unsupported option: --restore')
            for name, rom in (('play4', 'play.bin'), ('play8', 'play8.bin')):
                r = invoke(name, ipl=rom)
                assert r['uploads_accepted'] == 12288 and r['ipl_mapped_bytes'] == 4096
                assert r['accepted_samples'] == 10 and r['accepted_sample_cursor'] == 13
                assert r['playback_eof'] and not r['underflow'] and r['mode'] == 1
                with (out/name/'events.csv').open() as f:
                    events = list(csv.DictReader(f))
                records = [row for row in events if row['event'] == 'accept']
                assert [int(row['cursor']) for row in records] == list(range(3, 13))
                assert [int(row['level']) for row in records] == bits[3:]
                assert [int(row['last']) for row in records] == [0]*9+[1]
                times = [int(row['time_ps']) for row in records]
                assert all(b-a == 125000000 for a, b in zip(times, times[1:]))
                eof = [int(row['time_ps']) for row in events
                       if row['event'] == 'state' and row['sensor'] == '2']
                assert eof == [times[-1]+125000000], 'final sample must receive its full physical slot'
                expected_wave, level = [], 0
                for when, sample in zip(times, bits[3:]):
                    if sample != level:
                        expected_wave.append((when, sample))
                        level = sample
                if level:
                    expected_wave.append((eof[0], 0))
                wave = [(int(row['time_ps']), int(row['level'])) for row in events
                        if row['event'] == 'waveform']
                assert wave == expected_wave, 'public waveform transitions differ from accepted held samples'
            stopped = invoke('stopped', ipl='stop.bin')
            assert stopped['accepted_samples'] == 0 and stopped['accepted_sample_cursor'] == 3
            empty = invoke('empty', data=tap([], start=0))
            assert empty['accepted_samples'] == 0 and empty['playback_eof']
            for p, digest in original_assets.items():
                assert sha(Path(p)) == digest, f'generated original changed: {p}'
            assert sha(exe) == executable_hash
        verify()
        terminal['phase'] = 'synthetic-pass' if args.run else 'build-only'
    finally:
        try:
            verify()
            manifest('source.after.sha256')
            terminal['sources_unchanged'] = True
        except Exception:
            terminal['sources_unchanged'] = False
            terminal['phase'] = 'failed'
            raise
        finally:
            (out/'terminal.json').write_text(json.dumps(terminal, indent=2)+'\n')
            (out/'evidence.sha256').write_text(''.join(
                f'{sha(p)}  {p.relative_to(out)}\n' for p in sorted(out.rglob('*'))
                if p.is_file() and p.name != 'evidence.sha256' and not p.is_relative_to(out/'obj')))
    print(json.dumps(terminal), flush=True)


if __name__ == '__main__':
    main()
