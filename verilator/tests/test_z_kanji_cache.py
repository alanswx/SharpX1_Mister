#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Freeze/qualify the standalone glyph cache with the real frontend/backend.

Synthetic DDR and public pins only. No machine, native visibility, physical
CDC/RAM, fitted resource or hardware qualification. Every attempt is preserved.
"""
if not __debug__:
    raise SystemExit('Z_CACHE_PYTHON_OPTIMIZATION_REFUSED')

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
       'rtl/x1_z_kanji_cache.sv','verilator/tests/x1_z_kanji_cache_tb.sv',
       'verilator/tests/test_z_kanji_cache.py')
BOUND={'rtl/x1_z_kanji_ddr.sv':'638861b6a6b06c0307e8bc045d239c766079b1875d6b8c3ab21fe4ea6248558d',
       'rtl/x1_z_kanji_frontend.sv':'ad8d27b111d4e59d1e10398c6c2e30e20a674bd77efb1c7b50ebe4b7509af95e'}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--review-smoke',action='store_true',help='one small positive; not full acceptance')
    args=parser.parse_args()
    resource.setrlimit(resource.RLIMIT_CORE,(0,0))
    out=Path(tempfile.mkdtemp(prefix='x1-z-kanji-cache-')).resolve()
    print(f'EVIDENCE={out}',flush=True)
    hashes={name:sha(ROOT/name) for name in FILES}
    assert all(hashes[name]==digest for name,digest in BOUND.items()),'Qualified dependency changed'
    for name in FILES:
        path=out/'sources'/name
        path.parent.mkdir(parents=True,exist_ok=True)
        path.write_bytes((ROOT/name).read_bytes())
        assert sha(path)==hashes[name]
    report={'scope':__doc__,'source_sha256':hashes,'cases':[],'status':'running',
            'tool':subprocess.check_output(['verilator','--version'],text=True).strip()}

    def save():
        (out/'terminal.json').write_text(json.dumps(report,indent=2)+'\n')

    def qualify(tag,source,bits=3,sys_half=15625,vid_half=11640,marker=None):
        obj=out/('obj-'+tag)
        cmd=['verilator','--binary','--timing','--assert','-Wall','--top-module','x1_z_kanji_cache_tb',
             '--Mdir',str(obj),'-j','2',f'-GCELL_BITS={bits}',f'-GSYS_HALF_PS={sys_half}',
             f'-GVID_HALF_PS={vid_half}',str(out/'sources'/FILES[0]),str(out/'sources'/FILES[1]),
             str(source),str(out/'sources'/FILES[3])]
        record={'name':tag,'command':cmd,'cache_sha256':sha(source),'cell_bits':bits,
                'sys_half_ps':sys_half,'vid_half_ps':vid_half,'expected_rejection':marker}
        report['cases'].append(record);save()
        buildlog=out/(tag+'.build.log')
        with buildlog.open('w') as log:
            result=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=180)
        record['build_exit']=result.returncode
        record['warnings']=[line for line in buildlog.read_text().splitlines() if '%Warning' in line]
        save()
        assert result.returncode==0 and not record['warnings'],f'Compiler failure is not a matched negative: {buildlog}'
        exe=obj/'Vx1_z_kanji_cache_tb'
        record['executable_sha256']=sha(exe)
        runlog=out/(tag+'.run.log')
        with runlog.open('w') as log:
            result=subprocess.run([str(exe)],stdout=log,stderr=subprocess.STDOUT,timeout=240,cwd=out)
        record['run_exit']=result.returncode;record['run_log_sha256']=sha(runlog)
        text=runlog.read_text();save()
        assert 'Z_CACHE_TEST_TIMEOUT' not in text,f'{tag}: global timeout'
        if marker:
            failures=re.findall(r'Assertion failed[^\n]*?: (Z_CACHE_\w+)',text)
            assert result.returncode!=0 and failures==[marker] and 'PASS Z_CACHE' not in text,f'{tag}: {text}'
        else:
            lines=re.findall(r'^PASS Z_CACHE (.+)$',text,re.M)
            assert result.returncode==0 and len(lines)==1,f'{tag}: {text}'
            counts={key:int(value) for key,value in re.findall(r'(\w+)=(\d+)',lines[0])}
            cells=1<<bits
            expected={'cells':cells,'updates':5*cells+6,'invalidations':8,'cases':9,
                      'writes':524288,'reads':160*cells+241,'physical_bytes':262144 if bits==11 else 0,
                      'sys_half':sys_half,'vid_half':vid_half}
            assert {key:counts[key] for key in expected}==expected,f'{tag}: {counts}'
            assert counts['replies']>cells*32 and counts['vid_edges']>counts['replies']>0
            record['counts']=counts
        record['verified']=True;save()
        print(f'PASS {tag} exit={result.returncode} cause={marker or "positive"}',flush=True)

    save()
    try:
        refusal=subprocess.run([sys.executable,'-O','-B',str(out/'sources'/FILES[-1])],
                               stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=10)
        (out/'optimized-python-refusal.log').write_text(refusal.stdout)
        assert refusal.returncode!=0 and 'Z_CACHE_PYTHON_OPTIMIZATION_REFUSED' in refusal.stdout
        assert 'EVIDENCE=' not in refusal.stdout
        source=out/'sources'/FILES[2]
        if args.review_smoke:
            qualify('review',source)
            report['status']='review-smoke-pass'
        else:
            qualify('full-32mhz',source,bits=11)
            qualify('full-100mhz',source,bits=11,sys_half=5000)
            qualify('slow-vid',source,sys_half=5000,vid_half=20000)
            original=source.read_text()
            mutations=(
                ('visible-bank-refill','target_bank<=!active_bank[update_cell];',
                 'target_bank<=active_bank[update_cell];','Z_CACHE_ATOMIC_DATA',1),
                ('wrong-font-row','font_address={held_glyph,fill_offset};',
                 "font_address={held_glyph,fill_offset ^ 5'd1};",'Z_CACHE_FONT_ADDRESS',1),
                ('wrong-font-level','held_glyph<=update_glyph;',
                 "held_glyph<=update_glyph ^ 13'h1000;",'Z_CACHE_FONT_ADDRESS',1),
                ('descriptor-corruption','held_descriptor<=update_descriptor;',
                 "held_descriptor<=update_descriptor ^ 32'd1;",'Z_CACHE_DESCRIPTOR_OWNER',1),
                ('unheld-descriptor','{target_bank,held_glyph,held_descriptor}',
                 '{target_bank,held_glyph,update_descriptor}','Z_CACHE_DESCRIPTOR_OWNER',2),
                ('wrong-collision-forward','held_cell==vid_cell',
                 'held_cell!=vid_cell','Z_CACHE_COMMIT_FORWARD',1),
                ('wrong-cache-offset','glyph_bank1[{held_cell,fill_offset}]<=font_data;',
                 "glyph_bank1[{held_cell,fill_offset ^ 5'd1}]<=font_data;",'Z_CACHE_ATOMIC_DATA',1),
                ('invalid-ink',"glyph_read0) : 8'd0;",
                 "glyph_read0) : (vid_response_valid ? 8'h80 : 8'd0);",'Z_CACHE_INVALID_INK',1),
                ('wrong-reply-latency','vid_response_valid<=stage_request;',
                 'vid_response_valid<=vid_request;','Z_CACHE_REPLY_LATENCY',1),
                ('idle-data-leak',"glyph_read0) : 8'd0;",
                 "glyph_read0) : (vid_response_valid ? 8'd0 : 8'h80);",'Z_CACHE_IDLE_REPLY',1),
                ('invalidated-cells-survive','if(held_flush) visible<=0;',
                 'if(held_flush) visible<=visible;','Z_CACHE_DESCRIPTOR_OWNER',1),
                ('early-ack','request_seen<=req_sync;ack_pending<=1;',
                 'request_seen<=req_sync;ack_pending<=0;acknowledgement<=req_sync;','Z_CACHE_INVALIDATE_RETIRE',1),
                ('incomplete-glyph','else if(fill_offset==31)',
                 'else if(fill_offset==30)','Z_CACHE_EARLY_PUBLICATION',1),
                ('wrong-published-bank','{target_bank,held_glyph,held_descriptor}',
                 '{!target_bank,held_glyph,held_descriptor}','Z_CACHE_ATOMIC_DATA',2),
                ('lost-invalidate-pulse','if(invalidate && state!=INVALIDATED) flush_pending<=1;',
                 'if(invalidate && state==IDLE) flush_pending<=1;','Z_CACHE_CANCEL_REFILL',1),
                ('ready-while-completion-held','assign update_ready=state==IDLE &&',
                 'assign update_ready=(state==IDLE || state==DONE) &&','Z_CACHE_DONE_NOT_HELD',1),
            )
            for tag,old,new,marker,occurrences in mutations:
                assert original.count(old)==occurrences,(tag,original.count(old))
                mutated=out/'mutants'/tag/source.name
                mutated.parent.mkdir(parents=True);mutated.write_text(original.replace(old,new))
                qualify(tag,mutated,marker=marker)
            report['status']='pass'
    except BaseException as error:
        report.update(status='failed',error=repr(error))
        raise
    finally:
        current={name:sha(ROOT/name) for name in FILES}
        copies={name:sha(out/'sources'/name) for name in FILES}
        report['sources_unchanged']=current==copies==hashes
        if not report['sources_unchanged']: report['status']='failed'
        save()
        assert report['sources_unchanged'],'Original/frozen source changed'
    print(f"PASS Z_CACHE {report['status']} profiles={len(report['cases'])}; standalone synthetic only",flush=True)


if __name__=='__main__':
    main()
