# SPDX-License-Identifier: GPL-2.0-only
"""Original shared IPL for a bounded CSP/RTL CPU, RAM, overlay and PSG check."""
from z80_fixture import Program

PSG = ((7, 0x3f), (8, 0), (9, 0), (10, 0), (0, 0xa5), (1, 3), (2, 0x63), (3, 2))


def program(bad=False):
    p = Program()
    p.emit(0xf3)
    p.word(0x31, 0xffff)
    # Execute real CPU copies into RAM behind the 4-KiB IPL before disabling it.
    # Neither emulator receives a host RAM/debug bootstrap.
    p.word(0x21, 0)
    p.word(0x11, 0)
    p.word(0x01, 4096)
    p.emit(0xed, 0xb0)
    for n in range(4):
        p.store(0xf000+n, 0)
    p.compare_memory(0, 0xf3)
    p.store(0, 0xa5)
    p.compare_memory(0, 0xf3)
    p.word(0x01, 0x1e00)
    p.emit(0x3e, 0, 0xed, 0x79)
    p.compare_memory(0, 0xa5)
    p.word(0x21, 0x8000)
    p.word(0x01, 1024)
    p.label('write')
    p.emit(0x7c, 0xad, 0x77, 0x23, 0x0b, 0x78, 0xb1)
    p.jump(0xc2, 'write')
    p.word(0x21, 0x8000)
    p.word(0x01, 1024)
    p.label('read')
    p.emit(0x7c, 0xad, 0xbe)
    p.jump(0xc2, 'fail')
    p.emit(0x23, 0x0b, 0x78, 0xb1)
    p.jump(0xc2, 'read')
    p.word(0x01, 0x1d00)
    p.emit(0x3e, 0, 0xed, 0x79)
    p.compare_memory(0, 0xf3)
    for register, value in PSG:
        for port, data in ((0x1c00, register), (0x1b00, value)):
            p.word(0x01, port)
            p.emit(0x3e, data, 0xed, 0x79)
        if register in (0, 2, 7, 8):
            p.word(0x01, 0x1b00)
            p.emit(0xed, 0x78, 0xfe, value ^ (int(bad) if register == 2 else 0))
            p.jump(0xc2, 'fail')
    for n, value in enumerate(b'X1OK'):
        p.store(0xf000+n, value)
    p.label('done')
    p.emit(0x76)
    p.jump(0xc3, 'done')
    p.label('fail')
    p.store(0xf000, 0xee)
    p.emit(0x76)
    p.jump(0xc3, 'fail')
    image = p.finish()
    assert len(image) < 4096
    return image + bytes([0xff]) * (4096-len(image))


def expected_io():
    rows = [('W', 0x1e00, 0), ('W', 0x1d00, 0)]
    for register, value in PSG:
        rows += [('W', 0x1c00, register), ('W', 0x1b00, value)]
        if register in (0, 2, 7, 8):
            rows.append(('R', 0x1b00, value))
    return rows


def keyboard_program():
    p = Program()
    p.emit(0xf3)
    p.word(0x31, 0xffff)
    for n in range(4):
        p.store(0xf000+n, 0)
    p.word(0x01, 0x1a03)
    p.emit(0x3e, 0x82, 0xed, 0x79)
    p.word(0x01, 0x1a01)
    p.emit(0xed, 0x78)
    p.emit(0x16, 0)  # D=0 until the CPU consumes a real F mailbox reply.
    p.label('poll')
    for i, value in enumerate((0xe4, 0, 0xe6)):
        p.word(0x01, 0x1a01)
        p.label(f'tx{i}')
        p.emit(0xed, 0x78, 0xe6, 0x40)
        p.jump(0xc2, f'tx{i}')
        p.word(0x01, 0x1900)
        p.emit(0x3e, value, 0xed, 0x79)
    for i in range(2):
        p.word(0x01, 0x1a01)
        p.label(f'rx{i}')
        p.emit(0xed, 0x78, 0xe6, 0x20)
        p.jump(0xc2, f'rx{i}')
        p.word(0x01, 0x1900)
        p.emit(0xed, 0x78)
    p.emit(0xe6, 0xdf, 0xfe, 0x46)
    p.jump(0xc2, 'check-r')
    p.emit(0x16, 1)
    p.store(0xf010, 0x46)
    p.jump(0xc3, 'poll')
    p.label('check-r')
    p.emit(0xfe, 0x52)
    p.jump(0xc2, 'poll')
    p.emit(0x7a, 0xfe, 1)
    p.jump(0xc2, 'poll')
    p.store(0xf011, 0x52)
    for n, value in enumerate(b'KEYS'):
        p.store(0xf000+n, value)
    p.label('done')
    p.emit(0x76)
    p.jump(0xc3, 'done')
    image = p.finish()
    assert len(image) < 4096
    return image + bytes([255]) * (4096-len(image))
