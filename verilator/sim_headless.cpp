#include <algorithm>
#include <cerrno>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <fstream>
#include <sstream>
#include <vector>
#include <deque>
#include <stdexcept>
#include <string>

#include "verilated.h"
#include "verilated_fst_c.h"
#include "Vtop.h"
#ifdef X1_SAVABLE
#include "verilated_save.h"
#endif
#include "frame_capture.h"
#include "audio_capture.h"
#ifdef X1_SDL
#include "sdl_frontend.h"
#endif

struct Download { uint8_t index; uint32_t address; uint8_t data; };

static std::vector<uint8_t> image(const std::string &path) {
    std::ifstream stream(path, std::ios::binary);
    if (!stream) throw std::runtime_error("cannot open image: " + path);
    std::vector<uint8_t> bytes;
    if (path.size() >= 4 && path.substr(path.size() - 4) == ".hex") {
        std::string token;
        while (stream >> token) {
            size_t used;
            unsigned long byte = std::stoul(token, &used, 16);
            if (used != token.size() || byte > 255) throw std::runtime_error("invalid raw hex image");
            bytes.push_back(byte);
        }
    } else {
        char byte;
        while (stream.get(byte)) bytes.push_back(static_cast<uint8_t>(byte));
    }
    if (bytes.empty()) throw std::runtime_error("empty image: " + path);
    return bytes;
}

static uint64_t number(const char *value) {
    char *end = nullptr;
    errno = 0;
    if (!*value || *value == '-') throw std::runtime_error("invalid unsigned number");
    auto result = std::strtoull(value, &end, 0);
    if (errno || *end) throw std::runtime_error("invalid unsigned number");
    return result;
}

