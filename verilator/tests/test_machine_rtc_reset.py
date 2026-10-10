"""Original dual-boot Z80 diagnostic; no state conversion or reload on reset."""
import hashlib
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

from z80_fixture import Program
from test_rtc_commands import DATE,TIME

ROOT=pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'scripts'))
from build_mr16_rtc_firmware import build


def fixture():
    p=Program()
    p.emit(0xf3);p.word(0x31,0xffff);p.word(0x01,0x1a03);p.emit(0x3e,0x82,0xed,0x79)
    # The first CPU boot writes RTC2 after its actual elapsed-time check. RAM
    # retains that marker across reset; the second boot only reads the clock.
    p.word(0x3a,0xf003);p.emit(0xfe,ord('2'));p.jump(0xca,'warm')
    serial=0
    def send(value):
        nonlocal serial
        serial+=1;label=f'write-{serial}'
        p.word(0x01,0x1a01);p.label(label);p.emit(0xed,0x78,0xe6,0x40);p.jump(0xc2,label)
        p.word(0x01,0x1900);p.emit(0x3e,value,0xed,0x79)
    def read(command,address):
        nonlocal serial
        send(command)
        for i in range(3):
            serial+=1;label=f'read-{serial}'
            p.word(0x01,0x1a01);p.label(label);p.emit(0xed,0x78,0xe6,0x20);p.jump(0xc2,label)
            p.word(0x01,0x1900);p.emit(0xed,0x78);p.word(0x32,address+i)
    for i,value in enumerate(b'RTC0'):p.store(0xf000+i,value)
    for command,values in ((0xec,DATE),(0xee,TIME)):
        for value in (command,*values):send(value)
    read(0xed,0xf010);read(0xef,0xf013);p.store(0xf003,ord('1'))
    p.emit(0x16,4);p.label('outer');p.word(0x21,0xffff);p.label('inner')
    p.emit(0x2b,0x7c,0xb5);p.jump(0xc2,'inner');p.emit(0x15);p.jump(0xc2,'outer')
    read(0xed,0xf020);read(0xef,0xf023);p.store(0xf003,ord('2'))
    p.label('cold-done');p.emit(0x76);p.jump(0xc3,'cold-done')
    p.label('warm');read(0xed,0xf030);read(0xef,0xf033);p.store(0xf003,ord('3'))
    p.label('warm-done');p.emit(0x76);p.jump(0xc3,'warm-done')
    return p.finish()


def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    runner=pathlib.Path(sys.argv[1]).resolve()
    folder=pathlib.Path(tempfile.mkdtemp(prefix='qualified-',dir=runner.parent))
    inputs=[pathlib.Path(__file__).resolve(),ROOT/'verilator/tests/test_rtc_commands.py',
            ROOT/'verilator/tests/z80_fixture.py',ROOT/'verilator/tests/machine_rtc_tb.sv',
            ROOT/'scripts/build_mr16_rtc_firmware.py',ROOT/'scripts/assemble_mr16.py',
            ROOT/'verilator/tests/fixtures/rtc_mr16_host_extension.asm',
            ROOT/'verilator/tests/fixtures/rtc_mr16_compact.asm',ROOT/'verilator/Makefile',ROOT/'rtl/machine.qip']
    inputs += [ROOT/name for name in re.findall(r'^set_global_assignment -name (?:SYSTEMVERILOG_FILE|VERILOG_FILE) (\S+)$',(ROOT/'rtl/machine.qip').read_text(),re.M)]
    inputs += sorted((ROOT/'bios/reference/fw_subcpu').glob('*.asm'))
    inputs += sorted((ROOT/'bios/reference/fw_subcpu').glob('*.inc'))
    inputs += [ROOT/'bios/reference/fw_subcpu/verilog/X1SUB.BIN',runner]
    hashes={str(path):digest(path) for path in inputs}
    for i,path in enumerate(inputs):shutil.copy2(path,folder/f'input-{i}-{path.name}')
    frozen=folder/'runner';shutil.copy2(runner,frozen)
    image,_=build(receive_only=True);program=fixture()
    rom=folder/'controller.mem';ipl=folder/'dual-boot-ipl.mem'
    with rom.open('x') as out:out.writelines(f'{int.from_bytes(image[i:i+2],"little"):04x}\n' for i in range(0,len(image),2))
    with ipl.open('x') as out:out.writelines(f'{byte:02x}\n' for byte in program+bytes(8192-len(program)))
    manifest={'inputs':hashes,'controller_mem_sha256':digest(rom),'ipl_mem_sha256':digest(ipl),
              'scope':'actual shared Z80 retained IPL/controller warm reset; no owned DMA/in-flight/native/hardware acceptance'}
    (folder/'manifest-before.json').write_text(json.dumps(manifest,indent=2)+'\n')
    for negative in (False,True):
        result=subprocess.run([str(frozen),f'+ROM={rom}',f'+IPL={ipl}',*(['+NEGATIVE_COLD_RESET'] if negative else [])],capture_output=True,text=True,cwd=folder)
        label='wrong-power' if negative else 'retained-warm'
        (folder/f'{label}.log').write_text(result.stdout+result.stderr)
        if negative:
            assert result.returncode!=0 and 'machine RTC warm retained-time mismatch' in result.stdout+result.stderr,(folder,result.stdout,result.stderr)
        else:
            assert result.returncode==0 and 'PASS: actual shared Z80 retained-IPL warm reset' in result.stdout,(folder,result.stdout,result.stderr)
        print(f'PASS: {label} {"rejected by unchanged retained-time oracle" if negative else "actual CPU second boot with retained assets"}',flush=True)
    assert hashes=={str(path):digest(path) for path in inputs} and digest(frozen)==hashes[str(runner)]
    for i,path in enumerate(inputs):assert digest(folder/f'input-{i}-{path.name}')==hashes[str(path)]
    assert digest(rom)==manifest['controller_mem_sha256'] and digest(ipl)==manifest['ipl_mem_sha256']
    (folder/'manifest-after.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(f'PASS: immutable retained-reset evidence {folder}')


if __name__=='__main__':main()
