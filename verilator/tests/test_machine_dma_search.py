"""Original shared-CPU pure Byte search diagnostics; normal generated IPL load.

No destination writes, private assets, forced Ready/grants or debug bootstrap.
The full eight-million-reference-cycle invocation is retained for every case.
"""
import json
import pathlib
import subprocess
import sys
import tempfile
from test_machine_dma import Fixture

exe = str(pathlib.Path(sys.argv[1]).resolve())
with tempfile.TemporaryDirectory(prefix="x1-machine-dma-search-") as directory:
    root = pathlib.Path(directory)
    for direction in (False, True):
        for stop_match in (False, True):
            for position in range(5):
                f = Fixture()
                payload = bytes(0xC5 if i == position else 0x36 for i in range(4))
                for i, value in enumerate(payload):
                    f.p.store(0x9000 + i, value)
                    f.p.store(0x9100 + i, 0xEE)
                a, b = (0x9000, 0x9100) if direction else (0x9100, 0x9000)
                # LOAD only loads the source immediately. First select the
                # otherwise-unused port as source, then reselect the true
                # source and LOAD again. Search must preserve this 9100 counter.
                for value in (0xC3, 0x7E if direction else 0x7A,
                              a & 255, a >> 8, 3, 0, 0x14, 0x10,
                              0x9C if stop_match else 0x98, 0xF0, 0xA5,
                              0x8D, b & 255, b >> 8, 0x92,
                              0x02 if direction else 0x06, 0xCF,
                              0x06 if direction else 0x02, 0xCF):
                    f.out(0x1F80, value)
                operations = position + 1 if stop_match and position < 4 else 4
                for pair in range(operations):
                    f.out(0x1F80, 0xB3)
                    f.out(0x1F80, 0x87)
                    f.out(0x1F80, 0xBF)
                    matched = position < 4 and pair >= position
                    f.check(0x1F80, (0 if matched else 0x10) |
                            (0 if pair == 3 else 0x20), 0x30)
                f.out(0x1F80, 0xBB)
                f.out(0x1F80, 0x7E)
                f.out(0x1F80, 0xA7)
                count = operations if stop_match and position < 4 else 3
                src = 0x9000 + operations
                a_end, b_end = (src, 0x9100) if direction else (0x9100, src)
                for value in (count, 0, a_end & 255, a_end >> 8, b_end & 255, b_end >> 8):
                    f.check(0x1F80, value)
                for i, value in enumerate(payload):
                    f.p.compare_memory(0x9000 + i, value)
                    f.p.compare_memory(0x9100 + i, 0xEE)
                f.out(0x1F80, 0x8B)
                f.out(0x1F80, 0xBF)
                f.check(0x1F80, 0x30, 0x30)
                stem = f"pure-byte-{int(direction)}-{int(stop_match)}-{position}"
                rom = root / f"{stem}.rom"
                rom.write_bytes(f.finish())
                result = subprocess.run([exe, "--rom", str(rom), "--cycles", "8000000",
                                         "--peek", "0xf000", "--dump", str(root / stem)],
                                        capture_output=True, text=True, timeout=300)
                assert result.returncode == 0, (stem, result.stderr)
                report = json.loads(result.stdout.splitlines()[-1])
                assert report["turbo_dma"] and report["halted"] and report["peek"].startswith(b"DMA!".hex()), (stem, report)
                assert report["dma_reads"] == report["dma_grants"] == operations and report["dma_writes"] == 0, (stem, report)
                ram = (root / f"{stem}.ram").read_bytes()
                assert ram[0x9000:0x9004] == payload and ram[0x9100:0x9104] == bytes([0xEE] * 4)
                print(f"PASS shared-CPU pure Byte search source_A={direction} stop={stop_match} "
                      f"match_position={position}: {operations} reads, no writes, "
                      "source/destination/count/status/readback/8B", flush=True)
