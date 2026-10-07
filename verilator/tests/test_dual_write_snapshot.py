"""Original A/B write/readback checkpoint, disposable exports and protection."""
import pathlib
import argparse
import subprocess
import sys
import tempfile
from test_dual_snapshot import media
from test_machine_dma import Fixture
from test_machine_dma_irq_snapshot import run


def diagnostic(first_drive=0):
    f = Fixture()
    def delay(label):
        f.p.word(0x11, 16000)
        f.p.label(label)
        f.p.emit(0x1B, 0x7A, 0xB3)
        f.p.jump(0xC2, label)
    delay("mount")
    stages = [(0, 59, 0x9000, 0xB000), (1, 167, 0xA000, 0xB400)]
    if first_drive:
        stages.reverse()
    for stage, (drive, seed, source, destination) in enumerate(stages):
        payload = media(seed)[1]
        for i, byte in enumerate(payload):
            f.p.store(source+i, byte)
        f.out(0x0FFC, 0x80 | drive)
        f.poll(0x0FF8, 0x80, 0)
        f.configure_write(source, 0x0FFB, 1024)
        f.out(0x0FFA, 1)
        f.out(0x0FF8, 0xA0)
        f.out(0x1F80, 0x87)
        f.poll(0x0FF8, 1, 0)
        f.check(0x0FF8, 0, 0xDC)  # Includes write protection/fault.
        f.check(0x1F80, 0, 0x20)
        f.configure(0x0FFB, destination, 1024, disk=True)
        f.out(0x0FF8, 0x80)
        f.out(0x1F80, 0x87)
        f.poll(0x0FF8, 1, 0)
        f.check(0x0FF8, 0, 0x9C)
        for i, byte in enumerate(payload):
            f.p.compare_memory(destination+i, byte)
        if stage == 0:
            f.p.store(0xF020, 0xA5)
            delay("between")
    code = f.finish()
    assert len(code) < 32768
    return code


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable",type=pathlib.Path)
    parser.add_argument("--first-drive",type=int,choices=(0,1),default=0)
    args = parser.parse_args()
    exe = str(args.executable.resolve())
    with tempfile.TemporaryDirectory(prefix="x1-dual-write-state-") as temp:
        root = pathlib.Path(temp)
        rom, a, b = root/"original.rom", root/"a.d88", root/"b.d88"
        rom.write_bytes(diagnostic(args.first_drive))
        original_a, original_b = media(29)[0], media(103)[0]
        a.write_bytes(original_a); b.write_bytes(original_b)
        exported_a, exported_b = root/"checkpoint-a.d88", root/"checkpoint-b.d88"
        state, saved = root/"dual.state", root/"saved"
        checkpoint = 5600000
        before = run(exe,["--rom",rom,"--disk",a,"--disk-b",b,"--disk-output",exported_a,
            "--disk-b-output",exported_b,"--cycles",checkpoint,"--save-state",state,"--dump",saved])
        assert not before["halted"] and before["dma_reads"] == before["dma_writes"] == 2048, before
        assert saved.with_suffix(".ram").read_bytes()[0xF020] == 0xA5 and before["disk_writes"] > 0
        expected_a = bytearray(original_a)
        expected_a[704:] = media(59)[1]
        expected_b = bytearray(original_b)
        expected_b[704:] = media(167)[1]
        checkpoint_a = expected_a if args.first_drive == 0 else original_a
        checkpoint_b = expected_b if args.first_drive == 1 else original_b
        assert exported_a.read_bytes() == checkpoint_a and exported_b.read_bytes() == checkpoint_b
        # The first committed drive's original is now stale, even though the
        # RTL layout is unchanged. This covers the extra B-header field too.
        result = subprocess.run([exe,"--restore-state",str(state),"--disk",str(a),"--disk-b",str(b),
                                 "--cycles","20000"],capture_output=True,text=True,timeout=30)
        assert result.returncode == 2 and "fingerprint" in result.stderr, result
        resumed, direct = root/"resumed", root/"direct"
        final_a, final_b = root/"resumed-a.d88", root/"resumed-b.d88"
        direct_a, direct_b = root/"direct-a.d88", root/"direct-b.d88"
        after = run(exe,["--restore-state",state,"--disk",exported_a,"--disk-b",exported_b,
            "--disk-output",final_a,"--disk-b-output",final_b,
            "--cycles",16000000-checkpoint,"--dump",resumed])
        straight = run(exe,["--rom",rom,"--disk",a,"--disk-b",b,"--disk-output",direct_a,
            "--disk-b-output",direct_b,"--cycles",16000000,"--dump",direct])
        host = {"download_bytes","video_hash","hs_edges","vs_edges","disk_requests","disk_writes"}
        assert {k:v for k,v in after.items() if k not in host} == \
            {k:v for k,v in straight.items() if k not in host}, (after,straight)
        for field in ("hs_edges","vs_edges","disk_requests","disk_writes"):
            assert before[field]+after[field] == straight[field], field
        assert after["halted"] and after["peek"].startswith(b"DMA!".hex()), after
        assert all(after[k] == 4096 for k in ("dma_reads","dma_writes","dma_grants")), after
        assert after["disk_writes"] > 0 and after["cpu_fdc_data_reads"] == after["cpu_fdc_data_writes"] == 0
        for suffix in ("ram","text","attr","subram","cpu"):
            assert resumed.with_suffix("."+suffix).read_bytes() == direct.with_suffix("."+suffix).read_bytes(), suffix
        assert final_a.read_bytes() == direct_a.read_bytes() == expected_a
        assert final_b.read_bytes() == direct_b.read_bytes() == expected_b
        # Read-only restore must override BOTH saved writable pins. The CPU
        # intentionally takes its failure path on the second protected write.
        protected = run(exe,["--restore-state",state,"--disk",exported_a,"--disk-b",exported_b,
            "--cycles",16000000-checkpoint])
        assert protected["halted"] and protected["peek"].startswith("ee"), protected
        assert protected["disk_writes"] == 0
        assert a.read_bytes() == original_a and b.read_bytes() == original_b
        assert exported_a.read_bytes() == checkpoint_a and exported_b.read_bytes() == checkpoint_b
    print(f"PASS dual writable snapshot: first drive={args.first_drive}, exact media/dumps/counts, stale-media rejection, both-role protection override, unchanged originals")


if __name__ == "__main__":
    main()
