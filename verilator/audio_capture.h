#pragma once
#include <algorithm>
#include <cstdint>
#include <fstream>
#include <stdexcept>
#include <string>
#include <vector>

// Original deterministic mono capture of the core's unsigned PSG output.
// A fixed integer DC-blocker converts it to signed PCM at 48 kHz.
struct AudioCapture {
    std::string path;
    std::vector<int16_t> samples;
    int32_t previous = 0, filtered = 0;
    uint64_t edge = 1;
    static constexpr uint64_t rate = 48000;
    uint64_t next_time() const { return (static_cast<unsigned __int128>(edge) * 1000000000000ULL + rate / 2) / rate; }
    void sample(uint16_t input) {
        int32_t value = input / 2;
        filtered = value - previous + (filtered * 255) / 256;
        previous = value;
        samples.push_back(static_cast<int16_t>(std::clamp(filtered, -32768, 32767)));
        ++edge;
    }
    void finish() const {
        if (path.empty()) return;
        std::ofstream out(path, std::ios::binary);
        if (!out) throw std::runtime_error("cannot open audio capture");
        auto word = [&](uint32_t value, unsigned size) {
            while (size--) { out.put(value & 255); value >>= 8; }
        };
        out.write("RIFF", 4); word(36 + samples.size() * 2, 4);
        out.write("WAVEfmt ", 8); word(16, 4); word(1, 2); word(1, 2);
        word(rate, 4); word(rate * 2, 4); word(2, 2); word(16, 2);
        out.write("data", 4); word(samples.size() * 2, 4);
        for (auto value : samples) word(static_cast<uint16_t>(value), 2);
        if (!out) throw std::runtime_error("audio capture write failed");
    }
};
