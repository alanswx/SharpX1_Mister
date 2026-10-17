#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Freeze and execute the non-savable complete-machine external-font diagnostic."""
import csv,hashlib,json,re,resource,subprocess,tempfile,sys,struct,zlib,importlib.util
from pathlib import Path
from z80_fixture import Program
import z_kanji_machine_assets as assets
if not __debug__:raise SystemExit('optimized Python refused')
ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def program(columns=80):
    p=Program();p.emit(0xf3);p.word(0x31,0xffff)
    def out(port,value):p.word(0x01,port);p.emit(0x3e,value,0xed,0x79)
    out(0x1a03,0x82);p.word(0x01,0x1a01);p.emit(0xed,0x78)
    out(0x1a02,0x40 if columns==40 else 0);p.word(0x01,0x1a01);p.emit(0xed,0x78)
    for i in range(4):p.store(0xf000+i,0)
    # PSG writes and native PPI/CRTC traffic share the real machine bus.
    out(0x1c00,7);out(0x1b00,0x3f)
    for port in (0x1000,0x1100,0x1200,0x1300):out(port,0)
    regs=[55 if columns==40 else 111,columns,46 if columns==40 else 92,0x28,27,0,25,26,0,15,0,0,0,0,0,0]
    for r,v in enumerate(regs):out(0x1800,r);out(0x1801,v)
    out(0x1fd0,0x20)
    def equal(port,value):
        p.word(0x01,port);p.emit(0xed,0x78,0xfe,value);p.jump(0xc2,'fail')
    # Existing ANK ROM and PCG RAM use their real paths alongside the cache.
    out(0x27ff,7);out(0x37ff,65);out(0x3fff,0);equal(0x1400,0x18)
    out(0x27ff,0x20);out(0x1500,0xa6);equal(0x1500,0xa6)
    out(0x1fd0,0x21);out(0x27ff,7)
    for level,bank,half in ((0,0,0),(1,15,1)):
        out(0x3fff,0x80|level*16|bank|half*64);out(0x37ff,255)
        p.word(0x01,0x1400);p.word(0x21,0xd000)
        for row in range(16):p.emit(0xed,0xa2,0x04,0x0c)
        for row in range(16):p.compare_memory(0xd000+row,assets.pattern(level*131072+bank*8192+255*32+row*2+half))
    p.word(0x3a,0xf040);p.emit(0xfe,0xa5);p.jump(0xca,'retained')
    p.store(0xf040,0xa5)
    pointers=[]
    for component,base in enumerate((0x3000,0x3800,0x2000)):
        p.word(0x21,0);pointers.append((len(p.code)-2,component))
        p.word(0x01,base);p.word(0x11,2048);p.label(f'fill{component}')
        p.emit(0x7e,0xed,0x79,0x23,0x03,0x1b,0x7a,0xb3);p.jump(0xc2,f'fill{component}')
    p.label('retained')
    # Real CPU readback through the machine's muxed synchronous VRAM ports,
    # including attribute aliases and cells near the highest selector entry.
    for cell in (0,999,1999,2046):
        text,kan,attr=assets.cells(cell)
        for port,value in ((0x3000|cell,text),(0x3800|cell,kan),(0x2800|cell,attr)):equal(port,value)
    p.store(0xf010,0x90)
    for i,v in enumerate(b'ZPIX'):p.store(0xf000+i,v)
    p.emit(0x76);p.jump(0xc3,'fail');p.label('fail');p.store(0xf000,0xee);p.emit(0x76)
    table=len(p.code)
    for position,component in pointers:p.code[position:position+2]=(table+component*2048).to_bytes(2,'little')
    for component in range(3):p.code.extend(assets.cells(c)[component] for c in range(2048))
    image=p.finish();assert len(image)<32768
    return image+bytes(32768-len(image))
