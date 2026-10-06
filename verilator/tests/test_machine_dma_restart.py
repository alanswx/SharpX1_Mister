"""Original actual-CPU automatic-restart diagnostic on shared Turbo DMA RTL.

No native/private assets, forced grants/Ready or debugger state. CPU FORCE
READY admits one byte in Byte mode; physical FDC Ready stays inactive.
"""
import json
import pathlib
import subprocess
import sys
import tempfile
from test_machine_dma import Fixture

exe = str(pathlib.Path(sys.argv[1]).resolve())
with tempfile.TemporaryDirectory(prefix="x1-machine-dma-restart-") as directory:
    root = pathlib.Path(directory)
    for a_source in (False, True):
        f = Fixture()
        old = bytes((0x31 + i * 13) & 255 for i in range(4))
        new = bytes((0xA7 + i * 7) & 255 for i in range(4))
        for base, payload in ((0x9000, old), (0x9200, new)):
            for i, value in enumerate(payload):
                f.p.store(base + i, value)
        a, b = (0x9000, 0x9100) if a_source else (0x9100, 0x9000)
        for value in (0xC3, 0x7D if a_source else 0x79,
                      a & 255, a >> 8, 3, 0, 0x14, 0x10,
                      0x8D, b & 255, b >> 8, 0xB2, 0xCF):
            f.out(0x1F80, value)
        for block in range(3):
            for index in range(4):
                if block == 0 and index == 3:
                    # Update both programmed buffers before terminal byte,
                    # without LOAD. Active counters must remain unchanged.
                    a, b = (0x9200, 0x9300) if a_source else (0x9300, 0x9200)
                    for value in (0x7D if a_source else 0x79,
                                  a & 255, a >> 8, 3, 0,
                                  0x8D, b & 255, b >> 8):
                        f.out(0x1F80, value)
                f.out(0x1F80, 0xB3)
                f.out(0x1F80, 0x87)
                # CPU cannot execute this until the real DMA grant releases.
                f.out(0x1F80, 0xBF)  # Restore RR0 after prior six-register sequence.
                f.check(0x1F80, 0x20, 0x20)
                f.out(0x1F80, 0xBB)
                f.out(0x1F80, 0x7E)
                f.out(0x1F80, 0xA7)
                if index == 3:
                    count, source, destination = 0, 0x9200, 0x9300
                else:
                    count = index + 1
                    source = (0x9000 if block == 0 else 0x9200) + index + 1
                    destination = (0x9100 if block == 0 else 0x9300) + index
                a_end, b_end = (source, destination) if a_source else (destination, source)
                for value in (count, 0, a_end & 255, a_end >> 8, b_end & 255, b_end >> 8):
                    f.check(0x1F80, value)
            base, payload = (0x9100, old) if block == 0 else (0x9300, new)
            for i, value in enumerate(payload):
                f.p.compare_memory(base + i, value)
        f.out(0x1F80, 0x83)
        rom = root / f"restart-{int(a_source)}.rom"
        program = f.finish()
        assert len(program) <= 32768
        rom.write_bytes(program)
        result = subprocess.run([exe, "--rom", str(rom), "--cycles", "8000000",
                                 "--peek", "0xf000", "--dump", str(root / "result")],
                                capture_output=True, text=True, timeout=300)
        assert result.returncode == 0, result.stderr
        report = json.loads(result.stdout.splitlines()[-1])
        assert report["turbo_dma"] and report["halted"] and report["peek"].startswith(b"DMA!".hex()), report
        assert report["dma_reads"] == report["dma_writes"] == report["dma_grants"] == 12, report
        ram = (root / "result.ram").read_bytes()
        assert ram[0x9100:0x9104] == old and ram[0x9300:0x9304] == new
        print(f"PASS shared-machine automatic restart A_source={a_source}: three blocks, "
              "new buffers without LOAD, real CPU counters/payload, 12 grants", flush=True)
