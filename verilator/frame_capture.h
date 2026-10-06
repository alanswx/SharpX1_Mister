#pragma once
#include <algorithm>
#include <cstdint>
#include <fstream>
#include <stdexcept>
#include <string>
#include <vector>

// Capture actual active RGB pixels at the core's pixel enable, not VRAM.
struct FrameCapture {
    std::vector<uint32_t> line, pixels;
    std::vector<std::vector<uint32_t>> rows;
    bool old_hs = false, old_vs = false;
    unsigned width = 0, height = 0;
    uint64_t frames = 0, hash = 0;
    std::string path;
    void flush_line() {
        if (!line.empty()) rows.push_back(std::move(line));
        line.clear();
    }
    // Legacy digital G:R:B interface, retained for diagnostics.
    void sample(bool hs, bool vs, bool blank, uint8_t rgb) {
        sample_rgb12(hs, vs, blank, ((rgb & 2) ? 0xf00 : 0)
                     | ((rgb & 4) ? 0x0f0 : 0) | ((rgb & 1) ? 0x00f : 0));
    }
    // Conventional R:G:B nibbles, expanded exactly to 8-bit PPM/SDL pixels.
    void sample_rgb12(bool hs, bool vs, bool blank, uint16_t rgb) {
        if (hs && !old_hs) flush_line();
        if (vs && !old_vs) {
            flush_line();
            if (rows.size() >= 100) {
                width = 0;
                for (const auto &row : rows) width = std::max(width, unsigned(row.size()));
                height = rows.size();
                if (width > 2048 || height > 1024) throw std::runtime_error("invalid raster dimensions");
                pixels.assign(width * height, 0xff000000);
                for (unsigned y = 0; y < height; ++y)
                    std::copy(rows[y].begin(), rows[y].end(), pixels.begin() + y * width);
                hash = 14695981039346656037ULL;
                for (auto pixel : pixels) { hash ^= pixel & 0xffffff; hash *= 1099511628211ULL; }
                ++frames;
                if (!path.empty()) {
                    std::ofstream out(path, std::ios::binary);
                    if (!out) throw std::runtime_error("cannot open frame capture");
                    out << "P6\n" << width << ' ' << height << "\n255\n";
                    for (auto pixel : pixels) {
                        out.put((pixel >> 16) & 255);
                        out.put((pixel >> 8) & 255);
                        out.put(pixel & 255);
                    }
                }
            }
            rows.clear();
        }
        if (!blank) {
            if (line.size() >= 2048) throw std::runtime_error("no horizontal sync within active line");
            line.push_back(0xff000000 | (((rgb >> 8) & 15) * 17 << 16)
                           | (((rgb >> 4) & 15) * 17 << 8) | ((rgb & 15) * 17));
        }
        old_hs = hs;
        old_vs = vs;
    }
};
