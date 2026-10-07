"""Executing X3/DMA/FDC snapshot continuity; original media and CPU program."""
import pathlib
import subprocess
import sys
import tempfile
from test_dma_native_read_stream import diagnostic
from test_machine_dma_irq_snapshot import run


def reject(exe, state, disk):
    # Supply the same media so rejection cannot be explained merely by a
    # missing disk fingerprint instead of the incompatible clock profile.
    result = subprocess.run([exe, "--restore-state", str(state), "--disk", str(disk),
                             "--cycles", "20000"], capture_output=True, text=True, timeout=30)
    assert result.returncode == 2 and "snapshot version" in result.stderr, result


def main():
    x3, ordinary = (str(pathlib.Path(p).resolve()) for p in sys.argv[1:3])
    with tempfile.TemporaryDirectory(prefix="x1-x3-dma-state-") as temp:
        root = pathlib.Path(temp)
        code, image, payload = diagnostic()
        rom, disk = root / "original.rom", root / "original.d88"
        rom.write_bytes(code)
        disk.write_bytes(image)
        state, old = root / "x3.state", root / "ordinary.state"
        checkpoint = 3200000
        before = run(x3, ["--rom", rom, "--disk", disk, "--cycles", checkpoint,
                          "--save-state", state])
        assert before["turbo_dma"] and before["turbo_video_master"] and not before["halted"], before
        assert 0 < before["dma_writes"] <= before["dma_reads"] < 1024, before
        reject(ordinary, state, disk)
        run(ordinary, ["--disk", disk, "--cycles", 20000, "--save-state", old])
        reject(x3, old, disk)
        resumed, straight = root / "resumed", root / "direct"
        after = run(x3, ["--restore-state", state, "--disk", disk,
                         "--cycles", 16000000-checkpoint, "--dump", resumed])
        direct = run(x3, ["--rom", rom, "--disk", disk, "--cycles", 16000000, "--dump", straight])
        host = {"download_bytes", "video_hash", "hs_edges", "vs_edges",
                "disk_requests", "disk_writes"}
        assert {k: v for k, v in after.items() if k not in host} == \
            {k: v for k, v in direct.items() if k not in host}, (after, direct)
        assert after["halted"] and after["peek"].startswith(b"DMA!".hex()), after
        assert all(after[k] == 1024 for k in ("dma_reads", "dma_writes", "dma_grants")), after
        # SD request/write counters are host invocation accumulators, not
        # serialized chip state: require their exact additive totals too.
        for field in ("hs_edges", "vs_edges", "disk_requests", "disk_writes"):
            assert before[field] + after[field] == direct[field]
        for suffix in ("ram", "text", "attr", "subram", "cpu"):
            assert resumed.with_suffix(f".{suffix}").read_bytes() == \
                straight.with_suffix(f".{suffix}").read_bytes(), suffix
        assert resumed.with_suffix(".ram").read_bytes()[0x8000:0x8400] == payload
        assert after["disk_writes"] == 0 and disk.read_bytes() == image
    print("PASS X3 DMA snapshot: partial real FDC transfer, exact resumed payload/count/report/dumps, bidirectional clock-profile rejection")


if __name__ == "__main__":
    main()