int main(int argc, char **argv) {
    try {
        uint64_t cycles = 2000000, reset_cycles = 64;
        // Match the checked-in board PLL; the intended X1 crystal is different.
        uint64_t video_hz = 28571428;
        uint64_t joya = 0xff, joyb = 0xff;
        bool joya_override = false, joyb_override = false;
        const char *trace_path = nullptr;
        const char *rom_path = nullptr, *ram_path = nullptr;
        uint64_t load_address = 0x8000, entry = 0x8000, peek_address = 0xf000;
        const char *bus_path = nullptr;
        const char *disk_path = nullptr, *keys_path = nullptr, *dump_path = nullptr;
        const char *save_path = nullptr, *restore_path = nullptr;
        bool progress = false, io_only = false, interactive = false;
        FrameCapture frame;
        AudioCapture audio;
        for (int i = 1; i < argc; ++i) {
            if (!std::strcmp(argv[i], "--trace") && i + 1 < argc) trace_path = argv[++i];
            else if (!std::strcmp(argv[i], "--cycles") && i + 1 < argc) cycles = number(argv[++i]);
            else if (!std::strcmp(argv[i], "--reset-cycles") && i + 1 < argc) reset_cycles = number(argv[++i]);
            else if (!std::strcmp(argv[i], "--video-hz") && i + 1 < argc) video_hz = number(argv[++i]);
            else if (!std::strcmp(argv[i], "--joya") && i + 1 < argc) { joya = number(argv[++i]); joya_override = true; }
            else if (!std::strcmp(argv[i], "--joyb") && i + 1 < argc) { joyb = number(argv[++i]); joyb_override = true; }
            else if (!std::strcmp(argv[i], "--rom") && i + 1 < argc) rom_path = argv[++i];
            else if (!std::strcmp(argv[i], "--ram") && i + 1 < argc) ram_path = argv[++i];
            else if (!std::strcmp(argv[i], "--load-address") && i + 1 < argc) load_address = number(argv[++i]);
            else if (!std::strcmp(argv[i], "--entry") && i + 1 < argc) entry = number(argv[++i]);
            else if (!std::strcmp(argv[i], "--peek") && i + 1 < argc) peek_address = number(argv[++i]);
            else if (!std::strcmp(argv[i], "--bus-trace") && i + 1 < argc) bus_path = argv[++i];
            else if (!std::strcmp(argv[i], "--disk") && i + 1 < argc) disk_path = argv[++i];
            else if (!std::strcmp(argv[i], "--keys") && i + 1 < argc) keys_path = argv[++i];
            else if (!std::strcmp(argv[i], "--frame") && i + 1 < argc) frame.path = argv[++i];
            else if (!std::strcmp(argv[i], "--audio") && i + 1 < argc) audio.path = argv[++i];
            else if (!std::strcmp(argv[i], "--dump") && i + 1 < argc) dump_path = argv[++i];
            else if (!std::strcmp(argv[i], "--progress")) progress = true;
            else if (!std::strcmp(argv[i], "--io-only")) io_only = true;
            else if (!std::strcmp(argv[i], "--interactive")) interactive = true;
            else if (!std::strcmp(argv[i], "--save-state") && i + 1 < argc) save_path = argv[++i];
            else if (!std::strcmp(argv[i], "--restore-state") && i + 1 < argc) restore_path = argv[++i];
            else if (argv[i][0] != '-') cycles = number(argv[i]);
            else throw std::runtime_error("usage: Vtop [cycles] [--cycles N] [--reset-cycles N] [--video-hz N] [--trace output.fst] [--rom IMAGE] [--ram IMAGE --load-address A --entry A] [--disk IMAGE] [--keys SCRIPT] [--frame IMAGE.ppm] [--audio OUTPUT.wav] [--dump PREFIX] [--peek A] [--bus-trace CSV --io-only] [--progress] [--interactive] [--save-state FILE] [--restore-state FILE] [--joya BYTE --joyb BYTE]");
        }
        // Bound time arithmetic and avoid an entirely reset-only smoke run.
        if (cycles <= reset_cycles || reset_cycles == 0 || cycles > 1000000000000ULL)
            throw std::runtime_error("require 0 < reset-cycles < cycles <= 1000000000000");
        if (video_hz == 0 || video_hz > 100000000)
            throw std::runtime_error("require 0 < video-hz <= 100000000");
        if (load_address > 65535 || entry > 65535 || peek_address > 65520)
            throw std::runtime_error("load/entry/peek address out of range");
        if (joya > 255 || joyb > 255)
            throw std::runtime_error("joystick active-low pins must fit one byte");
        std::vector<Download> downloads;
        auto enqueue = [&](uint8_t index, uint32_t start, const std::vector<uint8_t> &bytes, uint32_t limit) {
            if (bytes.size() > limit || start + bytes.size() > limit)
                throw std::runtime_error("image exceeds memory aperture");
            for (size_t i = 0; i < bytes.size(); ++i)
                downloads.push_back({index, start + static_cast<uint32_t>(i), bytes[i]});
        };
        if (ram_path) enqueue(2, load_address, image(ram_path), 65536);
        if (rom_path) enqueue(0, 0, image(rom_path), 4096);
        else if (ram_path) {
            // Explicit debug boot, not an IPL/media boot. Execute the ROM-disable
            // trampoline in high RAM; never overwrite a game's entry at address 0.
            if (load_address + image(ram_path).size() > 0xfff0)
                throw std::runtime_error("RAM debug boot overlaps trampoline at FFF0; supply a ROM instead");
            std::vector<uint8_t> boot = {0xf3,0x01,0x00,0x1e,0xed,0x79,0xc3,
                                        static_cast<uint8_t>(entry),static_cast<uint8_t>(entry >> 8)};
            enqueue(0, 0, {0xc3,0xf0,0xff}, 4096);
            enqueue(2, 0xfff0, boot, 65536);
        }
        if (!downloads.empty())
            reset_cycles = std::max(reset_cycles, static_cast<uint64_t>(downloads.size()) + 64);
        if (cycles <= reset_cycles) throw std::runtime_error("cycles must exceed download plus reset duration");
        std::ofstream bus;
        std::vector<uint8_t> disk = disk_path ? image(disk_path) : std::vector<uint8_t>();
        if (disk.size() > 1048575) throw std::runtime_error("disk exceeds current FDC addressing");
        uint64_t disk_fingerprint = 14695981039346656037ULL;
        for (auto byte : disk) { disk_fingerprint ^= byte; disk_fingerprint *= 1099511628211ULL; }
        struct KeyEvent { uint64_t time; uint8_t byte; };
        std::deque<KeyEvent> keys;
        if (keys_path) {
            std::ifstream input(keys_path);
            if (!input) throw std::runtime_error("cannot open key script");
            uint64_t ms;
            std::string byte;
            while (input >> ms >> byte) {
                size_t used;
                auto value = std::stoul(byte, &used, 16);
                if (value > 255 || used != byte.size() || ms > 1000000)
                    throw std::runtime_error("invalid key script (milliseconds, PS/2 hex byte)");
                if (!keys.empty() && ms * 1000000000ULL < keys.back().time)
                    throw std::runtime_error("key events out of order");
                keys.push_back({ms * 1000000000ULL, static_cast<uint8_t>(value)});
            }
        }
        if (bus_path) {
            bus.open(bus_path);
            if (!bus) throw std::runtime_error("cannot open bus trace");
            bus << "time_ps,address,mreq_n,iorq_n,rd_n,wr_n,data_in,data_out\n";
        }
        VerilatedContext context;
#ifdef X1_SDL
        std::unique_ptr<SdlFrontend> frontend;
        if (interactive) frontend = std::make_unique<SdlFrontend>();
        uint64_t shown_frame = 0;
#else
        if (interactive) throw std::runtime_error("--interactive requires make interactive and obj_dir_interactive/Vtop");
#endif
        context.commandArgs(argc, argv);
        context.traceEverOn(trace_path != nullptr);
        Vtop top{&context};
        std::unique_ptr<VerilatedFstC> trace;
        if (trace_path) {
            trace = std::make_unique<VerilatedFstC>();
            top.trace(trace.get(), 8);
            trace->open(trace_path);
        }
        top.clk_sys = 0;
        top.clk_28636 = 0;
        top.reset = 1;
        top.ioctl_download = 0;
        top.ioctl_index = 0;
        top.ioctl_wr = 0;
        top.ioctl_addr = 0;
        top.ioctl_dout = 0;
        top.ps2_clk_in = 1;
        top.ps2_data_in = 1;
        top.joya_n = joya;
        top.joyb_n = joyb;
        top.disk_ready = !disk.empty();
        top.img_mounted = !disk.empty();
        top.disk_wp = 1; // Explicitly read-only media for initial boot testing.
        top.img_size = disk.size();
        top.sd_ack = 0;
        top.sd_buff_addr = 0;
        top.sd_buff_dout = 0;
        top.sd_buff_wr = 0;
        top.debug_addr = peek_address;
        size_t download_pos = 0;
        auto set_download = [&]() {
            const bool active = download_pos < downloads.size();
            top.ioctl_download = active;
            top.ioctl_wr = active;
            if (active) {
                const auto &item = downloads[download_pos];
                top.ioctl_index = item.index;
                top.ioctl_addr = item.address;
                top.ioctl_dout = item.data;
            }
        };
        set_download();
        auto evaluate = [&]() {
            top.eval();
            if (trace) trace->dump(context.time());
        };
        evaluate();

        // Fast-model snapshots preserve actual native-booted RTL state, not
        // a reconstructed RAM bootstrap. Only quiescent host interfaces are
        // supported; disk contents must match and clocks keep absolute phase.
        uint64_t resume_time = 0;
        constexpr uint64_t snapshot_magic = 0x5831534e41503031ULL;
#ifdef X1_SAVABLE
        if (restore_path) {
            if (rom_path || ram_path) throw std::runtime_error("snapshot restore cannot also download ROM/RAM");
            VerilatedRestore state;
            state.open(restore_path);
            if (!state.isOpen()) throw std::runtime_error("cannot open snapshot");
            uint64_t magic, saved_video_hz, saved_disk;
            state >> magic >> resume_time >> saved_video_hz >> saved_disk;
            if (magic != snapshot_magic || saved_video_hz != video_hz || saved_disk != disk_fingerprint)
                throw std::runtime_error("snapshot version, video clock or disk fingerprint mismatch");
            if (resume_time % 31250 || resume_time / 31250 + cycles > 1000000000000ULL)
                throw std::runtime_error("snapshot time or resumed duration out of range");
            state >> top;
            state.close();
            // Retain saved pins unless an explicit new external input is given.
            if (joya_override) top.joya_n = joya;
            if (joyb_override) top.joyb_n = joyb;
            if (top.sys_edges != resume_time / 31250 || top.clk_sys || top.reset)
                throw std::runtime_error("snapshot is not a running falling-clock boundary");
            cycles += top.sys_edges;
            reset_cycles = top.reset_edges;
            context.time(resume_time);
            for (auto &event : keys) event.time += resume_time;
            evaluate();
        }
#else
        if (save_path || restore_path) throw std::runtime_error("snapshots require make fast");
#endif

        // All times are picoseconds. 32 MHz is exactly 31,250 ps/cycle.
        // Round each video edge from its absolute rational time, avoiding drift.
        constexpr uint64_t sys_half_ps = 15625;
        auto video_time = [video_hz](uint64_t edge) -> uint64_t {
            // Wide intermediate prevents overflow on long simulations.
            return (static_cast<unsigned __int128>(edge) * 1000000000000ULL + video_hz) / (2 * video_hz);
        };
        uint64_t sys_edge = resume_time / sys_half_ps + 1;
        uint64_t vid_edge = (static_cast<unsigned __int128>(resume_time) * 2 * video_hz) / 1000000000000ULL + 1;
        while (video_time(vid_edge) <= resume_time) ++vid_edge;
        audio.edge = (static_cast<unsigned __int128>(resume_time) * AudioCapture::rate) / 1000000000000ULL + 1;
        while (audio.next_time() <= resume_time) ++audio.edge;
        const uint64_t end_ps = cycles * 2 * sys_half_ps;
        const uint64_t reset_end_ps = reset_cycles * 2 * sys_half_ps;
        uint64_t hs_edges = 0, vs_edges = 0;
        uint64_t hash = 14695981039346656037ULL;
        bool old_hs = top.HSync, old_vs = top.VSync;
        unsigned disk_byte = 0, disk_cooldown = 0;
        uint64_t disk_offset = 0, disk_requests = 0;
        bool disk_active = false;
        uint16_t key_packet = 0;
        unsigned key_bit = 0;
        bool key_active = false;
        uint64_t key_edge = 0;
        uint64_t progress_time = resume_time + 100000000000ULL;
        while (context.time() < end_ps && !context.gotFinish()) {
            uint64_t next = std::min({sys_edge * sys_half_ps, video_time(vid_edge), end_ps});
            if (context.time() < reset_end_ps) next = std::min(next, reset_end_ps);
            if (!audio.path.empty()) next = std::min(next, audio.next_time());
#if VM_TIMING
            if (top.eventsPending()) next = std::min(next, top.nextTimeSlot());
#endif
            if (key_active) next = std::min(next, key_edge);
            else if (!keys.empty()) next = std::min(next, std::max(context.time() + 1, keys.front().time));
            if (next <= context.time()) throw std::runtime_error("scheduler did not advance");
            context.timeInc(next - context.time());
            // Release at a falling system edge, away from a CPU sampling edge.
            top.reset = next < reset_end_ps;
            bool sys_rise = false;
            bool video_rise = false;
            bool pixel_enable = top.ce_pix;
            if (next == sys_edge * sys_half_ps) {
                top.clk_sys = !top.clk_sys;
                sys_rise = top.clk_sys;
                if (!sys_rise && download_pos < downloads.size()) {
                    ++download_pos;
                    set_download();
                }
                if (!sys_rise) {
                    if (sys_edge >= 10) top.img_mounted = 0;
                    top.sd_buff_wr = 0;
                    if (disk_active) {
                        if (++disk_byte == 512) {
                            disk_active = false;
                            top.sd_ack = 0;
                            disk_cooldown = 8;
                        } else {
                            top.sd_buff_addr = disk_byte;
                            top.sd_buff_dout = disk_offset + disk_byte < disk.size() ? disk[disk_offset + disk_byte] : 0;
                            top.sd_buff_wr = 1;
                        }
                    } else if (disk_cooldown) --disk_cooldown;
                    else if (top.sd_rd) {
                        disk_offset = uint64_t(top.sd_lba) * 512;
                        disk_byte = 0;
                        disk_active = true;
                        ++disk_requests;
                        top.sd_ack = 1;
                        top.sd_buff_wr = 1;
                        top.sd_buff_addr = 0;
                        top.sd_buff_dout = disk_offset < disk.size() ? disk[disk_offset] : 0;
                    } else if (top.sd_wr) throw std::runtime_error("unexpected write to read-only disk");
                }
                ++sys_edge;
            }
            if (next == video_time(vid_edge)) {
                top.clk_28636 = !top.clk_28636;
                video_rise = top.clk_28636;
                ++vid_edge;
            }
            if (!key_active && !keys.empty() && next >= keys.front().time) {
                uint8_t value = keys.front().byte;
                keys.pop_front();
                unsigned parity = 1;
                for (unsigned i = 0; i < 8; ++i) parity ^= (value >> i) & 1;
                key_packet = (uint16_t(value) << 1) | (parity << 9) | (1 << 10);
                key_bit = 0;
                key_active = true;
                top.ps2_clk_in = 1;
                top.ps2_data_in = 0;
                key_edge = next + 50000000;
            } else if (key_active && next == key_edge) {
                top.ps2_clk_in = !top.ps2_clk_in;
                if (top.ps2_clk_in) {
                    if (++key_bit == 11) {
                        key_active = false;
                        top.ps2_data_in = 1;
                        if (!keys.empty()) keys.front().time = std::max(keys.front().time, next + 200000000);
                    } else top.ps2_data_in = (key_packet >> key_bit) & 1;
                }
                key_edge += 50000000;
            }
            evaluate();
            if (!audio.path.empty() && next == audio.next_time()) audio.sample(top.audio);
            if (progress && next >= progress_time) {
                std::fprintf(stderr, "t=%.3fs cpu=%04x sub=%04x tx=%u rx_empty=%u frames=%llu disk_blocks=%llu\n",
                             double(next) / 1e12, top.cpu_address, top.sub_pc,
                             unsigned(top.sub_tx), unsigned(top.sub_rx),
                             (unsigned long long)frame.frames, (unsigned long long)disk_requests);
                progress_time += 100000000000ULL;
            }
            if (video_rise && pixel_enable && !top.reset)
                frame.sample(top.HSync, top.VSync, top.HBlank || top.VBlank, top.rgb);
#ifdef X1_SDL
            if (frontend && sys_rise && (top.sys_edges & 4095) == 0) {
                if (!frontend->poll([&](uint8_t byte) {
                    keys.push_back({std::max(next, keys.empty() ? next : keys.back().time), byte});
                })) { context.gotFinish(true); }
                if (frame.frames != shown_frame) {
                    frontend->show(frame.pixels, frame.width, frame.height, next);
                    shown_frame = frame.frames;
                }
            }
#endif
            if (sys_rise) {
                if (bus && !top.reset && (!top.cpu_rd_n || !top.cpu_wr_n)
                        && (!io_only || !top.cpu_iorq_n)) {
                    bus << context.time() << ',' << top.cpu_address << ','
                        << unsigned(top.cpu_mreq_n) << ',' << unsigned(top.cpu_iorq_n) << ','
                        << unsigned(top.cpu_rd_n) << ',' << unsigned(top.cpu_wr_n) << ','
                        << unsigned(top.cpu_in) << ',' << unsigned(top.cpu_out) << '\n';
                }
                hash ^= static_cast<uint8_t>(top.video);
                hash *= 1099511628211ULL;
                if (static_cast<bool>(top.HSync) != old_hs) ++hs_edges;
                if (static_cast<bool>(top.VSync) != old_vs) ++vs_edges;
                old_hs = top.HSync;
                old_vs = top.VSync;
            }
        }
#ifdef X1_SAVABLE
        if (save_path) {
            if (context.time() % 31250 || top.reset || disk_active || disk_cooldown
                    || key_active || !keys.empty() || top.sd_rd || top.sd_wr || top.ioctl_download)
                throw std::runtime_error("snapshot requires a running falling edge and quiescent disk/keyboard/download host");
            VerilatedSave state;
            state.open(save_path);
            if (!state.isOpen()) throw std::runtime_error("cannot create snapshot");
            state << snapshot_magic << context.time() << video_hz << disk_fingerprint << top;
            state.close();
        }
#endif
        std::string peek;
        audio.finish();
        if (dump_path) {
            std::ofstream memory(std::string(dump_path) + ".ram", std::ios::binary);
            std::ofstream text(std::string(dump_path) + ".text", std::ios::binary);
            std::ofstream attr(std::string(dump_path) + ".attr", std::ios::binary);
            if (!memory || !text || !attr) throw std::runtime_error("cannot open dumps");
            for (unsigned address = 0; address < 65536; ++address) {
                top.debug_addr = address;
                top.eval();
                memory.put(top.debug_ram);
                if (address < 2048) { text.put(top.debug_text); attr.put(top.debug_attr); }
            }
        }
        for (unsigned i = 0; i < 16; ++i) {
            top.debug_addr = peek_address + i;
            top.eval();
            char byte[3];
            std::snprintf(byte, sizeof(byte), "%02x", top.debug_ram);
            peek += byte;
        }
        std::printf("{\"machine\":\"sharpx1\",\"intra_assignment_delays\":%s,\"sys_hz\":32000000,\"video_hz\":%llu,"
                    "\"time_ps\":%llu,\"sys_edges\":%llu,\"video_edges\":%llu,"
                    "\"reset_edges\":%llu,\"cpu_enables\":%llu,\"delayed_sys_edges\":%llu,"
                    "\"hs_edges\":%llu,\"vs_edges\":%llu,\"video_hash\":\"%016llx\","
                    "\"download_bytes\":%llu,\"cpu_address\":%u,\"halted\":%s,\"peek\":\"%s\","
                    "\"disk_requests\":%llu,\"frames\":%llu,\"frame_width\":%u,\"frame_height\":%u,\"frame_hash\":\"%016llx\","
                    "\"sub_pc\":%u,\"sub_address\":%u,\"sub_control\":%u,\"sub_running\":%s,\"sub_tx_busy\":%s,\"sub_rx_empty\":%s}\n",
                    VM_TIMING ? "true" : "false",
                    (unsigned long long)video_hz, (unsigned long long)context.time(), (unsigned long long)top.sys_edges,
                    (unsigned long long)top.video_edges, (unsigned long long)top.reset_edges,
                    (unsigned long long)top.cpu_enables, (unsigned long long)top.delayed_sys_edges,
                    (unsigned long long)hs_edges, (unsigned long long)vs_edges, (unsigned long long)hash,
                    (unsigned long long)downloads.size(), top.cpu_address, top.cpu_halt_n ? "false" : "true", peek.c_str(),
                    (unsigned long long)disk_requests,(unsigned long long)frame.frames,frame.width,frame.height,
                    (unsigned long long)frame.hash,
                    top.sub_pc,top.sub_address,top.sub_control,
                    top.sub_wait ? "true" : "false",top.sub_tx ? "true" : "false",top.sub_rx ? "true" : "false");
        const bool passed = (interactive && context.gotFinish()) || (context.time() == end_ps && top.sys_edges == cycles
            && top.reset_edges == reset_cycles && top.delayed_sys_edges == cycles);
        top.final();
        if (trace) trace->close();
        return passed ? 0 : 1;
    } catch (const std::exception &error) {
        std::fprintf(stderr, "%s\n", error.what());
        return 2;
    }
}