def expected_frame(columns,replaced):
    if not replaced:return assets.expected_rgb(columns)
    image=bytearray()
    for y in range(400):
        for x in range(columns*8):
            c=y//16*columns+x//8;text,kan,attr=assets.cells(c)
            address=((kan&31)<<13)|(text<<5)|((y%16)<<1)|(kan>>6&1)
            glyph=assets.pattern(address) ^ (0 if 8160<=address<8192 or address>=262112 else 0x5a)
            color=((attr&7) if glyph&(128>>(x%8)) else 0) ^ (7 if attr&8 else 0)
            image.extend((255 if color&2 else 0,255 if color&4 else 0,255 if color&1 else 0))
    return image

def main():
    global Program,assets
    resource.setrlimit(resource.RLIMIT_CORE,(0,0))
    out=Path(tempfile.mkdtemp(prefix='x1-z-external-machine-')).resolve();print('EVIDENCE='+str(out),flush=True)
    order=re.findall(r'^set_global_assignment -name (?:SYSTEMVERILOG_FILE|VERILOG_FILE) (\S+)\s*$',(ROOT/'rtl/machine.qip').read_text(),re.M)
    own=['verilator/tests/z_external_font_machine_tb.sv','verilator/tests/test_z_external_font_machine.py','verilator/tests/z80_fixture.py','verilator/tests/z_kanji_machine_assets.py','rtl/machine.qip','bios/reference/fw_subcpu/verilog/X1SUB.BIN']
    hashes={name:sha(ROOT/name) for name in dict.fromkeys(order+own)}
    for name,h in hashes.items():
        p=out/'sources'/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes((ROOT/name).read_bytes());assert sha(p)==h
    # Generate and audit assets with the captured helpers, so a module import
    # cannot race the capture and bind an earlier in-memory emitter revision.
    def frozen_module(relative,name):
        spec=importlib.util.spec_from_file_location(name,out/'sources'/relative)
        module=importlib.util.module_from_spec(spec);sys.modules[name]=module;spec.loader.exec_module(module)
        return module
    Program=frozen_module('verilator/tests/z80_fixture.py','external_frozen_z80').Program
    assets=frozen_module('verilator/tests/z_kanji_machine_assets.py','external_frozen_assets')
    report={'status':'running','source_sha256':hashes,'cases':[],'tool':subprocess.check_output(['verilator','--version'],text=True).strip()}
    def save():(out/'terminal.json').write_text(json.dumps(report,indent=2)+'\n')
    save()
    for columns,fault in ((80,0),(40,0),(80,1),(80,2),(80,3)):
        folder=out/f'cols{columns}-fault{fault}';folder.mkdir();(folder/'font.hex').write_text(''.join(f'{assets.pattern(a):02x}\n' for a in range(262144)));(folder/'ipl.hex').write_text(''.join(f'{b:02x}\n' for b in program(columns)))
        markers={1:'Z_EXTERNAL_CPU_ORACLE',2:'Z_EXTERNAL_EARLY_RESET_UPLOAD',3:'Z_EXTERNAL_REBUILD_VALIDITY'}
        c={'fault':fault,'columns':columns,'expected_rejection':markers.get(fault)};report['cases'].append(c);save()
        service='rtl/x1_z_kanji_machine.sv'
        variant=out/'sources'/service
        if fault in (2,3):
            original=variant.read_text()
            before,after=('assign machine_reset=state!=RUN && (state!=DRAIN || writer_idle);','assign machine_reset=state!=RUN;') if fault==2 else ('if(|ram_write) journal[writer_cell]<=writer_descriptor;',"if(1'b0 && |ram_write) journal[writer_cell]<=writer_descriptor;")
            assert original.count(before)==1
            variant=folder/'x1_z_kanji_machine.sv';variant.write_text(original.replace(before,after));c['mutated_service_sha256']=sha(variant)
        obj=folder/'obj';cmd=['verilator','--binary','--timing','--assert','-Wno-fatal','--top-module','z_external_font_machine_tb','--Mdir',str(obj),'-j','2',f'-GCORRUPT_READ={int(fault==1)}',str(out/'sources'/own[0])]+[str(variant if n==service else out/'sources'/n) for n in order]
        with (folder/'build.log').open('w') as log:r=subprocess.run(cmd,cwd=out/'sources',stdout=log,stderr=subprocess.STDOUT,timeout=240)
        c.update(build_exit=r.returncode,build_log_sha256=sha(folder/'build.log'));save();assert r.returncode==0,'compile failure is not rejection'
        warnings=[line for line in (folder/'build.log').read_text().splitlines() if line.startswith('%Warning')];c['warnings']=warnings
        assert not any(re.search(r'%Warning-(IMPLICIT|MULTIDRIVEN|UNOPTFLAT|LATCH):',line) for line in warnings),warnings
        assert not any('rtl/x1_z_kanji_machine.sv:' in line for line in warnings),warnings
        exe=obj/'Vz_external_font_machine_tb';c['executable_sha256']=sha(exe);save()
        cmd=[str(exe),'+FONT='+str(folder/'font.hex'),'+IPL='+str(folder/'ipl.hex'),'+OUTPUT='+str(folder),'+COLUMNS='+str(columns)]
        with (folder/'run.log').open('w') as log:r=subprocess.run(cmd,cwd=out/'sources',stdout=log,stderr=subprocess.STDOUT,timeout=600)
        log=(folder/'run.log').read_text();c.update(run_exit=r.returncode,run_log_sha256=sha(folder/'run.log'));save()
        assert 'Z_EXTERNAL_TIMEOUT' not in log,'timeout is not rejection'
        if fault:
            assert r.returncode!=0 and re.findall(r'Assertion failed[^\n]*?: (Z_\w+)',log)==[markers[fault]],log[-2500:]
        else:
            assert r.returncode==0 and len(re.findall(r'^PASS Z_EXTERNAL_MACHINE ',log,re.M))==1,log[-3000:]
            frames=[]
            for number in range(3):
                actual=bytearray()
                for n,row in enumerate(csv.DictReader((folder/f'frame-{number}.csv').open())):
                    assert (int(row['y']),int(row['x']))==divmod(n,columns*8)
                    rgb=int(row['rgb12'],16);actual.extend(((rgb>>8&15)*17,(rgb>>4&15)*17,(rgb&15)*17))
                assert len(actual)==columns*8*400*3 and actual==expected_frame(columns,number==2),'Z_EXTERNAL_EXACT_FRAME'
                def chunk(tag,data):return struct.pack('>I',len(data))+tag+data+struct.pack('>I',zlib.crc32(tag+data)&0xffffffff)
                pixels=b''.join(b'\0'+actual[y*columns*24:(y+1)*columns*24] for y in range(400))
                (folder/f'frame-{number}.png').write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',columns*8,400,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(pixels))+chunk(b'IEND',b''))
                frames.append(hashlib.sha256(actual).hexdigest())
            assert frames[0]==frames[1] and frames[1]!=frames[2]
            reads=[int(row['data']) for row in csv.DictReader((folder/'events.csv').open()) if row['event']=='read']
            expected=[0x18,0xa6]+[assets.pattern(level*131072+bank*8192+255*32+row*2+half) for level,bank,half in ((0,0,0),(1,15,1)) for row in range(16)]
            vram=[value for cell in (0,999,1999,2046) for value in assets.cells(cell)]
            assert reads==[0x18,0xa6]+(expected+vram)*3,'Z_EXTERNAL_CPU_TRACE'
            ports=[int(row['address']) for row in csv.DictReader((folder/'events.csv').open()) if row['event']=='read']
            boot_ports=[0x1400,0x1500]+list(range(0x1400,0x1410))*2+[port|cell for cell in (0,999,1999,2046) for port in (0x3000,0x3800,0x2800)]
            assert ports==[0x1400,0x1500]+boot_ports*3,'Z_EXTERNAL_CPU_PORTS'
            c['rgb_sha256']=frames;c['pass_line']=re.findall(r'^PASS Z_EXTERNAL_MACHINE .+$',log,re.M)[0]
        c['artifacts']={p.name:sha(p) for p in folder.iterdir() if p.is_file()};save();print('PASS case fault='+str(fault),flush=True)
    assert all(sha(ROOT/name)==sha(out/'sources'/name)==h for name,h in hashes.items()),'inputs changed during qualification'
    report['status']='pass';save();print('PASS Z_EXTERNAL_FROZEN_GATE '+str(out),flush=True)
if __name__=='__main__':main()
