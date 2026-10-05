#include <algorithm>
#include <array>
#include <cerrno>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <fstream>
#include <filesystem>
#include <fcntl.h>
#include <unistd.h>
#include <sstream>
#include <vector>
#include <deque>
#include <stdexcept>
#include <string>

#include "verilated.h"
#include "verilated_fst_c.h"
#include "Vtop.h"
#include "Vtop___024root.h"
#ifdef X1_SAVABLE
#include "verilated_save.h"
#endif
#include "frame_capture.h"
#include "audio_capture.h"
#include "d88_image.h"
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
        std::vector<uint64_t> reset_at_ms;
        uint64_t reset_for_us = 1000;
        // Match the checked-in board PLL; the intended X1 crystal is different.
#ifdef X1_SINGLE_CLOCK
        constexpr uint64_t sys_hz = 28636364;
        uint64_t video_hz = sys_hz;
#else
        constexpr uint64_t sys_hz = 32000000;
#ifdef X1_TURBO_VIDEO_MASTER
        uint64_t video_hz = 42954540;
#else
        uint64_t video_hz = 28571428;
#endif
#endif
        uint64_t joya = 0xff, joyb = 0xff;
        bool joya_override = false, joyb_override = false;
        const char *trace_path = nullptr;
        const char *rom_path = nullptr, *ram_path = nullptr, *font16_path = nullptr;
        uint64_t load_address = 0x8000, entry = 0x8000, peek_address = 0xf000;
        const char *bus_path = nullptr;
        uint64_t bus_start_ms = 0, bus_end_ms = 0;
        bool bus_events = false;
        const char *disk_path = nullptr, *keys_path = nullptr, *dump_path = nullptr;
        const char *disk_output = nullptr;
        const char *disk_b_path = nullptr, *disk_b_output = nullptr;
        const char *save_path = nullptr, *restore_path = nullptr;
        bool progress = false, io_only = false, interactive = false, joystick_keys = false;
        FrameCapture frame;
        AudioCapture audio;
        for (int i = 1; i < argc; ++i) {
            if (!std::strcmp(argv[i], "--trace") && i + 1 < argc) trace_path = argv[++i];
            else if (!std::strcmp(argv[i], "--cycles") && i + 1 < argc) cycles = number(argv[++i]);
            else if (!std::strcmp(argv[i], "--reset-cycles") && i + 1 < argc) reset_cycles = number(argv[++i]);
            else if (!std::strcmp(argv[i], "--reset-at") && i + 1 < argc) reset_at_ms.push_back(number(argv[++i]));
            else if (!std::strcmp(argv[i], "--reset-for-us") && i + 1 < argc) reset_for_us = number(argv[++i]);
            else if (!std::strcmp(argv[i], "--video-hz") && i + 1 < argc) video_hz = number(argv[++i]);
            else if (!std::strcmp(argv[i], "--font16") && i + 1 < argc) font16_path = argv[++i];
            else if (!std::strcmp(argv[i], "--joya") && i + 1 < argc) { joya = number(argv[++i]); joya_override = true; }
            else if (!std::strcmp(argv[i], "--joyb") && i + 1 < argc) { joyb = number(argv[++i]); joyb_override = true; }
            else if (!std::strcmp(argv[i], "--rom") && i + 1 < argc) rom_path = argv[++i];
            else if (!std::strcmp(argv[i], "--ram") && i + 1 < argc) ram_path = argv[++i];
            else if (!std::strcmp(argv[i], "--load-address") && i + 1 < argc) load_address = number(argv[++i]);
            else if (!std::strcmp(argv[i], "--entry") && i + 1 < argc) entry = number(argv[++i]);
            else if (!std::strcmp(argv[i], "--peek") && i + 1 < argc) peek_address = number(argv[++i]);
            else if (!std::strcmp(argv[i], "--bus-trace") && i + 1 < argc) bus_path = argv[++i];
            else if (!std::strcmp(argv[i], "--bus-start-ms") && i + 1 < argc) bus_start_ms = number(argv[++i]);
            else if (!std::strcmp(argv[i], "--bus-end-ms") && i + 1 < argc) bus_end_ms = number(argv[++i]);
            else if (!std::strcmp(argv[i], "--bus-events")) bus_events = true;
            else if (!std::strcmp(argv[i], "--disk") && i + 1 < argc) disk_path = argv[++i];
            else if (!std::strcmp(argv[i], "--disk-output") && i + 1 < argc) disk_output = argv[++i];
            else if (!std::strcmp(argv[i], "--disk-b") && i + 1 < argc) disk_b_path = argv[++i];
            else if (!std::strcmp(argv[i], "--disk-b-output") && i + 1 < argc) disk_b_output = argv[++i];
            else if (!std::strcmp(argv[i], "--keys") && i + 1 < argc) keys_path = argv[++i];
            else if (!std::strcmp(argv[i], "--frame") && i + 1 < argc) frame.path = argv[++i];
            else if (!std::strcmp(argv[i], "--audio") && i + 1 < argc) audio.path = argv[++i];
            else if (!std::strcmp(argv[i], "--dump") && i + 1 < argc) dump_path = argv[++i];
            else if (!std::strcmp(argv[i], "--progress")) progress = true;
            else if (!std::strcmp(argv[i], "--io-only")) io_only = true;
            else if (!std::strcmp(argv[i], "--interactive")) interactive = true;
            else if (!std::strcmp(argv[i], "--joystick-keys")) joystick_keys = true;
            else if (!std::strcmp(argv[i], "--save-state") && i + 1 < argc) save_path = argv[++i];
            else if (!std::strcmp(argv[i], "--restore-state") && i + 1 < argc) restore_path = argv[++i];
            else if (argv[i][0] != '-') cycles = number(argv[i]);
            else throw std::runtime_error("usage: Vtop [cycles] [--cycles N] [--reset-cycles N] [--reset-at MS (repeatable) --reset-for-us US] [--video-hz N] [--trace output.fst] [--rom IMAGE] [--ram IMAGE --load-address A --entry A] [--disk IMAGE --disk-output NEW_COPY] [--disk-b IMAGE --disk-b-output NEW_COPY] [--keys SCRIPT] [--frame IMAGE.ppm] [--audio OUTPUT.wav] [--dump PREFIX] [--peek A] [--bus-trace CSV --io-only --bus-events --bus-start-ms N --bus-end-ms N] [--progress] [--interactive [--joystick-keys]] [--save-state FILE] [--restore-state FILE] [--joya BYTE --joyb BYTE]");
        }
        if (joystick_keys && !interactive)
            throw std::runtime_error("--joystick-keys requires --interactive");
        if ((bus_events || bus_start_ms || bus_end_ms) && !bus_path)
            throw std::runtime_error("bus trace options require --bus-trace");
        if (bus_start_ms > 1000000000ULL || bus_end_ms > 1000000000ULL
                || (bus_end_ms && bus_end_ms <= bus_start_ms))
            throw std::runtime_error("require bus-start-ms < bus-end-ms <= 1000000000 (end 0 means unbounded)");
        // Bound time arithmetic and avoid an entirely reset-only smoke run.
        if (cycles <= reset_cycles || reset_cycles == 0 || cycles > 1000000000000ULL)
            throw std::runtime_error("require 0 < reset-cycles < cycles <= 1000000000000");
        if (video_hz == 0 || video_hz > 100000000)
            throw std::runtime_error("require 0 < video-hz <= 100000000");
