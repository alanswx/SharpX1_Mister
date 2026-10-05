"""Original generated D88 + Z80 tests: actual machine controller, never game data."""
import binascii
import hashlib
import json
import pathlib
import struct
import subprocess
import sys
import tempfile
from z80_fixture import Program

exe = str(pathlib.Path(sys.argv[1]).resolve())


def media(protected=False, crc=0, mixed=False):
    image = bytearray(688)
    image[:8] = b"X1 TEST\0"
    image[26] = 0x10 if protected else 0
    sectors = {}
    for cylinder in range(2):
        for side in range(2):
            struct.pack_into("<I", image, 32 + 4 * (cylinder * 2 + side), len(image))
            for number in range(1, 17):
                header = bytearray(16)
                size_code = (number - 1) % 4 if mixed else 1
                length = 128 << size_code
                header[:4] = bytes((cylinder, side, number, size_code))
                struct.pack_into("<H", header, 4, 16)
                header[8] = crc if (cylinder, side, number) == (0, 0, 1) else 0
                struct.pack_into("<H", header, 14, length)
                image.extend(header)
                offset = len(image)
                payload = bytes((cylinder * 53 + side * 91 + number * 7 + i) & 255 for i in range(length))
                image.extend(payload)
                sectors[cylinder, side, number] = (offset, payload)
    struct.pack_into("<I", image, 28, len(image))
    return bytes(image), sectors


class DiskProgram:
    def __init__(self):
        self.p = Program()
        self.p.emit(0xF3)
        self.p.word(0x31, 0xFFFF)
        self.serial = 0
        self.delay(16000)  # Mount scanner completes while the CPU executes real instructions.
        self.output(0x0FFC, 0x80)

    def label(self, prefix):
        self.serial += 1
        return prefix + str(self.serial)

    def output(self, port, value):
        self.p.word(0x01, port)
        self.p.emit(0x3E, value, 0xED, 0x79)

    def equal(self, port, value, mask=255):
        self.p.word(0x01, port)
        self.p.emit(0xED, 0x78, 0xE6, mask, 0xFE, value)
        self.p.jump(0xC2, "fail")

    def delay(self, count):
        label = self.label("delay")
        self.p.word(0x11, count)
        self.p.label(label)
        self.p.emit(0x1B, 0x7A, 0xB3)
        self.p.jump(0xC2, label)

    def idle(self):
        label = self.label("idle")
        self.p.word(0x01, 0x0FF8)
        self.p.label(label)
        self.p.emit(0xED, 0x78, 0xE6, 1)
        self.p.jump(0xC2, label)

    def ready(self):
        # Switching physical media serializes an index rescan; wait for
        # actual READY rather than issuing a command into the quarantine.
        label = self.label("ready")
        self.p.word(0x01, 0x0FF8)
        self.p.label(label)
        self.p.emit(0xED, 0x78, 0xE6, 0x80)
        self.p.jump(0xC2, label)

    def drq(self):
        label = self.label("drq")
        self.p.word(0x01, 0x0FF8)
        self.p.label(label)
        self.p.emit(0xED, 0x78, 0xE6, 2)
        self.p.jump(0xCA, label)

    def read(self, number, address, count=256, command=0x80):
        self.output(0x0FFA, number)
        self.output(0x0FF8, command)
        self.p.word(0x21, address)
        self.p.word(0x11, count)
        label = self.label("read")
        self.p.label(label)
        self.drq()
        self.p.word(0x01, 0x0FFB)
        self.p.emit(0xED, 0x78, 0x77, 0x23, 0x1B, 0x7A, 0xB3)
        self.p.jump(0xC2, label)
        self.idle()

    def finish(self):
        for i, byte in enumerate(b"DSK!"):
            self.p.store(0xF000 + i, byte)
        self.p.emit(0x76)
        self.p.label("fail")
        self.p.store(0xF000, 0xEE)
        self.p.emit(0x76)
        return self.p.finish()


