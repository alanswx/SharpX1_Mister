#!/usr/bin/env python3
"""Frozen actual-stream completion/slow-consumer check; not WD/SD acceptance."""
import hashlib
import json
from pathlib import Path
import resource
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
out = Path(tempfile.mkdtemp(prefix='x1-fdc-completion-'))
sources = ['rtl/x1_fdc_completion.sv', 'rtl/x1_fdc_byte_slots.sv',
           'rtl/x1_fdc_stream_adapter.sv', 'verilator/tests/fdc_completion_tb.sv',
           'verilator/tests/test_fdc_completion.py']
digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
manifest = {}
for source in sources:
    dest = out / source
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(root / source, dest)
    manifest[source] = digest(dest)
(out / 'sources.json').write_text(json.dumps(manifest, indent=2) + '\n')
print('Frozen completion sources:', out, flush=True)
original = (out / sources[0]).read_text()
cases = [('original',None,None),
         ('pulse-only', "end else if(consume) valid <= 1'b0;", "end else valid <= 1'b0;"),
         ('drop-loss', 'result_lost <= lost;', "result_lost <= 1'b0;"),
         ('ignore-cancel', 'if(reset || cancel) begin', 'if(reset) begin')]
def no_core():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
for name,search,replacement in cases:
    rtl = out / sources[0]
    if search:
        assert original.count(search)==1, search
        rtl=out/(name+'.sv'); rtl.write_text(original.replace(search,replacement))
    build=out/name
    command=['verilator','--binary','--timing','--assert','--top-module',
             'fdc_completion_tb','--Mdir',str(build),'-j','2',str(rtl),
             *(str(out/s) for s in sources[1:4])]
    (out/(name+'.command.json')).write_text(json.dumps(command,indent=2)+'\n')
    with (out/(name+'.build.log')).open('w') as log:
        subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=180)
    result=subprocess.run([str(build/'Vfdc_completion_tb')],stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT,text=True,timeout=60,preexec_fn=no_core)
    (out/(name+'.run.log')).write_text(result.stdout)
    if search:
        assert result.returncode!=0 and 'completion lease mismatch' in result.stdout, result.stdout
        print('PASS matched completion negative:',name,flush=True)
    else:
        assert result.returncode==0 and 'PASS actual-stream completion lease:' in result.stdout,result.stdout
        print(result.stdout,end='',flush=True)
        invalid=subprocess.run([str(build/'Vfdc_completion_tb'),'+overwrite'],stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT,text=True,timeout=60,preexec_fn=no_core)
        (out/'overwrite.run.log').write_text(invalid.stdout)
        assert invalid.returncode!=0 and 'unconsumed FDC completion overwritten' in invalid.stdout,invalid.stdout
        print('PASS actual-producer illegal-overwrite contract rejection',flush=True)
for source,expected in manifest.items():
    assert digest(root/source)==digest(out/source)==expected,source
print('PASS frozen actual-stream completion lease; no WD/SD/CPU/hardware claim')
