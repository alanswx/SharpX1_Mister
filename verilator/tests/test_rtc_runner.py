"""Frozen delay-aware RTC runner gates, no private IPL/state conversions."""
import argparse
import hashlib
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
from test_rtc_commands import fixture as elapsed_fixture,DATE,TIME
from test_machine_rtc_reset import fixture as warm_fixture

ROOT=pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'scripts'))
from build_mr16_rtc_firmware import build

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('runner',type=pathlib.Path)
    parser.add_argument('--x3',action='store_true',help='require the separate nominal X3 video clock profile')
    parser.add_argument('--kanji',action='store_true',help='require the separate X3/Kanji combination')
    parser.add_argument('--dma',action='store_true',help='require explicit non-savable DMA/Kanji combination')
    parser.add_argument('--fm',action='store_true',help='require explicit FM/DMA/Kanji/X3 coexistence profile')
    args=parser.parse_args()
    if args.kanji and not args.x3:parser.error('--kanji qualification requires --x3')
    if args.dma and not args.kanji:parser.error('--dma qualification requires --kanji --x3')
    if args.fm and not args.dma:parser.error('--fm qualification requires --dma --kanji --x3')
    runner=args.runner.resolve()
    folder=pathlib.Path(tempfile.mkdtemp(prefix='qualified-',dir=runner.parent))
    inputs=[pathlib.Path(__file__).resolve(),ROOT/'verilator/tests/test_rtc_commands.py',
            ROOT/'verilator/tests/test_machine_rtc_reset.py',ROOT/'verilator/tests/z80_fixture.py',
            ROOT/'scripts/build_mr16_rtc_firmware.py',ROOT/'scripts/assemble_mr16.py',
            ROOT/'verilator/tests/fixtures/rtc_mr16_host_extension.asm',ROOT/'verilator/tests/fixtures/rtc_mr16_compact.asm',
            ROOT/'verilator/Makefile',ROOT/'verilator/sim.v',ROOT/'verilator/sim_headless.cpp',
            ROOT/'verilator/frame_capture.h',ROOT/'verilator/audio_capture.h',ROOT/'verilator/d88_image.h',ROOT/'rtl/machine.qip']
    inputs += [ROOT/name for name in re.findall(r'^set_global_assignment -name (?:SYSTEMVERILOG_FILE|VERILOG_FILE) (\S+)$',(ROOT/'rtl/machine.qip').read_text(),re.M)]
    inputs += sorted((ROOT/'bios/reference/fw_subcpu').glob('*.asm'))+sorted((ROOT/'bios/reference/fw_subcpu').glob('*.inc'))
    inputs += [ROOT/'bios/reference/fw_subcpu/verilog/X1SUB.BIN',runner]
    hashes={str(path):digest(path) for path in inputs}
    for i,path in enumerate(inputs):shutil.copy2(path,folder/f'input-{i}-{path.name}')
    frozen=folder/'runner';shutil.copy2(runner,frozen)
    image,_=build(receive_only=True)
    controller=folder/'controller.bin';controller.write_bytes(image)
    elapsed=folder/'elapsed.bin';elapsed.write_bytes(elapsed_fixture())
    warm=folder/'warm.bin';warm.write_bytes(warm_fixture())
    assets={str(path):digest(path) for path in (controller,elapsed,warm)}
    manifest={'inputs':hashes,'assets':assets,'x3_requested':args.x3,'kanji_requested':args.kanji,'dma_requested':args.dma,'fm_requested':args.fm,'scope':'non-savable Turbo RTC runner, real IPL elapsed/warm CPU execution; no Kanji pixels/native calendar/DMA/programmed FM/audio/hardware acceptance'}
    (folder/'manifest-before.json').write_text(json.dumps(manifest,indent=2)+'\n')
    sentinel=folder/'do-not-overwrite.state';sentinel.write_bytes(b'original sentinel, not an RTL state')
    short=folder/'short-controller.bin';short.write_bytes(image[:-1])
    negatives=[('missing',[],'requires --rtc-controller'),
               ('short',['--rtc-controller',str(short)],'exactly 8192'),
               ('save',['--save-state',str(sentinel)],'RTC experiment is non-savable'),
               ('restore',['--restore-state',str(sentinel)],'RTC experiment is non-savable')]
    for name,negative_args,marker in negatives:
        result=subprocess.run([str(frozen),*negative_args],capture_output=True,text=True,cwd=folder)
        output=result.stdout+result.stderr;(folder/f'{name}.log').write_text(output)
        assert result.returncode!=0 and marker in output,(folder,output)
        assert sentinel.read_bytes()==b'original sentinel, not an RTL state'
        print(f'PASS: RTC runner rejects {name} without changing state sentinel',flush=True)
    for name,rom,cycles,reset_args in [('elapsed',elapsed,70400000,[]),
                                     ('warm',warm,120000000,['--reset-at','2500','--reset-for-us','1000000'])]:
        print(f'START: RTC runner actual CPU {name}',flush=True)
        result=subprocess.run([str(frozen),'--rtc-controller',str(controller),'--rom',str(rom),
                               '--cycles',str(cycles),'--dump',str(folder/name),*reset_args],capture_output=True,text=True,cwd=folder)
        (folder/f'{name}.log').write_text(result.stdout+result.stderr)
        assert result.returncode==0,(folder,result.stdout,result.stderr)
        report=json.loads(result.stdout.splitlines()[-1]);memory=(folder/f'{name}.ram').read_bytes()
        assert report['rtc_experiment'] and report['rtc_controller_bytes']==8192
        assert report['turbo_foundation'] and report['turbo_dma']==args.dma and report['intra_assignment_delays']
        assert report.get('dma_kanji_experiment',False)==args.dma,'wrong combined profile'
        assert report['turbo_video_master']==args.x3,'wrong video clock profile'
        assert report['turbo_kanji']==args.kanji,'wrong Kanji profile'
        assert report['turbo_fm_cpu']==args.fm,'wrong FM coexistence profile'
        assert report['sys_hz']==32000000 and report['video_hz']==(42954540 if args.x3 else 28571428) and report['halted']
        assert report['download_bytes']==8193+len(rom.read_bytes()),'unexpected reupload during warm reset'
        assert memory[0xf010:0xf016]==DATE+TIME
        assert memory[0xf020:0xf025]==DATE+TIME[:2] and memory[0xf025] in (0x57,0x58)
        if name=='elapsed':assert memory[0xf000:0xf004]==b'RTC2'
        else:
            assert memory[0xf000:0xf004]==b'RTC3'
            assert memory[0xf030:0xf036]==bytes((0x31,0xc6,0,0x12,0x34,0x59)),memory[0xf030:0xf036].hex()
        print(f'PASS: RTC runner actual CPU {name}',flush=True)
    assert hashes=={str(path):digest(path) for path in inputs}
    for i,path in enumerate(inputs):assert digest(folder/f'input-{i}-{path.name}')==hashes[str(path)]
    assert digest(frozen)==hashes[str(runner)] and assets=={name:digest(pathlib.Path(name)) for name in assets}
    (folder/'manifest-after.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(f'PASS: immutable RTC runner evidence {folder}')

if __name__=='__main__':main()
