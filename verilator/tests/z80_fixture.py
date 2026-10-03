"""Tiny opcode emitter for original self-checking test fixtures, not a general assembler."""


class Program:
    def __init__(self, origin=0):
        self.origin = origin
        self.code = bytearray()
        self.labels = {}
        self.fixups = []

    def emit(self, *values):
        self.code.extend(values)

    def word(self, opcode, value):
        self.emit(opcode, value & 255, value >> 8)

    def label(self, name):
        self.labels[name] = self.origin + len(self.code)

    def jump(self, opcode, name):
        self.fixups.append((len(self.code) + 1, name))
        self.emit(opcode, 0, 0)

    def store(self, address, value):
        self.emit(0x3E, value)  # LD A,n
        self.word(0x32, address)  # LD (nn),A

    def compare_memory(self, address, expected):
        self.word(0x3A, address)  # LD A,(nn)
        self.emit(0xFE, expected)  # CP n
        self.jump(0xC2, "fail")  # JP NZ,fail

    def finish(self):
        for position, name in self.fixups:
            value = self.labels[name]
            self.code[position:position + 2] = bytes((value & 255, value >> 8))
        return bytes(self.code)


def memory_diagnostic():
    p = Program()
    p.emit(0xF3)  # DI
    p.word(0x31, 0xFFFF)  # LD SP,nn
    p.store(0xF000, 0)
    p.compare_memory(0, 0xF3)
    p.store(0, 0xA5)  # RAM behind ROM: does not alter IPL.
    p.compare_memory(0, 0xF3)
    p.word(0x01, 0x1E00)  # LD BC,ROM-disable port
    p.emit(0xED, 0x79)  # OUT (C),A; subsequent code is the same bytes in RAM.
    p.compare_memory(0, 0xA5)
    # Exercise every address on a 1 KiB page with a high/low-address pattern.
    p.word(0x21, 0x4000)  # LD HL,nn
    p.word(0x01, 0x0400)  # LD BC,count
    p.label("write")
    p.emit(0x7C, 0xAD, 0x77, 0x23, 0x0B, 0x78, 0xB1)  # A=H^L; (HL)=A; HL++; BC--
    p.jump(0xC2, "write")
    p.word(0x21, 0x4000)
    p.word(0x01, 0x0400)
    p.label("read")
    p.emit(0x7C, 0xAD, 0xBE)  # A=H^L; CP (HL)
    p.jump(0xC2, "fail")
    p.emit(0x23, 0x0B, 0x78, 0xB1)
    p.jump(0xC2, "read")
    for address, value in [(0x1000, 0x11), (0x7FFF, 0x7F), (0x8000, 0x80), (0xFFFF, 0xFF)]:
        p.store(address, value)
        p.compare_memory(address, value)
    p.word(0x01, 0x1D00)  # Restore IPL read overlay.
    p.emit(0xED, 0x79)
    p.compare_memory(0, 0xF3)
    for i, value in enumerate(b"X1OK"):
        p.store(0xF000 + i, value)
    p.label("done")
    p.emit(0x76)  # HALT
    p.jump(0xC3, "done")
    p.label("fail")
    p.store(0xF000, 0xEE)
    p.emit(0x76)
    p.jump(0xC3, "fail")
    return p.finish()
