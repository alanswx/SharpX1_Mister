#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Original public-port cached-stream/media-cancellation gate, not native timing."""
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

CASES = ['cached-read', 'cached-write', 'pending-read-reset',
         'pending-write-reset', 'pending-read-mount', 'pending-write-mount']
PROTECTED = {
    'verilator/tests/fdc_timing_machine_tb.sv': '65225d5356ee3670f2a820b8fa5e111d87588331500018d28a1b09d2c8d9928e',
    'verilator/tests/test_machine_fdc_timing.py': '8f74ef25baab3ebc60ba25336c111de961970b673862680cfb6826957952acf7',
}


def payload(d, i):
    return (i * 37 + (i >> 8) * 53 + d * 104 + 19) & 255


def program(case, drive, rate, Program, cpu_prefill=False):
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
        name = f'poll{serial}'
        p.word(0x01, 0x0FF8)
        p.label(name)
        p.emit(0xED, 0x78, 0xE6, mask)
        p.jump(0xC2, name)

    def select(d):
        out(0x0FFC, 0x80 | d)
        poll(0x81)

    def dma(writing, count=256):
        # Original UM0081 byte-mode diagnostic, physical DRQ Ready, count N-1.
        values = ([0xC3, 0x79, 0, 0x90, (count-1)&255, (count-1)>>8, 0x14, 0x28, 0xAD,
                   0xFB, 0x0F, 0x92, 0xCF, 0x05, 0xCF, 0xBB, 1, 0xA7]
                  if writing else
                  [0xC3, 0x7D, 0xFB, 0x0F, 255, 0, 0x2C, 0x10, 0xAD,
                   0, 0xA0, 0x92, 0xCF, 0xBB, 1, 0xA7])
        for value in values:
            out(0x1F80, value)

    def transfer(writing, name, use_dma, check=True):
        if use_dma:
            dma(writing)
        out(0x0FFA, 1)
        out(0x0FF8, 0xA0 if writing else 0x80)
        if use_dma:
            out(0x1F80, 0x87)
        else:
            p.word(0x21, 0x9000 if writing else 0xA000)
            p.word(0x11, 256)
            p.word(0x01, 0x0FF8)
            p.label(name)
            p.emit(0xED, 0x78, 0xE6, 2)
            p.jump(0xCA, name)
            p.emit(0x0E, 0xFB)
            p.emit(*([0x7E, 0xED, 0x79] if writing else [0xED, 0x78, 0x77]))
            p.emit(0x23, 0x1B, 0x7A, 0xB3, 0x0E, 0xF8)
            p.jump(0xC2, name)
        poll(1)
        if use_dma:
            out(0x1F80, 0x83)
        if check:
            p.word(0x01, 0x0FF8)
            p.emit(0xED, 0x78, 0xE6, 0xFC)
            p.jump(0xC2, 'fail')

    p.word(0x01, 0x1234)  # Real read clears DAM.
    p.emit(0xED, 0x78)
    p.word(0x01, 0x0FFD)  # MFM, not the FM control-read alias.
    p.emit(0xED, 0x78)
    select(drive)
    if case in (2, 3):
        # CPU-owned retained RAM sentinel prevents repeating the interrupted
        # prelude after public warm reset. No fixture RAM injection/readback.
        p.word(0x3A, 0xF030)
        p.emit(0xFE, 0xAA)
        p.jump(0xC2, 'prelude')
        p.word(0x3A, 0xF031)
        p.emit(0xFE, 0x55)
        p.jump(0xCA, 'recover')
    p.label('prelude')
    p.store(0xF030, 0xAA)
    p.store(0xF031, 0x55)
    if case % 2:
        for i in range(256):
            p.store(0x9000 + i, payload(drive, i) ^ 0xA7)
    p.store(0xF010, 1)
    if case < 2:
        dma_prefill = case == 1 and rate == 2000000 and not cpu_prefill
        if dma_prefill:
            # Two real DRQ-paced DMA bytes arm this stream. Program length 1:
            # this engine's native-reference zero length denotes 65537, NOT
            # one operation. The CPU
            # remains free to cause reselection; no successful 2MHz polling
            # throughput claim and no manufactured timing/Ready.
            dma(True, count=2)
        out(0x0FFA, 1)
        out(0x0FF8, 0xA0 if case == 1 else 0x80)
        if dma_prefill:
            out(0x1F80, 0x87)
        elif case == 1:
            p.word(0x01, 0x0FF8)
            p.label('first')
            p.emit(0xED, 0x78, 0xE6, 2)
            p.jump(0xCA, 'first')
            p.emit(0x0E, 0xFB, 0x3E, payload(drive, 0) ^ 0xA7, 0xED, 0x79)
        # 200 * 26T / 4MHz: CPU-caused reselect inside the cached stream.
        p.word(0x11, 200)
        p.label('delay')
        p.emit(0x1B, 0x7A, 0xB3)
        p.jump(0xC2, 'delay')
        if dma_prefill:
            out(0x1F80, 0x83)
        select(drive ^ 1)
    else:
        transfer(bool(case % 2), 'prelude_dma', True, check=False)
        poll(0x80)
    p.label('recover')
    for address in (0x9FFF, 0xA100, 0x8FFF, 0x9100):
        p.store(address, 0x63)
    for d, marker in ((drive ^ 1, 16), (drive, 32)):
        select(d)
        p.store(0xF010, marker)
        transfer(False, f'read{marker}', rate == 2000000)
        for i in range(256):
            p.compare_memory(0xA000 + i, payload(d, i))
    for i in range(256):
        p.store(0x9000 + i, payload(drive, i) ^ 0x5A)
    p.store(0xF010, 48)
    transfer(True, 'write_recovery', rate == 2000000)
    p.store(0xF010, 64)
    transfer(False, 'readback', rate == 2000000)
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
    ap.add_argument('--negative', choices=['cached-cancel', 'completion-cancel'])
    ap.add_argument('--cpu-prefill', action='store_true', help='retain CPU-only initial-service diagnostic at 2MHz')
    ap.add_argument('--wall-seconds', type=int, default=300)
    args = ap.parse_args()
    root = Path(__file__).resolve().parents[2]
    assert digest(root / 'rtl/sharpx1.v') == args.machine_sha
    for relative, sha in PROTECTED.items():
        assert digest(root / relative) == sha, ('qualified file changed', relative)
    order = re.findall(r'-name (?:SYSTEMVERILOG_FILE|VERILOG_FILE) (\S+)',
                       (root / 'rtl/machine.qip').read_text())
    inputs = list(dict.fromkeys(order + ['rtl/machine.qip',
        'verilator/tests/fdc_timing_media_machine_tb.sv',
        'verilator/tests/test_machine_fdc_timing_media.py',
        'verilator/tests/z80_fixture.py', *PROTECTED]))
    out = Path(tempfile.mkdtemp(prefix='x1-fdc-media-machine-'))
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
    mutated, mutation_sha, rejection = None, None, None
    if args.negative:
        if args.negative == 'cached-cancel':
            mutated = 'rtl/vendor/wd1793.sv'
            old = 'wire timing_cancel = reset || img_mounted || mount_pending || timing_replace;'
            new = 'wire timing_cancel = reset || timing_replace;'
            rejection = 'cached stream survived reselect'
            cases = [(0, 0)]
        else:
            mutated = 'rtl/x1_fdc_completion.sv'
            old, new = 'if(reset || cancel) begin', 'if(reset) begin'
            rejection = 'pending completion survived media cancellation'
            cases = [(5, 0)]
        target = out / mutated
        body = target.read_text()
        assert body.count(old) == 1
        target.write_text(body.replace(old, new))
        mutation_sha = digest(target)
        (out / 'mutation.json').write_text(json.dumps({'file': mutated,
            'sha256': mutation_sha, 'diagnostic': rejection}, indent=2) + '\n')
    else:
        cases = [(c, d) for c in ([CASES.index(args.case)] if args.case else range(6))
                 for d in ([args.drive] if args.drive is not None else range(2))]
    roms = []
    for c, d in cases:
        data = program(c, d, args.rate, emitter.Program, args.cpu_prefill)
        path = out / f'case{c}-drive{d}.hex'
        path.write_text(''.join(f'{b:02x}\n' for b in data))
        roms.append((c, d, path, len(data)))
    rom_hashes = {p.name: digest(p) for _, _, p, _ in roms}
    (out / 'roms.json').write_text(json.dumps(rom_hashes, indent=2) + '\n')
    command = ['verilator', '--binary', '--timing', '--assert', '-Wno-fatal',
        '--top-module', 'fdc_timing_media_machine_tb', '--Mdir', str(out / 'build'), '-j', '4',
        f'-GRATE={args.rate}', f'-GADDRESS_BITS={args.width}',
        *(str(out / r) for r in order), str(out / 'verilator/tests/fdc_timing_media_machine_tb.sv')]
    (out / 'build.command.json').write_text(json.dumps(command, indent=2) + '\n')
    try:
        status.update(phase='building', started=time.time()); save()
        with (out / 'build.log').open('w') as log:
            subprocess.run(command, stdout=log, stderr=subprocess.STDOUT,
                           check=True, timeout=args.wall_seconds)
        exe = out / 'build/Vfdc_timing_media_machine_tb'
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
                assert result.returncode != 0 and rejection in text, 'exact negative diagnostic absent'
            else:
                result.check_returncode()
                assert 'PASS media machine' in text
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
    print(f'PASS frozen media gate cases={len(cases)} negative={args.negative}', flush=True)


if __name__ == '__main__':
    main()
