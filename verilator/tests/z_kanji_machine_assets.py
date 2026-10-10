# SPDX-License-Identifier: GPL-2.0-only
"""Original Z physical-byte emitter/oracle; no native/private font assets.

Techknow functional selectors, CZ-880 IC65 then IC66 pin-order storage.
Not native ASIC timing, double-size policy or FPGA storage qualification.
"""
def pattern(address):
    level, bank = address >> 17, (address >> 13) & 15
    character, row, half = (address >> 5) & 255, (address >> 1) & 15, address & 1
    return (level * 167 + bank * 13 + character * 37 + row * 29 + half * 83) & 255


def cells(cell):
    # All levels/banks/halves across visible cells, independently varying color
    # and reverse. Bits 5/6/7 of ATTR stay clear: ROM, normal size, no blink.
    character = (cell * 7 + cell // 32) & 255
    kan = 0x80 | (cell & 15) | ((cell // 16 & 1) << 4) | ((cell // 32 & 1) << 6)
    attr = (cell // 3 & 7) | ((cell // 11 & 1) << 3)
    return character, kan, attr


def program(Program, kind, columns=80, absent=False):
    p = Program()
    def out(port, value):
        p.word(0x01, port); p.emit(0x3E, value, 0xED, 0x79)
    p.emit(0xF3); p.word(0x31, 0xFFFF)
    for i in range(4): p.store(0xF000+i, 0)
    out(0x1A03, 0x82); p.word(0x01, 0x1A01); p.emit(0xED, 0x78)
    out(0x1A02, 0x40 if columns == 40 else 0)
    p.word(0x01, 0x1A01); p.emit(0xED, 0x78)
    # Public warm boot counter initialized by real firmware, never RAM upload.
    # Markers are overwritten each boot; fixture uses actual HALT transitions.
    for port in (0x1000, 0x1100, 0x1200, 0x1300): out(port, 0)
    regs = [55 if columns == 40 else 111, columns,
            46 if columns == 40 else 92, 0x28, 27, 0, 25, 26, 0,
            7 if kind == 'nonraster' else 15, 0, 0, 0, 0, 0, 0]
    for r,v in enumerate(regs): out(0x1800,r); out(0x1801,v)
    out(0x1FD0, 0x21) # high scan, documented high-speed CPU font access
    if kind in ('render','unsupported','transition','nonraster'):
        # Runtime loops fill all cells. Generated per-cell literals would exceed
        # IPL; data table resides in the same uploaded 32-KiB IPL, not RAM.
        p.word(0x21, 0) # patched to embedded table below
        table_pointer = len(p.code)-2
        for base, offset in ((0x3000,0),(0x3800,1),(0x2000,2)):
            p.word(0x21, 0); pointer = len(p.code)-2
            p.word(0x01, base); p.word(0x11, 2048)
            label=f'fill-{base}'
            p.label(label); p.emit(0x7E,0xED,0x79,0x23,0x03,0x1B,0x7A,0xB3)
            p.jump(0xC2,label)
            # Track table relocations without modifying the general emitter.
            if offset == 0: pointers=[]
            pointers.append((pointer,offset))
        p.store(0xF010,0x90)
        for i,v in enumerate(b'ZPIX'): p.store(0xF000+i,v)
        p.emit(0x76); p.jump(0xC3,'fail')
        p.label('fail'); p.store(0xF000,0xEE); p.emit(0x76)
        table=len(p.code)
        for pointer,offset in pointers:
            target=table+offset*2048; p.code[pointer:pointer+2]=target.to_bytes(2,'little')
        p.code[table_pointer:table_pointer+2]=table.to_bytes(2,'little')
        for component in range(3):
            for c in range(2048):
                value=cells(c)[component]
                if component==2 and kind=='unsupported': value |= 0x88 if c&1 else 0x48
                if component==2 and kind=='transition' and not c&1: value |= 0x48
                p.code.append(value)
    else:
        out(0x27FF,7)
        # Poison all lower fallback entries; CPU must use only highest cells.
        for c in (0x3FF,0x5FF,0x1FF):
            out(0x2000+c,7);out(0x3000+c,0xA6);out(0x3800+c,0xDF)
        contexts = [(l,b,h) for l in range(2) for b in range(16) for h in range(2)] \
                   if kind == 'exhaustive' else [(0,0,0),(1,15,1)]
        for n,(level,bank,half) in enumerate(contexts):
            out(0x3FFF,0x80|level*16|bank|half*64)
            if kind == 'exhaustive':
                p.emit(0x1E,0,0x16,(level*167+bank*13+half*83)&255) # E=character,D=expected row0
                char_label=f'char-{n}'; p.label(char_label)
                p.word(0x01,0x37FF);p.emit(0x7B,0xED,0x79)
                p.word(0x01,0x1400);p.word(0x21,0xD000)
                for _ in range(16): p.emit(0xED,0xA2,0x04,0x0C) # INI / restore B / next row
                p.word(0x21,0xD000);p.emit(0x06,16,0x7A)
                row_label=f'compare-{n}';p.label(row_label)
                p.emit(0xBE);p.jump(0xC2,'fail')
                p.emit(0x23,0xC6,29,0x05);p.jump(0xC2,row_label)
                p.emit(0x7A,0xC6,37,0x57,0x1C);p.jump(0xC2,char_label)
            else:
                out(0x37FF,255)
                p.word(0x01,0x1400);p.word(0x21,0xD000)
                for _ in range(16):p.emit(0xED,0xA2,0x04,0x0C)
                for row in range(16):
                    a=level*131072+bank*8192+255*32+row*2+half
                    p.compare_memory(0xD000+row,255 if absent else pattern(a))
        p.store(0xF010,0x90)
        for i,v in enumerate(b'ZCPU'):p.store(0xF000+i,v)
        p.emit(0x76)
        p.label('fail');p.store(0xF000,0xEE);p.emit(0x76)
    result=p.finish()
    assert len(result)<=32768,'generated program exceeded Turbo IPL aperture'
    return result+bytes(32768-len(result))


def expected_rgb(columns,kind='render'):
    pixels=bytearray()
    for y in range(200 if kind=='nonraster' else 400):
        for x in range(columns*8):
            c=(y//16)*columns+x//8
            character,kan,attr=cells(c)
            a=((kan>>4)&1)*131072+(kan&15)*8192+character*32+(y%16)*2+((kan>>6)&1)
            color=((attr&7) if pattern(a)&(0x80>>(x%8)) else 0) ^ (7 if attr&8 else 0)
            if kind in ('unsupported','nonraster') or (kind=='transition' and not c&1):color=0
            pixels.extend((255 if color&2 else 0,255 if color&4 else 0,255 if color&1 else 0))
    return bytes(pixels)
