"""Actual shared CPU saves after auto-reload and buffer writes, before next pair.

Generated diagnostic IPL only; no forced state, private assets or patched snapshots.
"""
import argparse
import hashlib
import json
import pathlib
import subprocess
import tempfile
from test_machine_dma import Fixture


def run(exe, args):
    result = subprocess.run([str(exe), *map(str, args)], capture_output=True, text=True, timeout=300)
    assert result.returncode == 0, result.stderr
    return json.loads(result.stdout.splitlines()[-1])


def diagnostic(a_source):
    f = Fixture()
    old, new = bytes((0x31+i*13)&255 for i in range(4)), bytes((0xa7+i*7)&255 for i in range(4))
    f.p.store(0xf000, 0)
    f.p.store(0xf010, 0)
    for base, payload in ((0x9000, old), (0x9200, new)):
        for i, byte in enumerate(payload):
            f.p.store(base+i, byte)
    for base in (0x9100, 0x9300):
        for i in range(6):
            f.p.store(base+i, 0xee)
    a, b = (0x9000, 0x9100) if a_source else (0x9100, 0x9000)
    operation = 0x7d if a_source else 0x79
    for value in (0xc3, operation, a&255, a>>8, 3, 0, 0x14, 0x10, 0x8d, b&255, b>>8, 0xb2, 0xcf):
        f.out(0x1f80, value)
    for block in range(3):
        if block == 1:
            # Previous EOB already reloaded OLD counters. New buffer values
            # become live only at the next automatic boundary, without LOAD.
            new_a, new_b = (0x9200, 0x9300) if a_source else (0x9300, 0x9200)
            for value in (0x1d if a_source else 0x19, new_a&255, new_a>>8,
                          0x8d, new_b&255, new_b>>8, 0xbb, 0x7e, 0xa7):
                f.out(0x1f80, value)
            for value in (0, 0, a&255, a>>8, b&255, b>>8):
                f.check(0x1f80, value)
            f.p.store(0xf010, 1)
            f.p.word(0x11, 10000)
            f.p.label("reload_delay")
            f.p.emit(0x1b, 0x7a, 0xb3)
            f.p.jump(0xc2, "reload_delay")
            f.p.store(0xf010, 2)
        for _ in range(4):
            f.out(0x1f80, 0xb3)
            f.out(0x1f80, 0x87)
            f.out(0x1f80, 0xbf)
            f.check(0x1f80, 0x20, 0x20)  # auto-restart keeps EOB clear
        for i, byte in enumerate(old):
            f.p.compare_memory(0x9100+i, byte)
        for i in range(6):
            f.p.compare_memory(0x9300+i, new[i] if block==2 and i<4 else 0xee)
        for i in range(4,6):
            f.p.compare_memory(0x9100+i, 0xee)
    f.out(0x1f80, 0x83)
    return f.finish(), old, new


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=pathlib.Path)
    args = parser.parse_args()
    exe = args.executable.resolve()
    digest = hashlib.sha256(exe.read_bytes()).hexdigest()
    print(f"runner_sha256={digest}", flush=True)
    with tempfile.TemporaryDirectory(prefix="x1-reload-state-") as folder:
        root = pathlib.Path(folder)
        for a_source in (False, True):
            code, old, new = diagnostic(a_source)
            rom, state = root/"diag.rom", root/"native.state"
            rom.write_bytes(code)
            saved = root/"saved"
            before = run(exe, ["--rom", rom, "--cycles", 200000, "--save-state", state, "--dump", saved])
            ram = saved.with_suffix(".ram").read_bytes()
            assert ram[0xf010]==1 and ram[0xf000]==0 and not before["halted"], before
            assert (before["dma_reads"], before["dma_writes"], before["dma_grants"]) == (4,4,4), before
            values = dict(line.split("=") for line in saved.with_suffix(".dma").read_text().splitlines())
            values = {k:int(v,16) for k,v in values.items()}
            expected = dict(start_a=0x9200 if a_source else 0x9300, start_b=0x9300 if a_source else 0x9200,
                            counter_a=0x9000 if a_source else 0x9100, counter_b=0x9100 if a_source else 0x9000,
                            reload_destination=1)
            assert values==expected, (values,expected)
            state_hash = hashlib.sha256(state.read_bytes()).hexdigest()
            resumed, straight = root/"resumed", root/"straight"
            after = run(exe, ["--restore-state", state, "--cycles", 7800000, "--dump", resumed, "--peek", "0xf000"])
            direct = run(exe, ["--rom", rom, "--cycles", 8000000, "--dump", straight, "--peek", "0xf000"])
            ignored = {"download_bytes", "video_hash"}
            assert {k:v for k,v in after.items() if k not in ignored} == {k:v for k,v in direct.items() if k not in ignored}
            assert after["halted"] and after["peek"].startswith(b"DMA!".hex()), after
            assert (after["dma_reads"], after["dma_writes"], after["dma_grants"]) == (12,12,12), after
            for suffix in ("ram", "text", "attr", "subram", "cpu", "dma"):
                assert resumed.with_suffix("."+suffix).read_bytes()==straight.with_suffix("."+suffix).read_bytes(), suffix
            final = resumed.with_suffix(".ram").read_bytes()
            assert final[0x9100:0x9106]==old+b"\xee\xee" and final[0x9300:0x9306]==new+b"\xee\xee"
            assert hashlib.sha256(state.read_bytes()).hexdigest()==state_hash
            assert hashlib.sha256(exe.read_bytes()).hexdigest()==digest
            print(f"PASS reload snapshot A_source={a_source}: flag=1, new buffers/old counters, 3 CPU blocks, exact continuation", flush=True)


if __name__ == "__main__":
    main()
