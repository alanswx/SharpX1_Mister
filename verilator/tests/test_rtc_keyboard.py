"""Original real-Z80 concurrent RTC mailbox/keyboard-poll diagnostics."""
import argparse
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

CASES=(('F','25 2b\n',0x46),('Space','25 29\n',0x20),('Enter','25 5a\n',0x0d),
       ('cold-caps-off','5 58\n10 f0\n12 58\n25 2b\n',0x66),
       ('steady-caps-off','70 58\n75 f0\n77 58\n100 2b\n',0x66),
       ('caps-off-shift','5 58\n10 f0\n12 58\n20 12\n25 2b\n',0x46))

def fixture(expected):
    p=Program();p.emit(0xf3);p.word(0x31,0xffff);p.word(0x01,0x1a03);p.emit(0x3e,0x82,0xed,0x79)
    serial=0
    def send(value):
        nonlocal serial
        serial+=1;label=f'tx{serial}'
        p.word(0x01,0x1a01);p.label(label);p.emit(0xed,0x78,0xe6,0x40);p.jump(0xc2,label)
        p.word(0x01,0x1900);p.emit(0x3e,value,0xed,0x79)
    def receive(address,count):
        nonlocal serial
        for i in range(count):
            serial+=1;label=f'rx{serial}'
            p.word(0x01,0x1a01);p.label(label);p.emit(0xed,0x78,0xe6,0x20);p.jump(0xc2,label)
            p.word(0x01,0x1900);p.emit(0xed,0x78);p.word(0x32,address+i)
    def clock_read(command,address):send(command);receive(address,3)
    for value in (0xec,0x31,0xc6,0x99,0xee,0x12,0x34,0x56):send(value)
    clock_read(0xed,0xf010);clock_read(0xef,0xf013)
    p.label('poll')
    # Serial clock reads remain active while genuine PS/2 packets interrupt
    # the MR16. No artificial IRQ, mailbox or translated ASCII is injected.
    clock_read(0xef,0xf040)
    p.word(0x21,0xf050);p.emit(0x34);p.jump(0xc2,'counted');p.emit(0x23,0x34);p.label('counted')
    for value in (0xe4,0,0xe6):send(value)
    receive(0xf020,2);p.emit(0xfe,expected);p.jump(0xc2,'poll')
    clock_read(0xed,0xf030);clock_read(0xef,0xf033)
    for i,value in enumerate(b'RTCK'):p.store(0xf000+i,value)
    p.label('done');p.emit(0x76);p.jump(0xc3,'done')
    return p.finish()

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def validate(report,memory,expected):
    assert report['halted'] and memory[0xf000:0xf004]==b'RTCK','CPU key/RTC fixture incomplete'
    assert memory[0xf021]==expected,'actual keyboard translation changed'
    assert memory[0xf010:0xf016]==bytes((0x31,0xc6,0x99,0x12,0x34,0x56))
    assert memory[0xf030:0xf036]==memory[0xf010:0xf016],'RTC data corrupted by keyboard/host traffic'
    assert memory[0xf040:0xf043]==bytes((0x12,0x34,0x56)) and int.from_bytes(memory[0xf050:0xf052],'little')>0

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('runner',type=pathlib.Path)
    parser.add_argument('--x3',action='store_true',help='require the separate nominal X3 video clock profile')
    args=parser.parse_args()
    runner=args.runner.resolve()
    folder=pathlib.Path(tempfile.mkdtemp(prefix='keyboard-qualified-',dir=runner.parent))
    inputs=[pathlib.Path(__file__).resolve(),ROOT/'verilator/tests/z80_fixture.py',
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
    controller=folder/'controller.bin';controller.write_bytes(build(receive_only=True)[0])
    assets=[controller]
    for name,script,expected in CASES:
        rom=folder/f'{name}.bin';rom.write_bytes(fixture(expected));assets.append(rom)
        keys=folder/f'{name}.keys';keys.write_text(script);assets.append(keys)
    asset_hashes={str(path):digest(path) for path in assets}
    manifest={'inputs':hashes,'assets':asset_hashes,'x3_requested':args.x3,'scope':'real PS/2/MR16 IRQ plus Z80 E4/E6/EC..EF; no Z80 IRQ/native/FDC/hardware acceptance'}
    (folder/'manifest-before.json').write_text(json.dumps(manifest,indent=2)+'\n')
    for name,_,expected in CASES:
        print(f'START: RTC/keyboard {name}',flush=True)
        result=subprocess.run([str(frozen),'--rtc-controller',str(controller),'--rom',str(folder/f'{name}.bin'),
                               '--keys',str(folder/f'{name}.keys'),'--cycles','4000000','--dump',str(folder/name)],capture_output=True,text=True,cwd=folder)
        (folder/f'{name}.log').write_text(result.stdout+result.stderr)
        assert result.returncode==0,(folder,result.stdout,result.stderr)
        report=json.loads(result.stdout.splitlines()[-1]);memory=(folder/f'{name}.ram').read_bytes()
        assert report['turbo_video_master']==args.x3,'wrong video clock profile'
        assert report['rtc_experiment'] and report['intra_assignment_delays'] and report['sys_hz']==32000000 and report['video_hz']==(42954540 if args.x3 else 28571428)
        assert report['ps2_bytes_sent']==len((folder/f'{name}.keys').read_text().splitlines())
        validate(report,memory,expected)
        print(f'PASS: RTC/keyboard {name}, live clock polls={int.from_bytes(memory[0xf050:0xf052],"little")}',flush=True)
    # A genuine absent-key stream must fail the same completion/translation
    # oracle. This is not an injected key or deliberately patched device.
    result=subprocess.run([str(frozen),'--rtc-controller',str(controller),'--rom',str(folder/'F.bin'),
                           '--cycles','4000000','--dump',str(folder/'absent')],capture_output=True,text=True,cwd=folder)
    (folder/'absent.log').write_text(result.stdout+result.stderr);assert result.returncode==0
    report=json.loads(result.stdout.splitlines()[-1]);memory=(folder/'absent.ram').read_bytes()
    assert report['ps2_bytes_sent']==0
    try:validate(report,memory,0x46)
    except AssertionError as error:assert str(error)=='CPU key/RTC fixture incomplete',error
    else:raise AssertionError('absent key falsely passed unchanged oracle')
    print('PASS: absent real PS/2 stream rejected by unchanged completion oracle',flush=True)
    assert hashes=={str(path):digest(path) for path in inputs}
    for i,path in enumerate(inputs):assert digest(folder/f'input-{i}-{path.name}')==hashes[str(path)]
    assert digest(frozen)==hashes[str(runner)] and asset_hashes=={str(path):digest(path) for path in assets}
    (folder/'manifest-after.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(f'PASS: immutable RTC/keyboard evidence {folder}')

if __name__=='__main__':main()
