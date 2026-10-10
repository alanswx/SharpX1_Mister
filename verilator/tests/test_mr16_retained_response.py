#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Original standalone MR16 retained-response reset/stack/RAM/IRQ gate.

Firmware encodings are produced by the frozen restricted assembler, whose
references are unchanged MR16.MAC and mr16core.v. No inherited firmware bytes,
shared-machine interface, private core state or native MCU timing claim.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

FIRMWARE = '''; SPDX-License-Identifier: GPL-2.0-or-later
; Original public-bus diagnostic. Only unprefixed LDM/STM memory operations.
cseg
org 0
dw entry, unused_irq, handler, unused_irq, unused_irq, unused_irq
org 20h
entry:
mov r15,#1800h
mov r14,#2000h
mov r13,#1000h
mov r12,#1100h
mov r0,#1357h
stm (r12),r0
ldm r1,(r12)
stm (r13),r1
mov r2,#2468h
push r2
pop r3
stm (r13,#2),r3
jsr outer
after_outer:
stm (r13,#4),r4
ldm r0,(r14,#2)
stm (r13,#6),r0
mov r7,#0:8
mov r0,#11h:8
stm (r14),r0
sti
irq_wait:
cmp r7,#1:8
bne irq_wait
mov r0,#0beefh
stm (r13,#8),r0
mov r0,#0ddh:8
stm (r14),r0
done:
bra done
outer:
push r2
jsr inner
after_inner:
pop r5
stm (r13,#10),r5
mov r4,#0acedh
ret
inner:
mov r6,#9876h
push r6
pop r6
stm (r13,#12),r6
ret
handler:
push r4
ldm r0,(r12)
stm (r13,#14),r0
ldm r0,(r14,#2)
stm (r13,#16),r0
mov r7,#1:8
pop r4
ret sti
unused_irq:
bra unused_irq
code_end:
'''


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cadence', type=int, choices=[1, 3, 17, 32], action='append')
    parser.add_argument('--reset-kind', type=int, choices=[0, 1, 2], action='append',
                        help='RAM load / GPIO load / POP response')
    parser.add_argument('--negative', action='store_true', help='exact retained GPIO-data mutation, cadence32')
    parser.add_argument('--wall-seconds', type=int, default=120)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    paths = ['rtl/mr16core.v', 'rtl/mr16_x1.v', 'scripts/assemble_mr16.py',
             'bios/reference/fw_subcpu/MR16.MAC', 'rtl/legacy/mr16/doc/mr16.txt',
             'verilator/tests/mr16_retained_response_tb.sv',
             'verilator/tests/test_mr16_retained_response.py']
    folder = Path(tempfile.mkdtemp(prefix='x1-mr16-retained-'))
    hashes = {}
    for relative in paths:
        target = folder / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(root / relative, target)
        hashes[relative] = digest(target)
    (folder / 'sources.json').write_text(json.dumps(hashes, indent=2) + '\n')
    print(f'Frozen sources/logs: {folder}', flush=True)
    status = {'phase': 'frozen', 'cases': []}

    def save():
        (folder / 'status.json').write_text(json.dumps(status, indent=2) + '\n')

    save()
    spec = importlib.util.spec_from_file_location('frozen_mr16_assembler', folder / 'scripts/assemble_mr16.py')
    assembler = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(assembler)
    source = folder / 'original.asm'
    source.write_text(FIRMWARE)
    image, symbols, _ = assembler.assemble(source)
    assert symbols['code_end'] < 4096
    rom = folder / 'original.mem'
    rom.write_text(''.join(f'{int.from_bytes(image[i:i+2], "little"):04x}\n' for i in range(0, len(image), 2)))
    # Independently specified PUBLIC store sequence, not decoded DUT execution.
    # Interrupt entry is at one of the two instructions in the enabled loop;
    # both legal exact byte return addresses are recorded, not arbitrary range.
    stores = [(0x1100, 0x1357), (0x1000, 0x1357), (0x17fe, 0x2468),
              (0x1002, 0x2468), (0x17fe, symbols['after_outer']),
              (0x17fc, 0x2468), (0x17fa, symbols['after_inner']),
              (0x17f8, 0x9876), (0x100c, 0x9876), (0x100a, 0x2468),
              (0x1004, 0xaced), (0x1006, 0x5aa5),
              (0x17fe, symbols['irq_wait'], symbols['irq_wait'] + 2),
              (0x17fc, 0xaced), (0x100e, 0x1357), (0x1010, 0x5aa5), (0x1008, 0xbeef)]
    oracle = folder / 'store-oracle.mem'
    oracle.write_text(''.join(f'{address:04x}{(extra[0] if extra else 0):04x}ffff{value:04x}\n'
                              for address, value, *extra in stores))
    (folder / 'firmware.json').write_text(json.dumps({'symbols': symbols, 'stores': stores,
        'image_sha256': hashlib.sha256(image).hexdigest(), 'bytes': len(image)}, indent=2) + '\n')
    generated = {p.name: digest(p) for p in [source, rom, oracle]}
    (folder / 'generated.json').write_text(json.dumps(generated, indent=2) + '\n')
    mutated, mutation_sha = None, None
    rejection = 'MR16 data/return oracle cursor=11 address=1006 actual=5aa4'
    if args.negative:
        mutated = 'rtl/mr16_x1.v'
        target = folder / mutated
        body = target.read_text()
        old = 'held_data <= raw_d_in;'
        # Change ONLY the stopped-edge capture, not reset's separate capture.
        anchor = "else if (previous_ce) begin\n        held_valid <= 1'b1;\n        " + old
        assert body.count(anchor) == 1
        replacement = anchor.replace(old, "held_data <= raw_d_in == 16'h5aa5 ? 16'h5aa4 : raw_d_in;")
        target.write_text(body.replace(anchor, replacement))
        mutation_sha = digest(target)
        (folder / 'mutation.json').write_text(json.dumps({'file': mutated, 'original_sha256': hashes[mutated],
            'sha256': mutation_sha, 'old': anchor, 'new': replacement, 'required_assertion': rejection}, indent=2) + '\n')
    cadences = [32] if args.negative else args.cadence or [1, 3, 17, 32]
    kinds = args.reset_kind or [0, 1, 2]
    executables = {}
    try:
        for cadence in cadences:
            for kind in kinds:
                label = f'ce{cadence}-reset{kind}'
                build = folder / label
                command = ['verilator', '--binary', '--timing', '--assert', '-Wno-fatal', '-j', '4',
                           '--top-module', 'mr16_retained_response_tb', '--Mdir', str(build),
                           f'-GCE_DIVISOR={cadence}', f'-GRESET_KIND={kind}',
                           *(str(folder / p) for p in ['rtl/mr16core.v', 'rtl/mr16_x1.v',
                                                       'verilator/tests/mr16_retained_response_tb.sv'])]
                (folder / f'{label}.build.command.json').write_text(json.dumps(command) + '\n')
                record = {'label': label, 'phase': 'building', 'started': time.time()}
                status['cases'].append(record); status['phase'] = 'building'; save()
                with (folder / f'{label}.build.log').open('w') as log:
                    subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=args.wall_seconds)
                executable = build / 'Vmr16_retained_response_tb'
                executables[str(executable.relative_to(folder))] = digest(executable)
                (folder / 'executables.json').write_text(json.dumps(executables, indent=2) + '\n')
                command = [str(executable), f'+ROM={rom}', f'+ORACLE={oracle}', f'+COUNT={len(stores)}']
                (folder / f'{label}.run.command.json').write_text(json.dumps(command) + '\n')
                record['phase'] = 'running'; status['phase'] = 'running'; save()
                with (folder / f'{label}.run.log').open('w') as log:
                    result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=args.wall_seconds)
                text = (folder / f'{label}.run.log').read_text()
                record.update(phase='terminal', returncode=result.returncode, finished=time.time()); save()
                print(text, end='', flush=True)
                if args.negative:
                    assert result.returncode != 0 and rejection in text, 'exact data-oracle negative absent'
                else:
                    result.check_returncode()
                    assert 'PASS retained MR16' in text
        status['phase'] = 'passed'
    except BaseException as error:
        status.update(phase='failed', error=repr(error)); raise
    finally:
        try:
            for relative, sha in hashes.items():
                assert digest(root / relative) == sha, ('live source changed', relative)
                assert digest(folder / relative) == (mutation_sha if relative == mutated else sha), ('frozen source changed', relative)
            for name, sha in generated.items():
                assert digest(folder / name) == sha, ('generated firmware/oracle changed', name)
            for name, sha in executables.items():
                assert digest(folder / name) == sha, ('frozen executable changed', name)
            status['final_hash_checks'] = 'passed'
        finally:
            save()
    print(f'PASS frozen retained MR16 cases={len(status["cases"])} negative={args.negative}', flush=True)


if __name__ == '__main__':
    main()
