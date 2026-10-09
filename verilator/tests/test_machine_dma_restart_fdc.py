"""Original shared CPU/FDC/DMA sector-boundary restart interrupt checks.

Each IRQ follows an entire READ SECTOR. The real handler issues the next
command only after its checks; no artificial pause of the FDC/DRQ or Ready.
"""
import argparse
import hashlib
import json
import pathlib
import subprocess
import tempfile
from test_machine_dma import Fixture, media


def diagnostic(drive, a_source, mode, payload):
    f = Fixture()
    p = f.p
    for address in (0xf000, 0xf010):
        p.store(address, 0)
    for base in (0x9100, 0x9300):
        for i in range(258):
            p.store(base+i, 0xee)
    p.store(0x80d0, 0)
    p.store(0x80d1, 0x40)  # handler in unchanged IPL aperture at 4000
    p.emit(0x3e, 0x80, 0xed, 0x47, 0xed, 0x5e)
    p.word(0x11, 16000)
    p.label("mount")
    p.emit(0x1b, 0x7a, 0xb3)
    p.jump(0xc2, "mount")
    f.out(0x0ffc, 0x80|drive)
    f.poll(0x0ff8, 0x80, 0)
    a, b = (0x0ffb, 0x9100) if a_source else (0x9100, 0x0ffb)
    for value in (0xc3, 0x7d if a_source else 0x79, a&255, a>>8, 255, 0,
                  0x2c if a_source else 0x14, 0x10 if a_source else 0x28,
                  0x80, 0x9d|(mode<<5), b&255, b>>8, 0x12, 0xd0, 0xb2, 0xcf, 0xab):
        f.out(0x1f80, value)
    f.out(0x0ffa, 1)
    f.out(0x0ff8, 0x80)
    f.out(0x1f80, 0x87)
    p.emit(0xfb)
    p.label("main_wait")
    p.emit(0x76, 0xf3)
    p.word(0x3a, 0xf010)
    p.emit(0xfe, 3)
    p.jump(0xca, "complete")
    p.emit(0xfb)
    p.jump(0xc3, "main_wait")
    p.label("complete")
    for base in (0x9100, 0x9300):
        for i, byte in enumerate(payload):
            p.compare_memory(base+i, byte)
        for i in (256, 257):
            p.compare_memory(base+i, 0xee)
    for i, byte in enumerate(b"FDC!"):
        p.store(0xf000+i, byte)
    p.emit(0x76)
    p.label("fail")
    p.store(0xf000, 0xee)
    p.emit(0xf3, 0x76)
    assert len(p.code) < 0x4000
    p.code.extend(bytes(0x4000-len(p.code)))
    p.emit(0xf5, 0xc5)
    f.out(0x1f80, 0xbf)
    f.check(0x1f80, 0x38, 0x38)
    f.check(0x0ff8, 0, 0x9d)  # no BUSY/not-ready/RNF/CRC/lost-data
    p.word(0x3a, 0xf010)
    p.emit(0x3c)
    p.word(0x32, 0xf010)
    p.emit(0xfe, 1)
    p.jump(0xc2, "after_update")
    na, nb = (0x0ffb, 0x9300) if a_source else (0x9300, 0x0ffb)
    for value in (0x1d if a_source else 0x19, na&255, na>>8,
                  0x8d|(mode<<5), nb&255, nb>>8, 0xbb, 0x7e, 0xa7):
        f.out(0x1f80, value)
    for value in (0, 0, a&255, a>>8, b&255, b>>8):
        f.check(0x1f80, value)
    p.label("after_update")
    p.word(0x3a, 0xf010)
    p.emit(0xfe, 2)
    p.jump(0xc2, "choose_resume")
    for i in range(258):
        p.compare_memory(0x9300+i, 0xee)
    p.label("choose_resume")
    p.word(0x3a, 0xf010)
    p.emit(0xfe, 3)
    p.jump(0xca, "stop")
    f.out(0x0ffa, 1)
    f.out(0x0ff8, 0x80)
    f.out(0x1f80, 0x87)
    p.jump(0xc3, "return")
    p.label("stop")
    f.out(0x1f80, 0x83)
    p.label("return")
    p.emit(0xc1, 0xf1, 0xfb, 0xed, 0x4d)
    assert len(p.code) <= 32768
    return p.finish()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=pathlib.Path)
    parser.add_argument("--sys-hz", type=int, default=32000000)
    args = parser.parse_args()
    exe = args.executable.resolve()
    digest = hashlib.sha256(exe.read_bytes()).hexdigest()
    print("runner_sha256="+digest, flush=True)
    with tempfile.TemporaryDirectory(prefix="x1-restart-fdc-") as temporary:
        root = pathlib.Path(temporary)
        disks, payloads = [], []
        for seed in (0x21, 0x93):
            image, payload = media(seed)
            disk = root/f"{seed}.d88"
            disk.write_bytes(image)
            disks.append(disk)
            payloads.append(payload)
        hashes = [hashlib.sha256(path.read_bytes()).hexdigest() for path in disks]
        print(json.dumps({"disk_a_sha256": hashes[0], "disk_b_sha256": hashes[1]}), flush=True)
        for drive in (0, 1):
            for mode in (0, 1, 2):
                for a_source in (False, True):
                    rom, dump = root/"diag.rom", root/"result"
                    rom.write_bytes(diagnostic(drive, a_source, mode, payloads[drive]))
                    print(json.dumps({"drive": drive, "mode": mode, "a_source": a_source,
                                      "sys_hz": args.sys_hz, "reference_cycles": 8000000,
                                      "ipl_sha256": hashlib.sha256(rom.read_bytes()).hexdigest()}), flush=True)
                    result = subprocess.run([str(exe), "--rom", str(rom), "--cycles", "8000000",
                                             "--disk", str(disks[0]), "--disk-b", str(disks[1]),
                                             "--dump", str(dump)], capture_output=True, text=True, timeout=300)
                    assert result.returncode == 0, result.stderr
                    report = json.loads(result.stdout.splitlines()[-1])
                    assert report["sys_hz"] == args.sys_hz, report
                    assert report["peek"].startswith(b"FDC!".hex()) and report["halted"], report
                    assert report["dma_reads"] == report["dma_writes"] == 768, report
                    assert report["dma_grants"] == (3 if mode==1 else 768), report
                    assert report["disk_requests"] > 0 and report["disk_writes"] == 0, report
                    assert report["cpu_fdc_data_reads"] == 0 and report["cpu_fdc_data_writes"] == 0, report
                    ram = dump.with_suffix(".ram").read_bytes()
                    assert ram[0xf010] == 3
                    for base in (0x9100, 0x9300):
                        assert ram[base:base+258] == payloads[drive]+b"\xee\xee"
                    assert [hashlib.sha256(path.read_bytes()).hexdigest() for path in disks] == hashes
                    assert hashlib.sha256(exe.read_bytes()).hexdigest() == digest
                    print(f"PASS FDC restart drive={drive} mode={mode} A_source={a_source}: "
                          "3 sector IRQ/RETI blocks, real DRQ, 768 pairs, buffered guards/unchanged disks", flush=True)


if __name__ == "__main__":
    main()
