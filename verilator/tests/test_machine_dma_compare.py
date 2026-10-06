"""Original CPU-executed masked transfer/search on the shared DMA machine.

Stop-on-match/pure-search/IRQ are not claimed. No firmware patch, private
assets, forced Ready/grants or debugger RAM results.
"""
import json
import pathlib
import subprocess
import sys
import tempfile
from test_machine_dma import Fixture

exe = str(pathlib.Path(sys.argv[1]).resolve())
with tempfile.TemporaryDirectory(prefix="x1-machine-dma-compare-") as directory:
    root = pathlib.Path(directory)
    for direction in (False, True):
        for mode in range(3):
            for positive in (False, True):
                f = Fixture()
                payload = bytes((0xC5 if positive else 0xC4, 0x36, 0x47, 0x58))
                for i, value in enumerate(payload):
                    f.p.store(0x9000 + i, value)
                f.p.store(0x90FF, 0xBE)
                f.p.store(0x9104, 0xEF)
                a, b = (0x9000, 0x9100) if direction else (0x9100, 0x9000)
                for value in (0xC3, 0x7F if direction else 0x7B,
                              a & 255, a >> 8, 3, 0, 0x14, 0x10,
                              0x98, 0xF0, 0xA5, 0x8D | mode << 5,
                              b & 255, b >> 8, 0x92, 0xCF):
                    f.out(0x1F80, value)
                f.check(0x1F80, 0x30, 0x30)
                pairs = 4 if mode == 0 else 1
                for pair in range(pairs):
                    f.out(0x1F80, 0xB3)
                    f.out(0x1F80, 0x87)
                    f.out(0x1F80, 0xBF)
                    # Byte-mode Force Ready releases each pair; other modes
                    # return the CPU only after the whole block completes.
                    final = pair == pairs - 1
                    expected = (0 if positive else 0x10) | (0 if final else 0x20)
                    f.check(0x1F80, expected, 0x30)
                f.out(0x1F80, 0xBB)
                f.out(0x1F80, 0x7E)
                f.out(0x1F80, 0xA7)
                a_end, b_end = (0x9004, 0x9103) if direction else (0x9103, 0x9004)
                for value in (3, 0, a_end & 255, a_end >> 8, b_end & 255, b_end >> 8):
                    f.check(0x1F80, value)
                for i, value in enumerate(payload):
                    f.p.compare_memory(0x9100 + i, value)
                f.p.compare_memory(0x90FF, 0xBE)
                f.p.compare_memory(0x9104, 0xEF)
                f.out(0x1F80, 0x83)
                f.out(0x1F80, 0x8B)
                f.out(0x1F80, 0xBF)
                f.check(0x1F80, 0x30, 0x30)
                stem = f"compare-{int(direction)}-{mode}-{int(positive)}"
                rom = root / f"{stem}.rom"
                rom.write_bytes(f.finish())
                result = subprocess.run([exe, "--rom", str(rom), "--cycles", "8000000",
                                         "--peek", "0xf000", "--dump", str(root / stem)],
                                        capture_output=True, text=True, timeout=300)
                assert result.returncode == 0, (stem, result.stderr)
                report = json.loads(result.stdout.splitlines()[-1])
                assert report["turbo_dma"] and report["halted"] and report["peek"].startswith(b"DMA!".hex()), (stem, report)
                assert report["dma_reads"] == report["dma_writes"] == 4 and report["dma_grants"] == pairs, (stem, report)
                ram = (root / f"{stem}.ram").read_bytes()
                assert ram[0x9100:0x9104] == payload and ram[0x90FF] == 0xBE and ram[0x9104] == 0xEF
                print(f"PASS shared-CPU transfer/search source_A={direction} mode={mode} "
                      f"matched={positive}: payload/guards/status/counters/8B, grants={pairs}", flush=True)
