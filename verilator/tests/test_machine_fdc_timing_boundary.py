#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Original public-mount consumer-CE/store/prefill gate, not native timing."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time

CASES = ['consumer-read', 'consumer-write', 'final-store', 'prefill',
         'control-read', 'control-write']
PROTECTED = {
    'verilator/tests/fdc_timing_media_machine_tb.sv': 'cc031203eaec8ab3c97c639a4e553a2fcd44a6d462f002ecd1d5c6d6cb5750f6',
    'verilator/tests/test_machine_fdc_timing_media.py': 'f47ae3911ec93b0eddd1c3d7147a0abf4c27a18a7fad52c79124a2bd42d7e808',
    'verilator/tests/fdc_timing_machine_tb.sv': '65225d5356ee3670f2a820b8fa5e111d87588331500018d28a1b09d2c8d9928e',
    'verilator/tests/test_machine_fdc_timing.py': '8f74ef25baab3ebc60ba25336c111de961970b673862680cfb6826957952acf7',
}


def payload(d, i):
    if i == 255:
        return 0xD3 if d == 0 else 0x6C
    return (i * 37 + (i >> 8) * 53 + d * 104 + 19) & 255


def program(case, drive, rate, Program):
    """Original opcode diagnostic. All storage and service through CPU/DMA."""
    p = Program()
    p.emit(0xF3)
    p.word(0x31, 0xFFFF)
    serial = 0

    def out(port, value):
        p.word(0x01, port)
        p.emit(0x3E, value, 0xED, 0x79)

    def poll(mask):
        nonlocal serial
        serial += 1
        label = f'poll{serial}'
        p.word(0x01, 0x0FF8)
        p.label(label)
        p.emit(0xED, 0x78, 0xE6, mask)
        p.jump(0xC2, label)

    def select(d):
        out(0x0FFC, 0x80 | d)
        poll(0x81)

    def dma(writing):
        values = ([0xC3, 0x79, 0, 0x90, 255, 0, 0x14, 0x28, 0xAD,
                   0xFB, 0x0F, 0x92, 0xCF, 0x05, 0xCF, 0xBB, 1, 0xA7]
                  if writing else
                  [0xC3, 0x7D, 0xFB, 0x0F, 255, 0, 0x2C, 0x10, 0xAD,
                   0, 0xA0, 0x92, 0xCF, 0xBB, 1, 0xA7])
        for value in values:
            out(0x1F80, value)

    def transfer(writing, service=True, check=True):
        if service:
            dma(writing)
        out(0x0FFA, 1)
        out(0x0FF8, 0xA0 if writing else 0x80)
        if service:
            out(0x1F80, 0x87)
        poll(0x81)
        if service:
            out(0x1F80, 0x83)
        if check:
            p.word(0x01, 0x0FF8)
            p.emit(0xED, 0x78, 0xE6, 0xFC)
            p.jump(0xC2, 'fail')

    p.word(0x01, 0x1234)  # Real IN clears DAM.
    p.emit(0xED, 0x78)
    p.word(0x01, 0x0FFD)  # MFM control alias.
    p.emit(0xED, 0x78)
    select(drive)
    writing = case in (1, 2, 3, 5)
    if writing:
        for i in range(256):
            p.store(0x9000 + i, payload(drive, i) ^ 0xA7)
    p.store(0xF010, 1)
    transfer(writing, service=case != 3, check=case >= 4)
    # No reset or injected RAM sentinel: wait for public remount/rescan then
    # recover using real drive selects, physical DRQ DMA and CPU comparisons.
    for address in (0x9FFF, 0xA100, 0x8FFF, 0x9100):
        p.store(address, 0x63)
    for d, marker in ((drive ^ 1, 16), (drive, 32)):
        select(d)
        p.store(0xF010, marker)
        transfer(False)
        for i in range(256):
            expected = payload(d, i) ^ (0xA7 if case == 5 and d == drive else 0)
            p.compare_memory(0xA000 + i, expected)
    for i in range(256):
        p.store(0x9000 + i, payload(drive, i) ^ 0x5A)
    p.store(0xF010, 48)
    transfer(True)
    p.store(0xF010, 64)
    transfer(False)
    for i in range(256):
        p.compare_memory(0xA000 + i, payload(drive, i) ^ 0x5A)
        p.compare_memory(0x9000 + i, payload(drive, i) ^ 0x5A)
    for address in (0x9FFF, 0xA100, 0x8FFF, 0x9100):
        p.compare_memory(address, 0x63)
    p.store(0xF000, 0x5A)
    p.label('halt')
    p.emit(0x76)
    p.jump(0xC3, 'halt')
    p.label('fail')
    p.store(0xF000, 0xEE)
    p.emit(0x76)
    p.jump(0xC3, 'fail')
    return p.finish()


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--machine-sha', required=True)
    ap.add_argument('--rate', type=int, choices=[1000000, 2000000], default=1000000)
    ap.add_argument('--width', type=int, choices=[20, 24], default=20)
    ap.add_argument('--case', choices=CASES)
    ap.add_argument('--drive', type=int, choices=[0, 1])
    ap.add_argument('--negative', choices=['consumer-taken', 'final-store', 'prefill-stop', 'last-byte', 'ledger'])
    ap.add_argument('--wall-seconds', type=int, default=300)
    args = ap.parse_args()
    root = Path(__file__).resolve().parents[2]
    assert digest(root / 'rtl/sharpx1.v') == args.machine_sha
    for relative, sha in PROTECTED.items():
        assert digest(root / relative) == sha, ('qualified file changed', relative)
    order = re.findall(r'-name (?:SYSTEMVERILOG_FILE|VERILOG_FILE) (\S+)',
                       (root / 'rtl/machine.qip').read_text())
    inputs = list(dict.fromkeys(order + ['rtl/machine.qip',
        'verilator/tests/fdc_timing_boundary_machine_tb.sv',
        'verilator/tests/test_machine_fdc_timing_boundary.py',
        'verilator/tests/z80_fixture.py', *PROTECTED]))
    out = Path(tempfile.mkdtemp(prefix='x1-fdc-boundary-machine-'))
    manifest = {}
    for relative in inputs:
        target = out / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(root / relative, target)
        manifest[relative] = digest(target)
    assert manifest['rtl/sharpx1.v'] == args.machine_sha
    (out / 'sources.json').write_text(json.dumps(manifest, indent=2) + '\n')
    (out / 'source-order.json').write_text(json.dumps(order, indent=2) + '\n')
    print(f'Frozen sources/logs: {out}', flush=True)
    status = {'phase': 'frozen', 'runs': []}

    def save():
        (out / 'status.json').write_text(json.dumps(status, indent=2) + '\n')

    save()
    spec = importlib.util.spec_from_file_location('frozen_z80', out / 'verilator/tests/z80_fixture.py')
    emitter = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(emitter)
    spec = importlib.util.spec_from_file_location('frozen_boundary',
        out / 'verilator/tests/test_machine_fdc_timing_boundary.py')
    frozen_checker = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(frozen_checker)
    mutated, mutation_sha, rejection = None, None, None
    if args.negative:
        variants = {
            'consumer-taken': ('rtl/x1_fdc_completion.sv',
                'valid && consume && !reset && !cancel', 'valid && consume && !reset',
                'consumer collision accepted cancelled lease', 1),
            'final-store': ('rtl/vendor/wd1793.sv',
                'assign timing_buffer_store = write_emit && state == STATE_TIMING_WAIT && !timing_cancel;',
                'assign timing_buffer_store = write_emit && state == STATE_TIMING_WAIT;',
                'cancelled final store remained eligible', 2),
            'prefill-stop': ('rtl/vendor/wd1793.sv',
                '.stop(timing_cancel), .length(data_length)', '.stop(reset), .length(data_length)',
                'cancelled prefill remained armed', 3),
            'last-byte': ('rtl/vendor/wd1793.sv',
                'assign timing_buffer_address = {2\'d0, buff_a[8:0]} + (write_emit ? write_index : byte_index);',
                'assign timing_buffer_address = {2\'d0, buff_a[8:0]} + (write_emit ? (write_index == 11\'d255 ? 11\'d254 : write_index) : byte_index);',
                'published block differs from independent ledger', 5),
            'ledger': ('rtl/vendor/wd1793.sv',
                '(timing_buffer_store ? timing_write_byte : (format || zero_write_byte ? 8\'d0 : din))',
                '(timing_buffer_store ? (timing_write_byte ^ 8\'h01) : (format || zero_write_byte ? 8\'d0 : din))',
                'published block differs from independent ledger', 5),
        }
        mutated, old, new, rejection, c = variants[args.negative]
        cases = [(c, 0)]
        target = out / mutated
        body = target.read_text()
        assert body.count(old) == 1
        target.write_text(body.replace(old, new))
        mutation_sha = digest(target)
        (out / 'mutation.json').write_text(json.dumps({'file': mutated,
            'original_sha256': manifest[mutated], 'sha256': mutation_sha,
            'old': old, 'new': new, 'count': 1, 'diagnostic': rejection}, indent=2) + '\n')
    else:
        cases = [(c, d) for c in ([CASES.index(args.case)] if args.case else range(6))
                 for d in ([args.drive] if args.drive is not None else range(2))]
    roms = []
    for c, d in cases:
        data = frozen_checker.program(c, d, args.rate, emitter.Program)
        path = out / f'case{c}-drive{d}.hex'
        path.write_text(''.join(f'{b:02x}\n' for b in data))
        roms.append((c, d, path, len(data)))
    rom_hashes = {p.name: digest(p) for _, _, p, _ in roms}
    (out / 'roms.json').write_text(json.dumps(rom_hashes, indent=2) + '\n')
    command = ['verilator', '--binary', '--timing', '--assert', '-Wno-fatal',
        '--top-module', 'fdc_timing_boundary_machine_tb', '--Mdir', str(out / 'build'), '-j', '4',
        f'-GRATE={args.rate}', f'-GADDRESS_BITS={args.width}',
        *(str(out / r) for r in order), str(out / 'verilator/tests/fdc_timing_boundary_machine_tb.sv')]
    (out / 'build.command.json').write_text(json.dumps(command, indent=2) + '\n')
    try:
        status.update(phase='building', started=time.time()); save()
        with (out / 'build.log').open('w') as log:
            subprocess.run(command, stdout=log, stderr=subprocess.STDOUT,
                           check=True, timeout=args.wall_seconds)
        exe = out / 'build/Vfdc_timing_boundary_machine_tb'
        exe_sha = digest(exe)
        (out / 'executable.sha256').write_text(exe_sha + '\n')
        for c, d, rom, size in roms:
            command = [str(exe), f'+ROM={rom}', f'+ROM_SIZE={size}', f'+CASE={c}', f'+DRIVE={d}']
            (out / f'{rom.stem}.command.json').write_text(json.dumps(command) + '\n')
            record = {'case': c, 'drive': d, 'phase': 'running', 'started': time.time()}
            status['runs'].append(record); status['phase'] = 'running'; save()
            with (out / f'{rom.stem}.run.log').open('w') as log:
                result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT,
                                        timeout=args.wall_seconds)
            text = (out / f'{rom.stem}.run.log').read_text()
            record.update(phase='terminal', returncode=result.returncode, finished=time.time()); save()
            print(text, end='', flush=True)
            if rejection:
                assert (result.returncode != 0 and text.count(rejection) == 1 and
                        'Assertion failed' in text and 'Verilog $stop' in text and
                        'physical duration budget exhausted' not in text and
                        'PASS boundary machine' not in text), 'exact negative diagnostic absent'
            else:
                result.check_returncode()
                assert (text.count('PASS boundary machine') == 1 and
                        f'rate={args.rate} width={args.width} case={c} drive={d}' in text and
                        'Verilog $finish' in text and 'Assertion failed' not in text)
            assert digest(exe) == exe_sha and digest(rom) == rom_hashes[rom.name]
        status['phase'] = 'passed'
    except BaseException as error:
        status.update(phase='failed', error=repr(error)); raise
    finally:
        try:
            for relative, sha in manifest.items():
                assert digest(root / relative) == sha, ('live source changed', relative)
                assert digest(out / relative) == (mutation_sha if relative == mutated else sha), ('frozen source changed', relative)
            status['final_source_checks'] = 'passed'
        finally:
            save()
    print(f'PASS frozen boundary gate cases={len(cases)} negative={args.negative}', flush=True)


if __name__ == '__main__':
    main()
