"""Original CPU effect-register experiment and frozen enabled/disabled evidence."""
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

def fixture():
    p=Program();p.emit(0xf3);p.word(0x31,0xffff)
    def out(port,value):p.word(0x01,port);p.emit(0x3e,value,0xed,0x79)
    def inp(port,destination):p.word(0x01,port);p.emit(0xed,0x78);p.word(0x32,destination)
    out(0x1a03,0x82);inp(0x1a02,0xf830) # Real IN clears DAM after PPI mode-set.
    p.word(0x3a,0xf800);p.emit(0xfe,0xa5);p.jump(0xca,'warm')
    for slot in range(4):out(0x1fc1+slot,0xaa)
    out(0x1fb0,0x8c) # AEN plus capture/invert bits, CPU-only, not a renderer.
    for slot in range(4):inp(0x1fc1+slot,0xf810+slot)
    for slot in range(4):
        p.word(0x01,0x1fc1+slot);p.word(0x21,0xf000+slot*256);p.emit(0x16,0)
        p.label(f'bytes{slot}');p.emit(0x7a,0xed,0x79,0xed,0x78,0x77,0x23,0x14)
        p.jump(0xc2,f'bytes{slot}')
    for slot,value in enumerate((0x11,0x22,0x44,0x88)):out(0x1fc1+slot,value)
    # 1ECx is the real IPL-disable aperture, NOT a harmless alias. Use the
    # adjacent unmapped 1FC9..1FCC controls instead; never disable the boot ROM.
    for slot in range(4):out(0x1fc9+slot,0xaa)
    out(0x1a03,0x0b) # BSR sets C5 high; the next mode-set creates a real fall.
    out(0x1a03,0x82)
    for slot in range(4):out(0x1fc1+slot,0xaa)
    inp(0x1a02,0xf831)
    for slot in range(4):inp(0x1fc1+slot,0xf814+slot)
    out(0x1fb0,0)
    for slot in range(4):out(0x1fc1+slot,0xaa)
    out(0x1fb0,0x80)
    for slot in range(4):inp(0x1fc1+slot,0xf818+slot)
    p.store(0xf800,0xa5);p.label('cold-done');p.emit(0x76);p.jump(0xc3,'cold-done')
    p.label('warm');out(0x1fb0,0x80)
    for slot in range(4):inp(0x1fc1+slot,0xf820+slot)
    p.store(0xf800,0x5a);p.label('warm-done');p.emit(0x76);p.jump(0xc3,'warm-done')
    return p.finish()

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    runners=[pathlib.Path(arg).resolve() for arg in sys.argv[1:]]
    assert len(runners)==2
    folder=pathlib.Path(tempfile.mkdtemp(prefix='qualified-',dir=runners[0].parent))
    inputs=[pathlib.Path(__file__).resolve(),ROOT/'verilator/tests/z_effect_machine_tb.sv',
            ROOT/'verilator/tests/z80_fixture.py',ROOT/'verilator/Makefile',ROOT/'rtl/machine.qip']
    inputs += [ROOT/name for name in re.findall(r'^set_global_assignment -name (?:SYSTEMVERILOG_FILE|VERILOG_FILE) (\S+)$',(ROOT/'rtl/machine.qip').read_text(),re.M)]
    inputs += runners
    hashes={str(path):digest(path) for path in inputs}
    for i,path in enumerate(inputs):shutil.copy2(path,folder/f'input-{i}-{path.name}')
    ipl=folder/'effect-original.mem';program=fixture()
    with ipl.open('x') as out:out.writelines(f'{b:02x}\n' for b in program+bytes(8192-len(program)))
    manifest={'inputs':hashes,'ipl_mem_sha256':digest(ipl),
              'scope':'CPU-only provisional effect storage, real Z80 AEN/DAM/readback/warm reset; no input video/effects/native/hardware acceptance'}
    (folder/'manifest-before.json').write_text(json.dumps(manifest,indent=2)+'\n')
    for i,runner in enumerate(runners):
        frozen=folder/f'runner-{i}';shutil.copy2(runner,frozen)
        result=subprocess.run([str(frozen),f'+IPL={ipl}'],capture_output=True,text=True,cwd=folder)
        output=result.stdout+result.stderr;(folder/f'case-{i}.log').write_text(output)
        if i==0:assert result.returncode==0 and 'PASS: effect actual CPU' in output,(folder,output)
        else:assert result.returncode!=0 and 'effect actual CPU readback mismatch slot=0 byte=0 got=ff enabled=0' in output,(folder,output)
        assert digest(frozen)==hashes[str(runner)]
        print(f'PASS: effect machine {"enabled CPU control gate" if i==0 else "disabled control fails actual CPU readback"}',flush=True)
    assert hashes=={str(path):digest(path) for path in inputs}
    for i,path in enumerate(inputs):assert digest(folder/f'input-{i}-{path.name}')==hashes[str(path)]
    assert digest(ipl)==manifest['ipl_mem_sha256']
    (folder/'manifest-after.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(f'PASS: immutable effect machine evidence {folder}')

if __name__=='__main__':main()
