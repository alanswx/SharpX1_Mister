"""Original real-Z80 mailbox/DMA dual-boot program and frozen evidence."""
import hashlib
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
from z80_fixture import Program

ROOT=pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'scripts'))
from build_mr16_rtc_firmware import build

def fixture():
    p=Program();p.emit(0xf3);p.word(0x31,0xffff)
    def out(port,value):p.word(0x01,port);p.emit(0x3e,value,0xed,0x79)
    out(0x1a03,0x82)
    serial=0
    def send(value):
        nonlocal serial
        serial+=1;label=f'w{serial}'
        p.word(0x01,0x1a01);p.label(label);p.emit(0xed,0x78,0xe6,0x40);p.jump(0xc2,label)
        out(0x1900,value)
    def read(command,address):
        nonlocal serial
        send(command)
        for i in range(3):
            serial+=1;label=f'r{serial}'
            p.word(0x01,0x1a01);p.label(label);p.emit(0xed,0x78,0xe6,0x20);p.jump(0xc2,label)
            p.word(0x01,0x1900);p.emit(0xed,0x78);p.word(0x32,address+i)
    p.word(0x3a,0xf100);p.emit(0xfe,1);p.jump(0xca,'second')
    p.store(0xf100,1)
    for value in (0xec,0x31,0xc6,0x99,0xee,0x12,0x34,0x56):send(value)
    read(0xed,0xf010);read(0xef,0xf013);p.jump(0xc3,'dma')
    p.label('second');p.store(0xf100,2);read(0xed,0xf020);read(0xef,0xf023)
    p.label('dma')
    for i in range(16):p.store(0x9000+i,(0x31+i*13)&255)
    for value in (0xc3,0x7d,0,0x90,15,0,0x14,0x10,0xad,0,0x91,0x92,0xcf,0xb3,0x87):out(0x1f80,value)
    p.label('done');p.emit(0x76);p.jump(0xc3,'done')
    return p.finish()

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    runner=pathlib.Path(sys.argv[1]).resolve()
    folder=pathlib.Path(tempfile.mkdtemp(prefix='qualified-',dir=runner.parent))
    inputs=[pathlib.Path(__file__).resolve(),ROOT/'verilator/tests/machine_rtc_dma_reset_tb.sv',
            ROOT/'verilator/tests/z80_fixture.py',ROOT/'scripts/build_mr16_rtc_firmware.py',
            ROOT/'scripts/assemble_mr16.py',ROOT/'verilator/tests/fixtures/rtc_mr16_host_extension.asm',
            ROOT/'verilator/tests/fixtures/rtc_mr16_compact.asm',ROOT/'verilator/Makefile',ROOT/'rtl/machine.qip']
    inputs += [ROOT/name for name in re.findall(r'^set_global_assignment -name (?:SYSTEMVERILOG_FILE|VERILOG_FILE) (\S+)$',(ROOT/'rtl/machine.qip').read_text(),re.M)]
    inputs += sorted((ROOT/'bios/reference/fw_subcpu').glob('*.asm'))+sorted((ROOT/'bios/reference/fw_subcpu').glob('*.inc'))
    inputs += [ROOT/'bios/reference/fw_subcpu/verilog/X1SUB.BIN',runner]
    hashes={str(path):digest(path) for path in inputs}
    for i,path in enumerate(inputs):shutil.copy2(path,folder/f'input-{i}-{path.name}')
    frozen=folder/'runner';shutil.copy2(runner,frozen)
    image,_=build(receive_only=True);program=fixture()
    rom=folder/'controller.mem';ipl=folder/'dual-boot-dma.mem'
    with rom.open('x') as out:out.writelines(f'{int.from_bytes(image[i:i+2],"little"):04x}\n' for i in range(0,len(image),2))
    with ipl.open('x') as out:out.writelines(f'{byte:02x}\n' for byte in program+bytes(8192-len(program)))
    manifest={'inputs':hashes,'controller_mem_sha256':digest(rom),'ipl_mem_sha256':digest(ipl),
              'scope':'RTC enabled real CPU memory DMA read/write drain with blocked firmware/clock/IPL and stopped SYS; no FDC/native/pin acceptance'}
    (folder/'manifest-before.json').write_text(json.dumps(manifest,indent=2)+'\n')
    for phase in (0,1):
        for kind in (0,1,2):
            result=subprocess.run([str(frozen),f'+ROM={rom}',f'+IPL={ipl}',f'+PHASE={phase}',f'+KIND={kind}'],capture_output=True,text=True,cwd=folder)
            output=result.stdout+result.stderr;(folder/f'phase-{phase}-kind-{kind}.log').write_text(output)
            assert result.returncode==0 and 'PASS: RTC actual DMA owned' in output,(folder,output)
            print(f'PASS: RTC DMA phase {phase} asset kind {kind}',flush=True)
    for name,marker in [('NEGATIVE_AFTER_DRAIN','RTC DMA drain modified controller firmware'),
                        ('NEGATIVE_AFTER_POWER','RTC actual second CPU read lost retained clock')]:
        result=subprocess.run([str(frozen),f'+ROM={rom}',f'+IPL={ipl}','+PHASE=0','+KIND=0',f'+{name}'],capture_output=True,text=True,cwd=folder)
        output=result.stdout+result.stderr;(folder/f'{name}.log').write_text(output)
        assert result.returncode!=0 and marker in output,(folder,output)
        print(f'PASS: {name} admitted traffic rejected by unchanged oracle',flush=True)
    assert hashes=={str(path):digest(path) for path in inputs}
    for i,path in enumerate(inputs):assert digest(folder/f'input-{i}-{path.name}')==hashes[str(path)]
    assert digest(frozen)==hashes[str(runner)] and digest(rom)==manifest['controller_mem_sha256'] and digest(ipl)==manifest['ipl_mem_sha256']
    (folder/'manifest-after.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(f'PASS: immutable RTC DMA reset evidence {folder}')

if __name__=='__main__':main()
