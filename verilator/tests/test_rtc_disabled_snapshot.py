"""Check default state compatibility against an actual pre-RTC executable.

Generated counter program/state only; never patch/convert serialized bytes.
This is not enabled-RTC snapshot support or permission to reuse game states.
"""
import hashlib
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile


def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    reference,current=[pathlib.Path(arg).resolve() for arg in sys.argv[1:]]
    folder=pathlib.Path(tempfile.mkdtemp(prefix='rtc-disabled-state-',dir=current.parent))
    hashes=[digest(reference),digest(current)]
    copies=[]
    for i,path in enumerate((reference,current)):
        copied=folder/f'runner-{i}';shutil.copy2(path,copied);copies.append(copied)
    program=folder/'counter.bin'
    program.write_bytes(bytes((0x21,0,0xf0,0x34,0xc3,3,0x80)))
    state=folder/'original.state'
    def run(exe,arguments,label):
        result=subprocess.run([str(exe),*arguments],capture_output=True,text=True)
        (folder/f'{label}.stdout').write_text(result.stdout)
        (folder/f'{label}.stderr').write_text(result.stderr)
        assert result.returncode==0,(folder,label,result.stderr)
        return json.loads(result.stdout.splitlines()[-1])
    run(copies[0],['--cycles','10000','--ram',str(program),'--save-state',str(state)],'pre-rtc')
    state_hash=digest(state)
    resumed=run(copies[1],['--cycles','10000','--restore-state',str(state),'--dump',str(folder/'resumed')],'restored')
    straight=run(copies[1],['--cycles','20000','--ram',str(program),'--dump',str(folder/'straight')],'straight')
    for key in ('time_ps','sys_edges','video_edges','reset_edges','cpu_enables',
                'delayed_sys_edges','cpu_address','peek','sub_pc','sub_address','sub_control'):
        assert resumed[key]==straight[key],(key,resumed,straight)
    for suffix in ('ram','text','attr'):
        assert (folder/f'resumed.{suffix}').read_bytes()==(folder/f'straight.{suffix}').read_bytes(),suffix
    assert digest(state)==state_hash and hashes==[digest(reference),digest(current)]
    assert hashes==[digest(path) for path in copies]
    evidence={'reference_sha256':hashes[0],'current_sha256':hashes[1],
              'unchanged_original_state_sha256':state_hash,
              'scope':'default RTC-disabled v17 generated counter state only, not enabled RTC/native/game state acceptance'}
    (folder/'provenance.json').write_text(json.dumps(evidence,indent=2)+'\n')
    print(f'PASS: actual pre-RTC default state restores without modification and matches uninterrupted CPU/clock/RAM/text/attribute state; {folder}')


if __name__=='__main__':main()
