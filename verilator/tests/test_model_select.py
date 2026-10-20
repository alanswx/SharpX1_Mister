#!/usr/bin/env python3
"""Runtime X1/Turbo model select on an X1_MODEL_SELECT runner.

A real-Z80 RAM program reads the Turbo DIP switches (1FF0) and writes the
text plane at 3000 then the Turbo Kanji plane at 3800, reading 3000 back.
Turbo mode must decode both Turbo ports; X1 mode must not (DIP reads FF and
3800 mirrors the text plane). With the X1 IPL in its own slot (index 3),
each mode must run its own IPL. Optionally a disk boots in both modes.

Usage: test_model_select.py RUNNER X1_IPL TURBO_IPL [DISK]
"""
import json
import pathlib
import subprocess
import sys
import tempfile

PROGRAM = bytes([
    0xF3,                    # DI
    0x01, 0xF0, 0x1F,        # LD BC,1FF0
    0xED, 0x78,              # IN A,(C)
    0x32, 0x00, 0x90,        # LD (9000),A
    0x01, 0x00, 0x30,        # LD BC,3000
    0x3E, 0x11,              # LD A,11
    0xED, 0x79,              # OUT (C),A
    0x01, 0x00, 0x38,        # LD BC,3800
    0x3E, 0x22,              # LD A,22
    0xED, 0x79,              # OUT (C),A
    0x01, 0x00, 0x30,        # LD BC,3000
    0xED, 0x78,              # IN A,(C)
    0x32, 0x01, 0x90,        # LD (9001),A
    0x3E, 0xA5,              # LD A,A5
    0x32, 0x02, 0x90,        # LD (9002),A  completion marker
    0x76,                    # HALT
])


def run(runner, *args):
    out = subprocess.run([runner, *map(str, args)], capture_output=True, text=True, check=True)
    return json.loads(out.stdout.strip().splitlines()[-1])


def main():
    runner, x1_ipl, turbo_ipl = sys.argv[1:4]
    disk = sys.argv[4] if len(sys.argv) > 4 else None
    with tempfile.TemporaryDirectory() as tmp:
        program = pathlib.Path(tmp) / 'ports.bin'
        program.write_bytes(PROGRAM)
        for model_x1, dsw, mirror in ((False, 0xF1, 0x11), (True, 0xFF, 0x22)):
            flags = ['--model-x1'] if model_x1 else []
            r = run(runner, '--cycles', 6400000, '--ram', program, '--load-address', 0x8000,
                    '--entry', 0x8000, '--peek', 0x9000, *flags)
            peek = bytes.fromhex(r['peek'])
            assert r['model_x1'] is model_x1, r['model_x1']
            assert r['halted'] and peek[2] == 0xA5, ('program did not complete', r['peek'])
            assert peek[0] == dsw, f'model_x1={model_x1}: DIP 1FF0 read {peek[0]:02x}, want {dsw:02x}'
            assert peek[1] == mirror, f'model_x1={model_x1}: 3000 after 3800 write {peek[1]:02x}, want {mirror:02x}'
            print(f'PASS ports model_x1={model_x1}: DIP {peek[0]:02x}, text after 3800 write {peek[1]:02x}')

        frames = {}
        for name, flags in (('turbo', []), ('x1', ['--model-x1']), ('x1_main', ['--model-x1'])):
            roms = ['--rom', x1_ipl] if name == 'x1_main' else ['--rom', turbo_ipl, '--x1-ipl', x1_ipl]
            frames[name] = run(runner, '--cycles', 96000000, *roms, *flags)['frame_hash']
        # X1 mode runs the X1 IPL from its slot, identical to an X1 IPL in the main slot.
        assert frames['x1'] == frames['x1_main'], frames
        assert frames['x1'] != frames['turbo'], frames
        print('PASS IPL: X1 mode runs the slot-3 X1 IPL; Turbo mode runs the Turbo IPL')

        if disk:
            boots = {}
            for name, flags in (('turbo', []), ('x1', ['--model-x1'])):
                r = run(runner, '--cycles', 640000000, '--rom', turbo_ipl, '--x1-ipl', x1_ipl,
                        '--disk', disk, *flags)
                assert r['disk_requests'] > 0, (name, r['disk_requests'])
                boots[name] = r['frame_hash']
            assert boots['x1'] == boots['turbo'], boots
            print(f'PASS disk boot in both models: {boots["x1"]}')


if __name__ == '__main__':
    main()
