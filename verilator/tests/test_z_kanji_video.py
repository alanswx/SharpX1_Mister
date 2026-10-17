#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Freeze/qualify the exact-slot committed packet adapter and real renderer.

Default: strict adapter unit/fault gate. --render: real CPU/VRAM/cache/CRTC RGB,
generated assets and mock DDR. Neither enables a machine/board profile.
"""
if not __debug__:raise SystemExit('Z_VIDEO_OPTIMIZED_PYTHON_REFUSED')
import argparse,csv,hashlib,json,re,resource,struct,subprocess,sys,tempfile,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
ADAPTER='rtl/x1_z_kanji_video.sv';UNIT='verilator/tests/x1_z_kanji_video_tb.sv';TB='verilator/tests/x1_z_kanji_render_tb.sv';LEDGER='verilator/tests/z_kanji_render_warnings.json';CHECKER='verilator/tests/test_z_kanji_video.py'
RTL=(ADAPTER,'rtl/x1_z_kanji_vram_write.sv','rtl/x1_z_kanji_cache.sv','rtl/x1_z_kanji_frontend.sv','rtl/x1_z_kanji_ddr.sv','rtl/x1_video_ram.v','rtl/cpu.v','rtl/tv80/tv80e.v','rtl/tv80/tv80_core.v','rtl/tv80/tv80_mcode.v','rtl/tv80/tv80_alu.v','rtl/tv80/tv80_reg.v','rtl/x1_video_timing.sv','rtl/x1_text_raster.sv','rtl/legacy/x1_vid.v','rtl/legacy/crtc/crtc6845s.v')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def order(rows):return sorted(rows,key=lambda row:json.dumps(row,sort_keys=True))
def font(address):return ((address*43)^(address>>7)^(address>>14)^0xa7)&255
def attr(cell):return cell%7+1+((cell&1)<<3)+((cell&2)<<3)
def program():
    code=bytearray((0xf3,0x31,0xff,0xff,0x3e,0,0x32,0,0xf0));ops=[]
    for g in range(8):
        cell=g%3
        for port,select,value in ((0x3000|cell,1,(g*37+11)&255),(0x2800|cell,2,attr(g)),(0x3800|cell,4,0x80|(g<<4)|g)):
            code.extend((1,port&255,port>>8,0x3e,value,0xed,0x79,0xed,0x78,0xfe,value,0xc2,0,0xf1));ops.append((port,select,cell,value))
    code.extend((0x3e,0xa5,0x32,0,0xf0,0x76));image=bytearray(65536);image[:len(code)]=code;image[0xf100:0xf106]=bytes((0x3e,0xee,0x32,0,0xf0,0x76));return bytes(image),ops

def cpu_audit(folder):
    image,ops=program();assert bytes(int(v,16) for v in (folder/'program.hex').read_text().split())==image
    model=[(7<<24)|((0x80|c%128)<<16)|(attr(c)<<8)|((c*31+7)&255) for c in range(2048)]
    model[-1]=(model[-1]&~255)|0x92;model[-1]=(model[-1]&~0xff0000)|(0xdf<<16);model[-2]=(model[-2]&~0xff00)|(0x35<<8);model[0]=(model[0]&~255)|0x92
    expected=[]
    for boot,n in ((1,24),(2,10),(3,24)):
        for port,select,cell,value in ops[:n]:
            shift={1:0,2:8,4:16}[select];model[cell]=(model[cell]&~(255<<shift))|(value<<shift);d=model[cell]
            expected.append((boot,port,select,cell,value,d,(((d>>16)&31)<<8)|(d&255)))
    rows=[tuple(int(row[k]) for k in ('boot','port','select','cell','data','descriptor','glyph')) for row in csv.DictReader((folder/'trace.csv').open())];assert rows==expected
    reads=[tuple(int(row[k]) for k in ('boot','port','value')) for row in csv.DictReader((folder/'reads.csv').open())]
    assert reads==[(boot,op[0],op[3]) for boot,n in ((1,24),(2,9),(3,24)) for op in ops[:n]]
    return model,{'program_sha256':hashlib.sha256(image).hexdigest(),'cpu_writes':len(rows),'cpu_reads':len(reads)}

def png(path,pixels,width,height):
    def chunk(tag,data):return struct.pack('>I',len(data))+tag+data+struct.pack('>I',zlib.crc32(tag+data)&0xffffffff)
    rows=b''.join(b'\0'+pixels[y*width*3:(y+1)*width*3] for y in range(height))
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(rows))+chunk(b'IEND',b''))

def pixel_audit(folder,columns,final_model):
    results=[];actual_frames=[]
    for number in range(5):
        actual=bytearray();expected=bytearray();rows=0
        for row in csv.DictReader((folder/f'frame-{number}.csv').open()):
            y,x,value=(int(row[k]) for k in ('y','x','rgb'));assert (y,x)==divmod(rows,columns*8) and 0<=value<8;rows+=1
            cell=y//16*columns+x//8
            d=((7<<24)|((0x80|cell%128)<<16)|(attr(cell)<<8)|((cell*31+7)&255)) if number==0 else final_model[cell]
            text=d&255;att=(d>>8)&255;kan=(d>>16)&255
            address=((kan&31)<<13)|(text<<5)|((y%16)<<1)|((kan>>6)&1)
            ink=font(address)&(0x80>>(x%8))
            color=((att&7) if ink else 0)^(7 if bool(att&8) ^ (bool(att&16) and number in (2,3,4)) else 0)
            if number==4:color=0
            actual.extend((255 if value&2 else 0,255 if value&4 else 0,255 if value&1 else 0))
            expected.extend((255 if color&2 else 0,255 if color&4 else 0,255 if color&1 else 0))
        assert rows==columns*8*400,(number,rows)
        assert actual==expected,('Z_RENDER_EXACT_PIXELS',number,sum(a!=b for a,b in zip(actual,expected)))
        png(folder/f'frame-{number}.png',actual,columns*8,400);actual_frames.append(actual)
        results.append({'frame':number,'pixels':rows,'csv_sha256':sha(folder/f'frame-{number}.csv'),'png_sha256':sha(folder/f'frame-{number}.png'),'rgb_sha256':hashlib.sha256(actual).hexdigest()})
    assert actual_frames[0]!=actual_frames[1] and actual_frames[1]!=actual_frames[2] and actual_frames[2]==actual_frames[3] and not any(actual_frames[4])
    return results

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--render',action='store_true');args=parser.parse_args();resource.setrlimit(resource.RLIMIT_CORE,(0,0))
    files=(*RTL,TB,LEDGER,CHECKER) if args.render else (ADAPTER,UNIT,CHECKER)
    out=Path(tempfile.mkdtemp(prefix='x1-z-kanji-render-' if args.render else 'x1-z-kanji-video-')).resolve();print('EVIDENCE='+str(out),flush=True)
    hashes={name:sha(ROOT/name) for name in files};ledger=json.loads((ROOT/LEDGER).read_text()) if args.render else None
    if ledger:assert all(hashes[name]==value for name,value in ledger['source_sha256'].items()),'Bound renderer dependency changed'
    for name in files:
        p=out/'sources'/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes((ROOT/name).read_bytes());assert sha(p)==hashes[name]
    report={'scope':__doc__,'render':args.render,'status':'running','source_sha256':hashes,'cases':[],'tool':subprocess.check_output(['verilator','--version'],text=True).strip()}
    def save():(out/'terminal.json').write_text(json.dumps(report,indent=2)+'\n')
    def qualify(tag,source,marker=None,width=0,sys_half=15625,ce=8,live=0,glyph_fault=0):
        folder=out/tag;folder.mkdir();top='x1_z_kanji_render_tb' if args.render else 'x1_z_kanji_video_tb';obj=folder/'obj'
        cmd=['verilator','--binary','--timing','--assert','-Wall']+(['-Wno-fatal'] if args.render else [])+['--top-module',top,'--Mdir',str(obj),'-j','2']
        if args.render:cmd += [f'-GWIDTH40={width}',f'-GSYS_HALF_PS={sys_half}',f'-GCE_PERIOD={ce}',f'-GLIVE_METADATA={live}',f'-GGLYPH_FAULT={glyph_fault}']
        cmd += [str(source)]+([str(out/'sources'/name) for name in RTL[1:]]+[str(out/'sources'/TB)] if args.render else [str(out/'sources'/UNIT)])
        c={'name':tag,'command':cmd,'adapter_sha256':sha(source),'expected_rejection':marker,'columns':40 if width else 80,'sys_half_ps':sys_half,'ce_period':ce,'live_metadata':live,'glyph_fault':glyph_fault};report['cases'].append(c);save()
        with (folder/'build.log').open('w') as log:r=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=180)
        c['build_exit']=r.returncode;c['build_log_sha256']=sha(folder/'build.log');save();assert r.returncode==0,'Build failure is not a negative'
        warnings=[]
        for line in (folder/'build.log').read_text().splitlines():
            if '%Warning' not in line:continue
            m=re.fullmatch(r'%Warning-(\w+): ([^:]+):(\d+):(\d+): (.*)',line);assert m,line
            code,name,lineno,col,msg=m.groups();warnings.append(dict(code=code,file=str(Path(name).relative_to(out/'sources')),line=int(lineno),column=int(col),message=msg))
        c['warnings']=order(warnings);save();assert (len(warnings)==63 and order(warnings)==order(ledger['warnings'])) if args.render else not warnings,'New/changed compiler warning'
        exe=obj/('V'+top);c['executable_sha256']=sha(exe)
        runargs=[str(exe)]+(['+TRACE='+str(folder/'trace.csv'),'+PROGRAM='+str(folder/'program.hex'),'+READ_TRACE='+str(folder/'reads.csv'),'+FRAMES='+str(folder)] if args.render else [])
        with (folder/'run.log').open('w') as log:r=subprocess.run(runargs,stdout=log,stderr=subprocess.STDOUT,cwd=folder,timeout=360 if args.render else 60)
        c['run_exit']=r.returncode;c['run_log_sha256']=sha(folder/'run.log');text=(folder/'run.log').read_text();save()
        assert not any(word in text for word in ('Z_VIDEO_UNIT_TIMEOUT','Z_VRAM_TEST_TIMEOUT')),'Global timeout is not qualification'
        if marker:
            assert r.returncode!=0 and re.findall(r'Assertion failed[^\n]*?: (Z_\w+)',text)==[marker] and 'PASS Z_' not in text,(tag,text)
        else:
            if args.render:
                lines=re.findall(r'^PASS Z_RENDER (.+)$',text,re.M);assert r.returncode==0 and len(lines)==1,text
                counts={k:int(v) for k,v in re.findall(r'(\w+)=(\d+)',lines[0])}
                required={'cells':2048,'admissions':6206,'offers':6206,'commits':6206,'cpu_writes':58,'boots':2,'attempts':3,'reads':198592,'writes':262144,'sys_half':sys_half,'vid_half':11640,'ce_period':ce,'frames':5,'columns':c['columns']}
                assert {key:counts[key] for key in required}==required and counts['captures']>1000 and counts['rgb_edges']>10000 and (sys_half!=5000 or counts['stale']>0),counts
                c['counts']=counts;model,c['cpu_audit']=cpu_audit(folder);c['frames']=pixel_audit(folder,c['columns'],model)
            else:assert r.returncode==0 and re.findall(r'^PASS Z_VIDEO_UNIT cases=(\d+)$',text,re.M)==['65548'],text
        c['verified']=True
        c['artifacts']={p.name:sha(p) for p in folder.iterdir() if p.is_file()};save();print(f'PASS {tag} exit={r.returncode} cause={marker or "positive"}',flush=True)
    save()
    try:
        r=subprocess.run([sys.executable,'-O','-B',str(out/'sources'/CHECKER)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=10)
        (out/'optimized-python-refusal.log').write_text(r.stdout);assert r.returncode!=0 and 'Z_VIDEO_OPTIMIZED_PYTHON_REFUSED' in r.stdout and 'EVIDENCE=' not in r.stdout
        source=out/'sources'/ADAPTER
        if args.render:
            qualify('render80',source)
            qualify('render40-sys100',source,width=1,sys_half=5000,ce=25)
            qualify('live-vram-metadata',source,sys_half=5000,ce=25,live=1,marker='Z_PIXEL_RENDERER_CAPTURE')
            qualify('wrong-glyph-source',source,glyph_fault=1,marker='Z_PIXEL_RGB')
        else:
            qualify('positive',source);original=source.read_text()
            mutations=(
                ('live-cell','cache_response_cell==held_cell','cache_response_cell==(prefetch_start ? held_cell : beam_cell)','Z_VIDEO_EXACT_PACKET',1),
                ('live-row','{held_row,cache_response_descriptor[22]}','{(prefetch_start ? held_row : beam_row),cache_response_descriptor[22]}','Z_VIDEO_EXACT_PACKET',1),
                ('wrong-half-accepted','{held_row,cache_response_descriptor[22]}','{held_row,cache_response_offset[0]}','Z_VIDEO_ZERO_PACKET',1),
                ('wrong-tag-accepted','cache_response_glyph=={cache_response_descriptor[20:16],cache_response_descriptor[7:0]}','(cache_response_glyph=={cache_response_descriptor[20:16],cache_response_descriptor[7:0]} || cache_response_valid)','Z_VIDEO_ZERO_PACKET',1),
                ('unknown-metadata',"cache_response_descriptor[31:24]==8'h07","cache_response_descriptor[31:24]!=8'h00",'Z_VIDEO_ZERO_PACKET',1),
                ('reserved-metadata',"cache_response_descriptor[31:24]==8'h07","(cache_response_descriptor[31:24]==8'h07 || cache_response_descriptor[26:24]==3'd7)",'Z_VIDEO_ZERO_PACKET',1),
                ('missing-valid','cache_response_valid && cache_response_hit','(cache_response_valid || cache_response_hit) && cache_response_hit','Z_VIDEO_ZERO_PACKET',1),
                ('missing-hit','cache_response_valid && cache_response_hit','cache_response_valid && (cache_response_hit || cache_response_valid)','Z_VIDEO_ZERO_PACKET',1),
                ('out-of-slot-reply','else if(due_2 && window_open)','else if((due_2 && window_open) || cache_response_valid)','Z_VIDEO_ZERO_PACKET',1),
                ('capture-not-closed','else if(consume_capture) window_open<=0;','else if(consume_capture) window_open<=window_open;','Z_VIDEO_ZERO_PACKET',1),
                ('superseded-reply','due_2<=0;window_open<=!consume_capture;','due_2<=due_1;window_open<=!consume_capture;','Z_VIDEO_ZERO_PACKET',1),
                ('stale-start-metadata','window_open<=!consume_capture;\n                packet_metadata<=0;','window_open<=!consume_capture;\n                packet_metadata<=packet_metadata;','Z_VIDEO_ZERO_PACKET',1),
                ('stale-reset-metadata','packet_metadata<=0;packet_valid<=0;glyph_data<=0;\n        end else','packet_metadata<=packet_metadata;packet_valid<=0;glyph_data<=0;\n        end else','Z_VIDEO_ZERO_PACKET',1),
            )
            for tag,old,new,marker,n in mutations:
                assert original.count(old)==n,(tag,original.count(old));p=out/'mutants'/tag/Path(ADAPTER).name;p.parent.mkdir(parents=True);p.write_text(original.replace(old,new));qualify(tag,p,marker=marker)
        report['status']='pass'
    except BaseException as error:report.update(status='failed',error=repr(error));raise
    finally:
        report['sources_unchanged']=all(sha(ROOT/name)==sha(out/'sources'/name)==value for name,value in hashes.items())
        if not report['sources_unchanged']:report['status']='failed'
        save();assert report['sources_unchanged'],'Original/frozen source changed'
    print(f"PASS Z_VIDEO {'render' if args.render else 'unit'} runs={len(report['cases'])}; exact frozen scope only",flush=True)
if __name__=='__main__':main()
