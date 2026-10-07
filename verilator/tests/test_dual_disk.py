"""Original two-drive D88/CPU fixture; independent bytes, heads and protection."""
import json
import pathlib
import struct
import subprocess
import sys
import tempfile
from z80_fixture import Program


def media(seed):
    image = bytearray(688)
    offsets, payloads = [], []
    for track in range(2):
        struct.pack_into("<I", image, 32 + track * 8, len(image))
        header = bytearray(16)
        header[:4] = bytes((track, 0, 1, 1))
        struct.pack_into("<H", header, 4, 1)
        struct.pack_into("<H", header, 14, 256)
        image.extend(header)
        offsets.append(len(image))
        payload = bytes((seed + track * 32 + n) & 255 for n in range(256))
        payloads.append(payload)
        image.extend(payload)
    struct.pack_into("<I", image, 28, len(image))
    return bytes(image), offsets, payloads


class Fixture:
    def __init__(self, writable, swapped=False):
        self.p = Program(0x8000)
        self.p.emit(0xF3)
        self.p.word(0x31, 0xFFFF)
        self.serial = 0
        self.writable = writable
        self.swapped = swapped

    def label(self, prefix):
        self.serial += 1
        return prefix + str(self.serial)

    def out(self, port, value):
        self.p.word(0x01, port)
        self.p.emit(0x3E, value, 0xED, 0x79)

    def check(self, port, value, mask=255):
        self.p.word(0x01, port)
        self.p.emit(0xED, 0x78, 0xE6, mask, 0xFE, value)
        self.p.jump(0xC2, "fail")

    def wait(self, mask, value):
        label = self.label("poll")
        self.p.word(0x01, 0x0FF8)
        self.p.label(label)
        self.p.emit(0xED, 0x78, 0xE6, mask, 0xFE, value)
        self.p.jump(0xC2, label)

    def select(self, drive):
        self.out(0x0FFC, 0x80 | (drive ^ self.swapped))
        self.wait(0x80, 0)

    def seek(self, track):
        self.out(0x0FFB, track)
        self.out(0x0FF8, 0x10)
        self.wait(1, 0)
        self.check(0x0FF9, track)

    def read(self, address):
        self.out(0x0FFA, 1)
        self.out(0x0FF8, 0x80)
        self.p.word(0x21, address)
        self.p.word(0x11, 256)
        loop = self.label("read")
        self.p.label(loop)
        self.wait(2, 2)
        self.p.word(0x01, 0x0FFB)
        self.p.emit(0xED, 0x78, 0x77, 0x23, 0x1B, 0x7A, 0xB3)
        self.p.jump(0xC2, loop)
        self.wait(1, 0)
        self.check(0x0FF8, 0, 0x9C)

    def finish(self):
        self.select(0)
        self.seek(1)
        self.read(0x9000)
        self.out(0x0FFA, 7)
        self.out(0x0FFB, 0x5C)
        self.select(1)
        self.check(0x0FF9, 1)  # Shared register must not reset on selection.
        self.check(0x0FFA, 7)
        self.check(0x0FFB, 0x5C)
        self.out(0x0FF9, 0)   # B physical head is still zero.
        self.read(0x9100)
        self.seek(1)
        self.read(0x9200)
        self.select(0)
        self.check(0x0FF9, 1)
        self.read(0x9300)     # A head retained its earlier seek.
        self.select(1)
        self.out(0x0FF9, 0)
        self.out(0x0FF8, 0x80)
        self.wait(1, 0)
        self.check(0x0FF8, 0x10, 0x10)  # Logical C != B physical head.
        self.out(0x0FF9, 1)
        self.read(0x9400)
        # B remains protected even when A is explicitly writable.
        self.out(0x0FF8, 0xA0)
        self.wait(1, 0)
        self.check(0x0FF8, 0x40, 0x40)
        self.select(0)
        self.out(0x0FF8, 0xA0)
        if self.writable:
            self.p.word(0x21, 0x9800)
            self.p.word(0x11, 256)
            loop = self.label("write")
            self.p.label(loop)
            self.wait(2, 2)
            self.p.word(0x01, 0x0FFB)
            self.p.emit(0x7D, 0xEE, 0x5A, 0xED, 0x79, 0x23, 0x1B, 0x7A, 0xB3)
            self.p.jump(0xC2, loop)
            self.wait(1, 0)
        else:
            self.wait(1, 0)
            self.check(0x0FF8, 0x40, 0x40)
        self.read(0x9500)
        self.select(1)
        self.read(0x9600)
        self.out(0x0FF8, 0x60)  # B step-out without track-register update.
        self.wait(1, 0)
        self.check(0x0FF9, 1)
        self.select(0)
        self.out(0x0FF8, 0x30)  # Shared previous direction survives selection.
        self.wait(1, 0)
        self.check(0x0FF9, 0)
        self.read(0x9800)
        self.seek(1)
        self.select(1)
        self.out(0x0FF9, 0)
        self.read(0x9900)
        self.seek(1)
        self.out(0x0FFC, 0x82)  # Unsupported C must not move A's physical head.
        self.out(0x0FFB, 0)
        self.out(0x0FF8, 0x10)
        self.wait(1, 0)
        self.select(0)
        self.out(0x0FF9, 1)
        self.read(0x9700)
        for n, value in enumerate(b"ABOK"):
            self.p.store(0xF000 + n, value)
        self.p.emit(0x76)
        self.p.label("fail")
        self.p.store(0xF000, 0xEE)
        self.p.emit(0x76)
        return self.p.finish()


