#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Frozen original public-upload/CPU/full-RGB Z simulation qualification.

Default prepares only. Explicit --run builds/executes selected cases. This is
not native font loading, ASIC timing, a savable profile or FPGA memory fit.
"""
import argparse
import csv
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

CASES={'probe':(5,'probe',80),'render80':(1,'render',80),'render40':(1,'render',40),
       'warm80':(2,'render',80),'pending':(3,'probe',80),'exhaustive':(0,'exhaustive',80),
       'unsupported':(6,'unsupported',80),'transition':(7,'transition',80),'nonraster':(8,'nonraster',80)}
CASES.update({f'loader{n}':(4,'probe',80) for n in range(8)})
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def load(path,name):
    spec=importlib.util.spec_from_file_location(name,path)
    module=importlib.util.module_from_spec(spec);sys.modules[name]=module;spec.loader.exec_module(module);return module

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    action=parser.add_mutually_exclusive_group();action.add_argument('--run',action='store_true');action.add_argument('--build-only',action='store_true')
    parser.add_argument('--cases',nargs='+',choices=CASES,default=['probe','render80'])
    parser.add_argument('--negative',choices=['disabled','half-major','display-miss'])
    parser.add_argument('--jobs',type=int,default=2);parser.add_argument('--wall-seconds',type=float,default=900)
    parser.add_argument('--output',type=Path)
    args=parser.parse_args()
    if args.jobs<1 or args.wall_seconds<=0:parser.error('positive jobs and wall-seconds required')
    root=Path(__file__).resolve().parents[2]
    if args.output:
        out=args.output.resolve()
        if not any(out!=base and out.is_relative_to(base) for base in [Path('/tmp').resolve(),Path(tempfile.gettempdir()).resolve(),root/'output_files']):parser.error('new tmp/ignored output subdirectory required')
        out.mkdir(parents=True,exist_ok=False)
    else:out=Path(tempfile.mkdtemp(prefix='x1-machine-z-kanji-')).resolve()
    print(f'FROZEN_FOLDER={out}',flush=True)
    order=re.findall(r'^set_global_assignment -name (?:SYSTEMVERILOG_FILE|VERILOG_FILE) (\S+)\s*$',(root/'rtl/machine.qip').read_text(),re.M)
    assert order and len(order)==len(set(order))
    own=['verilator/tests/z_kanji_machine_tb.sv','verilator/tests/z_kanji_machine_assets.py',
         'verilator/tests/test_machine_z_kanji.py','verilator/tests/z80_fixture.py']
    inputs=list(dict.fromkeys(order+own+['rtl/machine.qip','bios/reference/fw_subcpu/verilog/X1SUB.BIN']))
    hashes={rel:sha(root/rel) for rel in inputs};frozen=out/'sources'
    for rel in inputs:
        dest=frozen/rel;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(root/rel,dest)
        assert sha(dest)==hashes[rel]==sha(root/rel),f'capture race {rel}'
    (out/'inputs.json').write_text(json.dumps(hashes,indent=2)+'\n')
    (out/'source-order.json').write_text(json.dumps(order,indent=2)+'\n')
    state={'phase':'captured','driver_pid':os.getpid(),'runs':[],'scope':'original connected Z simulation only','negative':args.negative}
    def save():(out/'status.json').write_text(json.dumps(state,indent=2)+'\n')
    def verify():
        for rel,h in hashes.items():assert sha(root/rel)==sha(frozen/rel)==h,f'source mutation {rel}'
    def child(command,log,record):
        with log.open('w') as handle:
            p=subprocess.Popen(command,cwd=frozen,stdout=handle,stderr=subprocess.STDOUT)
            record.update(pid=p.pid,command=command,log=str(log),started=time.time(),phase='running');save()
            print(f'CHILD_PID={p.pid} LOG={log}',flush=True)
            try:rc=p.wait(timeout=args.wall_seconds)
            except subprocess.TimeoutExpired:
                p.terminate()
                try:rc=p.wait(timeout=5)
                except subprocess.TimeoutExpired:p.kill();rc=p.wait()
                record.update(phase='timeout',returncode=rc);save();raise TimeoutError(f'own child {p.pid} timed out')
            record.update(phase='terminal',returncode=rc);save();return rc
    save()
    generated={};mutation={}
    try:
        verify()
        emitter=load(frozen/own[3],'z_frozen_emitter')
        assets=load(frozen/own[1],'z_frozen_assets')
        font=bytes(assets.pattern(a) for a in range(262144))
        selected=['render80'] if args.negative=='display-miss' else ['probe'] if args.negative else args.cases
        (out/'font.bin').write_bytes(font)
        font_upload=font
        if args.negative=='half-major':
            # ONLY uploaded font is permuted to an explicitly wrong layout.
            font_upload=bytes(font[l*131072+b*8192+c*32+r*2+h]
                for l in range(2) for h in range(2) for b in range(16) for c in range(256) for r in range(16))
        font_hex=out/'font.hex';font_hex.write_text(''.join(f'{b:02x}\n' for b in font_upload))
        absent=out/'absent.hex';absent.write_text(''.join(f'{b:02x}\n' for b in assets.program(emitter.Program,'probe',absent=True)))
        for name in selected:
            _,kind,columns=CASES[name]
            image=assets.program(emitter.Program,kind,columns)
            (out/(name+'.ipl.bin')).write_bytes(image)
            (out/(name+'.ipl.hex')).write_text(''.join(f'{b:02x}\n' for b in image))
        generated={str(p.relative_to(out)):sha(p) for p in out.iterdir() if p.suffix in ('.hex','.bin')}
        (out/'generated.json').write_text(json.dumps(generated,indent=2)+'\n')
        def verify_generated():
            for rel,h in generated.items():assert sha(out/rel)==h,f'generated mutation {rel}'
            for rel,h in mutation.items():assert sha(out/'mutation'/rel)==h,f'mutant changed {rel}'
        source_paths={rel:frozen/rel for rel in order}
        if args.negative=='display-miss':
            rel='rtl/x1_z_kanji_rom.sv';dest=out/'mutation'/rel;dest.parent.mkdir(parents=True)
            original=source_paths[rel].read_text()
            needle='assign display_valid=display_selected && loaded_video && !video_reset;'
            assert original.count(needle)==1
            dest.write_text(original.replace(needle,'assign display_valid=1\'b0;'))
            source_paths[rel]=dest;mutation[rel]=sha(dest)
            (out/'mutation.json').write_text(json.dumps(mutation,indent=2)+'\n')
        if not (args.run or args.build_only):state['phase']='prepared-not-built';return
        verify();verify_generated()
        cmd=['verilator','--binary','--timing','--assert','-Wno-fatal','--top-module','z_kanji_machine_tb',
             '--Mdir',str(out/'build'),'-j',str(args.jobs),f'-GENABLED={0 if args.negative=="disabled" else 1}',
             *(str(source_paths[r]) for r in order),str(frozen/own[0])]
        state['build']={};state['phase']='building';save()
        assert child(cmd,out/'build.log',state['build'])==0,'build failed (not negative qualification)'
        exe=out/'build/Vz_kanji_machine_tb';exe_hash=sha(exe)
        state['executable_sha256']=exe_hash
        warnings=[line for line in (out/'build.log').read_text().splitlines() if line.startswith('%Warning')]
        (out/'warnings.json').write_text(json.dumps(warnings,indent=2)+'\n')
        state['phase']='built-not-run';save()
        if not args.run:return
        diagnostics={'disabled':'Z_ORDERED_UPLOAD_ADMISSION','half-major':'Z_CPU_EXECUTED_DATA_ORACLE','display-miss':'Z_SUPPORTED_DISPLAY_MISS'}
        for name in selected:
            verify();verify_generated();assert sha(exe)==exe_hash
            scenario,kind,columns=CASES[name];dest=out/name;dest.mkdir()
            record={'case':name};state['runs'].append(record);state['phase']='running';save()
            cmd=[str(exe),f'+FONT={font_hex}',f'+IPL={out/(name+".ipl.hex")}',f'+ABSENT_IPL={absent}',
                 f'+OUTPUT={dest}',f'+SCENARIO={scenario}',f'+COLUMNS={columns}',
                 f'+LOAD_KIND={int(name[6:]) if name.startswith("loader") else 0}', '+DELAY=1']
            rc=child(cmd,out/(name+'.log'),record)
            log=(out/(name+'.log')).read_text()
            if args.negative:
                assert rc!=0 and diagnostics[args.negative] in log and 'Z_MACHINE_TIMEOUT' not in log,'exact negative not reached'
                record['exact_rejection']=diagnostics[args.negative];continue
            assert rc==0 and 'PASS Z_MACHINE' in log,log[-3000:]
            with (dest/'events.csv').open() as f:events=list(csv.DictReader(f))
            reads=[row for row in events if row['event']=='read']
            if kind=='exhaustive':
                expected=[l*131072+b*8192+c*32+r*2+h for l in range(2) for b in range(16) for h in range(2) for c in range(256) for r in range(16)]
                assert [int(row['address']) for row in reads]==expected,'Z_CPU_ADDRESS_VISIT_ORACLE'
                assert len(set(expected))==262144
            elif kind=='probe':
                expected=[l*131072+b*8192+255*32+r*2+h for l,b,h in [(0,0,0),(1,15,1)] for r in range(16)]
                assert [int(row['address']) for row in reads]==expected*(2 if scenario==4 else 1),'Z_CPU_PROBE_ADDRESS_ORACLE'
            for n,row in enumerate(reads):
                expected_byte=255 if scenario==4 and n<32 else assets.pattern(int(row['address']))
                assert int(row['value'])==expected_byte,'Z_CPU_PUBLIC_PAYLOAD_ORACLE'
            frames=[]
            if kind in ('render','unsupported','transition','nonraster'):
                expected=assets.expected_rgb(columns,kind);height=200 if kind=='nonraster' else 400
                for i in range(3):
                    frame=dest/f'frame-{i}.csv'
                    pixels=bytearray()
                    with frame.open() as f:
                        for n,row in enumerate(csv.DictReader(f)):
                            assert (int(row['y']),int(row['x']))==divmod(n,columns*8),'Z_PIXEL_RASTER_ORDER'
                            rgb=int(row['rgb12'],16);pixels.extend((((rgb>>8)&15)*17,((rgb>>4)&15)*17,(rgb&15)*17))
                    assert len(pixels)==columns*8*height*3,'Z_PIXEL_RASTER_SIZE'
                    assert pixels==expected,'Z_FULL_PIXEL_ORACLE'
                    ppm=dest/f'frame-{i}.ppm';ppm.write_bytes(f'P6\n{columns*8} {height}\n255\n'.encode()+pixels)
                    frames.append({'pixels':len(pixels)//3,'sha256':hashlib.sha256(pixels).hexdigest()})
            record.update(phase='accepted',public_reads=len(reads),frames=frames);save()
        verify();verify_generated();assert sha(exe)==exe_hash
        state['phase']='exact-negative-pass' if args.negative else 'selected-cases-pass'
    finally:
        try:verify();state['sources_unchanged']=True
        except Exception as exc:state['sources_unchanged']=False;state['source_failure']=str(exc);save();raise
        save()
    print(json.dumps(state,indent=2),flush=True)

if __name__=='__main__':main()
