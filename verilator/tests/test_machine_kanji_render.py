"""Original CPU-programmed Kanji raster; compare actual RGB, no native assets."""
import argparse
import csv
import hashlib
import json
import pathlib
import subprocess
import tempfile
from z80_fixture import Program


def pattern(address):
    return ((address * 37) ^ (address >> 4) ^ (address >> 12) ^ (address >> 16)) & 255


def fixture(high, columns=80, active_dma=False, loaded=True):
    p = Program()
    p.emit(0xF3)
    p.word(0x31, 0xFFFF)

    def out(port, value):
        p.word(0x01, port)
        p.emit(0x3E, value, 0xED, 0x79)

    out(0x1A03, 0x82)
    p.word(0x01, 0x1A02)
    p.emit(0xED, 0x78)
    out(0x1A02, 0x40 if columns == 40 else 0)
    p.emit(0xED, 0x78)
    for port in (0x2000, 0x3000, 0x3800):
        p.word(0x01, port)
        p.word(0x21, 2048)
        label = f"fill{port}"
        p.label(label)
        if port == 0x2000:
            # Reverse independently of the absent-level-2 selection below.
            p.emit(0x79, 0xE6, 0x40, 0x0F, 0x0F, 0x0F, 0xF6, 7)
        elif port == 0x3000:
            p.emit(0x79)
        else:
            # All banks, alternating halves; bit 5 selects absent level 2.
            p.emit(0x79, 0xE6, 0x10, 0x07, 0x07, 0xF6, 0x80, 0x57,
                   0x79, 0xE6, 0x20, 0x0F, 0xB2, 0x57,
                   0x79, 0xE6, 0x0F, 0xB2)
        p.emit(0xED, 0x79, 0x03, 0x2B, 0x7C, 0xB5)
        p.jump(0xC2, label)
    out(0x1FD0, int(high))
    registers = [55 if columns == 40 else 111, columns,
                 46 if columns == 40 else 92, 0x28, 27, 0, 25, 26, 0,
                 15 if high else 7, 0, 0, 0, 0, 0, 0]
    for index, value in enumerate(registers):
        out(0x1800, index)
        out(0x1801, value)
    for index, value in enumerate(b"KPIX"):
        p.store(0xF000 + index, value)
    if active_dma:
        # Selector entry zero is cell 2047, outside every displayed 25-row
        # 40/80-column frame. Changing it leaves the existing RGB oracle intact.
        out(0x27ff, 7);out(0x37ff, 0xa5);out(0x3fff, 0xcf)
        out(0x1fd0, int(high)|0x20)
        for value in (0xc3,0x7d,0,0x14,15,0,0x1c,0x10,0xad,0,0xd0,0x92):out(0x1f80,value)
        p.store(0xf010,0);p.store(0xf011,0)
        p.label('dma-loop')
        for value in (0xcf,0xb3,0x87):out(0x1f80,value)
        # Real CPU is held by BUSACK until completion; it then checks every
        # delivered byte, not just a diagnostic counter or the first payload.
        for row in range(16):p.compare_memory(0xd000+row,pattern(65536+15*4096+0xa5*16+row) if loaded else 0xff)
        p.word(0x21,0xf010);p.emit(0x34);p.jump(0xc2,'counted');p.emit(0x23,0x34);p.label('counted')
        p.jump(0xc3,'dma-loop')
        p.label('fail');p.store(0xf000,0xee);p.emit(0x76)
    else:p.emit(0x76)
    return p.finish()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("executable", type=pathlib.Path)
    parser.add_argument("--output", type=pathlib.Path,
                        help="preserve synthetic ROM/font, actual PPMs and reports in a new directory")
    parser.add_argument("--physical-rom", type=pathlib.Path,
                        help="optional authorized 131072-byte physical candidate, not an emulator export")
    parser.add_argument("--rtc-controller", type=pathlib.Path,
                        help="explicit packed 8192-byte controller for the separate RTC combination")
    parser.add_argument("--dma", action="store_true", help="require explicit combined DMA/Kanji/RTC profile")
    parser.add_argument("--active-dma", action="store_true", help="repeat real CG DMA with CPU payload checks throughout rendered frames")
    args = parser.parse_args()
    if args.dma and not args.rtc_controller:parser.error('--dma requires --rtc-controller')
    if args.active_dma and (not args.dma or args.physical_rom):parser.error('--active-dma requires --dma and the original synthetic font')
    controller = args.rtc_controller.resolve() if args.rtc_controller else None
    controller_hash = hashlib.sha256(controller.read_bytes()).hexdigest() if controller else None
    if controller:assert controller.stat().st_size == 8192
    executable = str(args.executable.resolve())
    with tempfile.TemporaryDirectory(prefix="x1-kanji-pixels-") as directory:
        root = args.output if args.output else pathlib.Path(directory)
        if args.output:
            root.mkdir(parents=True, exist_ok=False)
        font = root / "original.physical"
        if args.physical_rom:
            font = args.physical_rom.resolve()
            font_bytes = font.read_bytes()
            assert len(font_bytes) == 131072, "physical first-level ROM must be exactly 131072 bytes"
        else:
            font_bytes = bytes(pattern(address) for address in range(131072))
            font.write_bytes(font_bytes)
        font_hash = hashlib.sha256(font_bytes).hexdigest()
        print(json.dumps({"physical_rom_sha256": font_hash,
                          "private_candidate": bool(args.physical_rom)}), flush=True)
        cases = [(high, columns, loaded, False) for high in (False, True)
                 for columns in (40, 80) for loaded in (False, True)]
        cases += [(high, 80, True, True) for high in (False, True)]
        for high, columns, loaded, warm in cases:
            name = f"{'high' if high else 'standard'}-{columns}-{'loaded' if loaded else 'absent'}-{'warm' if warm else 'cold'}"
            rom, frame = root / f"{name}.rom", root / f"{name}.ppm"
            rom.write_bytes(fixture(high, columns,args.active_dma,loaded))
            command = [executable, "--rom", str(rom), "--cycles", "9600000", "--frame", str(frame)]
            if controller:
                command += ["--rtc-controller", str(controller)]
            if loaded:
                command += ["--kanji-physical", str(font)]
            if warm:
                command += ["--reset-at", "120", "--reset-for-us", "10"]
            if args.active_dma:
                command += ['--dump',str(root/name),'--bus-trace',str(root/f'{name}.csv'),
                            '--bus-events','--bus-start-ms','250']
            result = subprocess.run(command,
                                    capture_output=True, text=True, timeout=180)
            (root / f"{name}.stdout.log").write_text(result.stdout)
            (root / f"{name}.stderr.log").write_text(result.stderr)
            assert result.returncode == 0, result.stderr
            report = json.loads(result.stdout.splitlines()[-1])
            assert report["halted"]==(not args.active_dma) and report["peek"].startswith(b"KPIX".hex()), report
            if args.active_dma:
                memory=(root/f'{name}.ram').read_bytes()
                assert int.from_bytes(memory[0xf010:0xf012],'little')>=10,'real CPU did not repeatedly verify DMA payload'
                assert report['dma_grants']>=10 and report['dma_reads']>=160 and report['dma_writes']>=160,report
                assert 0<=report['dma_reads']-report['dma_writes']<=1,report
                expected_payload=bytes(pattern(65536+15*4096+0xa5*16+row) if loaded else 0xff for row in range(16))
                assert memory[0xd000:0xd010]==expected_payload
                with (root/f'{name}.csv').open() as source:
                    rows=list(csv.DictReader(source))
                transfers=[r for r in rows if 0x1400<=int(r['address'])<=0x140f and
                           r['mreq_n']=='1' and r['iorq_n']=='0' and r['rd_n']=='0' and r['wr_n']=='1']
                assert len(transfers)>=32 and max(int(r['time_ps']) for r in transfers)>=290000000000,'DMA did not continue through final frames'
                assert {int(r['address'])&15 for r in transfers}==set(range(16))
                # Runner flushes its still-active final bus row at end_ps.
                # A final read with no destination start is NOT a completed
                # response; require exact counter/address/time evidence before
                # excluding it. Every earlier completed response stays exact.
                if (int(transfers[-1]['time_ps'])==report['time_ps']-15625 and
                    report['dma_reads']==report['dma_writes']+1 and
                    int(transfers[-1]['address'])==report['cpu_address']):
                    transfers=transfers[:-1]
                assert all(int(r['data_in'])==expected_payload[int(r['address'])&15] for r in transfers),'actual DMA read bus payload mismatch'
                destinations=[r for r in rows if 0xd000<=int(r['address'])<=0xd00f and
                              r['mreq_n']=='0' and r['iorq_n']=='1' and r['wr_n']=='0']
                assert len(destinations)>=32
                assert all(int(r['data_out'])==expected_payload[int(r['address'])&15] for r in destinations),'actual DMA destination bus payload mismatch'
                for read in transfers:
                    following=next((w for w in destinations if int(w['time_ps'])>int(read['time_ps'])),None)
                    assert following and (int(following['address'])&15)==(int(read['address'])&15),'completed DMA read lost/misordered destination'
            assert report["turbo_kanji"] and report["frames"] >= 3, report
            assert report['turbo_dma']==args.dma and report.get('dma_kanji_experiment',False)==args.dma, report
            if controller:
                assert report["rtc_experiment"] and report["rtc_controller_bytes"] == 8192
            assert (report["sys_hz"], report["video_hz"]) == (32000000, 42954540), report
            expected_hs = 112 * (16 if high else 24) * 1e12 / 42954540
            expected_vs = expected_hs * 28 * (16 if high else 8)
            # Sync edges are observed on the 32 MHz reference scheduler;
            # permit two reference-edge quanta, not percentage-based drift.
            assert abs(report["hs_period_ps"] - expected_hs) <= 62500, report
            assert abs(report["vs_period_ps"] - expected_vs) <= 62500, report
            header, dimensions, maximum, pixels = frame.read_bytes().split(b"\n", 3)
            width, height = map(int, dimensions.split())
            assert (header, maximum, width, height) == (b"P6", b"255", columns * 8, 400 if high else 200), report
            errors = []
            for y in range(height):
                for x in range(width):
                    cell = (y // (16 if high else 8)) * columns + x // 8
                    row = y % 16 if high else (y % 8) * 2
                    address = ((cell // 16) % 2) * 65536 + (cell % 16) * 4096 + (cell % 256) * 16 + row
                    bits = 0 if not loaded or cell & 32 else font_bytes[address]
                    lit = bool(bits & (128 >> (x % 8))) ^ bool(cell & 64)
                    expected = bytes([255 if lit else 0]) * 3
                    offset = (y * width + x) * 3
                    if pixels[offset:offset + 3] != expected and len(errors) < 12:
                        errors.append((x, y, address, expected.hex(), pixels[offset:offset + 3].hex()))
            assert not errors, (high, errors, report)
            print(f"PASS actual CPU Kanji RGB: {name} {width}x{height}, bank/half/glyph/row/reverse/absent-level2", flush=True)
        if controller:assert hashlib.sha256(controller.read_bytes()).hexdigest() == controller_hash


if __name__ == "__main__":
    main()
