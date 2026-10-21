#!/usr/bin/env python3
"""Turbo Z registers on the release-parity runner (FM + DMA + Z, runtime model).

A generated real-Z80 ROM selects Z mode (1FB0=80), writes the 1FC0 priority
register and reads it back, then makes the real DMA write 16 bytes to
1FC0-1FCF (including the 1FC5 palette control) and read 1FC0 back to memory.
1FB0 must read back (games detect the Z this way). The provisional policy
is that Z registers decode CPU cycles only: the DMA
write must not change 1FC0 and the DMA read must see FF, not the register or
the CPU's retained read reply. Without the Turbo Z model, the CPU itself must
not reach the register (the program stops at its first check).

Usage: test_z_dma_isolation.py RUNNER
"""
import json
import pathlib
import subprocess
import sys
import tempfile
from test_machine_dma import Fixture


def configure(f, source, destination, source_io=False, destination_io=False):
    # Same 16-byte continuous incrementing transfer as test_machine_dma_video.
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


def build():
    f = Fixture()
    f.out(0x1A03, 0x82)
    f.p.word(0x01, 0x1A02)
    f.p.emit(0xED, 0x78)  # clear reset/PPI-induced DAM
    f.out(0x1FB0, 0x80)
    f.check(0x1FB0, 0x80)  # Z presence check (Kohakuiro); X1 Turbo reads FF
    f.out(0x1FC0, 0x5A)
    f.check(0x1FC0, 0x5A)  # CPU path reaches the register (Z mode only)
    for i in range(16):
        f.p.store(0x9000 + i, 0xA5 ^ i)
        f.p.store(0x9100 + i, 0x00)
    configure(f, 0x9000, 0x1FC0, destination_io=True)
    f.check(0x1FC0, 0x5A)  # DMA writes did not reach it
    f.check(0x1FC0, 0x5A)  # leave a retained CPU read reply before the DMA read
    configure(f, 0x1FC0, 0x9100, source_io=True)
    f.p.compare_memory(0x9100, 0xFF)
    f.check(0x1FC0, 0x5A)
    return f.finish()


def run(runner, rom, *flags):
    out = subprocess.run([str(runner), "--rom", str(rom), "--cycles", "8000000",
                          "--peek", "0xf000", *flags], capture_output=True, text=True, timeout=600)
    assert out.returncode == 0, out.stderr
    return json.loads(out.stdout.strip().splitlines()[-1])


def main():
    runner = pathlib.Path(sys.argv[1]).resolve()
    with tempfile.TemporaryDirectory(prefix="x1-z-dma-") as tmp:
        rom = pathlib.Path(tmp) / "z_dma.rom"
        rom.write_bytes(build())
        r = run(runner, rom, "--model-z")
        assert r["model_z"] and r["turbo_dma"] and r["z_video_experiment"], r
        assert r["halted"] and r["peek"].startswith(b"DMA!".hex()), ("Z mode", r["peek"])
        assert r["dma_grants"] == 2 and r["dma_reads"] == 32 and r["dma_writes"] == 32, r
        print("PASS Z mode: 1FB0 reads back, CPU reaches 1FC0; DMA write ignored, DMA read FF (2 real grants)")
        r = run(runner, rom)
        assert not r["model_z"] and r["halted"] and r["peek"].startswith("ee"), ("X1 Turbo", r["peek"])
        print("PASS X1 Turbo mode: CPU does not reach 1FC0")


if __name__ == "__main__":
    main()
