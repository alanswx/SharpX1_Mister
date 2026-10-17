#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Freeze/qualify real CPU writes through three VRAMs and the glyph cache.

Provisional standalone refill-before-write WAIT. Generated program/font,
mock DDR, synthetic cache scans; no machine RGB, native ASIC or board claim.
"""
if not __debug__:
    raise SystemExit('Z_VRAM_OPTIMIZED_PYTHON_REFUSED')
import argparse
import csv
import hashlib
import json
from pathlib import Path
import re
import resource
import subprocess
import sys
import tempfile

ROOT=Path(__file__).resolve().parents[2]
WRITER='rtl/x1_z_kanji_vram_write.sv'
TB='verilator/tests/x1_z_kanji_vram_tb.sv'
LEDGER='verilator/tests/z_kanji_vram_warnings.json'
RTL=(WRITER,'rtl/x1_z_kanji_cache.sv','rtl/x1_z_kanji_frontend.sv','rtl/x1_z_kanji_ddr.sv',
     'rtl/x1_video_ram.v','rtl/cpu.v','rtl/tv80/tv80e.v','rtl/tv80/tv80_core.v',
     'rtl/tv80/tv80_mcode.v','rtl/tv80/tv80_alu.v','rtl/tv80/tv80_reg.v')
FILES=(*RTL,TB,LEDGER,'verilator/tests/test_z_kanji_vram.py')
BOUND={'rtl/x1_z_kanji_cache.sv':'e9671fb7ef9548f265cc50c4e3effdc6358c3d292c90eca1ca2b4788ca310f0e',
       'rtl/x1_z_kanji_frontend.sv':'ad8d27b111d4e59d1e10398c6c2e30e20a674bd77efb1c7b50ebe4b7509af95e',
       'rtl/x1_z_kanji_ddr.sv':'638861b6a6b06c0307e8bc045d239c766079b1875d6b8c3ab21fe4ea6248558d'}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def order(rows):return sorted(rows,key=lambda row:json.dumps(row,sort_keys=True))
def reference(cells):
    code=bytearray((0xf3,0x31,0xff,0xff,0x3e,0,0x32,0,0xf0));ops=[]
    for g in range(8):
        cell=cells-1-g%3
        for port,select,value in ((0x3000|cell,1,(g*37+11)&255),(0x2800|cell,2,(g*13+1)&255),
                                  (0x3800|cell,4,0x80|(g<<4)|g)):
            code.extend((1,port&255,port>>8,0x3e,value,0xed,0x79,0xed,0x78,0xfe,value,0xc2,0,0xf1))
            ops.append((port,select,cell,value))
    code.extend((0x3e,0xa5,0x32,0,0xf0,0x76));image=bytearray(65536);image[:len(code)]=code
    image[0xf100:0xf106]=bytes((0x3e,0xee,0x32,0,0xf0,0x76))
    return bytes(image),ops

def audit_cpu(folder,cells,counts=None,fault=False):
    image,ops=reference(cells)
    actual=bytes(int(v,16) for v in (folder/'program.hex').read_text().split());assert actual==image
    model=[(7<<24)|((0x80|c%128)<<16)|(((c*17+3)&255)<<8)|((c*31+7)&255) for c in range(cells)]
    model[-1]=(model[-1]&~255)|0x92;model[-1]=(model[-1]&~0xff0000)|(0xdf<<16)
    model[-2]=(model[-2]&~0xff00)|(0x35<<8)
    expected=[]
    for boot,limit in ((1,1),) if fault else ((1,24),(2,10),(3,24)):
        for port,select,cell,value in ops[:limit]:
            shift={1:0,2:8,4:16}[select];model[cell]=(model[cell]&~(255<<shift))|(value<<shift)
            descriptor=model[cell];glyph=((descriptor>>16)&31)*256+(descriptor&255)
            expected.append((boot,port,select,cell,value,descriptor,glyph))
    rows=[tuple(int(row[k]) for k in ('boot','port','select','cell','data','descriptor','glyph')) for row in csv.DictReader((folder/'trace.csv').open())]
    assert rows==expected,'Independent real CPU OUT/descriptor intent audit failed'
    observed=[tuple(int(row[k]) for k in ('boot','port','value')) for row in csv.DictReader((folder/'reads.csv').open())]
    if fault:
        assert observed==[(1,ops[0][0],ops[0][3]^1)],observed
    else:
        expected_reads=[(boot,op[0],op[3]) for boot,limit in ((1,24),(2,9),(3,24)) for op in ops[:limit]]
        assert observed==expected_reads,('Independent CPU IN samples failed',observed)
        assert counts['cpu_writes']==len(rows)==58
    return {'program_sha256':hashlib.sha256(image).hexdigest(),'cpu_writes':len(rows),'cpu_reads':len(observed)}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--review-smoke',action='store_true',help='one small positive; not acceptance')
    args=parser.parse_args();resource.setrlimit(resource.RLIMIT_CORE,(0,0))
    out=Path(tempfile.mkdtemp(prefix='x1-z-kanji-vram-')).resolve();print('EVIDENCE='+str(out),flush=True)
    hashes={name:sha(ROOT/name) for name in FILES};ledger=json.loads((ROOT/LEDGER).read_text())
    assert all(hashes[name]==value for name,value in {**BOUND,**ledger['source_sha256']}.items()),'Qualified dependency changed'
    for name in FILES:
        p=out/'sources'/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes((ROOT/name).read_bytes());assert sha(p)==hashes[name]
    report={'scope':__doc__,'source_sha256':hashes,'status':'running','cases':[],
            'tool':subprocess.check_output(['verilator','--version'],text=True).strip()}
    def save():(out/'terminal.json').write_text(json.dumps(report,indent=2)+'\n')
    def qualify(tag,source,bits=3,sys_half=15625,vid_half=11640,ce=8,marker=None,cpu_fault=False):
        folder=out/tag;folder.mkdir();obj=folder/'obj'
        cmd=['verilator','--binary','--timing','--assert','-Wall','-Wno-fatal','--top-module','x1_z_kanji_vram_tb',
             '--Mdir',str(obj),'-j','2',f'-GCELL_BITS={bits}',f'-GSYS_HALF_PS={sys_half}',
             f'-GVID_HALF_PS={vid_half}',f'-GCE_PERIOD={ce}',f'-GCPU_READ_FAULT={int(cpu_fault)}',
             str(source),*[str(out/'sources'/name) for name in RTL[1:]],str(out/'sources'/TB)]
        c={'name':tag,'command':cmd,'writer_sha256':sha(source),'cell_bits':bits,'sys_half_ps':sys_half,
           'vid_half_ps':vid_half,'ce_period':ce,'expected_rejection':marker,'cpu_fault':cpu_fault}
        report['cases'].append(c);save();build=folder/'build.log'
        with build.open('w') as log:r=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=180)
        c['build_exit']=r.returncode;c['build_log_sha256']=sha(build);save();assert r.returncode==0,'Compiler failure is not qualification'
        warnings=[]
        for line in build.read_text().splitlines():
            if '%Warning' not in line:continue
            m=re.fullmatch(r'%Warning-(\w+): ([^:]+):(\d+):(\d+): (.*)',line);assert m,line
            code,name,lineno,col,msg=m.groups();warnings.append(dict(code=code,file=str(Path(name).relative_to(out/'sources')),line=int(lineno),column=int(col),message=msg))
        c['warnings']=order(warnings);save();assert len(warnings)==32 and order(warnings)==order(ledger['warnings']),'New/changed compiler warning'
        exe=obj/'Vx1_z_kanji_vram_tb';c['executable_sha256']=sha(exe);run=folder/'run.log'
        with run.open('w') as log:r=subprocess.run([str(exe),'+TRACE='+str(folder/'trace.csv'),'+PROGRAM='+str(folder/'program.hex'),'+READ_TRACE='+str(folder/'reads.csv')],stdout=log,stderr=subprocess.STDOUT,timeout=240,cwd=folder)
        c['run_exit']=r.returncode
        for file,key in (('run.log','run_log_sha256'),('trace.csv','trace_sha256'),('reads.csv','reads_sha256'),('program.hex','program_hex_sha256')):c[key]=sha(folder/file)
        text=run.read_text();save();assert 'Z_VRAM_TEST_TIMEOUT' not in text,'Global timeout is not qualification'
        image,_=reference(1<<bits);assert bytes(int(v,16) for v in (folder/'program.hex').read_text().split())==image
        if marker:
            assert r.returncode!=0 and re.findall(r'Assertion failed[^\n]*?: (Z_VRAM_\w+)',text)==[marker] and 'PASS Z_VRAM' not in text,(tag,text)
            if cpu_fault:
                assert 'marker=238 boot=1 writes=1' in text,text
                c['audit']=audit_cpu(folder,1<<bits,fault=True);c['real_cpu_failure_handler']=True
        else:
            lines=re.findall(r'^PASS Z_VRAM (.+)$',text,re.M);assert r.returncode==0 and len(lines)==1,text
            counts={key:int(value) for key,value in re.findall(r'(\w+)=(\d+)',lines[0])};cells=1<<bits
            required={'cells':cells,'admissions':3*cells+61,'offers':3*cells+61,'commits':3*cells+61,
                      'cpu_writes':58,'boots':2,'attempts':3,'reads':32*(3*cells+61),'writes':262144,
                      'sys_half':sys_half,'vid_half':vid_half,'ce_period':ce}
            assert {key:counts[key] for key in required}==required and counts['wait_edges']>1000 and counts['replies']>cells*32
            c['counts']=counts;c['audit']=audit_cpu(folder,cells,counts)
        c['verified']=True;save();print(f'PASS {tag} exit={r.returncode} cause={marker or "positive"}',flush=True)
    save()
    try:
        r=subprocess.run([sys.executable,'-O','-B',str(out/'sources'/FILES[-1])],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=10)
        (out/'optimized-python-refusal.log').write_text(r.stdout);assert r.returncode!=0 and 'Z_VRAM_OPTIMIZED_PYTHON_REFUSED' in r.stdout and 'EVIDENCE=' not in r.stdout
        lint=['verilator','--lint-only','--timing','-Wall','--top-module','x1_z_kanji_vram_write',str(out/'sources'/WRITER)]
        with (out/'strict-writer-lint.log').open('w') as log:r=subprocess.run(lint,stdout=log,stderr=subprocess.STDOUT,timeout=30)
        report['strict_writer_lint']={'command':lint,'exit':r.returncode,'log_sha256':sha(out/'strict-writer-lint.log')};save()
        assert r.returncode==0 and '%Warning' not in (out/'strict-writer-lint.log').read_text()
        source=out/'sources'/WRITER
        if args.review_smoke:qualify('review',source);report['status']='review-smoke-pass'
        else:
            qualify('full32',source,bits=11)
            qualify('full100',source,bits=11,sys_half=5000,ce=25)
            qualify('cpu2m-slow-vid',source,ce=16,vid_half=20000)
            original=source.read_text()
            mutations=(
                ('live-address','state==IDLE ? write_cell : held_cell','write_cell','Z_VRAM_COMMIT_OWNER',1),
                ('live-commit-data','assign ram_data=held_data;','assign ram_data=write_data;','Z_VRAM_COMMIT_OWNER',1),
                ('live-merged-data','? held_data :','? write_data :','Z_VRAM_DESCRIPTOR_INTENT',3),
                ('unknown-text',"(known_read[0] ? ram_text : 8'd0)",'ram_text','Z_VRAM_DESCRIPTOR_INTENT',1),
                ('unknown-attr',"(known_read[1] ? ram_attr : 8'd0)",'ram_attr','Z_VRAM_DESCRIPTOR_INTENT',1),
                ('unknown-kan',"(known_read[2] ? ram_kan : 8'd0)",'ram_kan','Z_VRAM_DESCRIPTOR_INTENT',1),
                ('lost-known-bit','held_known<=merged_known;',"held_known<=merged_known ^ 3'b001;",'Z_VRAM_DESCRIPTOR_INTENT',1),
                ('wrong-glyph-level','held_glyph<={merged_kan[4:0],merged_text};',"held_glyph<={merged_kan[4:0] ^ 5'h10,merged_text};",'Z_VRAM_DESCRIPTOR_INTENT',1),
                ('early-ram-write','(state==DRAIN && update_done)','(state==OFFER && update_ready)','Z_VRAM_COMMIT_OWNER',1),
                ('repeated-ram-write','(state==DRAIN && update_done)','((state==DRAIN && update_done) || state==REPLY)','Z_VRAM_COMMIT_OWNER',1),
                ('early-wait-release','!write_valid || state==REPLY','!write_valid || state==REPLY || state==OFFER','Z_VRAM_HOST_COMPLETION',1),
                ('disabled-admission','write_valid && armed && admit_enable','write_valid && armed && (admit_enable || write_valid)','Z_VRAM_ADMISSION',1),
                ('held-reply-rearms','REPLY: if(!write_valid)','REPLY: if(write_valid)','Z_VRAM_HELD_REQUEST',1),
                ('lost-offer-on-disable','assign update_valid=state==OFFER;','assign update_valid=state==OFFER && admit_enable;','Z_VRAM_BUSY_OFFER',1),
            )
            for tag,old,new,marker,count in mutations:
                assert original.count(old)==count,(tag,original.count(old))
                dest=out/'mutants'/tag/Path(WRITER).name;dest.parent.mkdir(parents=True);dest.write_text(original.replace(old,new))
                qualify(tag,dest,marker=marker)
            qualify('corrupt-cpu-read',source,marker='Z_VRAM_CPU_ORACLE',cpu_fault=True)
            report['status']='pass'
    except BaseException as error:report.update(status='failed',error=repr(error));raise
    finally:
        report['sources_unchanged']=all(sha(ROOT/name)==sha(out/'sources'/name)==value for name,value in hashes.items())
        if not report['sources_unchanged']:report['status']='failed'
        save();assert report['sources_unchanged'],'Original/frozen inputs changed'
    print(f"PASS Z_VRAM {report['status']} runs={len(report['cases'])}; standalone real-CPU/VRAM boundary only",flush=True)
if __name__=='__main__':main()
