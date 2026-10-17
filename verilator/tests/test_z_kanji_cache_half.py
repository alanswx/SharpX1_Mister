#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Freeze/qualify committed-descriptor half selection in the real font cache.

Real frontend/backend, generated full font and mock DDR. No machine renderer,
native write visibility, physical CDC, fitted timing or hardware acceptance.
"""
if not __debug__:
    raise SystemExit('Z_HALF_OPTIMIZED_PYTHON_REFUSED')

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
FILES=('rtl/x1_z_kanji_ddr.sv','rtl/x1_z_kanji_frontend.sv','rtl/x1_z_kanji_cache.sv',
       'verilator/tests/x1_z_kanji_cache_half_tb.sv','verilator/tests/test_z_kanji_cache_half.py')
BOUND={'rtl/x1_z_kanji_ddr.sv':'638861b6a6b06c0307e8bc045d239c766079b1875d6b8c3ab21fe4ea6248558d',
       'rtl/x1_z_kanji_frontend.sv':'ad8d27b111d4e59d1e10398c6c2e30e20a674bd77efb1c7b50ebe4b7509af95e'}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--review-smoke',action='store_true',help='one small positive; not acceptance')
    args=parser.parse_args()
    resource.setrlimit(resource.RLIMIT_CORE,(0,0))
    out=Path(tempfile.mkdtemp(prefix='x1-z-kanji-cache-half-')).resolve()
    print(f'EVIDENCE={out}',flush=True)
    hashes={name:sha(ROOT/name) for name in FILES}
    assert all(hashes[name]==value for name,value in BOUND.items()),'Qualified dependency changed'
    for name in FILES:
        dest=out/'sources'/name;dest.parent.mkdir(parents=True,exist_ok=True)
        dest.write_bytes((ROOT/name).read_bytes());assert sha(dest)==hashes[name]
    report={'scope':__doc__,'status':'running','cases':[],'source_sha256':hashes,
            'tool':subprocess.check_output(['verilator','--version'],text=True).strip()}
    def save(): (out/'terminal.json').write_text(json.dumps(report,indent=2)+'\n')
    def qualify(tag,source,bits=3,width=32,half=22,sys_half=15625,vid_half=11640,marker=None,parameter=False):
        obj=out/('obj-'+tag)
        top='x1_z_kanji_cache' if parameter else 'x1_z_kanji_cache_half_tb'
        cmd=['verilator','--binary','--timing','--assert','-Wall','--top-module',top,
             '--Mdir',str(obj),'-j','2',f'-GCELL_BITS={bits}',f'-GDESCRIPTOR_WIDTH={width}']
        if parameter: cmd.extend([f'-GVID_DESCRIPTOR_HALF_BIT={half}',str(source)])
        else:
            cmd.extend([f'-GHALF_BIT={half}',f'-GSYS_HALF_PS={sys_half}',f'-GVID_HALF_PS={vid_half}',
                        str(out/'sources'/FILES[0]),str(out/'sources'/FILES[1]),str(source),str(out/'sources'/FILES[3])])
        case={'name':tag,'command':cmd,'cache_sha256':sha(source),'cell_bits':bits,'descriptor_width':width,
              'half_bit':half,'sys_half_ps':sys_half,'vid_half_ps':vid_half,
              'expected_rejection':marker,'parameter_rejection':parameter}
        report['cases'].append(case);save()
        buildlog=out/(tag+'.build.log')
        with buildlog.open('w') as log:
            result=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=180)
        case['build_exit']=result.returncode;case['build_log_sha256']=sha(buildlog)
        case['warnings']=[line for line in buildlog.read_text().splitlines() if '%Warning' in line];save()
        assert result.returncode==0 and not case['warnings'],f'Build failure is not a rejection: {buildlog}'
        exe=obj/('V'+top);case['executable_sha256']=sha(exe)
        runlog=out/(tag+'.run.log')
        with runlog.open('w') as log:
            result=subprocess.run([str(exe)],stdout=log,stderr=subprocess.STDOUT,timeout=180,cwd=out)
        case['run_exit']=result.returncode;case['run_log_sha256']=sha(runlog)
        text=runlog.read_text();save()
        assert 'Z_HALF_TEST_TIMEOUT' not in text,'Global timeout is not qualification'
        if marker:
            failures=re.findall(r'Assertion failed[^\n]*?: (Z_(?:HALF|CACHE)_\w+)',text)
            assert result.returncode!=0 and failures==[marker] and 'PASS Z_HALF' not in text,(tag,text)
        else:
            lines=re.findall(r'^PASS Z_HALF (.+)$',text,re.M)
            assert result.returncode==0 and len(lines)==1,(tag,text)
            counts={key:int(value) for key,value in re.findall(r'(\w+)=(\d+)',lines[0])}
            cells=1<<bits
            expected={'cells':cells,'updates':cells*3+1,'reads':32*(cells*3+1),'writes':262144,
                      'invalidations':1,'width':width,'half_bit':half,'sys_half':sys_half,'vid_half':vid_half}
            assert {key:counts[key] for key in expected}==expected,counts
            assert counts['poison']>cells*16 and counts['replies']>cells*16
            assert counts['vid_edges']>counts['replies'] and counts['sys_edges']>1048576
            case['counts']=counts
        case['verified']=True;save()
        print(f'PASS {tag} exit={result.returncode} cause={marker or "positive"}',flush=True)
    save()
    try:
        refusal=subprocess.run([sys.executable,'-O','-B',str(out/'sources'/FILES[-1])],
            stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=10)
        (out/'optimized-python-refusal.log').write_text(refusal.stdout)
        assert refusal.returncode!=0 and 'Z_HALF_OPTIMIZED_PYTHON_REFUSED' in refusal.stdout
        assert 'EVIDENCE=' not in refusal.stdout
        source=out/'sources'/FILES[2]
        if args.review_smoke:
            qualify('review',source);report['status']='review-smoke-pass'
        else:
            qualify('full32',source,bits=11)
            qualify('full100',source,bits=11,sys_half=5000)
            qualify('one-bit-slow-vid',source,width=1,half=0,sys_half=5000,vid_half=20000)
            qualify('wide-top-bit',source,width=64,half=63)
            original=source.read_text()
            mutations=(
                ('caller-half','stage_hit && stage_entry[VID_DESCRIPTOR_HALF_BIT]',
                 'stage_hit && stage_offset[0]','Z_HALF_COMMITTED_OFFSET',1),
                ('returned-half-zero','stage_request ? read_offset :',
                 "stage_request ? {read_offset[4:1],1'b0} :",'Z_HALF_COMMITTED_OFFSET',1),
                ('data-uses-caller','[{stage_cell,read_offset}]',
                 '[{stage_cell,stage_offset}]','Z_HALF_COMMITTED_DATA',2),
                ('unforwarded-half','stage_hit && stage_entry[VID_DESCRIPTOR_HALF_BIT]',
                 'stage_hit && descriptor_read[VID_DESCRIPTOR_HALF_BIT]','Z_HALF_COMMITTED_OFFSET',1),
                ('pending-sys-half','stage_hit && stage_entry[VID_DESCRIPTOR_HALF_BIT]',
                 'stage_hit && held_descriptor[VID_DESCRIPTOR_HALF_BIT]','Z_HALF_COMMITTED_OFFSET',1),
                ('live-input-half','stage_hit && stage_entry[VID_DESCRIPTOR_HALF_BIT]',
                 'stage_hit && update_descriptor[VID_DESCRIPTOR_HALF_BIT]','Z_HALF_COMMITTED_OFFSET',1),
                ('invalid-half-leak','stage_hit && stage_entry[VID_DESCRIPTOR_HALF_BIT]',
                 'stage_entry[VID_DESCRIPTOR_HALF_BIT]','Z_HALF_INVALID_HALF',1),
                ('flipped-half','stage_hit && stage_entry[VID_DESCRIPTOR_HALF_BIT]',
                 'stage_hit && !stage_entry[VID_DESCRIPTOR_HALF_BIT]','Z_HALF_COMMITTED_OFFSET',1),
                ('adjacent-descriptor-bit','stage_hit && stage_entry[VID_DESCRIPTOR_HALF_BIT]',
                 'stage_hit && stage_entry[(VID_DESCRIPTOR_HALF_BIT+1)%DESCRIPTOR_WIDTH]','Z_HALF_COMMITTED_OFFSET',1),
                ('missing-commit-forward','held_cell==vid_cell',
                 'held_cell!=vid_cell','Z_HALF_COMMIT_FORWARD',1),
                ('live-row','read_offset={stage_offset[4:1],',
                 'read_offset={(vid_request ? vid_offset[4:1] : stage_offset[4:1]),','Z_HALF_REPLY_TAG',1),
            )
            for tag,old,new,marker,count in mutations:
                assert original.count(old)==count,(tag,original.count(old))
                dest=out/'mutants'/tag/source.name;dest.parent.mkdir(parents=True)
                dest.write_text(original.replace(old,new));qualify(tag,dest,marker=marker)
            qualify('negative-bit',source,half=-2,marker='Z_CACHE_PARAMETERS',parameter=True)
            qualify('outside-descriptor',source,half=32,marker='Z_CACHE_PARAMETERS',parameter=True)
            report['status']='pass'
    except BaseException as error:
        report.update(status='failed',error=repr(error));raise
    finally:
        report['sources_unchanged']=all(sha(ROOT/name)==sha(out/'sources'/name)==digest for name,digest in hashes.items())
        if not report['sources_unchanged']: report['status']='failed'
        save();assert report['sources_unchanged'],'Original/frozen source changed'
    print(f"PASS Z_HALF {report['status']} runs={len(report['cases'])}; committed-cache bytes only",flush=True)


if __name__=='__main__':
    main()
