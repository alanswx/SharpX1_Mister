"""Frozen shared-machine RTC execution; unchanged original Z80 emitter."""
import hashlib
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

from test_rtc_commands import fixture

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT / "scripts"))
from build_mr16_rtc_firmware import build


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    runners = [pathlib.Path(arg).resolve() for arg in sys.argv[1:]]
    assert len(runners)==2,"expected enabled and disabled shared-machine runners"
    folder=pathlib.Path(tempfile.mkdtemp(prefix="qualified-",dir=runners[0].parent))
    inputs=[pathlib.Path(__file__).resolve(),ROOT/'verilator/tests/test_rtc_commands.py',
            ROOT/'verilator/tests/z80_fixture.py',ROOT/'verilator/tests/machine_rtc_tb.sv',
            ROOT/'scripts/build_mr16_rtc_firmware.py',ROOT/'scripts/assemble_mr16.py',
            ROOT/'verilator/tests/fixtures/rtc_mr16_host_extension.asm',
            ROOT/'verilator/tests/fixtures/rtc_mr16_compact.asm',
            ROOT/'verilator/Makefile',ROOT/'rtl/machine.qip']
    inputs += [ROOT/name for name in re.findall(r'^set_global_assignment -name (?:SYSTEMVERILOG_FILE|VERILOG_FILE) (\S+)$',(ROOT/'rtl/machine.qip').read_text(),re.M)]
    inputs += sorted((ROOT/'bios/reference/fw_subcpu').glob('*.asm'))
    inputs += sorted((ROOT/'bios/reference/fw_subcpu').glob('*.inc'))
    inputs += [ROOT/'bios/reference/fw_subcpu/verilog/X1SUB.BIN',*runners]
    hashes={str(path):digest(path) for path in inputs}
    for i,path in enumerate(inputs):shutil.copy2(path,folder/f'input-{i}-{path.name}')
    image,_=build(receive_only=True)
    rom=folder/'controller.mem'
    with rom.open('x') as out:
        out.writelines(f'{int.from_bytes(image[i:i+2],"little"):04x}\n' for i in range(0,len(image),2))
    program=fixture()
    assert len(program)<=8192
    ipl=folder/'original-rtc-ipl.mem'
    with ipl.open('x') as out:out.writelines(f'{byte:02x}\n' for byte in program+bytes(8192-len(program)))
    manifest={'inputs':hashes,'controller_image_sha256':hashlib.sha256(image).hexdigest(),
              'controller_mem_sha256':digest(rom),'ipl_mem_sha256':digest(ipl),
              'scope':'actual shared Z80/controller EC..EF elapsed-time gate, not native calendar/year/power/DMA/hardware acceptance'}
    (folder/'manifest-before.json').write_text(json.dumps(manifest,indent=2)+'\n')
    for i,runner in enumerate(runners):
        frozen=folder/f'runner-{i}';shutil.copy2(runner,frozen)
        result=subprocess.run([str(frozen),f'+ROM={rom}',f'+IPL={ipl}'],cwd=folder,capture_output=True,text=True)
        label=('enabled','disabled')[i]
        (folder/f'{label}.log').write_text(result.stdout+result.stderr)
        if i==0:
            assert result.returncode==0 and 'PASS: shared machine real Z80 EC..EF' in result.stdout,(folder,result.stdout,result.stderr)
        else:
            assert result.returncode!=0 and 'machine RTC elapsed seconds mismatch sec=56 enabled=0' in result.stdout+result.stderr,(folder,result.stdout,result.stderr)
        assert digest(frozen)==hashes[str(runner)]
        print(f'PASS: {label} {"executes original CPU elapsed-time diagnostic" if i==0 else "rejected at missing-tick oracle"}',flush=True)
    assert hashes=={str(path):digest(path) for path in inputs},'source or runner changed during execution'
    for i,path in enumerate(inputs):assert digest(folder/f'input-{i}-{path.name}')==hashes[str(path)]
    assert digest(rom)==manifest['controller_mem_sha256'] and digest(ipl)==manifest['ipl_mem_sha256']
    (folder/'manifest-after.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(f'PASS: immutable shared-machine RTC evidence {folder}')


if __name__=='__main__':main()
