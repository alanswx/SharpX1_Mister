"""Original real shared-CPU DMA-over-CTC and queued lower CTC service test.

No forced triggers/IRQ/IEI/grants: native CTC timers and DMA command streams.
Channel 1 must stay pending throughout channel 0's interrupted handler, then
run only after that handler's RETI. CPU phase checks detect broadcast RETI.
"""
import json
import pathlib
import subprocess
import sys
import tempfile
from test_machine_dma import Fixture


def fixture():
    f = Fixture()
    p = f.p
    payload = bytes((0x31, 0xA5, 0x7D, 0xC3))
    for i, value in enumerate(payload):
        p.store(0x9000 + i, value)
        p.store(0x9100 + i, 0xCC)
    p.store(0x9104, 0xCC)
    for addr in range(0xF020, 0xF024):
        p.store(addr, 0)
    for vector, handler in ((0xA0, 0x1000), (0xA2, 0x1400), (0xC4, 0x1800)):
        p.store(0x8000 + vector, handler & 255)
        p.store(0x8001 + vector, handler >> 8)
    p.emit(0x3E, 0x80, 0xED, 0x47, 0xED, 0x5E)
    f.out(0x1FA0, 0xA0)
    f.out(0x1FA0, 0x87)
    f.out(0x1FA0, 8)
    p.emit(0xFB, 0x76)  # real CTC0 timer wakes HALT
    p.label("wait_channel1")
    p.word(0x3A, 0xF022)
    p.emit(0xFE, 1)
    p.jump(0xC2, "wait_channel1")
    p.emit(0xF3)
    for address, value in ((0xF020, 3), (0xF021, 1), (0xF022, 1), (0xF023, 1)):
        p.compare_memory(address, value)
    for i, value in enumerate(payload):
        p.compare_memory(0x9000 + i, value)
        p.compare_memory(0x9100 + i, value)
    p.compare_memory(0x9104, 0xCC)
    for i, value in enumerate(b"NEST"):
        p.store(0xF000 + i, value)
    p.label("done")
    p.emit(0x76)
    p.jump(0xC3, "done")
    p.label("fail")
    p.store(0xF000, 0xEE)
    p.emit(0xF3, 0x76)
    p.jump(0xC3, "fail")
    assert len(p.code) < 0x1000
    p.code.extend(bytes(0x1000 - len(p.code)))
    # CTC0: retain IUS while disabling its timer/pending request, queue CTC1.
    p.emit(0xF5, 0xC5, 0xD5)
    p.compare_memory(0xF020, 0)
    p.store(0xF020, 1)
    p.store(0xF021, 1)
    f.out(0x1FA0, 3)
    f.out(0x1FA1, 0x87)
    f.out(0x1FA1, 1)
    for value in (0xC3, 0x7D, 0, 0x90, 3, 0, 0x14, 0x10, 0xA0,
                  0xBD, 0, 0x91, 0x32, 0xC0, 0x8A, 0xCF, 0x87):
        f.out(0x1F80, value)
    p.emit(0xFB, 0x76)  # keep EI set: only retained CTC IUS may block CTC1
    p.compare_memory(0xF023, 1)
    p.compare_memory(0xF020, 2)
    # Plenty of genuine instruction time for CTC1 to become pending again.
    p.word(0x11, 1000)
    p.label("hold_ctc_service")
    p.emit(0x1B, 0x7A, 0xB3)
    p.jump(0xC2, "hold_ctc_service")
    p.compare_memory(0xF022, 0)
    p.store(0xF020, 3)
    p.emit(0xD1, 0xC1, 0xF1, 0xFB, 0xED, 0x4D)
    assert len(p.code) < 0x1400
    p.code.extend(bytes(0x1400 - len(p.code)))
    # CTC1 can execute only after CTC0 RETI releases the downstream chain.
    p.emit(0xF5, 0xC5)
    p.compare_memory(0xF020, 3)
    p.compare_memory(0xF022, 0)
    f.out(0x1FA1, 3)
    p.store(0xF022, 1)
    p.emit(0xC1, 0xF1, 0xFB, 0xED, 0x4D)
    assert len(p.code) < 0x1800
    p.code.extend(bytes(0x1800 - len(p.code)))
    # DMA's return must not release the interrupted CTC0 IUS.
    p.emit(0xF5, 0xC5)
    p.compare_memory(0xF020, 1)
    p.compare_memory(0xF023, 0)
    f.out(0x1F80, 0xAF)
    f.out(0x1F80, 0xBF)
    f.check(0x1F80, 0x18, 0x38)
    f.out(0x1F80, 0x8B)
    p.store(0xF020, 2)
    p.store(0xF023, 1)
    p.emit(0xC1, 0xF1, 0xFB, 0xED, 0x4D)
    return p.finish(), payload


def main():
    exe = str(pathlib.Path(sys.argv[1]).resolve())
    with tempfile.TemporaryDirectory(prefix="x1-dma-ctc-nested-") as directory:
        root = pathlib.Path(directory)
        code, payload = fixture()
        rom = root / "nested.rom"
        rom.write_bytes(code)
        reports, images = [], []
        for repeat in range(2):
            stem = root / f"repeat-{repeat}"
            result = subprocess.run([exe, "--rom", str(rom), "--cycles", "8000000",
                                     "--peek", "0xf000", "--dump", str(stem)],
                                    capture_output=True, text=True, timeout=300)
            assert result.returncode == 0, result.stderr
            report = json.loads(result.stdout.splitlines()[-1])
            ram = stem.with_suffix(".ram").read_bytes()
            assert report["turbo_dma_irq"] and report["halted"] and report["peek"].startswith(b"NEST".hex()), \
                (report, ram[0xF020:0xF024].hex())
            assert (report["dma_reads"], report["dma_writes"], report["dma_grants"]) == (4, 4, 1), report
            assert ram[0xF020:0xF024] == bytes((3, 1, 1, 1))
            assert ram[0x9000:0x9004] == payload and ram[0x9100:0x9104] == payload
            reports.append(report)
            images.append(tuple(stem.with_suffix(f".{suffix}").read_bytes()
                                for suffix in ("ram", "text", "attr", "subram", "cpu")))
        assert reports[0] == reports[1] and images[0] == images[1], "native nested run not deterministic"
        print("PASS real shared CPU: CTC0 HALT -> nested DMA IM2/HALT/RR0/AF/8B/RETI -> "
              "retained CTC0 service -> queued CTC1 after RETI; exact transfers/guards/cold repeat", flush=True)


if __name__ == "__main__":
    main()
