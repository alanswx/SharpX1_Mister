// Original host-side structural preflight, based on local MAME's documented
// D88 layout. This does not replace bounds/error checks in the FPGA scanner.
#pragma once
#include <cstdint>
#include <stdexcept>
#include <string>
#include <vector>

inline void validate_d88(const std::vector<uint8_t>& bytes, unsigned address_bits = 20) {
    if (address_bits != 20 && address_bits != 24)
        throw std::runtime_error("D88 address profile must be ordinary20 or experimental24");
    const size_t sector_limit = address_bits == 24 ? 4095 : 1992;
    auto fail = [](const char* reason) {
        throw std::runtime_error(std::string("invalid D88: ") + reason);
    };
    auto unsupported = [](const char* reason) {
        throw std::runtime_error(std::string("unsupported D88: ") + reason);
    };
    auto u16 = [&](size_t at) -> uint32_t {
        return uint32_t(bytes.at(at)) | (uint32_t(bytes.at(at + 1)) << 8);
    };
    auto u32 = [&](size_t at) -> uint32_t {
        return u16(at) | (u16(at + 2) << 16);
    };
    // Concatenated volumes are valid D88; validate every volume rather than
    // interpreting trailing bytes as part of the first. The machine selects 0.
    for (size_t base = 0; base < bytes.size();) {
        if (bytes.size() - base < 688) fail("truncated volume header");
        size_t size = u32(base + 28);
        if (size < 688 || size > bytes.size() - base) fail("volume size outside container");
        std::vector<size_t> tracks;
        for (size_t i = 0; i < 164; ++i) {
            size_t offset = u32(base + 32 + i * 4);
            if (!offset) continue;
            if (offset < 688 || offset >= size) fail("track offset outside volume");
            if (!tracks.empty() && offset <= tracks.back())
                unsupported("non-increasing track offsets (forward-only scanner)");
            tracks.push_back(offset);
        }
        size_t total_sectors = 0;
        for (size_t t = 0; t < tracks.size(); ++t) {
            size_t cursor = base + tracks[t];
            size_t end = base + (t + 1 < tracks.size() ? tracks[t + 1] : size);
            if (end - cursor < 16) fail("truncated first sector header");
            size_t count = u16(cursor + 4);
            if (!count) fail("zero sector count");
            if (count > 255) unsupported("sector count exceeds scanner field");
            total_sectors += count;
            if (total_sectors > sector_limit) unsupported("sector index capacity exceeded");
            for (size_t sector = 0; sector < count; ++sector) {
                if (end - cursor < 16) fail("truncated sector header");
                if (u16(cursor + 4) != count) fail("inconsistent track sector counts");
                size_t length = u16(cursor + 14);
                if (length > end - cursor - 16) fail("sector payload crosses track boundary");
                // The runtime uses N, not the explicit length. Refuse layouts
                // it cannot reproduce, without calling copy-protected media invalid.
                if (bytes[cursor + 3] > 3 || length != (size_t(128) << bytes[cursor + 3]))
                    unsupported("sector length/size code outside current runtime");
                cursor += 16 + length;
            }
        }
        // Diagnose structural corruption first. The active controller selects
        // volume zero and rejects declared size at/above its address limit. A larger
        // valid disk is unsupported, not a masked smaller mount. Total
        // concatenated-container size is not the selected-volume size.
        if (base == 0 && size >= (size_t(1) << address_bits))
            unsupported(("selected volume exceeds " + std::to_string(address_bits)
                         + "-bit controller address space").c_str());
        base += size;
    }
    if (bytes.size() >= (size_t(1) << 24))
        unsupported("container exceeds 24-bit machine size interface");
}
