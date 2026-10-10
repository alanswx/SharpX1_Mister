// SPDX-License-Identifier: GPL-2.0-only
// Original non-savable waveform harness: no decoded bytes, mailbox replies,
// snapshots, RAM bootstrap or disk service. Exit zero is observational only.
#include "Vcassette_top.h"
#include "verilated.h"
#include "frame_capture.h"
#include "x1_tap_image.h"
#include <array>
#include <bit>
#include <filesystem>
#include <iomanip>
#include <iostream>
#include <sstream>

namespace fs = std::filesystem;
using Bytes = std::vector<uint8_t>;
static Bytes read_file(const fs::path& p, size_t limit) {
    std::ifstream in(p, std::ios::binary);
    if (!in) throw std::runtime_error("cannot read: " + p.string());
    Bytes b;
    for (char c; in.get(c);) {
        if (b.size()==limit) throw std::runtime_error("input exceeds bound: "+p.string());
        b.push_back(static_cast<uint8_t>(c));
    }
    if (!in.eof()) throw std::runtime_error("input read failed");
    return b;
}
// Standard SHA-256; original implementation, no shell/platform dependency.
static std::string sha256(Bytes b) {
    static constexpr uint32_t k[] = {
        0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
        0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
        0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
        0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
        0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
        0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
        0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
        0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2};
    std::array<uint32_t,8> h={0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19};
    uint64_t bits=uint64_t(b.size())*8;
    b.push_back(0x80);
    while(b.size()%64!=56) b.push_back(0);
    for(int i=7;i>=0;--i) b.push_back(uint8_t(bits>>(i*8)));
    for(size_t at=0;at<b.size();at+=64) {
        uint32_t w[64]{};
        for(unsigned i=0;i<16;++i)
            for(unsigned j=0;j<4;++j) w[i]=(w[i]<<8)|b[at+i*4+j];
        for(unsigned i=16;i<64;++i) {
            auto x=w[i-15],y=w[i-2];
            w[i]=w[i-16]+(std::rotr(x,7)^std::rotr(x,18)^(x>>3))+w[i-7]
                +(std::rotr(y,17)^std::rotr(y,19)^(y>>10));
        }
        auto v=h;
        for(unsigned i=0;i<64;++i) {
            uint32_t a=v[7]+(std::rotr(v[4],6)^std::rotr(v[4],11)^std::rotr(v[4],25))
                +((v[4]&v[5])^(~v[4]&v[6]))+k[i]+w[i];
            uint32_t z=(std::rotr(v[0],2)^std::rotr(v[0],13)^std::rotr(v[0],22))
                +((v[0]&v[1])^(v[0]&v[2])^(v[1]&v[2]));
            for(unsigned j=7;j>0;--j) v[j]=v[j-1];
            v[4]+=a;v[0]=a+z;
        }
        for(unsigned i=0;i<8;++i) h[i]+=v[i];
    }
    std::ostringstream out;
    for(auto n:h) out<<std::hex<<std::setfill('0')<<std::setw(8)<<n;
    return out.str();
}
static uint64_t number(const std::string& s) {
    if(s.empty() || s[0]=='-') throw std::runtime_error("invalid unsigned number");
    size_t used=0;auto n=std::stoull(s,&used,0);
    if(used!=s.size()) throw std::runtime_error("invalid unsigned number");
    return n;
}
struct Asset { fs::path path; std::string hash; size_t limit; };
struct Key { uint64_t ps; uint8_t byte; };
struct ResetEdge { uint64_t ps; bool asserted; };

