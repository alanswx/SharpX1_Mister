"""Real loader/CPU negative for repeated Kanji DMA during video rendering.

One synthetic font byte is corrupted, never the CPU oracle, RAM or bus grant.
The same active-video program must actually reject its DMA-delivered payload.
"""
import argparse
import hashlib
import json
import pathlib
import shutil
import subprocess
import tempfile
from test_machine_kanji_render import fixture,pattern

def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('runner',type=pathlib.Path)
    parser.add_argument('--rtc-controller',type=pathlib.Path,required=True)
    args=parser.parse_args();runner=args.runner.resolve();controller=args.rtc_controller.resolve()
    assert controller.stat().st_size==8192
    folder=pathlib.Path(tempfile.mkdtemp(prefix='kanji-dma-negative-',dir=runner.parent))
    tests=pathlib.Path(__file__).resolve().parent
    inputs=[pathlib.Path(__file__).resolve(),tests/'test_machine_kanji_render.py',tests/'z80_fixture.py',runner,controller]
    hashes={str(p):digest(p) for p in inputs}
    for i,p in enumerate(inputs):shutil.copy2(p,folder/f'input-{i}-{p.name}')
    frozen=folder/'runner';shutil.copy2(runner,frozen)
    clock=folder/'controller.bin';shutil.copy2(controller,clock)
    rom=folder/'original.bin';code=fixture(False,40,active_dma=True,loaded=True);rom.write_bytes(code)
    data=bytearray(pattern(a) for a in range(131072));address=65536+15*4096+0xa5*16
    data[address]^=1
    font=folder/'one-corrupt-byte.physical';font.write_bytes(data)
    manifest={'inputs':hashes,'program_sha256':digest(rom),'font_sha256':digest(font),'corrupted_address':address,
              'scope':'actual CPU payload rejection, not native font/pixels/hardware acceptance'}
    (folder/'manifest-before.json').write_text(json.dumps(manifest,indent=2)+'\n')
    result=subprocess.run([str(frozen),'--rom',str(rom),'--kanji-physical',str(font),
                           '--rtc-controller',str(clock),'--cycles','9600000','--dump',str(folder/'result')],
                          capture_output=True,text=True,cwd=tests.parent,timeout=300)
    (folder/'result.log').write_text(result.stdout+result.stderr)
    assert result.returncode==0,(folder,result.stderr)
    report=json.loads(result.stdout.splitlines()[-1]);memory=(folder/'result.ram').read_bytes()
    assert report['dma_kanji_experiment'] and report['halted'] and memory[0xf000]==0xee,report
    assert report['dma_reads']==report['dma_writes']==16 and report['dma_grants']==1,report
    assert memory[0xf010:0xf012]==b'\0\0','corrupted first payload passed CPU comparison'
    assert memory[0xd000]==(pattern(address)^1)
    assert memory[0xd001:0xd010]==bytes(pattern(address+i) for i in range(1,16))
    assert hashes=={str(p):digest(p) for p in inputs}
    for i,p in enumerate(inputs):assert digest(folder/f'input-{i}-{p.name}')==hashes[str(p)]
    assert digest(rom)==manifest['program_sha256'] and digest(font)==manifest['font_sha256']
    assert digest(frozen)==hashes[str(runner)] and digest(clock)==hashes[str(controller)]
    (folder/'manifest-after.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(f'PASS active-video CPU rejects one genuinely uploaded corrupt DMA font byte: {folder}',flush=True)

if __name__=='__main__':main()