def basic():
    d = DiskProgram()
    d.output(0x0FF8, 8)  # Restore + head load.
    d.idle()
    d.equal(0x0FF9, 0)
    d.equal(0x0FF8, 0x24, 0x24)
    d.read(1, 0x9000)
    d.output(0x0FFC, 0x90)
    d.read(3, 0x9100)
    d.output(0x0FFB, 1)
    d.output(0x0FF8, 0x10)
    d.idle()
    d.equal(0x0FF9, 1)
    d.read(2, 0x9200)
    d.output(0x0FF8, 0x70)  # Step out + update track.
    d.idle()
    d.equal(0x0FF9, 0)
    d.read(4, 0x9300)
    d.read(1, 0x9400, 6, 0xC0)
    d.output(0x0FFA, 99)
    d.output(0x0FF8, 0x80)
    d.idle()
    d.equal(0x0FF8, 0x10, 0x10)
    d.read(1, 0x9500)
    d.equal(0x0FF8, 0, 0x1C)  # New read clears stale errors.
    d.output(0x0FF9, 7)  # Logical C must match the physical head's ID.
    d.output(0x0FF8, 0x80)
    d.idle()
    d.equal(0x0FF8, 0x10, 0x10)
    d.output(0x0FF8, 0)
    d.idle()
    d.equal(0x0FFC, 255)  # Read selects unsupported FM.
    d.output(0x0FF8, 0x80)
    d.idle()
    d.equal(0x0FF8, 0x10, 0x10)
    d.equal(0x0FFD, 255)  # Select MFM again.
    d.read(1, 0x9600)
    d.output(0x0FFC, 0x81)
    d.output(0x0FF8, 0x80)
    d.idle()
    d.equal(0x0FF8, 0x80, 0x80)
    d.output(0x0FFC, 0x80)
    d.ready()
    d.output(0x0FFA, 1)
    d.output(0x0FF8, 0xA0)
    d.idle()
    d.equal(0x0FF8, 0x40, 0x40)  # Default host protection prevents writing.
    d.output(0x0FF8, 0x80)
    d.drq()
    d.delay(1024)  # Miss several DRQs deliberately; error must remain sticky.
    d.equal(0x0FF8, 4, 4)
    d.output(0x0FF8, 0xD0)
    d.idle()
    return d.finish()


def writer(protected=False, number=2, count=256):
    d = DiskProgram()
    d.output(0x0FFA, number)
    d.output(0x0FF8, 0xA0)
    if protected:
        d.idle()
        d.equal(0x0FF8, 0x40, 0x40)
    else:
        d.p.word(0x11, count)
        d.p.word(0x21, 0x9800)  # L supplies a repeating 256-byte pattern.
        label = d.label("write")
        d.p.label(label)
        d.drq()
        d.p.word(0x01, 0x0FFB)
        d.p.emit(0x7D, 0xEE, 0x5A, 0xED, 0x79, 0x23, 0x1B, 0x7A, 0xB3)
        d.p.jump(0xC2, label)
        d.idle()
        d.equal(0x0FF8, 0, 0x7C)
        d.read(number, 0x9900, count)
    return d.finish()


