"""Original shared-machine CPU/IM2 completion diagnostics, no private assets.

Two native-command blocks per case, real loader/CPU/RAM/DMA/interrupt chain.
EI;HALT deliberately uses the Z80's one-instruction EI delay, not a forced IEI
gate. Handler checks RR0, clears flags, counts entry and returns with RETI.
"""
import json
import pathlib
import subprocess
import sys
import tempfile
from test_machine_dma import Fixture


def diagnostic(profile, handler_delay=0):
    f = Fixture()
    p = f.p
    reads = (4, 3, 2, 5)[profile]
    writes = (4, 0, 2, 0)[profile]
    vector = (0xD4, 0xD2, 0xD2, 0xD6)[profile]
    flags = (0x18, 0x28, 0x28, 0x08)[profile]  # RR0 IP cleared by ACK
    payload = bytes(0xA5 if i == (3 if profile == 3 else 1)
                    else 0x36 for i in range(6))
    p.store(0xF010, 0)
    p.store(0x8000 + vector, 0)
    p.store(0x8001 + vector, 0x10)  # handler at IPL 1000
    p.emit(0x3E, 0x80, 0xED, 0x47, 0xED, 0x5E)  # I=80, IM2
    for i, value in enumerate(payload):
        p.store(0x9000 + i, value)
        p.store(0x9100 + i, 0xCC)
    for block in range(2):
        for value in (0xC3, 0x7D if profile == 0 else 0x7F if profile == 2 else 0x7E,
                      0, 0x90, 4 if profile in (1, 3) else 3, 0, 0x14, 0x10):
            f.out(0x1F80, value)
        for value in ((0x80,) if profile == 0 else (0x9C, 0, 0xA5)):
            f.out(0x1F80, value)
        for value in (0x9D if profile == 2 else 0xBD, 0, 0x91,
                      0x30 | (2 if profile == 0 else 3 if profile == 3 else 1),
                      0xD6, 0x8A, 0xCF, 0xAB, 0x87):
            f.out(0x1F80, value)
        p.emit(0xFB, 0x76, 0xF3)  # EI; HALT; DI after real interrupt return
        p.compare_memory(0xF010, block + 1)
        p.word(0x3A, 0xF011)
        p.emit(0xE6, 0x38, 0xFE, flags)  # IRQ/match/EOB, not Ready's live bits
        p.jump(0xC2, "fail")
        for i, value in enumerate(payload):
            p.compare_memory(0x9000 + i, value)
            p.compare_memory(0x9100 + i, value if i < writes else 0xCC)
    for i, value in enumerate(b"IRQ!"):
        p.store(0xF000 + i, value)
    p.label("done")
    p.emit(0x76)
    p.jump(0xC3, "done")
    p.label("fail")
    p.store(0xF000, 0xEE)
    p.emit(0xF3, 0x76)
    p.jump(0xC3, "fail")
    assert len(p.code) < 0x1000
    p.code.extend(bytes(0x1000 - len(p.code)))
    p.emit(0xF5, 0xC5)  # PUSH AF,BC
    if handler_delay:
        p.emit(0xD5)  # preserve DE around original deterministic service delay
        p.store(0xF012, 1)
        p.word(0x11, handler_delay)
        p.label("handler_delay")
        p.emit(0x1B, 0x7A, 0xB3)  # DEC DE; A=D; OR E
        p.jump(0xC2, "handler_delay")
        p.emit(0xD1)
    f.out(0x1F80, 0xAF)
    f.out(0x1F80, 0xBF)
    p.emit(0xED, 0x78)
    p.word(0x32, 0xF011)
    p.emit(0xE6, 0x38, 0xFE, flags)
    p.jump(0xC2, "fail")
    f.out(0x1F80, 0x8B)
    f.out(0x1F80, 0xBF)
    f.check(0x1F80, 0x38, 0x38)
    p.word(0x3A, 0xF010)
    p.emit(0x3C)
    p.word(0x32, 0xF010)
    f.out(0x1F80, 0xAB)
    if handler_delay:
        p.store(0xF012, 0)
    p.emit(0xC1, 0xF1, 0xFB, 0xED, 0x4D)  # POP BC,AF; EI; RETI
    return p.finish(), payload, reads, writes, flags


def main():
    exe = str(pathlib.Path(sys.argv[1]).resolve())
    with tempfile.TemporaryDirectory(prefix="x1-machine-dma-irq-") as directory:
        root = pathlib.Path(directory)
        for profile in range(4):
            code, payload, reads, writes, flags = diagnostic(profile)
            rom = root / f"irq-{profile}.rom"
            rom.write_bytes(code)
            stem = root / f"irq-{profile}"
            result = subprocess.run([exe, "--rom", str(rom), "--cycles", "8000000",
                                     "--peek", "0xf000", "--dump", str(stem)],
                                    capture_output=True, text=True, timeout=300)
            assert result.returncode == 0, (profile, result.returncode, result.stdout, result.stderr)
            report = json.loads(result.stdout.splitlines()[-1])
            assert report["turbo_dma_irq"] and report["turbo_dma"] and report["halted"], report
            ram = stem.with_suffix(".ram").read_bytes()
            assert report["peek"].startswith(b"IRQ!".hex()), (profile, report, ram[0xF010:0xF012].hex())
            assert (report["dma_reads"], report["dma_writes"], report["dma_grants"]) == \
                (2 * reads, 2 * writes, 4 if profile == 2 else 2), (profile, report)
            assert ram[0xF010] == 2 and ram[0xF011] & 0x38 == flags, (profile, ram[0xF010:0xF012])
            assert ram[0x9000:0x9006] == payload
            assert ram[0x9100:0x9106] == payload[:writes] + bytes([0xCC] * (6 - writes))
            print(f"PASS shared-machine completion IRQ profile={profile}: two real IM2/HALT/AF/RR0/8B/AB/RETI blocks, "
                  f"{2 * reads} reads/{2 * writes} writes, RAM guards", flush=True)


if __name__ == "__main__":
    main()
