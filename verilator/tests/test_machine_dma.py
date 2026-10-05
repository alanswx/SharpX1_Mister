"""Original CPU-executed DMA fixtures on the actual shared machine.

No firmware/game bytes, forced grants, patched model state or debug injection.
Generated ROM and media travel through the normal loader/SD interfaces.
"""
import json
import pathlib
import struct
import subprocess
import sys
import tempfile
from z80_fixture import Program


class Fixture:
    def __init__(self):
        self.p = Program()
        self.p.emit(0xF3)
        self.p.word(0x31, 0xFFFF)
        self.serial = 0

    def out(self, port, value):
        self.p.word(0x01, port)
        self.p.emit(0x3E, value, 0xED, 0x79)

    def poll(self, port, mask, expected):
        self.serial += 1
        label = f"poll{self.serial}"
        self.p.word(0x01, port)
        self.p.label(label)
        self.p.emit(0xED, 0x78, 0xE6, mask, 0xFE, expected)
        self.p.jump(0xC2, label)

    def configure(self, source, destination, count, disk=False):
        # A is source; sequential N+1 count; B incrementing memory.
        stream = [0xC3, 0x7D, source & 255, source >> 8,
                  (count - 1) & 255, (count - 1) >> 8,
                  0x2C if disk else 0x14, 0x10,
                  0x8D if disk else 0xAD, destination & 255, destination >> 8,
                  0x92, 0xCF, 0xBB, 1, 0xA7]
        for byte in stream:
            self.out(0x1F80, byte)

    def configure_write(self, source, destination, count):
        # Fixed destination: load B as temporary source, then true A source.
        # UM0081 PDF139 workaround, not MAME's eager two-counter LOAD.
        stream = [0xC3, 0x79, source & 255, source >> 8,
                  (count - 1) & 255, (count - 1) >> 8,
                  0x14, 0x28, 0x8D, destination & 255, destination >> 8,
                  0x92, 0xCF, 0x05, 0xCF, 0xBB, 1, 0xA7]
        for byte in stream:
            self.out(0x1F80, byte)

    def check(self, port, value, mask=255):
        self.p.word(0x01, port)
        self.p.emit(0xED, 0x78, 0xE6, mask, 0xFE, value)
        self.p.jump(0xC2, "fail")

    def finish(self):
        for i, byte in enumerate(b"DMA!"):
            self.p.store(0xF000 + i, byte)
        self.p.emit(0x76)
        self.p.label("fail")
        self.p.store(0xF000, 0xEE)
        self.p.emit(0x76)
        return self.p.finish()


def media(seed):
    image = bytearray(688)
    struct.pack_into("<I", image, 32, 688)
    header = bytearray(16)
    header[:4] = bytes((0, 0, 1, 1))
    struct.pack_into("<H", header, 4, 1)
    struct.pack_into("<H", header, 14, 256)
    payload = bytes((seed + i * 7) & 255 for i in range(256))
    image.extend(header)
    image.extend(payload)
    struct.pack_into("<I", image, 28, len(image))
    return bytes(image), payload


