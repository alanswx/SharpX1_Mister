"""Freeze public-transport admission evidence and legal-traffic negatives."""
import hashlib
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT=pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'scripts'))
from build_mr16_rtc_firmware import build

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    runner=pathlib.Path(sys.argv[1]).resolve()
    folder=pathlib.Path(tempfile.mkdtemp(prefix='qualified-',dir=runner.parent))
    inputs=[pathlib.Path(__file__).resolve(),ROOT/'verilator/tests/machine_rtc_transport_tb.sv',
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
    image,_=build(receive_only=True)
    rom=folder/'controller.mem'
    with rom.open('x') as out:out.writelines(f'{int.from_bytes(image[i:i+2],"little"):04x}\n' for i in range(0,len(image),2))
    manifest={'inputs':hashes,'controller_mem_sha256':digest(rom),
              'scope':'public ioctl firmware/address/power admission only; no DMA or partial-image boot acceptance'}
    (folder/'manifest-before.json').write_text(json.dumps(manifest,indent=2)+'\n')
    cases=[('positive',None),('valid-write','NEGATIVE_VALID_WRITE'),('valid-power','NEGATIVE_VALID_POWER')]
    for label,negative in cases:
        result=subprocess.run([str(frozen),f'+ROM={rom}',*([f'+{negative}'] if negative else [])],capture_output=True,text=True,cwd=folder)
        output=result.stdout+result.stderr
        (folder/f'{label}.log').write_text(output)
        if negative:
            marker='RTC transport firmware corruption' if label=='valid-write' else 'RTC transport unexpected clock-storage loss'
            assert result.returncode!=0 and marker in output,(folder,output)
        else:assert result.returncode==0 and 'PASS: RTC public transport' in output,(folder,output)
        print(f'PASS: {label}',flush=True)
    assert hashes=={str(path):digest(path) for path in inputs}
    for i,path in enumerate(inputs):assert digest(folder/f'input-{i}-{path.name}')==hashes[str(path)]
    assert digest(frozen)==hashes[str(runner)] and digest(rom)==manifest['controller_mem_sha256']
    (folder/'manifest-after.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(f'PASS: immutable RTC transport evidence {folder}')

if __name__=='__main__':main()
