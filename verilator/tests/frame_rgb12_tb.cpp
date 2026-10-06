// Original asset-free full-color capture diagnostic.
#include "../frame_capture.h"
#include <iostream>
#include <iterator>

static void check(bool condition, const char *message) {
    if (!condition) throw std::runtime_error(message);
}

int main(int argc, char **argv) {
    try {
        check(argc == 2, "expected a disposable PPM output path");
        FrameCapture full;
        full.path = argv[1];
        // 32 x 128 covers every possible 12-bit color exactly once. Sync
        // samples are blanked, with poison colors to catch accidental capture.
        for (unsigned y = 0; y < 128; ++y) {
            full.sample_rgb12(false, false, true, 0xfff);
            for (unsigned x = 0; x < 32; ++x)
                full.sample_rgb12(false, false, false, y * 32 + x);
            full.sample_rgb12(true, false, true, 0xfff);
        }
        full.sample_rgb12(false, true, true, 0xfff);
        check(full.frames == 1 && full.width == 32 && full.height == 128,
              "full-color frame dimensions/count");
        uint64_t expected_hash = 14695981039346656037ULL;
        std::string expected_ppm = "P6\n32 128\n255\n";
        for (unsigned color = 0; color < 4096; ++color) {
            const unsigned red = (color / 256) * 17;
            const unsigned green = ((color / 16) % 16) * 17;
            const unsigned blue = (color % 16) * 17;
            const uint32_t pixel = 0xff000000 | (red << 16) | (green << 8) | blue;
            check(full.pixels.at(color) == pixel, "12-bit channel order/scaling");
            expected_hash ^= pixel & 0xffffff;
            expected_hash *= 1099511628211ULL;
            expected_ppm.push_back(static_cast<char>(red));
            expected_ppm.push_back(static_cast<char>(green));
            expected_ppm.push_back(static_cast<char>(blue));
        }
        check(full.hash == expected_hash, "full-color deterministic hash");
        std::ifstream input(argv[1], std::ios::binary);
        check(input.good(), "PPM missing");
        const std::string ppm{std::istreambuf_iterator<char>(input), {}};
        check(ppm == expected_ppm, "PPM header/payload differs");

        FrameCapture legacy, expanded;
        for (unsigned y = 0; y < 128; ++y) {
            legacy.sample(false, false, true, 7);
            expanded.sample_rgb12(false, false, true, 0xfff);
            for (unsigned color = 0; color < 8; ++color) {
                legacy.sample(false, false, false, color);
                const uint16_t rgb12 = ((color & 2) ? 0xf00 : 0)
                    | ((color & 4) ? 0x0f0 : 0) | ((color & 1) ? 0x00f : 0);
                expanded.sample_rgb12(false, false, false, rgb12);
            }
            legacy.sample(true, false, true, 7);
            expanded.sample_rgb12(true, false, true, 0xfff);
        }
        legacy.sample(false, true, true, 7);
        expanded.sample_rgb12(false, true, true, 0xfff);
        check(legacy.frames == 1 && expanded.frames == 1,
              "legacy/expanded frame count");
        check(legacy.pixels == expanded.pixels && legacy.hash == expanded.hash,
              "digital palette changed");
        for (unsigned color = 0; color < 8; ++color) {
            const uint32_t expected = 0xff000000 | ((color & 2) ? 0xff0000 : 0)
                | ((color & 4) ? 0x00ff00 : 0) | ((color & 1) ? 0x0000ff : 0);
            check(legacy.pixels.at(color) == expected, "legacy G:R:B order");
        }
        // Holding VSYNC must not recapture the same frame.
        full.sample_rgb12(false, true, true, 0);
        check(full.frames == 1, "held sync created a second frame");
        std::cout << "PASS RGB12: all 4096 colors, PPM bytes/hash, eight digital colors, blank/sync\n";
        return 0;
    } catch (const std::exception &error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
