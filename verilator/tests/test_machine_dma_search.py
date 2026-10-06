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
nonbyte = "--nonbyte" in sys.argv[2:]
short = "--short" in sys.argv[2:]
zero = "--zero" in sys.argv[2:]
pipeline = "--stop-pipeline" in sys.argv[2:]
assert not (short and zero) and (not (short or zero) or nonbyte)
assert not pipeline or (nonbyte and not short and not zero)
profiles = [(1, pipeline), (2, pipeline)] if nonbyte else [(0, False), (0, True)]
with tempfile.TemporaryDirectory(prefix="x1-machine-dma-search-") as directory:
    root = pathlib.Path(directory)
    for direction in (False, True):
        for ownership, stop_match in profiles:
            for position in ([0] if zero else [0, 4] if short else range(5)):
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
                              a & 255, a >> 8, 0 if zero else 1 if short else 4 if ownership == 1 else 3,
                              0, 0x14, 0x10,
                              0x9C if stop_match else 0x98, 0xFF if zero else 0xF0, 0xA5,
                              0x8D | ownership << 5, b & 255, b >> 8,
                              0xB2 if pipeline and position < 4 else 0x92,
                              0x02 if direction else 0x06, 0xCF,
                              0x06 if direction else 0x02, 0xCF):
                    f.out(0x1F80, value)
                operations = position + 1 if stop_match and position < 4 else 4
                if pipeline and position < 4:
                    operations = position + 2
                if short:
                    operations = 1 if ownership == 1 else 2
                if zero:
                    operations = 65536 if ownership == 1 else 65537
                grants = operations if ownership == 0 else 1
                for pair in range(grants):
                    f.out(0x1F80, 0xB3)
                    # Exercise genuine WR3 immediate-enable as well as WR6
                    # ENABLE on the new stop pipeline; original profiles unchanged.
                    f.out(0x1F80, 0xC4 if pipeline and position % 2 == 0 else 0x87)
                    f.out(0x1F80, 0xBF)
                    matched = zero or position < min(4, operations) and (ownership != 0 or pair >= position)
                    terminal = (short or zero or operations >= 4) if ownership != 0 else pair == 3
                    f.check(0x1F80, (0 if matched else 0x10) |
                            (0 if terminal else 0x20), 0x30)
                f.out(0x1F80, 0xBB)
                f.out(0x1F80, 0x7E)
                f.out(0x1F80, 0xA7)
                count = (operations & 65535) if ownership != 0 else operations if stop_match and position < 4 else 3
                src = (0x9000 + operations) & 65535
                a_end, b_end = (src, 0x9100) if direction else (0x9100, src)
                for value in (count, 0, a_end & 255, a_end >> 8, b_end & 255, b_end >> 8):
                    f.check(0x1F80, value)
                for i, value in enumerate(payload):
                    f.p.compare_memory(0x9000 + i, value)
                    f.p.compare_memory(0x9100 + i, 0xEE)
                f.out(0x1F80, 0x8B)
                f.out(0x1F80, 0xBF)
                f.check(0x1F80, 0x30, 0x30)
                stem = f"pure-search-{ownership}-{int(direction)}-{int(stop_match)}-{position}-short{int(short)}-zero{int(zero)}"
                rom = root / f"{stem}.rom"
                rom.write_bytes(f.finish())
                result = subprocess.run([exe, "--rom", str(rom), "--cycles", "8000000",
                                         "--peek", "0xf000", "--dump", str(root / stem)],
                                        capture_output=True, text=True, timeout=300)
                assert result.returncode == 0, (stem, result.stderr)
                report = json.loads(result.stdout.splitlines()[-1])
                assert report["turbo_dma"] and report["halted"] and report["peek"].startswith(b"DMA!".hex()), (stem, report)
                assert report["dma_reads"] == operations and report["dma_grants"] == grants and report["dma_writes"] == 0, (stem, report)
                ram = (root / f"{stem}.ram").read_bytes()
                assert ram[0x9000:0x9004] == payload and ram[0x9100:0x9104] == bytes([0xEE] * 4)
                print(f"PASS shared-CPU pure search mode={ownership} source_A={direction} stop={stop_match} "
                      f"match_position={position}: {operations} reads, no writes, "
                      "source/destination/count/status/readback/8B", flush=True)