exe = str(pathlib.Path(sys.argv[1]).resolve())
a, offsets, pa = media(0x11)
b, _, pb = media(0xA1)
with tempfile.TemporaryDirectory(prefix="x1-dual-") as tmp:
    root = pathlib.Path(tmp)
    ap, bp = root / "a.d88", root / "b.d88"
    ap.write_bytes(a)
    bp.write_bytes(b)
    for writable, swapped in ((False, False), (True, False), (True, True)):
        ram = root / "program.bin"
        ram.write_bytes(Fixture(writable, swapped).finish())
        first, second = (pb, pa) if swapped else (pa, pb)
        repeats = []
        for n in range(2):
            dump = root / f"dump-{writable}-{swapped}-{n}"
            output = root / f"copy-{swapped}-{n}.d88"
            command = [exe, "--cycles", "7000000", "--ram", str(ram), "--disk", str(ap),
                       "--disk-b", str(bp), "--dump", str(dump)]
            if writable:
                command += ["--disk-b-output" if swapped else "--disk-output", str(output)]
            result = subprocess.run(command, check=True, capture_output=True, text=True, timeout=180)
            report = json.loads(result.stdout.splitlines()[-1])
            memory = dump.with_suffix(".ram").read_bytes()
            assert report["halted"] and memory[0xF000:0xF004] == b"ABOK", (report, memory[0xF000:0xF004])
            for address, payload in ((0x9000, first[1]), (0x9100, second[0]), (0x9200, second[1]),
                                     (0x9300, first[1]), (0x9400, second[1]), (0x9600, second[1])):
                assert memory[address:address + 256] == payload, hex(address)
            pattern = bytes(i ^ 0x5A for i in range(256))
            assert memory[0x9500:0x9600] == (pattern if writable else first[1])
            assert memory[0x9700:0x9800] == (pattern if writable else first[1])
            assert memory[0x9800:0x9900] == first[0]
            assert memory[0x9900:0x9A00] == second[0]
            expected = bytearray(b if swapped else a)
            if writable:
                expected[offsets[1]:offsets[1] + 256] = pattern
                assert output.read_bytes() == expected and report["disk_writes"] > 0
            else:
                assert report["disk_writes"] == 0
            assert ap.read_bytes() == a and bp.read_bytes() == b
            repeats.append((report, memory))
        assert repeats[0] == repeats[1], "cold repeats differ"
    # Mount B alone: initial empty A must neither prevent B's later scan nor
    # cause an accidental request to the absent A image.
    f = Fixture(False)
    f.select(1)
    f.read(0x9000)
    f.out(0x0FFC, 0x80)
    f.check(0x0FF8, 0x80, 0x80)
    for n, value in enumerate(b"ONLY"):
        f.p.store(0xF000 + n, value)
    f.p.emit(0x76)
    f.p.label("fail")
    f.p.store(0xF000, 0xEE)
    f.p.emit(0x76)
    ram.write_bytes(f.p.finish())
    repeats = []
    for n in range(2):
        dump = root / f"only-b-{n}"
        result = subprocess.run([exe, "--cycles", "2000000", "--ram", str(ram),
                                 "--disk-b", str(bp), "--dump", str(dump)],
                                check=True, capture_output=True, text=True, timeout=180)
        report = json.loads(result.stdout.splitlines()[-1])
        memory = dump.with_suffix(".ram").read_bytes()
        assert report["halted"] and memory[0xF000:0xF004] == b"ONLY", report
        assert memory[0x9000:0x9100] == pb[0]
        assert report["disk_writes"] == 0 and bp.read_bytes() == b
        repeats.append((report, memory))
    assert repeats[0] == repeats[1], "B-only cold repeats differ"
    for args in (["--disk-b-output", str(root / "missing.d88")],
                 ["--disk", str(ap), "--disk-b", str(bp), "--disk-output", str(bp)]):
        assert subprocess.run([exe] + args, capture_output=True).returncode == 2
print("PASS: distinct A/B sectors, retained physical heads/shared registers/direction, RNF, isolated A/B writes and protection, B-only mount, unchanged originals and cold repeats")
