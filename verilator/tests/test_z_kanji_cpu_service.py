#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Freeze/qualify real Z80/PCG access through the external font service.

Original generated diagnostic/font, competing real cache and mock DDR. No
shared-machine profile, native renderer/firmware, physical CDC or board claim.
"""
if not __debug__:
    raise SystemExit('Z_CPU_SERVICE_OPTIMIZED_PYTHON_REFUSED')

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
RTL=('rtl/x1_z_kanji_ddr.sv','rtl/x1_z_kanji_frontend.sv','rtl/x1_z_kanji_cache.sv',
     'rtl/x1_z_kanji_arbiter.sv','rtl/x1_z_kanji_quiesce.sv','rtl/x1_z_kanji_cpu_port.sv',
     'rtl/x1_z_pcg_selector.sv','rtl/x1_pcg_access.v','rtl/x1_reset_release.sv',
     'rtl/cpu.v','rtl/tv80/tv80e.v','rtl/tv80/tv80_core.v','rtl/tv80/tv80_mcode.v',
     'rtl/tv80/tv80_alu.v','rtl/tv80/tv80_reg.v')
BRIDGE='rtl/x1_z_kanji_cpu_port.sv'
TB='verilator/tests/x1_z_kanji_cpu_service_tb.sv'
LEDGER='verilator/tests/z_kanji_cpu_service_warnings.json'
FILES=(*RTL,TB,LEDGER,'verilator/tests/test_z_kanji_cpu_service.py')
BOUND={'rtl/x1_z_kanji_ddr.sv':'638861b6a6b06c0307e8bc045d239c766079b1875d6b8c3ab21fe4ea6248558d',
       'rtl/x1_z_kanji_frontend.sv':'ad8d27b111d4e59d1e10398c6c2e30e20a674bd77efb1c7b50ebe4b7509af95e',
       'rtl/x1_z_kanji_cache.sv':'e9671fb7ef9548f265cc50c4e3effdc6358c3d292c90eca1ca2b4788ca310f0e',
       'rtl/x1_z_kanji_arbiter.sv':'e97c58a3890a542af7056fc16ccd8a6a18720f0b744b29b19699f33e37eca0a6',
       'rtl/x1_z_kanji_quiesce.sv':'ee2e02b26ca3bc135a9e9ad4c41ef822105bba33502e1f07ef6e96858a64f313'}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def pattern(address):
    return ((address*43)^(address>>7)^(address>>14)^0xa7)&255


def reference():
    """Independent byte emitter and CPU-bus oracle, not DUT response data."""
    code=bytearray([0xf3,0x31,0xff,0xff,0x3e,0,0x32,0,0xf0])
    reads=[]
    def port(value): code.extend((0x01,value&255,value>>8))
    def output(target,value):
        port(target);code.extend((0x3e,value,0xed,0x79))
    def equal(target,value,physical=-1):
        port(target);code.extend((0xed,0x78,0xfe,value,0xc2,0,0xf1))
        reads.append((target,physical,value))
    for level in range(2):
        for bank in range(16):
            for character in (0,127,128,255):
                for half in range(2):
                    output(0x37ff,character);output(0x27ff,7)
                    output(0x3fff,0x80+64*half+16*level+bank)
                    output(0x37fc,0x31);output(0x27fd,0x27);output(0x3ffb,0)
                    for row in (0,1,7,15):
                        address=(level<<17)|(bank<<13)|(character<<5)|(row<<1)|half
                        equal(0x1400+row,pattern(address),address)
    output(0x3fff,0);equal(0x1403,0xa6)
    output(0x27ff,0x27);equal(0x1400,0xff)
    output(0x27ff,7);output(0x3fff,0xdf);output(0x1400,0x66)
    port(0x1400);code.extend((0x21,0,0xd0))
    for row in range(16):
        code.extend((0xed,0xa2,0x04,0x0c))
        address=0x3ffe1+2*row
        reads.append((0x1400+row,address,pattern(address)))
    for row in range(16):
        code.extend((0x3a,row,0xd0,0xfe,pattern(0x3ffe1+2*row),0xc2,0,0xf1))
    assert len(code)<0xd000
    code.extend((0x3e,0xa5,0x32,0,0xf0,0x76))
    image=bytearray(65536);image[:len(code)]=code
    image[0xf100:0xf106]=bytes((0x3e,0xee,0x32,0,0xf0,0x76))
    assert len(reads)==1042 and sum(p>=0 for _,p,_ in reads)==1040
    return bytes(image),reads


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--review-smoke',action='store_true',help='one positive, not full acceptance')
    args=parser.parse_args()
    resource.setrlimit(resource.RLIMIT_CORE,(0,0))
    out=Path(tempfile.mkdtemp(prefix='x1-z-kanji-cpu-service-')).resolve()
    print(f'EVIDENCE={out}',flush=True)
    hashes={name:sha(ROOT/name) for name in FILES}
    assert all(hashes[name]==value for name,value in BOUND.items()),'Qualified dependency changed'
    ledger=json.loads((ROOT/LEDGER).read_text())
    assert all(hashes[name]==value for name,value in ledger['source_sha256'].items()),'Warning baseline source changed'
    for name in FILES:
        dest=out/'sources'/name
        dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes((ROOT/name).read_bytes())
        assert sha(dest)==hashes[name]
    image,expected_reads=reference()
    (out/'expected-program.bin').write_bytes(image)
    (out/'expected-reads.json').write_text(json.dumps(expected_reads)+'\n')
    (out/'expected-font.bin').write_bytes(bytes(pattern(address) for address in range(262144)))
    report={'scope':__doc__,'source_sha256':hashes,'status':'running','cases':[],
            'tool':subprocess.check_output(['verilator','--version'],text=True).strip(),
            'expected_program_sha256':sha(out/'expected-program.bin'),
            'expected_font_sha256':sha(out/'expected-font.bin'),
            'expected_reads_sha256':sha(out/'expected-reads.json')}
    def save(): (out/'terminal.json').write_text(json.dumps(report,indent=2)+'\n')
    def warning_inventory(log):
        result=[]
        for line in log.splitlines():
            if '%Warning' not in line: continue
            match=re.fullmatch(r'%Warning-(\w+): ([^:]+):(\d+):(\d+): (.*)',line)
            assert match,('Unparsed warning',line)
            code,name,lineno,column,message=match.groups()
            relative=str(Path(name).relative_to(out/'sources'))
            result.append(dict(code=code,file=relative,line=int(lineno),column=int(column),message=message))
        return sorted(result,key=lambda row:json.dumps(row,sort_keys=True))
    expected_warnings=sorted(ledger['warnings'],key=lambda row:json.dumps(row,sort_keys=True))
    def qualify(tag,source,ce=8,vid=11640,marker=None,failed_external=None):
        folder=out/tag;folder.mkdir()
        obj=folder/'obj'
        cmd=['verilator','--binary','--timing','--assert','-Wall','-Wno-fatal',
             '--top-module','x1_z_kanji_cpu_service_tb','--Mdir',str(obj),'-j','2',
             f'-GCE_PERIOD={ce}',f'-GVID_HALF_PS={vid}',
             *(str(source if name==BRIDGE else out/'sources'/name) for name in RTL),str(out/'sources'/TB)]
        case={'name':tag,'command':cmd,'ce_period':ce,'vid_half_ps':vid,'bridge_sha256':sha(source),
              'expected_rejection':marker,'failed_external':failed_external}
        report['cases'].append(case);save()
        buildlog=folder/'build.log'
        with buildlog.open('w') as log:
            result=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=180)
        case['build_exit']=result.returncode;case['build_log_sha256']=sha(buildlog)
        case['warnings']=warning_inventory(buildlog.read_text());save()
        assert result.returncode==0,'Build failure is not a matched rejection'
        assert case['warnings']==expected_warnings,f'New/changed warning: {buildlog}'
        exe=obj/'Vx1_z_kanji_cpu_service_tb';case['executable_sha256']=sha(exe)
        runlog=folder/'run.log';trace=folder/'trace.csv';program=folder/'program.hex'
        with runlog.open('w') as log:
            result=subprocess.run([str(exe),f'+TRACE={trace}',f'+PROGRAM={program}'],
                stdout=log,stderr=subprocess.STDOUT,timeout=180,cwd=folder)
        case['run_exit']=result.returncode;case['run_log_sha256']=sha(runlog)
        case['trace_sha256']=sha(trace);case['program_hex_sha256']=sha(program)
        actual_image=bytes(int(token,16) for token in program.read_text().split())
        assert actual_image==image,'CPU program differs from independent emitter'
        case['program_bytes_sha256']=hashlib.sha256(actual_image).hexdigest()
        text=runlog.read_text();save()
        assert 'Z_CPU_SERVICE_TEST_TIMEOUT' not in text and 'Z_CPU_SERVICE_CPU_DEADLINE' not in text,'Timeout is not qualification'
        rows=[tuple(int(row[key]) for key in ('boot','port','physical','value'))
              for row in csv.DictReader(trace.open())]
        if marker:
            failures=re.findall(r'Assertion failed[^\n]*?: (Z_CPU_SERVICE_\w+)',text)
            assert result.returncode!=0 and failures==[marker] and 'PASS Z_CPU_SERVICE' not in text,text
            if marker=='Z_CPU_SERVICE_EXECUTED_ORACLE':
                assert f'marker=238 boot=1 external={failed_external}' in text,text
                assert len(rows)==failed_external and all(row[0]==1 for row in rows),rows
                assert [row[1:3] for row in rows]==[row[:2] for row in expected_reads[:len(rows)]]
                assert any(row[3]!=expected_reads[i][2] for i,row in enumerate(rows))
                case['real_cpu_failure_handler']=True
        else:
            lines=re.findall(r'^PASS Z_CPU_SERVICE (.+)$',text,re.M)
            assert result.returncode==0 and len(lines)==1,text
            counts={key:int(value) for key,value in re.findall(r'(\w+)=(\d+)',lines[0])}
            required={'boots':4,'attempts':6,'cpu_reads':4162,'cg_reads':4168,'writes':262144,
                      'ce_period':ce,'vid_half':vid,'long_reads':4}
            assert {key:counts[key] for key in required}==required,counts
            assert counts['requests']==counts['acks']==counts['cpu_reads']+counts['cache_reads']
            assert counts['updates']>=counts['completed_updates']>0
            assert counts['cache_reads']>1040 and counts['held_reply_edges']>0 and counts['wait_edges']>0
            assert counts['replies']>0 and counts['edges']>1048576
            expected=[(boot,*row) for boot in (1,2,4,6) for row in expected_reads]
            assert rows==expected,'Independent actual CPU-bus address/data trace failed'
            case['counts']=counts;case['audited_cpu_reads']=len(rows)
        case['verified']=True;save()
        print(f'PASS {tag} exit={result.returncode} cause={marker or "positive"}',flush=True)
    save()
    try:
        refusal=subprocess.run([sys.executable,'-O','-B',str(out/'sources'/FILES[-1])],
                               stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=10)
        (out/'optimized-python-refusal.log').write_text(refusal.stdout)
        assert refusal.returncode!=0 and 'Z_CPU_SERVICE_OPTIMIZED_PYTHON_REFUSED' in refusal.stdout
        assert 'EVIDENCE=' not in refusal.stdout
        lintlog=out/'bridge-lint.log'
        lintcmd=['verilator','--lint-only','--timing','-Wall','--top-module','x1_z_kanji_cpu_port',str(out/'sources'/BRIDGE)]
        with lintlog.open('w') as log:
            lint=subprocess.run(lintcmd,stdout=log,stderr=subprocess.STDOUT,timeout=30)
        report['strict_bridge_lint']={'command':lintcmd,'exit':lint.returncode,'log_sha256':sha(lintlog)}
        assert lint.returncode==0 and '%Warning' not in lintlog.read_text()
        source=out/'sources'/BRIDGE
        qualify('cpu4m-x3',source)
        if args.review_smoke: report['status']='review-smoke-pass'
        else:
            qualify('cpu2m-x3',source,ce=16)
            qualify('slow-vid',source,vid=20000)
            original=source.read_text()
            mutants=(
                ('corrupt-data',"pcg_valid ? cpu_data : 8'd0;", "pcg_valid ? (cpu_data ^ 8'd1) : 8'd0;",'Z_CPU_SERVICE_EXECUTED_ORACLE',1),
                ('missing-ack','cpu_valid && !pcg_read && !cpu_cancel;', 'cpu_valid && !pcg_read && cpu_cancel;','Z_CPU_SERVICE_EXECUTED_ORACLE',2),
                ('early-ack','cpu_valid && !pcg_read && !cpu_cancel;', 'cpu_valid && (pcg_read || !pcg_read) && !cpu_cancel;','Z_CPU_SERVICE_EARLY_ACK',None),
                ('cancel-rearms-old-read','assign cpu_read=pcg_read;', 'assign cpu_read=pcg_read && !cpu_cancel;','Z_CPU_SERVICE_CPU_ADDRESS',None),
                ('wrong-half','assign cpu_address=pcg_address;', "assign cpu_address=pcg_address ^ 18'd1;",'Z_CPU_SERVICE_CPU_ADDRESS',None),
                ('wrong-high-address','assign cpu_address=pcg_address;', "assign cpu_address=pcg_address ^ 18'h08000;",'Z_CPU_SERVICE_CPU_ADDRESS',None),
                ('idle-data-leak',"pcg_valid ? cpu_data : 8'd0;",'cpu_data;','Z_CPU_SERVICE_IDLE_DATA',None),
                ('premature-valid','pcg_read && cpu_valid && !cpu_cancel;', '(pcg_read || cpu_valid) && !cpu_cancel;','Z_CPU_SERVICE_EXECUTED_ORACLE',1),
            )
            for tag,old,new,marker,failed_external in mutants:
                assert original.count(old)==1,(tag,original.count(old))
                dest=out/'mutants'/tag/Path(BRIDGE).name
                dest.parent.mkdir(parents=True);dest.write_text(original.replace(old,new))
                qualify(tag,dest,marker=marker,failed_external=failed_external)
            report['status']='pass'
    except BaseException as error:
        report.update(status='failed',error=repr(error));raise
    finally:
        report['sources_unchanged']=all(sha(ROOT/name)==sha(out/'sources'/name)==digest for name,digest in hashes.items())
        if not report['sources_unchanged']: report['status']='failed'
        save();assert report['sources_unchanged'],'Original/frozen source changed'
    print(f"PASS Z_CPU_SERVICE {report['status']} runs={len(report['cases'])}; fixture boundary only",flush=True)


if __name__=='__main__':
    main()
