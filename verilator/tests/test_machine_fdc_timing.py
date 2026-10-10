#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Original public-port CPU/DMA fixed-FDC gate; not native timing acceptance.

No ROM assets, force, RAM injection, or savable runner. Fresh frozen source
copies retain machine.qip order; generated IPL verifies high RAM itself.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

def payload(drive, i):
    return (i * 37 + (i >> 8) * 53 + drive * 104 + 19) & 255


def program(length, drive, mode, cancel=0, cancel_write=False, *, Program):
    cpu_miss = mode == -2
    if cpu_miss:
        mode = 0  # Actual CPU observes missed read, then actual DMA recovers.
    p = Program()
    p.emit(0xF3)
    p.word(0x31, 0xFFFF)
    serial = 0

    def out(port, value):
        p.word(0x01, port)
        p.emit(0x3E, value, 0xED, 0x79)

    def poll(mask, expected=0):
        nonlocal serial
        serial += 1
        label = f'poll{serial}'
        p.word(0x01, 0x0FF8)
        p.label(label)
        p.emit(0xED, 0x78, 0xE6, mask, 0xFE, expected)
        p.jump(0xC2, label)

    def dma(writing, continuous=False, skip_first=False):
        count = length - 1 - int(skip_first)
        operation_mode = 1 if continuous else mode
        if writing:
            # Fixed B: UM0081 temporary-source LOAD then restore A source.
            stream = [0xC3, 0x79, int(skip_first), 0x90, count & 255, count >> 8,
                      0x14, 0x28, 0x8D | (operation_mode << 5), 0xFB, 0x0F,
                      0x92, 0xCF, 0x05, 0xCF, 0xBB, 1, 0xA7]
        else:
            stream = [0xC3, 0x7D, 0xFB, 0x0F, count & 255, count >> 8,
                      0x2C, 0x10, 0x8D | (operation_mode << 5), 0, 0xA0,
                      0x92, 0xCF, 0xBB, 1, 0xA7]
        for byte in stream:
            out(0x1F80, byte)

    def transfer(writing, tag, check_status=True):
        if mode >= 0:
            dma(writing)
        out(0x0FFA, 1)
        out(0x0FF8, 0xA0 if writing else 0x80)
        if mode >= 0:
            out(0x1F80, 0x87)
        else:
            p.word(0x21, 0x9000 if writing else 0xA000)
            p.word(0x11, length)
            p.word(0x01, 0x0FF8)
            p.label(f'byte{tag}')
            p.emit(0xED, 0x78, 0xE6, 2)
            p.jump(0xCA, f'byte{tag}')
            p.emit(0x0E, 0xFB)
            p.emit(*( [0x7E, 0xED, 0x79] if writing else [0xED, 0x78, 0x77] ))
            p.emit(0x23, 0x1B, 0x7A, 0xB3, 0x0E, 0xF8)
            p.jump(0xC2, f'byte{tag}')
        poll(1)
        if mode >= 0:
            out(0x1F80, 0x83)
        if check_status:
            p.word(0x01, 0x0FF8)
            p.emit(0xED, 0x78, 0xE6, 0xFC)
            p.jump(0xC2, 'fail')

    # Real read clears initial DAM; select MFM using the controller port.
    p.word(0x01, 0x1234)
    p.emit(0xED, 0x78)
    p.word(0x01, 0x0FFD)
    p.emit(0xED, 0x78)
    out(0x0FFC, 0x80 | drive)
    poll(0x80)
    if cpu_miss:
        # A CPU-commanded read, serviced only by status polling: deliberately
        # miss the actual 16-us DATA windows, require sticky loss, then recover
        # using real DRQ-paced DMA. Not successful general CPU2M polling.
        p.store(0xF010, 3)
        out(0x0FFA, 1)
        out(0x0FF8, 0x80)
        poll(1)
        p.emit(0xED, 0x78, 0xE6, 4, 0xFE, 4)
        p.jump(0xC2, 'fail')
        out(0x0FF8, 0xD0)
    if cancel:
        p.store(0xF010, 2 if cancel_write else 1)
        if cancel_write:
            for i in range(length):
                p.store(0x9000 + i, payload(drive, i))
            if cancel == 3:
                # Special diagnostic: CPU supplies the initial DR byte;
                # already-configured DMA handles the remaining N-1 bytes.
                # This is not a claim about general CPU2M polling throughput.
                dma(True, continuous=True, skip_first=True)
                out(0x0FFA, 1)
                out(0x0FF8, 0xA0)
                p.word(0x01, 0x0FF8)
                p.label('prefill')
                p.emit(0xED, 0x78, 0xE6, 2)
                p.jump(0xCA, 'prefill')
                p.emit(0x0E, 0xFB, 0x3E, payload(drive, 0), 0xED, 0x79)
                out(0x1F80, 0x87)
            else:
                # Mount/reset deliberately cancels this prelude. Await BUSY
                # release, not normal-success status for an aborted command.
                # The recovery R/W/R below still requires exact clean status.
                transfer(True, 'prelude', check_status=False)
        elif cancel == 4:
            transfer(False, 'prelude', check_status=False)
        else:
            out(0x0FFA, 1)
            out(0x0FF8, 0x80)
        # Original CPU instructions, not injected bus strobes. Reselection
        # occurs within the deliberately delayed real host ACK window.
        p.word(0x11, (24 if cancel_write else 60) if cancel == 3 else 96)
        p.label('cancel_delay')
        p.emit(0x1B, 0x7A, 0xB3)
        p.jump(0xC2, 'cancel_delay')
        if cancel == 3:
            out(0x0FFC, 0x80 | (drive ^ 1))
        out(0x0FF8, 0xD0)
        poll(1)
        poll(0x80)
        out(0x1F80, 0x83)
        if cancel == 3:
            out(0x0FFC, 0x80 | drive)
            poll(0x80)
    for addr, value in [(0x9FFF, 0xA6), (0xA000 + length, 0xB7),
                        (0x8FFF, 0xC8), (0x9000 + length, 0xD9)]:
        p.store(addr, value)
    p.store(0xF010, 0x10)
    transfer(False, 'first')
    for i in range(length):
        p.compare_memory(0xA000 + i, payload(drive, i))
        p.store(0x9000 + i, payload(drive, i) ^ 0x5A)
    p.store(0xF010, 0x20)
    transfer(True, 'write')
    p.store(0xF010, 0x30)
    transfer(False, 'last')
    for i in range(length):
        p.compare_memory(0xA000 + i, payload(drive, i) ^ 0x5A)
        p.compare_memory(0x9000 + i, payload(drive, i) ^ 0x5A)
    for addr, value in [(0x9FFF, 0xA6), (0xA000 + length, 0xB7),
                        (0x8FFF, 0xC8), (0x9000 + length, 0xD9)]:
        p.compare_memory(addr, value)
    p.store(0xF000, 0x5A)
    p.emit(0x76)
    p.label('fail')
    p.store(0xF000, 0xEE)
    p.emit(0x76)
    result = p.finish()
    assert len(result) <= 32768
    return result


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--machine-sha', required=True)
    parser.add_argument('--rate', type=int, choices=[1000000, 2000000], default=1000000)
    parser.add_argument('--width', type=int, choices=[20, 24], default=20)
    parser.add_argument('--full', action='store_true', help='all sizes, drives and three DMA modes')
    parser.add_argument('--negative', choices=['disabled', 'wrong-rate', 'force-ready'])
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--cancellation', action='store_true', help='ACK reset/mount/CPU reselect and owned DMA reset')
    parser.add_argument('--wall-seconds', type=int, default=300)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    if digest(root / 'rtl/sharpx1.v') != args.machine_sha:
        parser.error('machine differs from approved source hash')
    order = re.findall(r'-name (?:SYSTEMVERILOG_FILE|VERILOG_FILE) (\S+)',
                       (root / 'rtl/machine.qip').read_text())
    inputs = list(dict.fromkeys(order + ['rtl/machine.qip',
                   'verilator/tests/fdc_timing_machine_tb.sv',
                   'verilator/tests/test_machine_fdc_timing.py',
                   'verilator/tests/z80_fixture.py']))
    out = Path(tempfile.mkdtemp(prefix='x1-machine-fdc-timing-'))
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
    # Load the emitter ONLY from the captured, hashed source. An import from
    # the live tree before freeze could otherwise execute different bytes.
    spec = importlib.util.spec_from_file_location('frozen_z80_fixture', out / 'verilator/tests/z80_fixture.py')
    emitter = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(emitter)
    rejection = None
    mutated_relative = None
    mutation_sha = None
    if args.negative:
        if args.negative == 'wrong-rate':
            target = out / 'verilator/tests/fdc_timing_machine_tb.sv'
            old, new = '.FDC_CLOCK_HZ(RATE)', '.FDC_CLOCK_HZ(3000000-RATE)'
            rejection = 'explicit nominal FDC clock period'
        elif args.negative == 'force-ready':
            target = out / 'rtl/sharpx1.v'
            old, new = '.rdy(!fdc_drq)', ".rdy(1'b0)"
            rejection = 'DMA pair began without FDC DRQ'
        else:
            target = None
            rejection = 'connected timed arrivals/loads absent or wrong'
        if target:
            body = target.read_text()
            assert body.count(old) == 1, ('non-unique mutation', old)
            target.write_text(body.replace(old, new))
            mutated_relative = str(target.relative_to(out))
            mutation_sha = digest(target)
        (out / 'mutation.json').write_text(json.dumps({'name': args.negative,
                'rejection': rejection, 'file': str(target),
                'sha256': digest(target) if target else None}, indent=2) + '\n')
    # The straightforward polling loop services within a 32-us slot, not
    # the 16-us slot at 2 MHz. Qualify CPU at 1 MHz and DMA at both rates.
    modes = [-1, 0] if args.rate == 1000000 else [-2, 0]
    cases = [(128, d, m, 0, 0) for d in [0, 1] for m in modes]
    if args.full:
        cases = [(n, d, m, 0, 0) for n in [128, 256, 512, 1024]
                 for d in [0, 1] for m in ([-1, 0, 1, 2] if args.rate == 1000000 else [-2, 0, 1, 2])]
    if args.cancellation:
        cases = [(128, d, 0, c, w) for d in [0, 1]
                 for c in [1, 2, 3] for w in [0, 1]]
        cases += [(128, d, 0, 4, 0) for d in [0, 1]]
    if args.negative:
        cases = [(128, 0, 0 if args.negative == 'force-ready' else -1, 0, 0)]
    roms = []
    for n, d, m, c, w in cases:
        path = out / f'n{n}-d{d}-m{m}-c{c}-w{w}.hex'
        data = program(n, d, m, c, bool(w), Program=emitter.Program)
        path.write_text(''.join(f'{byte:02x}\n' for byte in data))
        roms.append((n, d, m, c, w, path, len(data)))
    rom_manifest = {p.name: digest(p) for *_, p, size in roms}
    (out / 'roms.json').write_text(json.dumps(rom_manifest, indent=2) + '\n')
    if args.prepare_only:
        print('Prepared original IPLs; no build or execution', flush=True)
        return
    build = out / 'build'
    command = ['verilator', '--binary', '--timing', '--assert', '-Wno-fatal',
               '--top-module', 'fdc_timing_machine_tb', '--Mdir', str(build), '-j', '4',
               f'-GRATE={args.rate}', f'-GADDRESS_BITS={args.width}',
               f'-GTIMING_ENABLED={0 if args.negative == "disabled" else 1}',
               *(str(out / relative) for relative in order),
               str(out / 'verilator/tests/fdc_timing_machine_tb.sv')]
    (out / 'command.json').write_text(json.dumps(command, indent=2) + '\n')
    with (out / 'build.log').open('w') as log:
        subprocess.run(command, stdout=log, stderr=subprocess.STDOUT,
                       check=True, timeout=args.wall_seconds)
    exe = build / 'Vfdc_timing_machine_tb'
    exe_sha = digest(exe)
    (out / 'executable.sha256').write_text(exe_sha + '\n')
    for n, d, m, c, w, rom, size in roms:
        command = [str(exe), f'+ROM={rom}', f'+ROM_SIZE={size}',
                   f'+LENGTH={n}', f'+DRIVE={d}', f'+MODE={m}', f'+CANCEL={c}', f'+CANCEL_WRITE={w}']
        (out / f'{rom.stem}.command.json').write_text(json.dumps(command) + '\n')
        with (out / f'{rom.stem}.run.log').open('w') as log:
            result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT,
                                    timeout=args.wall_seconds)
        output = (out / f'{rom.stem}.run.log').read_text()
        print(output, end='', flush=True)
        if rejection:
            if result.returncode == 0 or rejection not in output:
                raise RuntimeError('negative did not hit its exact simulation diagnostic')
        else:
            result.check_returncode()
            assert 'PASS actual CPU/DMA fixed FDC' in output
        assert digest(exe) == exe_sha
        assert digest(rom) == rom_manifest[rom.name]
    for relative, sha in manifest.items():
        assert digest(root / relative) == sha, ('live source changed', relative)
        expected = mutation_sha if relative == mutated_relative else sha
        assert digest(out / relative) == expected, ('frozen source changed', relative)
    print(f'PASS frozen machine fixed FDC cases={len(cases)} negative={args.negative}', flush=True)


if __name__ == '__main__':
    main()