with tempfile.TemporaryDirectory(prefix="x1-disk-") as directory:
    folder = pathlib.Path(directory)
    disk, rom = folder / "original.d88", folder / "test.bin"

    def run(program, data, name, writable=False, resets=()):
        disk.write_bytes(data)
        original_hash = hashlib.sha256(data).hexdigest()
        rom.write_bytes(program)
        output, dump = folder / (name + ".d88"), folder / name
        command = [exe, "--cycles", "8000000", "--rom", str(rom), "--disk", str(disk), "--dump", str(dump)]
        for when in resets:
            command += ["--reset-at", str(when), "--reset-for-us", "1000"]
        if writable:
            command += ["--disk-output", str(output)]
        result = subprocess.run(command, check=True, capture_output=True, text=True)
        report = json.loads(result.stdout.splitlines()[-1])
        assert report["halted"] and report["peek"].startswith(b"DSK!".hex()), (name, report)
        assert hashlib.sha256(disk.read_bytes()).hexdigest() == original_hash, "input media modified"
        return report, dump.with_suffix(".ram").read_bytes(), output

    data, sectors = media()
    report, memory, _ = run(basic(), data, "basic")
    for address, sector in ((0x9000, (0, 0, 1)), (0x9100, (0, 1, 3)),
                            (0x9200, (1, 1, 2)), (0x9300, (0, 1, 4)),
                            (0x9500, (0, 1, 1)), (0x9600, (0, 1, 1))):
        assert memory[address:address + 256] == sectors[sector][1], (address, sector)
    identifier = memory[0x9400:0x9406]
    assert identifier[0:2] == bytes((0, 1)) and 1 <= identifier[2] <= 16 and identifier[3] == 1
    crc = binascii.crc_hqx(bytes((0xA1, 0xA1, 0xA1, 0xFE)) + identifier[:4], 0xFFFF)
    assert identifier[4:] == crc.to_bytes(2, "big"), identifier.hex()
    assert report["disk_writes"] == 0
    # Keep the mounted image and host service alive through a reset during
    # scanning, then reset again after scan completion. No ROM/media reload.
    recovered, memory, _ = run(basic(), data, "warm-scan-reset", resets=(1, 50))
    assert recovered["reset_edges"] > report["reset_edges"] and recovered["disk_writes"] == 0
    for address, sector in ((0x9000, (0, 0, 1)), (0x9100, (0, 1, 3)), (0x9200, (1, 1, 2))):
        assert memory[address:address + 256] == sectors[sector][1], ("warm reset", address)
    written, memory, output = run(writer(), data, "written", True)
    expected = bytearray(data)
    offset = sectors[0, 0, 2][0]
    expected[offset:offset + 256] = bytes(i ^ 0x5A for i in range(256))
    assert output.read_bytes() == expected, "write changed neighboring data/header or used wrong offset"
    assert memory[0x9900:0x9A00] == expected[offset:offset + 256]
    assert written["disk_writes"] >= 1
    # Sector sizes come from each ID, not a hardcoded 256-byte transfer.
    mixed, mixed_sectors = media(mixed=True)
    d = DiskProgram()
    for number, address in ((1, 0x9000), (2, 0x9100), (3, 0x9300), (4, 0x9500)):
        d.read(number, address, len(mixed_sectors[0, 0, number][1]))
        d.equal(0x0FF8, 0, 0x1C)
    _, memory, _ = run(d.finish(), mixed, "variable")
    for number, address in ((1, 0x9000), (2, 0x9100), (3, 0x9300), (4, 0x9500)):
        payload = mixed_sectors[0, 0, number][1]
        assert memory[address:address + len(payload)] == payload
    written, memory, output = run(writer(number=4, count=1024), mixed, "large-write", True)
    expected = bytearray(mixed)
    offset = mixed_sectors[0, 0, 4][0]
    pattern = bytes((i & 255) ^ 0x5A for i in range(1024))
    expected[offset:offset + 1024] = pattern
    assert output.read_bytes() == expected and memory[0x9900:0x9D00] == pattern
    assert written["disk_writes"] >= 2
    d = DiskProgram()
    d.read(15, 0x9000, 512, 0x90)  # Multi-sector command reaches absent R=17.
    d.equal(0x0FF8, 0x10, 0x10)
    d.equal(0x0FFA, 17)
    _, memory, _ = run(d.finish(), data, "multi-read")
    assert memory[0x9000:0x9200] == sectors[0, 0, 15][1] + sectors[0, 0, 16][1]
    protected, _ = media(True)
    report, _, output = run(writer(True), protected, "protected", True)
    assert report["disk_writes"] == 0 and output.read_bytes() == protected
    for error in (0xA0, 0xB0):
        damaged, _ = media(crc=error)
        d = DiskProgram()
        d.read(1, 0x9000)
        d.equal(0x0FF8, 8, 8)
        run(d.finish(), damaged, "crc" + str(error))
    # Refuse destructive output paths before starting simulation.
    for output in (disk, folder / "protected.d88"):
        result = subprocess.run([exe, "--disk", str(disk), "--disk-output", str(output)], capture_output=True)
        assert result.returncode == 2
    assert subprocess.run([exe, "--disk-output", str(folder / "no-input.d88")], capture_output=True).returncode == 2
print("PASS: native FDC variable/multi-sector reads, warm scanner/controller reset recovery, seek/side/ID CRC/RNF/density/not-ready/lost-data, safe cross-block writes, protection and CRC errors")
