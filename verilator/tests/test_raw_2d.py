"""Original raw X1 2D media fixture through the real CPU/FDC/SD path.

Drive A holds a headerless 40x2x16x256 image (cylinder, side, sector order);
drive B holds a D88 container in the same run. Reads cover both sides and
outer cylinders, a missing sector reports RNF, and a raw write must change
exactly its own 256 bytes: no D88 header update may land in a neighbour.
"""
import json
import pathlib
import struct
import subprocess
import sys
import tempfile
from z80_fixture import Program


def media(seed):
    """Two-track single-sector D88, as in test_dual_disk.py."""
    image = bytearray(688)
    payloads = []
    for track in range(2):
        struct.pack_into("<I", image, 32 + track * 8, len(image))
        header = bytearray(16)
        header[:4] = bytes((track, 0, 1, 1))
        struct.pack_into("<H", header, 4, 1)
        struct.pack_into("<H", header, 14, 256)
        image.extend(header)
        payload = bytes((seed + track * 32 + n) & 255 for n in range(256))
        payloads.append(payload)
        image.extend(payload)
    struct.pack_into("<I", image, 28, len(image))
    return bytes(image), None, payloads

RAW_BYTES = 40 * 2 * 16 * 256


def raw_image():
    image = bytearray()
    for c in range(40):
        for h in range(2):
            for r in range(1, 17):
                image.extend(((c * 7 + h * 61 + r * 13 + n) & 255) ^ (n >> 4) for n in range(256))
    assert len(image) == RAW_BYTES
    return bytes(image)


def offset(c, h, r):
    return ((c * 2 + h) * 16 + r - 1) * 256


READS = ((0, 0, 1), (0, 1, 16), (17, 0, 5), (17, 1, 3), (39, 0, 9), (39, 1, 16))
WRITE = (17, 1, 3)


class Fixture:
    def __init__(self, writable):
        self.p = Program(0x8000)
        self.p.emit(0xF3)
        self.p.word(0x31, 0xFFFF)
        self.serial = 0
        self.writable = writable

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

    def select(self, drive, side=0):
        self.out(0x0FFC, 0x80 | (side << 4) | drive)
        self.wait(0x80, 0)

    def seek(self, track):
        self.out(0x0FFB, track)
        self.out(0x0FF8, 0x10)
        self.wait(1, 0)
        self.check(0x0FF9, track)

    def read(self, sector, address):
        self.out(0x0FFA, sector)
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
        address = 0x9000
        for c, h, r in READS:
            self.select(0, h)
            self.seek(c)
            self.read(r, address)
            address += 0x100
        # Drive B is a D88 container mounted alongside the raw drive.
        self.select(1)
        self.seek(1)
        self.read(1, 0x9800)
        # Raw geometry has exactly sixteen sectors: R=17 is record-not-found.
        self.select(0, 1)
        self.seek(39)
        self.out(0x0FFA, 17)
        self.out(0x0FF8, 0x80)
        self.wait(1, 0)
        self.check(0x0FF8, 0x10, 0x10)
        c, h, r = WRITE
        self.select(0, h)
        self.seek(c)
        self.out(0x0FFA, r)
        self.out(0x0FF8, 0xA0)
        if self.writable:
            self.p.word(0x21, 0x9900)
            self.p.word(0x11, 256)
            loop = self.label("write")
            self.p.label(loop)
            self.wait(2, 2)
            self.p.word(0x01, 0x0FFB)
            self.p.emit(0x7D, 0xEE, 0xA5, 0xED, 0x79, 0x23, 0x1B, 0x7A, 0xB3)
            self.p.jump(0xC2, loop)
            self.wait(1, 0)
            self.check(0x0FF8, 0, 0xDC)
        else:
            self.wait(1, 0)
            self.check(0x0FF8, 0x40, 0x40)
        # Read back the written sector and both neighbours on that track.
        for n, sector in enumerate((r - 1, r, r + 1)):
            self.read(sector, 0x9A00 + n * 0x100)
        for n, value in enumerate(b"RWOK"):
            self.p.store(0xF000 + n, value)
        self.p.emit(0x76)
        self.p.label("fail")
        self.p.store(0xF000, 0xEE)
        self.p.emit(0x76)
        return self.p.finish()


def main():
    exe = str(pathlib.Path(sys.argv[1]).resolve())
    raw = raw_image()
    d88, _, d88_payloads = media(0xA1)
    pattern = bytes((n & 255) ^ 0xA5 for n in range(256))
    with tempfile.TemporaryDirectory(prefix="x1-raw2d-") as tmp:
        root = pathlib.Path(tmp)
        ap, bp = root / "a.2d", root / "b.d88"
        ap.write_bytes(raw)
        bp.write_bytes(d88)
        # Negative control: the same raw file is rejected as a D88 container.
        ram = root / "program.bin"
        ram.write_bytes(Fixture(False).finish())
        refused = subprocess.run([exe, "--cycles", "1000", "--ram", str(ram), "--disk", str(ap)],
                                 capture_output=True, text=True, timeout=60)
        assert refused.returncode != 0, "raw image without the raw flag must be refused"
        for writable in (False, True):
            ram.write_bytes(Fixture(writable).finish())
            repeats = []
            for n in range(2):
                dump = root / f"dump-{writable}-{n}"
                output = root / f"copy-{n}.2d"
                command = [exe, "--cycles", "16000000", "--ram", str(ram), "--disk", str(ap),
                           "--disk-raw2d", "--disk-b", str(bp), "--dump", str(dump)]
                if writable:
                    command += ["--disk-output", str(output)]
                result = subprocess.run(command, check=True, capture_output=True, text=True, timeout=600)
                report = json.loads(result.stdout.splitlines()[-1])
                memory = dump.with_suffix(".ram").read_bytes()
                assert report["halted"] and memory[0xF000:0xF004] == b"RWOK", (writable, report, memory[0xF000:0xF004])
                for k, chr_ in enumerate(READS):
                    start = offset(*chr_)
                    assert memory[0x9000 + k * 0x100:0x9100 + k * 0x100] == raw[start:start + 256], chr_
                assert memory[0x9800:0x9900] == d88_payloads[1], "D88 drive B beside raw drive A"
                c, h, r = WRITE
                expected = bytearray(raw)
                if writable:
                    expected[offset(c, h, r):offset(c, h, r) + 256] = pattern
                    assert report["disk_writes"] > 0
                    assert output.read_bytes() == bytes(expected), "raw write must change only its own sector"
                else:
                    assert report["disk_writes"] == 0
                for k, sector in enumerate((r - 1, r, r + 1)):
                    start = offset(c, h, sector)
                    got = memory[0x9A00 + k * 0x100:0x9B00 + k * 0x100]
                    assert got == bytes(expected[start:start + 256]), (writable, sector)
                assert ap.read_bytes() == raw and bp.read_bytes() == d88, "originals changed"
                repeats.append((report, memory))
            assert repeats[0] == repeats[1], "cold repeats differ"
    print("PASS: raw X1 2D reads (both sides, cylinders 0/17/39) beside a D88 drive, RNF R=17, "
          "protected and writable single-sector raw write with unchanged neighbours, D88-flag rejection, cold repeats")


if __name__ == "__main__":
    main()
