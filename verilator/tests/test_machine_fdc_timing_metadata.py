#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Original public-machine D88 split metadata/owned-publication diagnostic."""
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

PROTECTED = {
    'verilator/tests/fdc_timing_machine_tb.sv': '65225d5356ee3670f2a820b8fa5e111d87588331500018d28a1b09d2c8d9928e',
    'verilator/tests/test_machine_fdc_timing.py': '8f74ef25baab3ebc60ba25336c111de961970b673862680cfb6826957952acf7',
    'verilator/tests/fdc_timing_media_machine_tb.sv': 'cc031203eaec8ab3c97c639a4e553a2fcd44a6d462f002ecd1d5c6d6cb5750f6',
    'verilator/tests/test_machine_fdc_timing_media.py': 'f47ae3911ec93b0eddd1c3d7147a0abf4c27a18a7fad52c79124a2bd42d7e808',
}


def payload(d, i):
    return (i * 37 + (i >> 8) * 53 + d * 104 + 19) & 255


def program(drive, header, reject_high, cancel_block, cancel_kind, Program):
    p = Program()
    p.emit(0xF3)
    p.word(0x31, 0xFFFF)
    serial = 0

    def out(port, value):
        p.word(0x01, port)
        p.emit(0x3E, value, 0xED, 0x79)

    def poll(mask, value=0):
        nonlocal serial
        serial += 1
        name = f'poll{serial}'
        p.word(0x01, 0x0FF8)
        p.label(name)
        p.emit(0xED, 0x78, 0xE6, mask, 0xFE, value)
        p.jump(0xC2, name)

    def status(value, mask=0xFC):
        p.word(0x01, 0x0FF8)
        p.emit(0xED, 0x78, 0xE6, mask, 0xFE, value)
        p.jump(0xC2, 'fail')

    def dma(writing):
        # N=1024, byte mode, actual FDC DRQ Ready. Fixed B source-only
        # LOAD sequence follows the existing independently qualified model.
        values = ([0xC3, 0x79, 0, 0x90, 255, 3, 0x14, 0x28, 0xAD,
                   0xFB, 0x0F, 0x92, 0xCF, 0x05, 0xCF, 0xBB, 1, 0xA7]
                  if writing else
                  [0xC3, 0x7D, 0xFB, 0x0F, 255, 3, 0x2C, 0x10, 0xAD,
                   0, 0xA0, 0x92, 0xCF, 0xBB, 1, 0xA7])
        for value in values:
            out(0x1F80, value)

    def transfer(writing=False, deleted=False, expected=0):
        dma(writing)
        out(0x0FFA, 1)
        out(0x0FF8, (0xA1 if deleted else 0xA0) if writing else 0x80)
        out(0x1F80, 0x87)
        poll(1)
        out(0x1F80, 0x83)
        poll(0x80)
        if expected is not None:
            status(expected)

    def compare_buffers():
        nonlocal serial
        serial += 1
        label = f'compare{serial}'
        p.word(0x21, 0x9000)
        p.word(0x11, 0xA000)
        p.word(0x01, 1024)
        p.label(label)
        p.emit(0x1A, 0xBE)
        p.jump(0xC2, 'fail')
        p.emit(0x23, 0x13, 0x0B, 0x78, 0xB1)
        p.jump(0xC2, label)

    p.word(0x01, 0x1234)
    p.emit(0xED, 0x78)  # Actual read clears DAM.
    p.word(0x01, 0x0FFD)
    p.emit(0xED, 0x78)  # MFM, no capacity-derived clock.
    out(0x0FFC, 0x80 | drive)
    if reject_high:
        if cancel_block >= 0 and cancel_kind == 0:
            p.word(0x3A, 0xF030)
            p.emit(0xFE, 0xAA)
            p.jump(0xC2, 'high_probe')
            p.word(0x3A, 0xF031)
            p.emit(0xFE, 0x55)
            p.jump(0xCA, 'post_probe')
        p.label('high_probe')
        out(0x0FFA, 1)
        out(0x0FF8, 0x80)
        poll(1)
        status(0x80, 0x80)  # Real CPU NOTREADY; TB also checks completed scan.
        p.store(0xF010, 2)  # Request public low-image remount.
    p.label('post_probe')
    poll(0x81)
    if cancel_block >= 0 and cancel_kind == 0:
        # CPU-owned high-RAM retained sentinel; deterministic cold model,
        # never injected by the fixture. A warm reset resumes recovery.
        p.word(0x3A, 0xF030)
        p.emit(0xFE, 0xAA)
        p.jump(0xC2, 'initial')
        p.word(0x3A, 0xF031)
        p.emit(0xFE, 0x55)
        p.jump(0xCA, 'recover')
    p.label('initial')
    for address in (0x8FFF, 0x9400, 0x9FFF, 0xA400):
        p.store(address, 0x63)
    for i in range(1024):
        p.store(0x9000 + i, payload(drive, i))
    p.store(0xF010, 10)
    transfer(expected=0x28)  # Deleted + data CRC, NOT ID CRC/RNF.
    compare_buffers()
    for i in range(1024):
        p.store(0x9000 + i, payload(drive, i) ^ 0x5A)
    p.store(0xF030, 0xAA)
    p.store(0xF031, 0x55)
    p.store(0xF010, 20)
    transfer(writing=True, expected=None if cancel_block >= 0 else 0)
    p.label('recover')
    if cancel_block >= 0:
        # Independent partial-publication expectation: the selected write was
        # already published, so it commits; later blocks remain original.
        effective_header = 1016 if reject_high else header
        pay = effective_header + 16
        committed = max(0, min(1024, (pay // 512 + min(cancel_block, 2) + 1) * 512 - pay))
        for i in range(committed, 1024):
            p.store(0x9000 + i, payload(drive, i))
    expected = 0 if cancel_block < 0 or cancel_block >= 4 else (8 if cancel_block == 3 else 0x28)
    p.store(0xF010, 30)
    transfer(expected=expected)
    compare_buffers()
    p.store(0xF010, 40)  # Remount initiated solely through public TB pin.
    poll(0x81)
    transfer(expected=expected)
    compare_buffers()
    for i in range(1024):
        p.store(0x9000 + i, payload(drive, i) ^ 0xA7)
    p.store(0xF010, 50)
    transfer(writing=True, deleted=cancel_block < 0)
    p.store(0xF010, 60)
    transfer(expected=0x20 if cancel_block < 0 else 0)
    compare_buffers()
    if cancel_block < 0:
        p.store(0xF010, 70)
        poll(0x81)
        transfer(expected=0x20)
        compare_buffers()
    for address in (0x8FFF, 0x9400, 0x9FFF, 0xA400):
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
    ap.add_argument('--high', action='store_true')
    ap.add_argument('--drive', type=int, choices=[0, 1])
    ap.add_argument('--cancel-block', type=int, choices=range(5), help='payload 0/1/2, mark 3, CRC 4')
    ap.add_argument('--cancel-point', type=int, choices=range(3), default=1, help='before ACK / byte128 / ACK tail')
    ap.add_argument('--cancel-kind', choices=['reset', 'mount'], default='reset')
    ap.add_argument('--wall-seconds', type=int, default=600)
    ap.add_argument('--negative', choices=['crc-edit', 'split-next', 'early-cache'])
    args = ap.parse_args()
    root = Path(__file__).resolve().parents[2]
    assert digest(root / 'rtl/sharpx1.v') == args.machine_sha
    for relative, sha in PROTECTED.items():
        assert digest(root / relative) == sha, ('qualified file changed', relative)
    order = re.findall(r'-name (?:SYSTEMVERILOG_FILE|VERILOG_FILE) (\S+)', (root / 'rtl/machine.qip').read_text())
    inputs = list(dict.fromkeys(order + ['rtl/machine.qip',
        'verilator/tests/fdc_timing_metadata_machine_tb.sv',
        'verilator/tests/test_machine_fdc_timing_metadata.py', 'verilator/tests/z80_fixture.py', *PROTECTED]))
    out = Path(tempfile.mkdtemp(prefix='x1-fdc-metadata-machine-'))
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
    mutated, mutation_sha, rejection = None, None, None
    if args.negative:
        assert args.cancel_block is None, 'negative uses uncancelled diagnostic'
        mutated = 'rtl/vendor/wd1793.sv'
        if args.negative == 'crc-edit':
            old, new = "(buff_dout == 8'hb0 ? 8'h00 : buff_dout)", 'buff_dout'
            rejection = 'published block differs from planned ledger stage=20 kind=2'
        elif args.negative == 'split-next':
            old, new = "if(!metadata_second && (&metadata_mark_address[8:0])) begin", "if(1'b0) begin"
            rejection = 'split metadata publication missing before CPU readback'
        else:
            old = "wire metadata_commit = metadata_inflight && ack[5:4] == 2'b10 &&"
            new = "wire metadata_commit = metadata_inflight && ack[5:4] == 2'b01 &&"
            rejection = 'metadata cache committed before owned ACK drain'
        target = out / mutated
        body = target.read_text()
        assert body.count(old) == 1, ('non-unique mutation', old)
        target.write_text(body.replace(old, new))
        mutation_sha = digest(target)
        (out / 'mutation.json').write_text(json.dumps({'file': mutated,
            'sha256': mutation_sha, 'diagnostic': rejection}, indent=2) + '\n')
    spec = importlib.util.spec_from_file_location('frozen_z80', out / 'verilator/tests/z80_fixture.py')
    emitter = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(emitter)
    header = (1 << 20) + 504 if args.high else 1016
    cancel_block = -1 if args.cancel_block is None else args.cancel_block
    cancel_kind = int(args.cancel_kind == 'mount')
    roms = []
    for d in ([args.drive] if args.drive is not None else range(2)):
        data = program(d, header, args.high and args.width == 20, cancel_block, cancel_kind, emitter.Program)
        assert len(data) <= 32768
        path = out / f'drive{d}.hex'
        path.write_text(''.join(f'{b:02x}\n' for b in data))
        roms.append((d, path, len(data)))
    rom_hashes = {p.name: digest(p) for _, p, _ in roms}
    (out / 'roms.json').write_text(json.dumps(rom_hashes, indent=2) + '\n')
    command = ['verilator', '--binary', '--timing', '--assert', '-Wno-fatal',
        '--top-module', 'fdc_timing_metadata_machine_tb', '--Mdir', str(out / 'build'), '-j', '4',
        f'-GRATE={args.rate}', f'-GADDRESS_BITS={args.width}', f'-GHEADER_OFFSET={header}',
        *(str(out / r) for r in order), str(out / 'verilator/tests/fdc_timing_metadata_machine_tb.sv')]
    (out / 'build.command.json').write_text(json.dumps(command, indent=2) + '\n')
    try:
        status.update(phase='building', started=time.time()); save()
        with (out / 'build.log').open('w') as log:
            subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=args.wall_seconds)
        exe = out / 'build/Vfdc_timing_metadata_machine_tb'
        exe_sha = digest(exe)
        (out / 'executable.sha256').write_text(exe_sha + '\n')
        for d, rom, size in roms:
            command = [str(exe), f'+ROM={rom}', f'+ROM_SIZE={size}', f'+DRIVE={d}',
                f'+CANCEL_BLOCK={cancel_block}', f'+CANCEL_POINT={args.cancel_point}', f'+CANCEL_KIND={cancel_kind}']
            (out / f'{rom.stem}.command.json').write_text(json.dumps(command) + '\n')
            record = {'drive': d, 'phase': 'running', 'started': time.time()}
            status['runs'].append(record); status['phase'] = 'running'; save()
            with (out / f'{rom.stem}.run.log').open('w') as log:
                result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=args.wall_seconds)
            text = (out / f'{rom.stem}.run.log').read_text()
            record.update(phase='terminal', returncode=result.returncode, finished=time.time()); save()
            print(text, end='', flush=True)
            if rejection:
                assert result.returncode != 0 and rejection in text, 'exact simulation negative absent'
            else:
                result.check_returncode()
                assert 'PASS metadata machine' in text
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
    print(f'PASS frozen metadata gate cases={len(roms)}', flush=True)


if __name__ == '__main__':
    main()