def main():
    exe = str(pathlib.Path(sys.argv[1]).resolve())
    with tempfile.TemporaryDirectory(prefix="x1-machine-dma-") as directory:
        root = pathlib.Path(directory)
        for kind in ("ram", "drive-a", "drive-b", "drive-a-write",
                     "drive-b-write-crc", "drive-b-protected"):
            f = Fixture()
            writing = "write" in kind or "protected" in kind
            protected = "protected" in kind
            drive_b = kind.startswith("drive-b")
            if kind == "ram":
                payload = bytes((0x31 + i * 13) & 255 for i in range(16))
                for i, byte in enumerate(payload):
                    f.p.store(0x9000 + i, byte)
                f.configure(0x9000, 0x9100, len(payload))
                f.out(0x1F80, 0xB3)  # Force Ready only in continuous mode.
            else:
                # Let mount scanning advance using real CPU instructions.
                f.p.word(0x11, 16000)
                f.p.label("mount")
                f.p.emit(0x1B, 0x7A, 0xB3)
                f.p.jump(0xC2, "mount")
                f.out(0x0FFC, 0x80 | drive_b)
                f.poll(0x0FF8, 0x80, 0)
                payload = media(0x93 if drive_b else 0x21)[1]
                if writing:
                    payload = bytes(byte ^ 0x5C for byte in payload)
                    for i, byte in enumerate(payload):
                        f.p.store(0x9000 + i, byte)
                    f.configure_write(0x9000, 0x0FFB, 256)
                else:
                    f.configure(0x0FFB, 0x9100, 256, disk=True)
                f.out(0x0FFA, 1)
                f.out(0x0FF8, 0xA0 if writing else 0x80)
            f.out(0x1F80, 0x87)
            if kind != "ram":
                # Primary UM0081 Table 13 requires disabling before control
                # reads in enabled/inactive state. Poll the FDC, not DMA,
                # while byte-mode ownership returns to the CPU between bytes.
                f.poll(0x0FF8, 1, 0)
            if protected:
                f.check(0x0FF8, 0x40, 0x40)
                f.out(0x1F80, 0x83)
            else:
                f.check(0x1F80, 0, 0x20)
                if kind != "ram":
                    f.check(0x0FF8, 0, 0x9C)
                # Counter readback is firmware-visible, not just a RAM copy.
                f.out(0x1F80, 0xBB)
                f.out(0x1F80, 0x7E)
                f.out(0x1F80, 0xA7)
                a_end = 0x9100 if writing else 0x0FFB if kind != "ram" else 0x9010
                b_end = 0x0FFB if writing else 0x91FF if kind != "ram" else 0x910F
                for byte in (len(payload)-1, 0, a_end & 255, a_end >> 8, b_end & 255, b_end >> 8):
                    f.check(0x1F80, byte)
            if not writing:
                for i, byte in enumerate(payload):
                    f.p.compare_memory(0x9100 + i, byte)
            rom = root / f"{kind}.rom"
            rom.write_bytes(f.finish())
            args = [exe, "--rom", str(rom), "--cycles", "8000000",
                    "--peek", "0xf000", "--dump", str(root / kind)]
            if kind != "ram":
                originals = {}
                for flag, seed in (("--disk", 0x21), ("--disk-b", 0x93)):
                    disk = root / f"{seed}.d88"
                    image = bytearray(media(seed)[0])
                    if flag == "--disk-b" and protected:
                        image[26] = 0x10
                    if flag == "--disk-b" and "crc" in kind:
                        image[688 + 7] = 0x10
                        image[688 + 8] = 0xB0
                    originals[seed] = bytes(image)
                    disk.write_bytes(image)
                    args += [flag, str(disk)]
                    if writing:
                        args += ["--disk-b-output" if flag == "--disk-b" else "--disk-output",
                                 str(root / f"{kind}-{seed}.d88")]
            result = subprocess.run(args, capture_output=True, text=True, timeout=300)
            assert result.returncode == 0, (kind, result.stderr)
            report = json.loads(result.stdout.splitlines()[-1])
            assert report["turbo_dma"] and report["halted"], (kind, report)
            assert report["peek"].startswith(b"DMA!".hex()), (kind, report)
            count = 0 if protected else len(payload)
            assert report["dma_reads"] == count, (kind, report)
            assert report["dma_writes"] == count, (kind, report)
            assert report["dma_grants"] == (0 if protected else 1 if kind == "ram" else 256), (kind, report)
            assert report["cpu_fdc_data_reads"] == 0, (kind, report)
            assert report["cpu_fdc_data_writes"] == 0, (kind, report)
            ram = (root / f"{kind}.ram").read_bytes()
            if not writing:
                assert ram[0x9100:0x9100 + len(payload)] == payload, kind
            else:
                for seed in (0x21, 0x93):
                    expected = bytearray(originals[seed])
                    if not protected and seed == (0x93 if drive_b else 0x21):
                        expected[704:] = payload
                        expected[695] = expected[696] = 0
                    assert (root / f"{kind}-{seed}.d88").read_bytes() == expected, (kind, seed)
            print(f"PASS: shared-machine {kind}, {count} byte pairs, real CPU grant, counters/media", flush=True)


if __name__ == "__main__":
    main()
