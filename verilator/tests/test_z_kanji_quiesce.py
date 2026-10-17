#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Freeze/qualify font quiescence with real cache/arbiter/frontend/backend.

Synthetic host/CPU/VID requests and caller hold acknowledgement; no machine
reset dispatch, native renderer, physical CDC, combined fit or hardware acceptance.
"""
if not __debug__:
    raise SystemExit('Z_QUIESCE_PYTHON_OPTIMIZATION_REFUSED')

import argparse
import hashlib
import json
from pathlib import Path
import re
import resource
import subprocess
import sys
import tempfile

ROOT=Path(__file__).resolve().parents[2]
FILES=('rtl/x1_z_kanji_ddr.sv','rtl/x1_z_kanji_frontend.sv',
       'rtl/x1_z_kanji_cache.sv','rtl/x1_z_kanji_arbiter.sv','rtl/x1_z_kanji_quiesce.sv',
       'verilator/tests/x1_z_kanji_quiesce_tb.sv','verilator/tests/test_z_kanji_quiesce.py')
BOUND={'rtl/x1_z_kanji_ddr.sv':'638861b6a6b06c0307e8bc045d239c766079b1875d6b8c3ab21fe4ea6248558d',
       'rtl/x1_z_kanji_frontend.sv':'ad8d27b111d4e59d1e10398c6c2e30e20a674bd77efb1c7b50ebe4b7509af95e',
       'rtl/x1_z_kanji_cache.sv':'e9671fb7ef9548f265cc50c4e3effdc6358c3d292c90eca1ca2b4788ca310f0e',
       'rtl/x1_z_kanji_arbiter.sv':'e97c58a3890a542af7056fc16ccd8a6a18720f0b744b29b19699f33e37eca0a6'}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--review-smoke',action='store_true',help='one positive only; not full acceptance')
    args=parser.parse_args()
    resource.setrlimit(resource.RLIMIT_CORE,(0,0))
    out=Path(tempfile.mkdtemp(prefix='x1-z-kanji-quiesce-')).resolve()
    print(f'EVIDENCE={out}',flush=True)
    hashes={name:sha(ROOT/name) for name in FILES}
    assert all(hashes[name]==value for name,value in BOUND.items()),'Qualified dependency changed'
    for name in FILES:
        dest=out/'sources'/name
        dest.parent.mkdir(parents=True,exist_ok=True)
        dest.write_bytes((ROOT/name).read_bytes())
        assert sha(dest)==hashes[name]
    report={'scope':__doc__,'source_sha256':hashes,'cases':[],'status':'running',
            'tool':subprocess.check_output(['verilator','--version'],text=True).strip()}

    def save():
        (out/'terminal.json').write_text(json.dumps(report,indent=2)+'\n')

    def qualify(tag,source,half=15625,marker=None):
        obj=out/('obj-'+tag)
        cmd=['verilator','--binary','--timing','--assert','-Wall','--top-module','x1_z_kanji_quiesce_tb',
             '--Mdir',str(obj),'-j','2',f'-GSYS_HALF_PS={half}',str(out/'sources'/FILES[0]),
             str(out/'sources'/FILES[1]),str(out/'sources'/FILES[2]),
             str(out/'sources'/FILES[3]),str(source),str(out/'sources'/FILES[5])]
        record={'name':tag,'command':cmd,'quiesce_sha256':sha(source),'sys_half_ps':half,
                'expected_rejection':marker}
        report['cases'].append(record);save()
        buildlog=out/(tag+'.build.log')
        with buildlog.open('w') as log:
            result=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=180)
        record['build_exit']=result.returncode
        record['warnings']=[line for line in buildlog.read_text().splitlines() if '%Warning' in line]
        save()
        assert result.returncode==0 and not record['warnings'],f'Build failure is not a matched rejection: {buildlog}'
        exe=obj/'Vx1_z_kanji_quiesce_tb'
        record['executable_sha256']=sha(exe)
        runlog=out/(tag+'.run.log')
        with runlog.open('w') as log:
            result=subprocess.run([str(exe)],stdout=log,stderr=subprocess.STDOUT,timeout=90,cwd=out)
        record['run_exit']=result.returncode;record['run_log_sha256']=sha(runlog)
        text=runlog.read_text();save()
        assert 'Z_QUIESCE_TEST_TIMEOUT' not in text,f'{tag}: global timeout'
        if marker:
            failures=re.findall(r'Assertion failed[^\n]*?: (Z_QUIESCE_\w+)',text)
            assert result.returncode!=0 and failures==[marker] and 'PASS Z_QUIESCE' not in text,f'{tag}: {text}'
        else:
            lines=re.findall(r'^PASS Z_QUIESCE (.+)$',text,re.M)
            assert result.returncode==0 and len(lines)==1,f'{tag}: {text}'
            counts={key:int(value) for key,value in re.findall(r'(\w+)=(\d+)',lines[0])}
            expected={'cases':5,'reads':68,'requests':68,'acks':68,'writes':786435,
                      'updates':4,'cancels':5,'cold_cancels':2,'sys_half':half}
            assert {key:counts[key] for key in expected}==expected,f'{tag}: {counts}'
            assert counts['edges']>3145728
            record['counts']=counts
        record['verified']=True;save()
        print(f'PASS {tag} exit={result.returncode} cause={marker or "positive"}',flush=True)

    save()
    try:
        refusal=subprocess.run([sys.executable,'-O','-B',str(out/'sources'/FILES[-1])],
                               stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=10)
        (out/'optimized-python-refusal.log').write_text(refusal.stdout)
        assert refusal.returncode!=0 and 'Z_QUIESCE_PYTHON_OPTIMIZATION_REFUSED' in refusal.stdout
        assert 'EVIDENCE=' not in refusal.stdout
        source=out/'sources'/FILES[4]
        qualify('sys32',source)
        if args.review_smoke:
            report['status']='review-smoke-pass'
        else:
            qualify('sys100',source,half=5000)
            original=source.read_text()
            mutations=(
                ('cache-starved-during-drain','state==RUN || state==CACHE',
                 'state==RUN || (state==CACHE && !consumers_quiescent)','Z_QUIESCE_PAUSE_PROGRESS'),
                ('skip-cache-drain','CACHE: if(cache_invalidate_done)',
                 'CACHE: if(cache_invalidate_done || (loaded && consumers_quiescent))','Z_QUIESCE_UNDRAINED_PERMISSION'),
                ('skip-arbiter-drain','ARBITER: if(arbiter_idle)',
                 'ARBITER: if(arbiter_idle || loaded)','Z_QUIESCE_UNDRAINED_PERMISSION'),
                ('skip-consumer-hold','CONSUMERS: if(consumers_quiescent)',
                 'CONSUMERS: if(!consumers_quiescent || consumers_quiescent)',
                 'Z_QUIESCE_UNDRAINED_PERMISSION'),
                ('early-frontend-cancel','assign frontend_cancel=state==CANCEL;',
                 'assign frontend_cancel=state==CANCEL || state==CACHE;',
                 'Z_QUIESCE_UNDRAINED_PERMISSION'),
                ('skip-invalidation','assign cache_invalidate=state==CACHE;',
                 'assign cache_invalidate=state==ARBITER;','Z_QUIESCE_PAUSE_PROGRESS'),
                ('lose-cold-pulse','if(cold_start) cold_pending<=1;',
                 'if(cold_start && state==PAUSED) cold_pending<=1;','Z_QUIESCE_COLD_LOSS'),
                ('cold-does-not-reset-font','state==CANCEL && cold_pending;',
                 'state==CANCEL && cold_pending && cold_reset_request;', 'Z_QUIESCE_COLD_LOSS'),
                ('aborted-download-restarts','!cold_reset_request && !upload_blocked;',
                 '!cold_reset_request && (!upload_blocked || host_download);','Z_QUIESCE_ABORT_RESTARTED'),
                ('release-owned-upload','!upload_active && !host_download &&',
                 '(upload_active || !upload_active) && !host_download &&','Z_QUIESCE_OWNED_UPLOAD_RELEASE'),
                ('release-held-pause','!pause_request && !cold_reset_request;',
                 '(pause_request || !pause_request) && !cold_reset_request;','Z_QUIESCE_HELD_PAUSE'),
            )
            for tag,old,new,marker in mutations:
                assert original.count(old)==1,(tag,original.count(old))
                dest=out/'mutants'/tag/source.name
                dest.parent.mkdir(parents=True);dest.write_text(original.replace(old,new))
                qualify(tag,dest,marker=marker)
            report['status']='pass'
    except BaseException as error:
        report.update(status='failed',error=repr(error))
        raise
    finally:
        current={name:sha(ROOT/name) for name in FILES}
        frozen={name:sha(out/'sources'/name) for name in FILES}
        report['sources_unchanged']=current==frozen==hashes
        if not report['sources_unchanged']: report['status']='failed'
        save()
        assert report['sources_unchanged'],'Original/frozen source changed'
    print(f"PASS Z_QUIESCE {report['status']} runs={len(report['cases'])}; standalone synthetic only",flush=True)


if __name__=='__main__':
    main()
