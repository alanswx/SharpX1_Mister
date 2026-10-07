"""Original generated 1024-byte sector using the observed Arcus DMA command shape.

No game/firmware bytes: only the executed public chip register sequence is
reproduced. Real CPU, mount scanner, FDC DRQ, bus grants and RAM verification.
"""
import argparse
import json
import pathlib
import struct
import subprocess
import tempfile
from test_machine_dma import Fixture


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=pathlib.Path)
    args = parser.parse_args()
    payload = bytes((i * 37 + (i >> 8) * 13 + 29) & 255 for i in range(1024))
    image = bytearray(688)
    struct.pack_into("<I", image, 32, 688)
    header = bytearray(16)
    header[:4] = bytes((0, 0, 4, 3))
    struct.pack_into("<H", header, 4, 1)
    struct.pack_into("<H", header, 14, 1024)
    image.extend(header + payload)
    struct.pack_into("<I", image, 28, len(image))
    f = Fixture()
    f.p.word(0x11, 16000)
    f.p.label("mount")
    f.p.emit(0x1B, 0x7A, 0xB3)
    f.p.jump(0xC2, "mount")
    f.out(0x0FFC, 0x80)
    f.poll(0x0FF8, 0x80, 0)
    # Exact observed setup, LOAD, and ENABLE; no force-ready or fake grant.
    for byte in (0xC3, 0x83, 0x7D, 0xFB, 0x0F, 0xFF, 0x03,
                 0x2C, 0x10, 0x8D, 0x00, 0x80, 0x92, 0xCF, 0x87):
        f.out(0x1F80, byte)
    f.out(0x0FFA, 4)
    f.out(0x0FF8, 0x80)
    f.poll(0x0FF8, 1, 0)
    f.check(0x0FF8, 0, 0x9C)
    f.check(0x1F80, 0, 0x20)
    for byte in (0x83, 0xBB, 0x7E, 0xA7):
        f.out(0x1F80, byte)
    for byte in (0xFF, 0x03, 0xFB, 0x0F, 0xFF, 0x83):
        f.check(0x1F80, byte)
    for i, byte in enumerate(payload):
        f.p.compare_memory(0x8000 + i, byte)
    with tempfile.TemporaryDirectory(prefix="x1-native-dma-shape-") as temp:
        root = pathlib.Path(temp)
        rom, disk = root / "original.rom", root / "original.d88"
        rom.write_bytes(f.finish())
        disk.write_bytes(image)
        for warm in (False, True):
            dump = root / f"result-{warm}"
            command = [str(args.executable.resolve()), "--rom", str(rom),
                       "--disk", str(disk), "--cycles", "16000000", "--dump", str(dump)]
            if warm:
                command += ["--reset-at", "250", "--reset-for-us", "10"]
            result = subprocess.run(command, check=True, capture_output=True, text=True, timeout=300)
            report = json.loads(result.stdout.splitlines()[-1])
            assert report["turbo_dma"] and report["turbo_video_master"], report
            assert report["halted"] and report["peek"].startswith(b"DMA!".hex()), report
            # Counters persist across warm reset, unlike the device registers.
            count = 2048 if warm else 1024
            assert all(report[k] == count for k in ("dma_reads", "dma_writes", "dma_grants")), report
            assert report["cpu_fdc_data_reads"] == report["cpu_fdc_data_writes"] == 0, report
            assert report["disk_writes"] == 0 and disk.read_bytes() == image
            assert dump.with_suffix(".ram").read_bytes()[0x8000:0x8400] == payload
            print(json.dumps({"warm": warm, "pairs": count, "video_hz": report["video_hz"]}), flush=True)
    print("PASS native DMA read command shape: real 1024-byte FDC sector, count/readback/payload, cold/warm X3")


if __name__ == "__main__":
    main()
