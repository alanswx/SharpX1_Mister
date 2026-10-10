"""Frozen original-CPU RTC commands during real FDC/DMA sector ownership.

Enabled Kanji renderer/storage coexistence, not initialized displayed glyphs
or native-game acceptance. No private assets, fake grants or state patches.
"""
import argparse
import hashlib
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
from test_dma_native_read_stream import diagnostic

ROOT=pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'scripts'))
from build_mr16_rtc_firmware import build

def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('runner',type=pathlib.Path)
    parser.add_argument('--fm',action='store_true',help='require FM enabled; fixture does not program or qualify FM sound')
    args=parser.parse_args();runner=args.runner.resolve()
    folder=pathlib.Path(tempfile.mkdtemp(prefix='fdc-qualified-',dir=runner.parent))
    inputs=[pathlib.Path(__file__).resolve(),runner]
    inputs += [ROOT/'verilator/tests'/n for n in ('test_dma_native_read_stream.py','test_machine_dma.py','z80_fixture.py')]
    inputs += [ROOT/'scripts'/n for n in ('build_mr16_rtc_firmware.py','assemble_mr16.py')]
    inputs += [ROOT/'verilator'/n for n in ('Makefile','sim.v','sim_headless.cpp','frame_capture.h','audio_capture.h','d88_image.h')]
    inputs += [ROOT/'rtl/machine.qip']
    inputs += [ROOT/name for name in re.findall(r'^set_global_assignment -name (?:SYSTEMVERILOG_FILE|VERILOG_FILE) (\S+)$',(ROOT/'rtl/machine.qip').read_text(),re.M)]
    inputs += sorted((ROOT/'bios/reference/fw_subcpu').glob('*.asm'))+sorted((ROOT/'bios/reference/fw_subcpu').glob('*.inc'))
    inputs += [ROOT/'bios/reference/fw_subcpu/verilog/X1SUB.BIN']
    inputs += [ROOT/'verilator/tests/fixtures'/n for n in ('rtc_mr16_host_extension.asm','rtc_mr16_compact.asm')]
    hashes={str(p):digest(p) for p in inputs}
    for i,p in enumerate(inputs):shutil.copy2(p,folder/f'input-{i}-{p.name}')
    frozen=folder/'runner';shutil.copy2(runner,frozen)
    controller=folder/'controller.bin';controller.write_bytes(build(receive_only=True)[0])
    font=folder/'original.physical';font.write_bytes(bytes(((a*37)^(a>>4)^(a>>12)^(a>>16))&255 for a in range(131072)))
    assets={str(p):digest(p) for p in (controller,font)}
    manifest={'inputs':hashes,'assets':assets,'fm_requested':args.fm,'scope':'CPU RTC during real 1024-byte FDC DMA; enabled renderer, no displayed glyph/programmed FM/audio/native/hardware claim'}
    (folder/'manifest-before.json').write_text(json.dumps(manifest,indent=2)+'\n')
    for explicit in (False,True):
        code,image,payload=diagnostic(explicit_wr3=explicit,with_rtc=True)
        rom=folder/f'wr3-{explicit}.bin';rom.write_bytes(code)
        disk=folder/f'wr3-{explicit}.d88';disk.write_bytes(image)
        for warm in (False,True):
            prefix=folder/f'wr3-{explicit}-warm-{warm}'
            command=[str(frozen),'--rtc-controller',str(controller),'--kanji-physical',str(font),
                     '--rom',str(rom),'--disk',str(disk),'--cycles','16000000','--dump',str(prefix)]
            if warm:command += ['--reset-at','250','--reset-for-us','10']
            print(f'START RTC/FDC/DMA wr3={explicit} warm={warm}',flush=True)
            result=subprocess.run(command,capture_output=True,text=True,cwd=ROOT/'verilator',timeout=600)
            prefix.with_suffix('.stdout.log').write_text(result.stdout)
            prefix.with_suffix('.stderr.log').write_text(result.stderr)
            assert result.returncode==0,(folder,result.stderr)
            report=json.loads(result.stdout.splitlines()[-1]);memory=prefix.with_suffix('.ram').read_bytes()
            assert report['dma_kanji_experiment'] and report['rtc_experiment'] and report['turbo_kanji'] and report['turbo_dma']
            assert report['turbo_fm_cpu']==args.fm,'wrong FM coexistence profile'
            assert report['intra_assignment_delays'] and (report['sys_hz'],report['video_hz'])==(32000000,42954540)
            assert report['halted'] and memory[0xf000:0xf004]==b'DMA!',report
            assert memory[0x8000:0x8400]==payload
            assert memory[0xf100:0xf103]==memory[0xf110:0xf113]==bytes((0x12,0x34,0x56))
            count=2048 if warm else 1024
            assert all(report[n]==count for n in ('dma_reads','dma_writes','dma_grants')),report
            assert report['cpu_fdc_data_reads']==report['cpu_fdc_data_writes']==report['disk_writes']==0
            assert disk.read_bytes()==image and rom.read_bytes()==code
            print(f'PASS RTC/FDC/DMA wr3={explicit} warm={warm} pairs={count}',flush=True)
    assert hashes=={str(p):digest(p) for p in inputs}
    for i,p in enumerate(inputs):assert digest(folder/f'input-{i}-{p.name}')==hashes[str(p)]
    assert digest(frozen)==hashes[str(runner)] and assets=={str(p):digest(pathlib.Path(p)) for p in assets}
    (folder/'manifest-after.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(f'PASS immutable RTC/FDC/DMA evidence {folder}',flush=True)

if __name__=='__main__':main()
