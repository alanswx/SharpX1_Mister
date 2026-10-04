"""Original 32 KiB Turbo IPL mapping/protection/overlay diagnostic."""
import json
import pathlib
import subprocess
import sys
import tempfile
from z80_fixture import Program

exe = str(pathlib.Path(sys.argv[1]).resolve())
p = Program(0x8000)
p.emit(0xF3)
addresses = (0x0FFF, 0x1000, 0x1FFF, 0x2000, 0x3FFF, 0x4000, 0x7FFE, 0x7FFF)
rom = bytearray([0xFF] * 32768)
rom[:3] = bytes.fromhex("c30080")  # Execute diagnostic in high RAM, overlay stays on.
def equal(address, value):
    p.word(0x3A, address)
    p.emit(0xFE, value)
    p.jump(0xC2, "fail")
def out(port):
    p.word(0x01, port)
    p.emit(0xED, 0x79)
for i, address in enumerate(addresses):
    rom[address] = 0x31 + i
    equal(address, 0x31+i)
    p.store(address, 0xA0+i)  # ROM-protected reads, writes land underneath.
    equal(address, 0x31+i)
out(0x1E00)
for i, address in enumerate(addresses): equal(address, 0xA0+i)
out(0x1D00)
for i, address in enumerate(addresses): equal(address, 0x31+i)
for i, byte in enumerate(b"IPL!"): p.store(0xF000+i, byte)
p.emit(0x76)
p.label("fail")
p.store(0xF000, 0xEE)
p.emit(0x76)
with tempfile.TemporaryDirectory(prefix="x1-turbo-ipl-") as folder:
    folder=pathlib.Path(folder)
    firmware, program=folder/"ipl.bin", folder/"ram.bin"
    firmware.write_bytes(rom)
    program.write_bytes(p.finish())
    result=subprocess.run([exe,"--cycles","1000000","--rom",str(firmware),"--ram",str(program)],
                          capture_output=True,text=True,check=True)
    report=json.loads(result.stdout.splitlines()[-1])
    assert report["turbo_foundation"] and report["halted"] and report["peek"].startswith(b"IPL!".hex()), report
    firmware.write_bytes(rom+b"oversize")
    result=subprocess.run([exe,"--cycles","1000000","--rom",str(firmware)],capture_output=True,text=True)
    assert result.returncode != 0 and "exceeds memory aperture" in result.stderr,result.stderr
print("PASS: 32 KiB Turbo IPL boundaries, no 4 KiB aliasing, underlying RAM writes, overlay switching and oversize rejection")
