#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Freeze/qualify fair font-port arbitration with real frontend/backend.

Synthetic CPU/cache clients and DDR only; no machine reset/upload lifecycle,
native CPU/renderer, physical CDC, fitted resource or hardware acceptance.
"""
if not __debug__:
    raise SystemExit('Z_ARB_PYTHON_OPTIMIZATION_REFUSED')

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
       'rtl/x1_z_kanji_arbiter.sv','verilator/tests/x1_z_kanji_arbiter_tb.sv',
       'verilator/tests/test_z_kanji_arbiter.py')
BOUND={'rtl/x1_z_kanji_ddr.sv':'638861b6a6b06c0307e8bc045d239c766079b1875d6b8c3ab21fe4ea6248558d',
       'rtl/x1_z_kanji_frontend.sv':'ad8d27b111d4e59d1e10398c6c2e30e20a674bd77efb1c7b50ebe4b7509af95e'}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--review-smoke',action='store_true',help='one positive only; not full acceptance')
    args=parser.parse_args()
    resource.setrlimit(resource.RLIMIT_CORE,(0,0))
    out=Path(tempfile.mkdtemp(prefix='x1-z-kanji-arbiter-')).resolve()
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
        cmd=['verilator','--binary','--timing','--assert','-Wall','--top-module','x1_z_kanji_arbiter_tb',
             '--Mdir',str(obj),'-j','2',f'-GSYS_HALF_PS={half}',str(out/'sources'/FILES[0]),
             str(out/'sources'/FILES[1]),str(source),str(out/'sources'/FILES[3])]
        record={'name':tag,'command':cmd,'arbiter_sha256':sha(source),'sys_half_ps':half,
                'expected_rejection':marker}
        report['cases'].append(record);save()
        buildlog=out/(tag+'.build.log')
        with buildlog.open('w') as log:
            result=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=180)
        record['build_exit']=result.returncode
        record['warnings']=[line for line in buildlog.read_text().splitlines() if '%Warning' in line]
        save()
        assert result.returncode==0 and not record['warnings'],f'Build failure is not a matched rejection: {buildlog}'
        exe=obj/'Vx1_z_kanji_arbiter_tb'
        record['executable_sha256']=sha(exe)
        runlog=out/(tag+'.run.log')
        with runlog.open('w') as log:
            result=subprocess.run([str(exe)],stdout=log,stderr=subprocess.STDOUT,timeout=90,cwd=out)
        record['run_exit']=result.returncode;record['run_log_sha256']=sha(runlog)
        text=runlog.read_text();save()
        assert 'Z_ARB_TEST_TIMEOUT' not in text,f'{tag}: global timeout'
        if marker:
            failures=re.findall(r'Assertion failed[^\n]*?: (Z_ARB_\w+)',text)
            assert result.returncode!=0 and failures==[marker] and 'PASS Z_ARB' not in text,f'{tag}: {text}'
        else:
            lines=re.findall(r'^PASS Z_ARB (.+)$',text,re.M)
            assert result.returncode==0 and len(lines)==1,f'{tag}: {text}'
            counts={key:int(value) for key,value in re.findall(r'(\w+)=(\d+)',lines[0])}
            expected={'cases':9,'reads':77,'requests':77,'acks':77,'writes':262144,'sys_half':half}
            assert {key:counts[key] for key in expected}==expected,f'{tag}: {counts}'
            assert counts['edges']>1048576 and counts['cpu_ack_edges']>=32 and counts['cache_ack_edges']>=32
            record['counts']=counts
        record['verified']=True;save()
        print(f'PASS {tag} exit={result.returncode} cause={marker or "positive"}',flush=True)

    save()
    try:
        refusal=subprocess.run([sys.executable,'-O','-B',str(out/'sources'/FILES[-1])],
                               stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=10)
        (out/'optimized-python-refusal.log').write_text(refusal.stdout)
        assert refusal.returncode!=0 and 'Z_ARB_PYTHON_OPTIMIZATION_REFUSED' in refusal.stdout
        assert 'EVIDENCE=' not in refusal.stdout
        source=out/'sources'/FILES[2]
        qualify('sys32',source)
        if args.review_smoke:
            report['status']='review-smoke-pass'
        else:
            qualify('sys100',source,half=5000)
            original=source.read_text()
            mutations=(
                ('unfair-cpu','prefer_cache<=!choose_cache;',
                 'prefer_cache<=choose_cache;','Z_ARB_REQUEST_ORDER_ADDRESS'),
                ('swapped-address','held_address<=choose_cache ? cache_address : cpu_address;',
                 'held_address<=choose_cache ? cpu_address : cache_address;','Z_ARB_REQUEST_ORDER_ADDRESS'),
                ('unheld-address','assign font_address=held_address;',
                 'assign font_address=idle ? held_address : (owner_cache ? cache_address : cpu_address);','Z_ARB_ADDRESS_HELD'),
                ('corrupt-response','held_data<=font_data;',
                 "held_data<=font_data ^ 8'd1;",'Z_ARB_CPU_PAYLOAD'),
                ('stale-cpu-ack','(cpu_response_ack && cpu_ack_armed)',
                 '(cpu_response_ack && (cpu_ack_armed || cpu_response_ack))','Z_ARB_STALE_ACK'),
                ('stale-cache-ack','(cache_response_ack && cache_ack_armed)',
                 '(cache_response_ack && (cache_ack_armed || cache_response_ack))','Z_ARB_STALE_ACK'),
                ('early-cpu-retirement','(cpu_response_ack && cpu_ack_armed)',
                 '(cpu_response_ack || cpu_ack_armed)','Z_ARB_HELD_RESPONSE'),
                ('early-cache-retirement','(cache_response_ack && cache_ack_armed)',
                 '(cache_response_ack || cache_ack_armed)','Z_ARB_HELD_RESPONSE'),
                ('cpu-replay','cpu_read && cpu_armed &&',
                 '(cpu_read || cpu_armed) &&','Z_ARB_REQUEST_ORDER_ADDRESS'),
                ('cache-replay','cache_read && cache_armed;',
                 '(cache_read || cache_armed);','Z_ARB_REQUEST_ORDER_ADDRESS'),
                ('lost-cancel','if(!owner_cache && state!=IDLE) discard_cpu<=1;',
                 'if(!owner_cache && state!=IDLE) discard_cpu<=0;','Z_ARB_CPU_OWNER'),
                ('cache-cancelled','assign cache_valid=state==HELD && owner_cache;',
                 'assign cache_valid=state==HELD && owner_cache && !cpu_cancel;','Z_ARB_CACHE_QUIESCE_REPLY'),
                ('cache-admission-revokes-owner','assign cache_valid=state==HELD && owner_cache;',
                 'assign cache_valid=state==HELD && owner_cache && cache_enabled;','Z_ARB_CACHE_QUIESCE_REPLY'),
                ('cpu-admission-revokes-owner','state==HELD && !owner_cache && !cpu_cancel && !discard_cpu;',
                 'state==HELD && !owner_cache && !cpu_cancel && !discard_cpu && cpu_enabled;','Z_ARB_CPU_DISABLED_OWNER'),
                ('early-idle','assign idle=state==IDLE;',
                 'assign idle=state==IDLE || state==READ;','Z_ARB_FALSE_IDLE'),
                ('cpu-idle-leak',"assign cpu_data=cpu_valid ? held_data : 8'd0;",
                 'assign cpu_data=held_data;','Z_ARB_IDLE_CPU_DATA'),
                ('cache-idle-leak',"assign cache_data=cache_valid ? held_data : 8'd0;",
                 'assign cache_data=held_data;','Z_ARB_IDLE_CACHE_DATA'),
                ('early-read-release','state==READ || state==HELD || state==ACK;',
                 'state==READ;','Z_ARB_ACK_OWNER'),
                ('cpu-admission-ignored','cpu_enabled && cpu_read',
                 '(cpu_enabled || cpu_read) && cpu_read','Z_ARB_REQUEST_ORDER_ADDRESS'),
                ('cache-admission-ignored','cache_enabled && cache_read',
                 '(cache_enabled || cache_read) && cache_read','Z_ARB_REQUEST_ORDER_ADDRESS'),
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
    print(f"PASS Z_ARB {report['status']} runs={len(report['cases'])}; standalone synthetic only",flush=True)


if __name__=='__main__':
    main()