int main(int argc,char** argv) {
    try {
        fs::path ip,cp,tp,kp,out;
        uint64_t cycles=0,reset_us=10; unsigned marker=0;
        bool marker_set=false,reset_width_set=false;
        std::vector<uint64_t> reset_ms;
        for(int i=1;i<argc;++i) {
            std::string arg=argv[i];
            if(arg=="--help") {
                std::cout<<"--ipl FILE --controller FILE --tape FILE --cycles N --output NEW_DIR "
                    "[--keys FILE] [--marker-address N] [--reset-at MS (repeatable) --reset-for-us US]\n"
                    "Binary assets; no snapshots/disks.\n";
                return 0;
            }
            if(i+1==argc) throw std::runtime_error("missing option value");
            std::string value=argv[++i];
            if(arg=="--ipl") ip=value;
            else if(arg=="--controller") cp=value;
            else if(arg=="--tape") tp=value;
            else if(arg=="--keys") kp=value;
            else if(arg=="--output") out=value;
            else if(arg=="--cycles") cycles=number(value);
            else if(arg=="--reset-at") {
                if(reset_ms.size()>=1024) throw std::runtime_error("too many reset events");
                reset_ms.push_back(number(value));
            } else if(arg=="--reset-for-us") {reset_us=number(value);reset_width_set=true;}
            else if(arg=="--marker-address") {
                auto n=number(value);if(n>65535) throw std::runtime_error("marker out of range");
                marker=unsigned(n);marker_set=true;
            } else throw std::runtime_error("unsupported option: "+arg);
        }
        if(ip.empty() || cp.empty() || tp.empty() || out.empty())
            throw std::runtime_error("IPL/controller/tape/output required");
        if(!cycles || cycles>1000000000000ULL) throw std::runtime_error("cycles out of bounds");
        std::vector<Asset> assets;
        auto asset=[&](const fs::path& p,size_t limit) {
            auto b=read_file(p,limit);assets.push_back({fs::canonical(p),sha256(b),limit});return b;
        };
        auto ipl=asset(ip,8192),controller=asset(cp,8192);
        if(ipl.size()!=4096 && ipl.size()!=8192) throw std::runtime_error("IPL must be 4096 or 8192 bytes");
        if(controller.size()!=8192) throw std::runtime_error("controller must be 8192 bytes");
        X1TapImage tape(asset(tp,X1TapImage::max_image_bytes));
        if(!tape.sampling_supported()) throw std::runtime_error("format-zero waveform semantics unresolved");
        std::vector<Key> keys;
        if(!kp.empty()) {
            auto b=asset(kp,1024*1024);
            std::istringstream in(std::string(b.begin(),b.end()));std::string line;
            while(std::getline(in,line)) {
                line=line.substr(0,line.find('#'));std::istringstream row(line);
                std::string ms,byte,extra;
                if(!(row>>ms)) continue;
                if(!(row>>byte) || (row>>extra)) throw std::runtime_error("invalid PS2 row");
                uint64_t time=number(ms);size_t used=0;auto code=std::stoul(byte,&used,16);
                if(time>1000000 || code>255 || used!=byte.size() || keys.size()>=65536)
                    throw std::runtime_error("PS2 script out of bounds");
                time*=1000000000ULL;
                if(!keys.empty() && time<keys.back().ps) throw std::runtime_error("unordered PS2 script");
                keys.push_back({time,uint8_t(code)});
            }
        }
        constexpr uint64_t startup_cycles=4096+8192+64;
        if(cycles<=startup_cycles) throw std::runtime_error("cycles must exceed 12352 startup cycles");
        const uint64_t reset_end=startup_cycles*31250,end=cycles*31250;
        if(reset_us==0 || reset_us>1000000 || (reset_width_set && reset_ms.empty()))
            throw std::runtime_error("reset width requires events and 1..1000000 us");
        std::sort(reset_ms.begin(),reset_ms.end());
        std::vector<ResetEdge> reset_edges;
        for(auto when:reset_ms) {
            if(when>1000000) throw std::runtime_error("reset time out of bounds");
            const uint64_t at=when*1000000000ULL,release=at+reset_us*1000000ULL;
            if(at<=reset_end || release>=end)
                throw std::runtime_error("reset must fit strictly after startup and before duration");
            if(!reset_edges.empty() && at<=reset_edges.back().ps)
                throw std::runtime_error("overlapping or touching reset events");
            reset_edges.push_back({at,true});reset_edges.push_back({release,false});
        }
        for(const auto& key:keys)
            if(key.ps<reset_end || key.ps>=end) throw std::runtime_error("key outside post-startup run");
        // Explicit executable pathname avoids PATH ambiguity in provenance.
        asset(fs::canonical(argv[0]),512ULL*1024*1024);
        if(fs::exists(out)) throw std::runtime_error("output directory already exists");
        if(!fs::create_directory(out)) throw std::runtime_error("cannot create new output directory");
        std::ofstream log(out/"events.csv");
        if(!log) throw std::runtime_error("cannot open event log");
        log<<"time_ps,event,cursor,level,last,mode,sensor\n";
        VerilatedContext context;context.commandArgs(argc,argv);
#if VM_TIMING
        constexpr bool timing=true;
#else
        constexpr bool timing=false;
#endif
        Vcassette_top top{&context};
        top.clk_sys=0;top.clk_28636=0;top.reset=1;
        top.ioctl_download=1;top.ioctl_wr=1;top.ioctl_index=0;top.ioctl_addr=0;top.ioctl_dout=ipl[0];
        top.ps2_clk_in=1;top.ps2_data_in=1;
        top.tape_mount=1;top.tape_present=1;top.tape_empty=tape.eof();top.debug_addr=marker;
        auto buffer=[&]() {
            top.tape_sample_valid=!tape.eof();
            top.tape_sample_level=tape.eof()?0:tape.sample(tape.position());
            top.tape_sample_last=!tape.eof() && tape.position()+1==tape.metadata().sample_count;
        };
        buffer();top.eval();
        FrameCapture frame;frame.path=(out/"frame.ppm").string();
        uint64_t se=1,ve=1,accepted=0,uploads=0,sys_rises=0,video_rises=0;
        auto st=[](uint64_t e) {return e*15625;};
        auto vt=[](uint64_t e) {
            // Quotient/remainder form stays bounded for the admitted duration.
            return (e/28571428)*500000000000ULL
                +(e%28571428)*500000000000ULL/28571428;
        };
        bool upload_ack=false,sample_ack=false;
        size_t ri=0;
        uint64_t warm_assertions=0,warm_releases=0;
        size_t ki=0;uint16_t packet=0;unsigned bit=0;bool key_active=false;
        uint64_t key_edge=0,key_gap=0,keys_sent=0;
        bool hs=top.HSync,vs=top.VSync;
        uint64_t hc=0,vc=0,hl=0,vl=0,hperiod=0,vperiod=0;
        unsigned old_mode=top.tape_mode,old_sensor=top.tape_sensor;
        bool old_waveform=top.tape_waveform;
        std::string failure;
        try {
            while(context.time()<end) {
                if(context.gotFinish()) throw std::runtime_error("unexpected HDL finish");
                uint64_t next=std::min({st(se),vt(ve),end});
                if(context.time()<reset_end) next=std::min(next,reset_end);
                if(ri<reset_edges.size()) next=std::min(next,reset_edges[ri].ps);
                if(key_active) next=std::min(next,key_edge);
                else if(ki<keys.size()) next=std::min(next,std::max({context.time()+1,keys[ki].ps,key_gap}));
#if VM_TIMING
                if(top.eventsPending()) next=std::min(next,top.nextTimeSlot());
#endif
                if(next<=context.time()) throw std::runtime_error("scheduler did not advance");
                context.timeInc(next-context.time());
                if(next==reset_end) {
                    if(uploads!=12288 || top.ioctl_download) throw std::runtime_error("upload reset deadline missed");
                    top.reset=0;
                }
                if(ri<reset_edges.size() && next==reset_edges[ri].ps) {
                    const bool asserted=reset_edges[ri++].asserted;
                    top.reset=asserted;
                    warm_assertions+=asserted;warm_releases+=!asserted;
                    // Count a sample already consumed on the preceding rising
                    // edge even if its producer pins update on this falling
                    // edge. Reset logs describe consumed cursor, not stale pins.
                    log<<next<<','<<(asserted?"reset_assert":"reset_release")<<','
                        <<(tape.position()+(sample_ack?1:0))
                        <<','<<unsigned(asserted)<<",0,"<<unsigned(top.tape_mode)<<','<<unsigned(top.tape_sensor)<<'\n';
                }
                bool sr=false,vr=false,pix=top.ce_pix;
                if(next==st(se)) {
                    sr=!top.clk_sys;
                    if(sr) {
                        upload_ack=top.ioctl_wr && !top.ioctl_wait;
                        if(upload_ack && !top.core_reset) throw std::runtime_error("upload outside drained reset");
                        // A reset asserted on this same consuming SYS edge must
                        // not advance the producer using stale pre-eval ready.
                        sample_ack=!top.reset && top.tape_sample_valid && top.tape_sample_ready;
                        if(sample_ack) {
                            log<<next<<",accept,"<<tape.position()<<','<<unsigned(top.tape_sample_level)<<','
                                <<unsigned(top.tape_sample_last)<<','<<unsigned(top.tape_mode)<<','<<unsigned(top.tape_sensor)<<'\n';
                            ++accepted;
                        }
                        ++sys_rises;
                    } else {
                        top.tape_mount=0;
                        if(upload_ack) {
                            ++uploads;upload_ack=false;
                            top.ioctl_download=uploads<12288;top.ioctl_wr=top.ioctl_download;
                            if(uploads<12288) {
                                top.ioctl_index=uploads<4096?0:6;
                                top.ioctl_addr=uploads<4096?uploads:uploads-4096;
                                top.ioctl_dout=uploads<4096?ipl[uploads]:controller[uploads-4096];
                            }
                        }
                        if(sample_ack) {tape.seek(tape.position()+1);sample_ack=false;buffer();}
                    }
                    top.clk_sys=!top.clk_sys;++se;
                }
                if(next==vt(ve)) {top.clk_28636=!top.clk_28636;vr=top.clk_28636;++ve;video_rises+=vr;}
                if(!key_active && ki<keys.size() && next>=std::max(keys[ki].ps,key_gap)) {
                    unsigned value=keys[ki++].byte,parity=1;
                    for(unsigned i=0;i<8;++i) parity^=(value>>i)&1;
                    packet=uint16_t((value<<1)|(parity<<9)|(1<<10));
                    bit=0;key_active=true;top.ps2_clk_in=1;top.ps2_data_in=0;key_edge=next+50000000;
                } else if(key_active && next==key_edge) {
                    top.ps2_clk_in=!top.ps2_clk_in;
                    if(top.ps2_clk_in) {
                        if(++bit==11) {key_active=false;top.ps2_data_in=1;++keys_sent;key_gap=next+200000000;}
                        else top.ps2_data_in=(packet>>bit)&1;
                    }
                    key_edge+=50000000;
                }
                top.eval();
                if(sr && !top.reset) {
                    if(top.HSync && !hs) {++hc;if(hl)hperiod=next-hl;hl=next;}
                    if(top.VSync && !vs) {++vc;if(vl)vperiod=next-vl;vl=next;}
                    hs=top.HSync;vs=top.VSync;
                }
                if(old_mode!=top.tape_mode || old_sensor!=top.tape_sensor) {
                    log<<next<<",state,"<<tape.position()<<",0,0,"<<unsigned(top.tape_mode)<<','<<unsigned(top.tape_sensor)<<'\n';
                    old_mode=top.tape_mode;old_sensor=top.tape_sensor;
                }
                if(old_waveform!=bool(top.tape_waveform)) {
                    log<<next<<",waveform,"<<tape.position()<<','<<unsigned(top.tape_waveform)
                        <<",0,"<<unsigned(top.tape_mode)<<','<<unsigned(top.tape_sensor)<<'\n';
                    old_waveform=top.tape_waveform;
                }
                if(vr && pix && !top.reset) {
                    if(frame.rows.size()>=1024) throw std::runtime_error("no bounded vertical sync");
                    frame.sample_rgb12(top.HSync,top.VSync,top.HBlank||top.VBlank,top.rgb12);
                }
                if(top.sd_rd || top.sd_wr) throw std::runtime_error("unexpected disk request; no service");
                if(top.tape_underflow) throw std::runtime_error("cassette producer underflow");
            }
        } catch(const std::exception& e) {failure=e.what();}
        if(sample_ack) tape.seek(tape.position()+1); // duration ended before falling edge
        if(upload_ack) ++uploads;
        top.debug_addr=marker;top.eval();unsigned marker_value=top.debug_ram;
        auto dump=[&](const char* name,int kind,unsigned count) {
            std::ofstream f(out/name,std::ios::binary);
            for(unsigned i=0;i<count;++i) {
                top.debug_addr=i;top.eval();
                f.put(char(kind==0?top.debug_ram:kind==1?top.debug_text:top.debug_attr));
            }
            if(!f) throw std::runtime_error("dump write failed");
        };
        dump("ram.bin",0,65536);dump("text.bin",1,2048);dump("attr.bin",2,2048);
        bool unchanged=true;std::ofstream provenance(out/"assets.sha256");
        for(const auto& a:assets) {
            bool same=false;try {same=sha256(read_file(a.path,a.limit))==a.hash;}catch(...){}
            unchanged &= same;provenance<<a.hash<<"  "<<a.path.string()<<"  unchanged="<<same<<'\n';
        }
        if(!unchanged) failure="input/executable mutation detected";
        // No unescaped caller strings in JSON. Detailed failure in terminal.txt.
        std::ofstream json(out/"report.json");
        json<<"{\n\"scope\":\"observational-native-waveform-not-compatibility\",\n"
            <<"\"terminal_exit\":"<<(failure.empty()?0:1)<<",\"inputs_unchanged\":"<<(unchanged?"true":"false")
            <<",\"non_savable\":true,\"cassette_enable\":true,\"turbo\":false,\"rtc\":false,\"dma\":false,"
            <<"\"disk_service\":false,\"intra_assignment_delays\":"<<(timing?"true":"false")
            <<",\"sys_hz\":32000000,\"video_hz\":28571428,\n"
            <<"\"cycles_requested\":"<<cycles<<",\"time_ps\":"<<context.time()<<",\"reset_release_ps\":"<<reset_end
            <<",\"startup_included\":true,\"sys_rising_edges\":"<<sys_rises<<",\"video_rising_edges\":"<<video_rises
            <<",\"warm_reset_assertions\":"<<warm_assertions<<",\"warm_reset_releases\":"<<warm_releases
            <<",\"warm_reset_width_us\":"<<reset_us<<",\"warm_reset_edges_pending\":"<<(reset_edges.size()-ri)
            <<",\"ipl_asset_bytes\":"<<ipl.size()<<",\"ipl_mapped_bytes\":4096,\"upper_ipl_bytes_uploaded\":false,\n"
            <<"\"ipl_sha256\":\""<<assets[0].hash<<"\",\"controller_sha256\":\""<<assets[1].hash
            <<"\",\"tape_sha256\":\""<<assets[2].hash<<"\",\"executable_sha256\":\""<<assets.back().hash<<"\",\n"
            <<"\"uploads_accepted\":"<<uploads<<",\"sample_rate\":8000,\"sample_count\":"<<tape.metadata().sample_count
            <<",\"start_position\":"<<tape.metadata().start_position<<",\"accepted_samples\":"<<accepted
            <<",\"accepted_sample_cursor\":"<<tape.position()<<",\"producer_exhausted\":"<<(tape.eof()?"true":"false")
            <<",\"playback_eof\":"<<(top.tape_sensor==2?"true":"false")<<",\"underflow\":"<<unsigned(top.tape_underflow)
            <<",\"mode\":"<<unsigned(top.tape_mode)<<",\"sensor\":"<<unsigned(top.tape_sensor)
            <<",\"write_protect_metadata\":"<<(tape.metadata().write_protected()?"true":"false")
            <<",\"ps2_bytes_sent\":"<<keys_sent<<",\"ps2_pending\":"<<(keys.size()-ki+(key_active?1:0))
            <<",\"marker_enabled\":"<<(marker_set?"true":"false")<<",\"marker_address\":"<<marker
            <<",\"marker_value\":"<<marker_value<<",\"cpu_address\":"<<top.cpu_address<<",\"cpu_halt_n\":"<<unsigned(top.cpu_halt_n)
            <<",\"frames\":"<<frame.frames<<",\"width\":"<<frame.width<<",\"height\":"<<frame.height
            <<",\"frame_fnv64\":"<<frame.hash<<",\"hs_edges\":"<<hc<<",\"vs_edges\":"<<vc
            <<",\"hs_period_ps\":"<<hperiod<<",\"vs_period_ps\":"<<vperiod<<"\n}\n";
        log<<context.time()<<",terminal,"<<tape.position()<<",0,0,"<<unsigned(top.tape_mode)<<','<<unsigned(top.tape_sensor)<<'\n';
        std::ofstream terminal(out/"terminal.txt");
        terminal<<"terminal_exit="<<(failure.empty()?0:1)<<"\n"
            <<(failure.empty()?"duration-complete; no loading-success claim":failure)<<'\n';
        top.final();
        if(!json || !log || !provenance || !terminal) throw std::runtime_error("evidence write failed");
        if(!failure.empty()) {std::cerr<<failure<<'\n';return 1;}
        return 0;
    } catch(const std::exception& e) {std::cerr<<"cassette runner: "<<e.what()<<'\n';return 1;}
}
