"""Original CPU A/B DMA reads across a quiescent dual-media checkpoint."""
import pathlib
import struct
import subprocess
import sys
import tempfile
from test_machine_dma import Fixture
from test_machine_dma_irq_snapshot import run


def media(seed):
    payload = bytes((seed + i * 37 + (i >> 8) * 13) & 255 for i in range(1024))
    image = bytearray(688)
    struct.pack_into("<I", image, 32, 688)
    header = bytearray(16)
    header[:4] = bytes((0, 0, 1, 3))
    struct.pack_into("<H", header, 4, 1)
    struct.pack_into("<H", header, 14, 1024)
    image.extend(header + payload)
    struct.pack_into("<I", image, 28, len(image))
    return bytes(image), payload


def diagnostic():
    f = Fixture()
    def delay(label):
        f.p.word(0x11, 16000)
        f.p.label(label)
        f.p.emit(0x1B, 0x7A, 0xB3)
        f.p.jump(0xC2, label)
    delay("mount")
    for drive, seed, destination in ((0, 29, 0x8000), (1, 103, 0x9000)):
        f.out(0x0FFC, 0x80 | drive)
        f.poll(0x0FF8, 0x80, 0)
        f.configure(0x0FFB, destination, 1024, disk=True)
        f.out(0x1F80, 0x87)
        f.out(0x0FFA, 1)
        f.out(0x0FF8, 0x80)
        f.poll(0x0FF8, 1, 0)
        f.check(0x0FF8, 0, 0x9C)
        for i, byte in enumerate(media(seed)[1]):
            f.p.compare_memory(destination+i, byte)
        if drive == 0:
            f.p.store(0xF020, 0xA5)
            delay("between")
    return f.finish()


def main():
    exe = str(pathlib.Path(sys.argv[1]).resolve())
    with tempfile.TemporaryDirectory(prefix="x1-dual-state-") as temp:
        root = pathlib.Path(temp)
        rom, a, b = root/"original.rom", root/"a.d88", root/"b.d88"
        rom.write_bytes(diagnostic())
        image_a, payload_a = media(29)
        image_b, payload_b = media(103)
        a.write_bytes(image_a); b.write_bytes(image_b)
        assets = ["--disk", a, "--disk-b", b]
        state, saved = root/"dual.state", root/"saved"
        checkpoint = 5600000
        before = run(exe, ["--rom", rom, *assets, "--cycles", checkpoint,
                           "--save-state", state, "--dump", saved])
        assert not before["halted"] and before["dma_reads"] == before["dma_writes"] == 1024, before
        assert saved.with_suffix(".ram").read_bytes()[0xF020] == 0xA5
        resumed, direct = root/"resumed", root/"direct"
        after = run(exe, ["--restore-state", state, *assets,
                          "--cycles", 16000000-checkpoint, "--dump", resumed])
        straight = run(exe, ["--rom", rom, *assets, "--cycles", 16000000, "--dump", direct])
        host = {"download_bytes", "video_hash", "hs_edges", "vs_edges", "disk_requests", "disk_writes"}
        assert {k:v for k,v in after.items() if k not in host} == \
            {k:v for k,v in straight.items() if k not in host}, (after,straight)
        for field in ("hs_edges", "vs_edges", "disk_requests", "disk_writes"):
            assert before[field]+after[field] == straight[field], field
        assert after["halted"] and after["peek"].startswith(b"DMA!".hex()), after
        assert all(after[k] == 2048 for k in ("dma_reads", "dma_writes", "dma_grants")), after
        for suffix in ("ram", "text", "attr", "subram", "cpu"):
            assert resumed.with_suffix("."+suffix).read_bytes() == direct.with_suffix("."+suffix).read_bytes(), suffix
        ram = resumed.with_suffix(".ram").read_bytes()
        assert ram[0x8000:0x8400] == payload_a and ram[0x9000:0x9400] == payload_b
        wrong = root/"wrong.d88"
        wrong.write_bytes(media(104)[0])
        for options in (["--disk", a], ["--disk-b", b], ["--disk", b, "--disk-b", a],
                        ["--disk", wrong, "--disk-b", b], ["--disk", a, "--disk-b", wrong]):
            result = subprocess.run([exe,"--restore-state",str(state),*map(str,options),"--cycles","20000"],
                                    capture_output=True,text=True,timeout=30)
            assert result.returncode == 2 and "fingerprint" in result.stderr, result
        single = root/"single.state"
        run(exe,["--disk",a,"--cycles",200000,"--save-state",single])
        result = subprocess.run([exe,"--restore-state",str(single),*map(str,assets),"--cycles","20000"],
                                capture_output=True,text=True,timeout=30)
        assert result.returncode == 2 and "snapshot version" in result.stderr, result
        truncated = root/"truncated.state"
        truncated.write_bytes(state.read_bytes()[:48])
        result = subprocess.run([exe,"--restore-state",str(truncated),*map(str,assets),"--cycles","20000"],
                                capture_output=True,text=True,timeout=30)
        assert result.returncode == 2 and "fingerprint missing" in result.stderr, result
        assert a.read_bytes() == image_a and b.read_bytes() == image_b and after["disk_writes"] == 0
    print("PASS dual snapshot: real A then B CPU/DMA reads, exact continuation/dumps/counts, ordered fingerprints, missing/wrong/swapped media and single/dual rejection")


if __name__ == "__main__":
    main()