#ifdef X1_TURBO_VIDEO_MASTER
        if (video_hz != 42954540)
            throw std::runtime_error("Turbo video-master model requires video-hz = 42954540");
#endif
        if (!reset_for_us || reset_for_us > 1000000)
            throw std::runtime_error("require 0 < reset-for-us <= 1000000");
#ifdef X1_SINGLE_CLOCK
        if (video_hz != sys_hz) throw std::runtime_error("single-clock model requires video-hz = 28636364");
#endif
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
        if (font16_path) {
#ifdef X1_TURBO_FOUNDATION
            auto font_bytes = image(font16_path);
            if (font_bytes.size() != 4096) throw std::runtime_error("font16 must contain exactly 4096 bytes");
            enqueue(4, 0, font_bytes, 4096);
#else
            throw std::runtime_error("font16 requires a Turbo model");
#endif
        }
#ifdef X1_TURBO_FOUNDATION
        constexpr unsigned ipl_capacity = 32768;
        constexpr const char *turbo_foundation = "true";
#else
        constexpr unsigned ipl_capacity = 4096;
        constexpr const char *turbo_foundation = "false";
#endif
        if (rom_path) enqueue(0, 0, image(rom_path), ipl_capacity);
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
            reset_cycles = std::max(reset_cycles,
                ((static_cast<uint64_t>(downloads.size()) + 64) * 32000000 + sys_hz - 1) / sys_hz);
        if (cycles <= reset_cycles) throw std::runtime_error("cycles must exceed download plus reset duration");
        std::ofstream bus;
        std::array<uint64_t, 11> bus_row{};
        bool bus_pending = false;
        auto flush_bus = [&]() {
            if (!bus_pending) return;
            for (size_t field = 0; field < bus_row.size(); ++field)
                bus << (field ? "," : "") << bus_row[field];
            bus << '\n';
            bus_pending = false;
        };
        std::vector<uint8_t> disk = disk_path ? image(disk_path) : std::vector<uint8_t>();
        std::vector<uint8_t> disk_b = disk_b_path ? image(disk_b_path) : std::vector<uint8_t>();
        std::array<const char*,2> disk_paths{disk_path,disk_b_path};
        std::array<const char*,2> disk_outputs{disk_output,disk_b_output};
        for (size_t d = 0; d < 2; ++d) if (disk_outputs[d]) {
            if (!disk_paths[d]) throw std::runtime_error("disk output requires its drive's input image");
            if (std::filesystem::exists(disk_outputs[d]))
                throw std::runtime_error("disk output already exists; choose a new copy path");
            for (const auto source : disk_paths) if (source &&
                std::filesystem::weakly_canonical(disk_outputs[d]) == std::filesystem::canonical(source))
                    throw std::runtime_error("disk output must not overwrite either input image");
        }
        if (disk_output && disk_b_output && std::filesystem::weakly_canonical(disk_output)
            == std::filesystem::weakly_canonical(disk_b_output))
            throw std::runtime_error("drive outputs must be different paths");
        if (disk_b_path && (save_path || restore_path))
            throw std::runtime_error("dual-drive snapshots are not supported; use a fresh boot");
        if (disk.size() > 1048575 || disk_b.size() > 1048575) throw std::runtime_error("disk exceeds current FDC addressing");
        if (disk_path) validate_d88(disk);
        if (disk_b_path) validate_d88(disk_b);
        uint64_t disk_fingerprint = 14695981039346656037ULL;
        for (auto byte : disk) { disk_fingerprint ^= byte; disk_fingerprint *= 1099511628211ULL; }
        struct KeyEvent { uint64_t time; uint8_t byte; };
        std::deque<KeyEvent> keys;
        if (keys_path) {
            std::ifstream input(keys_path);
            if (!input) throw std::runtime_error("cannot open key script");
            std::string line;
            while (std::getline(input, line)) {
                line.resize(line.find('#') == std::string::npos ? line.size() : line.find('#'));
                std::istringstream fields(line);
                fields >> std::ws;
                if (fields.eof()) continue;
                uint64_t ms;
                std::string byte, extra;
                if (!(fields >> ms >> byte) || (fields >> extra))
                    throw std::runtime_error("invalid key script (milliseconds, PS/2 hex byte)");
                size_t used;
                unsigned long value;
                try { value = std::stoul(byte, &used, 16); }
                catch (const std::exception &) {
                    throw std::runtime_error("invalid key script (milliseconds, PS/2 hex byte)");
                }
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
            bus << "time_ps,address,mreq_n,iorq_n,rd_n,wr_n,data_in,data_out,drive_control,motor,media_ready\n";
        }
        VerilatedContext context;
#ifdef X1_SDL
        std::unique_ptr<SdlFrontend> frontend;
        if (interactive) frontend = std::make_unique<SdlFrontend>(joystick_keys);
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
        top.disk_wp = disk_output ? 0 : 1; // Writes only to an explicit new copy.
        top.img_size = disk.size();
        top.disk_ready_b = !disk_b.empty();
        top.img_mounted_b = !disk_b.empty();
        top.disk_wp_b = disk_b_output ? 0 : 1;
        top.img_size_b = disk_b.size();
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
        // v08: X3 video-to-PPI status synchronizers.
        // v07: high-speed PCG/font transactions and payload/header metadata
        // publication/cancellation. v06 added the FDC ID-side flags.
        // v05 added the FDC transfer-completion CRC latch.
        // v04 widened the D88 index to retain deleted-data metadata. Never load
        // an earlier serialized model into the new RAM layout.
        // Keep a distinct identity for different compiled
        // machine layouts before calling VerilatedRestore. Matching rates
        // alone do not make base/Turbo model serialization interchangeable.
        constexpr uint64_t snapshot_profile = 0
#ifdef X1_TURBO_FOUNDATION
            ^ (1ULL << 56)
#endif
#ifdef X1_TURBO_VIDEO_MASTER
            ^ (1ULL << 55)
#endif
            ;
        constexpr uint64_t snapshot_magic = 0x5831534e41503038ULL ^ sys_hz ^ snapshot_profile;
#ifdef X1_SAVABLE
        if (restore_path) {
            if (rom_path || ram_path || font16_path) throw std::runtime_error("snapshot restore cannot also download ROM/RAM/font16");
            // Reject our application header before constructing VerilatedRestore:
            // its destructor checks a trailer at the current read position,
            // which can abort while unwinding an early header exception.
            // Verilator save02 has a fixed 16-byte prefix; unknown versions
            // fail closed instead of attempting incompatible deserialization.
            std::ifstream header(restore_path, std::ios::binary);
            char signature[16];
            uint64_t fields[4];
            header.read(signature, sizeof signature);
            header.read(reinterpret_cast<char *>(fields), sizeof fields);
            if (!header || std::memcmp(signature, "verilatorsave02\n", 16))
                throw std::runtime_error("snapshot header missing, truncated or unsupported");
            if (fields[0] != snapshot_magic || fields[2] != video_hz || fields[3] != disk_fingerprint)
                throw std::runtime_error("snapshot version, video clock or disk fingerprint mismatch");
            if (fields[1] % 31250 || fields[1] / 31250 + cycles > 1000000000000ULL)
                throw std::runtime_error("snapshot time or resumed duration out of range");
            VerilatedRestore state;
            state.open(restore_path);
            if (!state.isOpen()) throw std::runtime_error("cannot open snapshot");
            uint64_t magic, saved_video_hz, saved_disk;
            state >> magic >> resume_time >> saved_video_hz >> saved_disk;
            if (magic != snapshot_magic || saved_video_hz != video_hz || saved_disk != disk_fingerprint)
                throw std::runtime_error("snapshot version, video clock or disk fingerprint mismatch");
            state >> top;
            state.close();
            // Retain saved pins unless an explicit new external input is given.
            if (joya_override || joystick_keys) top.joya_n = joya;
            if (joyb_override) top.joyb_n = joyb;
            top.disk_wp = disk_output ? 0 : 1;
            if (top.reset) throw std::runtime_error("snapshot is still in reset");
            cycles += resume_time / 31250;
            reset_cycles = 0; // Restored RTL retains reset counters and clock phase.
            context.time(resume_time);
            for (auto &event : keys) event.time += resume_time;
            evaluate();
        }
#else
        if (save_path || restore_path) throw std::runtime_error("snapshots require make fast");
#endif

        // All times are picoseconds. 32 MHz is exactly 31,250 ps/cycle.
        // Round each video edge from its absolute rational time, avoiding drift.
        auto sys_time = [](uint64_t edge) -> uint64_t {
            return (static_cast<unsigned __int128>(edge) * 1000000000000ULL + sys_hz) / (2 * sys_hz);
        };
        auto video_time = [video_hz](uint64_t edge) -> uint64_t {
            // Wide intermediate prevents overflow on long simulations.
            return (static_cast<unsigned __int128>(edge) * 1000000000000ULL + video_hz) / (2 * video_hz);
        };
        uint64_t sys_edge = (static_cast<unsigned __int128>(resume_time) * 2 * sys_hz) / 1000000000000ULL + 1;
        while (sys_time(sys_edge) <= resume_time) ++sys_edge;
        uint64_t vid_edge = (static_cast<unsigned __int128>(resume_time) * 2 * video_hz) / 1000000000000ULL + 1;
        while (video_time(vid_edge) <= resume_time) ++vid_edge;
        audio.edge = (static_cast<unsigned __int128>(resume_time) * AudioCapture::rate) / 1000000000000ULL + 1;
        while (audio.next_time() <= resume_time) ++audio.edge;
        // --cycles remains a 32 MHz reference-duration unit for A/B comparisons.
        const uint64_t end_ps = cycles * 31250;
        const uint64_t reset_end_ps = reset_cycles * 31250;
        std::vector<std::pair<uint64_t, uint64_t>> resets;
        for (auto ms : reset_at_ms) {
            if (ms > 1000000) throw std::runtime_error("reset-at exceeds 1000000 ms");
            uint64_t start = resume_time + ms * 1000000000ULL;
            uint64_t finish = start + reset_for_us * 1000000ULL;
            if (start <= std::max(resume_time, reset_end_ps) || finish >= end_ps
                || (!resets.empty() && start <= resets.back().second))
                throw std::runtime_error("reset pulses must be ordered, non-overlapping and inside the run after startup reset");
            resets.emplace_back(start, finish);
        }
        size_t reset_cursor = 0;
        uint64_t hs_edges = 0, vs_edges = 0;
        // Settled rising-edge periods sampled on clk_sys. Quantization is
        // one system period; these are not sub-cycle pin/CDC measurements.
        uint64_t last_hs_rise = 0, last_vs_rise = 0, hs_period_ps = 0, vs_period_ps = 0;
        uint64_t hash = 14695981039346656037ULL;
        bool old_hs = top.HSync, old_vs = top.VSync;
        unsigned disk_byte = 0, disk_cooldown = 0;
        uint64_t disk_offset = 0, disk_requests = 0, disk_writes = 0;
        unsigned request_drive = 0;
        bool disk_active = false, disk_writing = false;
        uint16_t key_packet = 0;
        unsigned key_bit = 0;
        uint64_t ps2_bytes_sent = 0;
        bool key_active = false;
        uint64_t key_edge = 0;
        uint64_t progress_time = resume_time + 100000000000ULL;
        uint64_t expected_reset_edges = top.reset_edges;
        while (context.time() < end_ps && !context.gotFinish()) {
            uint64_t next = std::min({sys_time(sys_edge), video_time(vid_edge), end_ps});
            if (context.time() < reset_end_ps) next = std::min(next, reset_end_ps);
            if (reset_cursor < resets.size()) {
                auto [start, finish] = resets[reset_cursor];
                next = std::min(next, context.time() < start ? start : finish);
            }
            if (!audio.path.empty()) next = std::min(next, audio.next_time());
#if VM_TIMING
            if (top.eventsPending()) next = std::min(next, top.nextTimeSlot());
#endif
            if (key_active) next = std::min(next, key_edge);
            else if (!keys.empty()) next = std::min(next, std::max(context.time() + 1, keys.front().time));
            if (next <= context.time()) throw std::runtime_error("scheduler did not advance");
            context.timeInc(next - context.time());
            // Warm resets are relative to this run/restore, with deterministic
            // boundaries. Host disk/PS2 interfaces keep running during reset.
            while (reset_cursor < resets.size() && next >= resets[reset_cursor].second) ++reset_cursor;
            top.reset = next < reset_end_ps || (reset_cursor < resets.size()
                         && next >= resets[reset_cursor].first);
            bool sys_rise = false;
            bool video_rise = false;
            bool pixel_enable = top.ce_pix;
            if (next == sys_time(sys_edge)) {
                top.clk_sys = !top.clk_sys;
                sys_rise = top.clk_sys;
                if (sys_rise && top.reset) ++expected_reset_edges;
                if (!sys_rise && download_pos < downloads.size()) {
                    ++download_pos;
                    set_download();
                }
                if (!sys_rise) {
                    if (sys_edge >= 10) { top.img_mounted = 0; top.img_mounted_b = 0; }
                    top.sd_buff_wr = 0;
                    if (disk_active) {
                        auto &medium = request_drive ? disk_b : disk;
                        if (top.sd_drive != request_drive)
                            throw std::runtime_error("disk request changed owner during ACK");
                        if (disk_writing && disk_offset + disk_byte < medium.size())
                            medium[disk_offset + disk_byte] = top.sd_buff_din;
                        if (++disk_byte == 512) {
                            disk_active = false;
                            top.sd_ack = 0;
                            disk_cooldown = 8;
                        } else if (!disk_writing) {
                            top.sd_buff_addr = disk_byte;
                            top.sd_buff_dout = disk_offset + disk_byte < medium.size() ? medium[disk_offset + disk_byte] : 0;
                            top.sd_buff_wr = 1;
                        }
                    } else if (disk_cooldown) --disk_cooldown;
                    else if (top.sd_rd) {
                        request_drive = top.sd_drive;
                        const auto &medium = request_drive ? disk_b : disk;
                        if (medium.empty()) throw std::runtime_error("read request for empty drive");
                        disk_offset = uint64_t(top.sd_lba) * 512;
                        disk_byte = 0;
                        disk_active = true;
                        disk_writing = false;
                        ++disk_requests;
                        top.sd_ack = 1;
                        top.sd_buff_wr = 1;
                        top.sd_buff_addr = 0;
                        top.sd_buff_dout = disk_offset < medium.size() ? medium[disk_offset] : 0;
                    } else if (top.sd_wr) {
                        request_drive = top.sd_drive;
                        const auto &medium = request_drive ? disk_b : disk;
                        if (!disk_outputs[request_drive]) throw std::runtime_error("unexpected write to read-only disk");
                        disk_offset = uint64_t(top.sd_lba) * 512;
                        if (disk_offset >= medium.size()) throw std::runtime_error("disk write outside image");
                        disk_byte = 0;
                        disk_active = true;
                        disk_writing = true;
                        ++disk_requests; ++disk_writes;
                        top.sd_ack = 1;
                        top.sd_buff_addr = 0;
                    }
                    if (disk_active && disk_writing) top.sd_buff_addr = disk_byte;
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
                        ++ps2_bytes_sent;
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
                if (joystick_keys) top.joya_n = joya & frontend->joystick();
                if (frame.frames != shown_frame) {
                    frontend->show(frame.pixels, frame.width, frame.height, next);
                    shown_frame = frame.frames;
                }
            }
#endif
            if (sys_rise) {
                if (bus) {
                    const bool capture = !top.reset && (!top.cpu_rd_n || !top.cpu_wr_n)
                        && (!io_only || !top.cpu_iorq_n)
                        && context.time() >= bus_start_ms * 1000000000ULL
                        && (!bus_end_ms || context.time() < bus_end_ms * 1000000000ULL);
                    if (!capture) flush_bus();
                    else {
                        const std::array<uint64_t, 11> row{context.time(), top.cpu_address,
                            top.cpu_mreq_n, top.cpu_iorq_n, top.cpu_rd_n, top.cpu_wr_n,
                            top.cpu_in, top.cpu_out,
                            top.debug_disk_control, top.debug_disk_motor, top.debug_disk_ready};
                        // A transaction is a contiguous held address/strobe,
                        // not a data-value transition. Emit its last sampled
                        // data and timestamp; default remains every sys edge.
                        if (bus_pending && (!bus_events || !std::equal(row.begin()+1, row.begin()+6, bus_row.begin()+1)))
                            flush_bus();
                        bus_row = row;
                        bus_pending = true;
                    }
                }
                hash ^= static_cast<uint8_t>(top.video);
                hash *= 1099511628211ULL;
                if (static_cast<bool>(top.HSync) != old_hs) {
                    ++hs_edges;
                    if (top.HSync) {
                        if (last_hs_rise) hs_period_ps = next - last_hs_rise;
                        last_hs_rise = next;
                    }
                }
                if (static_cast<bool>(top.VSync) != old_vs) {
                    ++vs_edges;
                    if (top.VSync) {
                        if (last_vs_rise) vs_period_ps = next - last_vs_rise;
                        last_vs_rise = next;
                    }
                }
                old_hs = top.HSync;
                old_vs = top.VSync;
            }
        }
        flush_bus();
#ifdef X1_SAVABLE
        if (save_path) {
            if (context.time() % 31250 || top.reset || disk_active || disk_cooldown
                    || key_active || !keys.empty() || top.sd_rd || top.sd_wr || top.ioctl_download)
                throw std::runtime_error("snapshot requires a running falling edge and quiescent disk/keyboard/download host");
            VerilatedSave state;
            disk_fingerprint = 14695981039346656037ULL;
            for (auto byte : disk) { disk_fingerprint ^= byte; disk_fingerprint *= 1099511628211ULL; }
            state.open(save_path);
            if (!state.isOpen()) throw std::runtime_error("cannot create snapshot");
            state << snapshot_magic << context.time() << video_hz << disk_fingerprint << top;
            state.close();
        }
#endif
        std::string peek;
        audio.finish();
        for (unsigned d = 0; d < 2; ++d) if (disk_outputs[d]) {
            const auto &medium = d ? disk_b : disk;
            if ((disk_active && disk_writing) || top.sd_wr)
                throw std::runtime_error("cannot export disk during a pending write");
            // Recheck atomically at export: never truncate a path created while
            // the simulation ran, including a newly introduced symlink.
            const int copy_fd = ::open(disk_outputs[d], O_WRONLY | O_CREAT | O_EXCL, 0666);
            if (copy_fd < 0) throw std::runtime_error("cannot exclusively create disk output");
            size_t exported = 0;
            while (exported < medium.size()) {
                const ssize_t count = ::write(copy_fd, medium.data() + exported, medium.size() - exported);
                if (count < 0 && errno == EINTR) continue;
                if (count <= 0) {
                    ::close(copy_fd);
                    throw std::runtime_error("disk export failed; partial new copy may remain");
                }
                exported += static_cast<size_t>(count);
            }
            if (::close(copy_fd) != 0) throw std::runtime_error("disk output close failed");
        }
        if (dump_path) {
            // Read-only simulation instrumentation. Sub-CPU work RAM begins
            // at 0x1000; write explicit little-endian bytes, not host words.
            // This does not change RTL or the serialized model layout.
            std::ofstream subram(std::string(dump_path) + ".subram", std::ios::binary);
            if (!subram) throw std::runtime_error("cannot open sub-CPU RAM dump");
            for (unsigned address = 0; address < 1024; ++address) {
                auto word = top.rootp->top__DOT__machine__DOT__subCPU__DOT__sub_w_ram__DOT__mem[address];
                subram.put(word & 255);
                subram.put(word >> 8);
            }
            std::ofstream registers(std::string(dump_path) + ".cpu", std::ios::binary);
            if (!registers) throw std::runtime_error("cannot open CPU register dump");
            auto *root = top.rootp;
            registers << "FWJOY=" << std::hex
                      << root->top__DOT__machine__DOT__subCPU__DOT__OP6 << '\n';
            registers << "PC=" << std::hex << root->top__DOT__machine__DOT__Cpu__DOT__Z80CPU__DOT__i_tv80_core__DOT__PC
                      << " SP=" << root->top__DOT__machine__DOT__Cpu__DOT__Z80CPU__DOT__i_tv80_core__DOT__SP
                      << " AF=" << ((unsigned(root->top__DOT__machine__DOT__Cpu__DOT__Z80CPU__DOT__i_tv80_core__DOT__ACC) << 8)
                                   | root->top__DOT__machine__DOT__Cpu__DOT__Z80CPU__DOT__i_tv80_core__DOT__F) << '\n';
            // Raw TV80 register-file slots, including the alternate bank and
            // index registers; names avoid guessing the active bank mid-cycle.
            for (unsigned index = 0; index < 8; ++index)
                registers << "R" << index << '='
                          << ((unsigned(root->top__DOT__machine__DOT__Cpu__DOT__Z80CPU__DOT__i_tv80_core__DOT__i_reg__DOT__RegsH[index]) << 8)
                              | root->top__DOT__machine__DOT__Cpu__DOT__Z80CPU__DOT__i_tv80_core__DOT__i_reg__DOT__RegsL[index]) << '\n';
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
#ifdef X1_TURBO_VIDEO_MASTER
        constexpr const char *turbo_video_master = "true";
#else
        constexpr const char *turbo_video_master = "false";
#endif
        std::printf("{\"machine\":\"sharpx1\",\"turbo_foundation\":%s,\"turbo_video_master\":%s,\"intra_assignment_delays\":%s,\"sys_hz\":%llu,\"video_hz\":%llu,"
                    "\"time_ps\":%llu,\"sys_edges\":%llu,\"video_edges\":%llu,"
                    "\"reset_edges\":%llu,\"cpu_enables\":%llu,\"delayed_sys_edges\":%llu,"
                    "\"hs_edges\":%llu,\"vs_edges\":%llu,\"hs_period_ps\":%llu,\"vs_period_ps\":%llu,\"video_hash\":\"%016llx\","
                    "\"download_bytes\":%llu,\"cpu_address\":%u,\"halted\":%s,\"peek\":\"%s\","
                    "\"ps2_bytes_sent\":%llu,\"disk_requests\":%llu,\"disk_writes\":%llu,\"frames\":%llu,\"frame_width\":%u,\"frame_height\":%u,\"frame_hash\":\"%016llx\","
                    "\"sub_pc\":%u,\"sub_address\":%u,\"sub_control\":%u,\"sub_running\":%s,\"sub_tx_busy\":%s,\"sub_rx_empty\":%s}\n",
                    turbo_foundation, turbo_video_master, VM_TIMING ? "true" : "false",
                    (unsigned long long)sys_hz,
                    (unsigned long long)video_hz, (unsigned long long)context.time(), (unsigned long long)top.sys_edges,
                    (unsigned long long)top.video_edges, (unsigned long long)top.reset_edges,
                    (unsigned long long)top.cpu_enables, (unsigned long long)top.delayed_sys_edges,
                    (unsigned long long)hs_edges, (unsigned long long)vs_edges,
                    (unsigned long long)hs_period_ps, (unsigned long long)vs_period_ps, (unsigned long long)hash,
                    (unsigned long long)downloads.size(), top.cpu_address, top.cpu_halt_n ? "false" : "true", peek.c_str(),
                    (unsigned long long)ps2_bytes_sent,
                    (unsigned long long)disk_requests,(unsigned long long)disk_writes,(unsigned long long)frame.frames,frame.width,frame.height,
                    (unsigned long long)frame.hash,
                    top.sub_pc,top.sub_address,top.sub_control,
                    top.sub_wait ? "true" : "false",top.sub_tx ? "true" : "false",top.sub_rx ? "true" : "false");
        const uint64_t expected_edges = sys_edge / 2;
        const uint64_t expected_delayed = expected_edges -
            (expected_edges && sys_time(expected_edges * 2 - 1) + 1000 > end_ps ? 1 : 0);
        const bool passed = (interactive && context.gotFinish()) || (context.time() == end_ps && top.sys_edges == expected_edges
            && top.reset_edges == expected_reset_edges && top.delayed_sys_edges == (VM_TIMING ? expected_delayed : expected_edges));
        top.final();
        if (trace) trace->close();
        return passed ? 0 : 1;
    } catch (const std::exception &error) {
        std::fprintf(stderr, "%s\n", error.what());
        return 2;
    }
}
