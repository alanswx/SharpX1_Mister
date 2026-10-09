"""CPU-only visible result for DMA hardware IPLs; no debug/model writes."""


def initialize(f):
    p = f.p
    f.out(0x1a03, 0x82)
    f.out(0x1a02, 0x40)  # 40 columns; disable DAM by real PPI read.
    p.word(0x01, 0x1a02)
    p.emit(0xed, 0x78)
    for base in (0x2000, 0x3000):
        p.word(0x01, base)
        p.word(0x11, 2048)
        label = "visible_fill_" + str(base)
        p.label(label)
        p.emit(0xaf, 0xed, 0x79, 0x03, 0x1b, 0x7a, 0xb3)
        p.jump(0xc2, label)
    f.out(0x1fd0, 0)
    f.out(0x1fe0, 0)
    f.out(0x1300, 255)
    result(f, False)  # Red remains until all CPU assertions succeed.
    for register, value in enumerate((55, 40, 46, 0x28, 31, 2, 25, 28,
                                       0, 7, 0, 0, 0, 0, 0, 0)):
        f.out(0x1800, register)
        f.out(0x1801, value)


def result(f, success):
    # All eight graphics colors map identically; independent of unknown GRAM.
    f.out(0x1000, 0)
    f.out(0x1100, 0 if success else 255)
    f.out(0x1200, 255 if success else 0)
