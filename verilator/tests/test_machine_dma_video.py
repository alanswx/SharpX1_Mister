"""Original CPU/DMA video-target diagnostics on the opt-in shared machine.

No private ROMs/fonts, debug RAM injection, fabricated grants or Ready pulses.
Force Ready is programmed by the CPU; PCG WAIT remains the real CDC handshake.
"""
import argparse
import json
import pathlib
import subprocess
import tempfile
from test_machine_dma import Fixture


def configure(f, source, destination, source_io=False, destination_io=False):
    # Both increment; continuous transfer, standard timing and WAIT enabled.
    stream = [0xC3, 0x7D, source & 255, source >> 8, 15, 0,
              0x1C if source_io else 0x14,
              0x18 if destination_io else 0x10,
              0xAD, destination & 255, destination >> 8, 0x92, 0xCF, 0xB3, 0x87]
    for byte in stream:
        f.out(0x1F80, byte)
    f.check(0x1F80, 0, 0x20)
    f.out(0x1F80, 0xBB)
    f.out(0x1F80, 0x7E)
    f.out(0x1F80, 0xA7)
    # Primary source post-increment versus last destination address.
    for byte in (15, 0, (source+16) & 255, ((source+16) & 65535) >> 8,
                 (destination+15) & 255, ((destination+15) & 65535) >> 8):
        f.check(0x1F80, byte)


def transfer(f, port, payload):
    for i, byte in enumerate(payload):
        f.p.store(0x9000+i, byte)
        f.p.store(0x9100+i, byte ^ 255)  # stale RAM cannot satisfy the check
    configure(f, 0x9000, port, destination_io=True)
    configure(f, port, 0x9100, source_io=True)
    for i, byte in enumerate(payload):
        f.p.compare_memory(0x9100+i, byte)


def build(kind):
    f = Fixture()
    f.out(0x1A03, 0x82)
    f.p.word(0x01, 0x1A02)
    f.p.emit(0xED, 0x78)  # clear reset/PPI-induced DAM
    pairs = 0
    if kind == "gram":
        for bank in range(2):
            for plane, start in enumerate((0x4000, 0x8000, 0xC000)):
                for offset in (0, 0x1FFF, 0x3FF0):
                    port = start+offset
                    f.out(0x1FD0, (bank ^ 1) << 4)
                    for i in range(16):
                        f.out(port+i, 0xAA)
                    f.out(0x1FD0, bank << 4)
                    payload = bytes((0x31+bank*0x40+plane*13+offset+i*7) & 255 for i in range(16))
                    transfer(f, port, payload)
                    pairs += 32
                    f.out(0x1FD0, (bank ^ 1) << 4)
                    for i in range(16):
                        f.check(port+i, 0xAA)
    else:
        # Recurrent HSYNC window, no IPL-programmed CRTC or private font.
        f.out(0x1A02, 0x40)
        for register, value in enumerate((15, 1, 2, 0x12, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0)):
            f.out(0x1800, register)
            f.out(0x1801, value)
        for i, cell in enumerate((0x7FF, 0x3FF, 0x5FF, 0x1FF)):
            f.out(0x3000+cell, 60+i)
            f.out(0x2000+cell, 0x20)
            f.out(0x3800+cell, 0x10)  # paired sixteen-row PCG, not Kanji ROM
        f.out(0x1FD0, 0x20)
        for plane in range(1, 4):
            payload = bytes((plane*53+i*7) & 255 for i in range(16))
            transfer(f, 0x1400+plane*256, payload)
            pairs += 32
        # Plane contents must not alias one another.
        for plane in range(1, 4):
            for i in range(16):
                f.check(0x1400+plane*256+i, (plane*53+i*7) & 255)
    return f.finish(), pairs, payload


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("executable", type=pathlib.Path)
parser.add_argument("--case", choices=("gram", "pcg"), action="append")
args = parser.parse_args()
with tempfile.TemporaryDirectory(prefix="x1-machine-dma-video-") as temporary:
    root = pathlib.Path(temporary)
    for kind in args.case or ("gram", "pcg"):
        rom_bytes, pairs, last_payload = build(kind)
        assert len(rom_bytes) <= 32768
        rom = root / f"{kind}.rom"
        rom.write_bytes(rom_bytes)
        result = subprocess.run([str(args.executable.resolve()), "--rom", str(rom),
                                 "--cycles", "8000000", "--peek", "0xf000",
                                 "--dump", str(root / kind)],
                                capture_output=True, text=True, timeout=300)
        assert result.returncode == 0, (kind, result.stderr)
        report = json.loads(result.stdout.splitlines()[-1])
        assert report["turbo_dma"] and report["halted"] and report["peek"].startswith(b"DMA!".hex()), (kind, report)
        assert report["dma_reads"] == pairs and report["dma_writes"] == pairs, (kind, report)
        assert report["dma_grants"] == pairs//16, (kind, report)
        assert report["cpu_fdc_data_reads"] == 0 and report["cpu_fdc_data_writes"] == 0
        ram = (root / f"{kind}.ram").read_bytes()
        assert ram[0x9100:0x9110] == last_payload, kind
        print(f"PASS: shared-machine DMA {kind}, {pairs} pairs/{pairs//16} real grants, CPU count/readback/target isolation", flush=True)
