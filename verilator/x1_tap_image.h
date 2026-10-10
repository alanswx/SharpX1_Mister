// Original bounded TAP preflight/sample accessor. Layout reference: local
// MAME src/lib/formats/x1_tap.cpp (BSD-3-Clause, Barry Rodewald); no copied code.
// Samples are waveform levels, not decoded cassette bytes or baud timing.
#pragma once
#include <array>
#include <cstddef>
#include <cstdint>
#include <span>
#include <stdexcept>
#include <vector>

class X1TapImage {
public:
    static constexpr std::size_t max_image_bytes = 8 * 1024 * 1024;
    struct Metadata {
        bool new_header = false;
        std::array<std::uint8_t, 17> title{};
        std::array<std::uint8_t, 5> reserved{};
        std::uint8_t write_protect_flags = 0;
        std::uint8_t format_flags = 0;
        std::uint32_t sample_rate = 8000;
        std::uint64_t sample_count = 0;
        std::uint64_t start_position = 0;
        bool write_protected() const { return (write_protect_flags & 0x10) != 0; }
        bool speed_limit_method() const { return (format_flags & 1) != 0; }
    };

    explicit X1TapImage(std::span<const std::uint8_t> input) {
        if (input.size() > max_image_bytes) invalid("image exceeds bounded capacity");
        if (input.size() < 4) invalid("truncated header");
        meta_.new_header = input[0] == 'T' && input[1] == 'A' &&
                           input[2] == 'P' && input[3] == 'E';
        const auto le32 = [&](std::size_t at) {
            return std::uint32_t(input[at]) | (std::uint32_t(input[at + 1]) << 8) |
                   (std::uint32_t(input[at + 2]) << 16) |
                   (std::uint32_t(input[at + 3]) << 24);
        };
        payload_offset_ = meta_.new_header ? 40 : 4;
        if (meta_.new_header) {
            if (input.size() < 40) invalid("truncated new header");
            for (std::size_t i = 0; i < 17; ++i) meta_.title[i] = input[4 + i];
            for (std::size_t i = 0; i < 5; ++i) meta_.reserved[i] = input[21 + i];
            // Reserved bytes and the fixed-width title are retained, not decoded.
            meta_.write_protect_flags = input[26];
            meta_.format_flags = input[27];
            if (meta_.write_protect_flags & ~0x10u) unsupported("unknown write-protect flags");
            if (meta_.format_flags & ~1u) unsupported("unknown encoding flags");
            meta_.sample_rate = le32(28);
            meta_.sample_count = le32(32);
            meta_.start_position = le32(36);
            const auto required = meta_.sample_count / 8 + (meta_.sample_count % 8 != 0);
            if (required != input.size() - payload_offset_)
                invalid("declared bit count does not match payload length");
        } else {
            meta_.sample_rate = le32(0);
            meta_.sample_count = std::uint64_t(input.size() - 4) * 8;
        }
        if (meta_.sample_rate != 8000) unsupported("only 8000 Hz supported");
        if (meta_.start_position > meta_.sample_count) invalid("position exceeds sample count");
        // Own a frozen copy; caller changes never alter this image.
        bytes_.assign(input.begin(), input.end());
        reset();
    }

    const Metadata& metadata() const { return meta_; }
    bool sampling_supported() const { return !meta_.speed_limit_method(); }
    std::uint64_t position() const { return position_; }
    bool eof() const { return position_ == meta_.sample_count; }
    void reset() { position_ = meta_.start_position; }
    void rewind() { position_ = 0; }
    void seek(std::uint64_t position) {
        if (position > meta_.sample_count) throw std::out_of_range("TAP position outside samples");
        position_ = position;
    }
    bool sample(std::uint64_t index) const {
        if (index >= meta_.sample_count) throw std::out_of_range("TAP sample index outside samples");
        if (!sampling_supported()) unsupported("speed-limit waveform semantics unresolved");
        return (bytes_.at(payload_offset_ + std::size_t(index / 8)) &
                (std::uint8_t(0x80) >> unsigned(index % 8))) != 0;
    }
    bool next_sample() {
        const bool level = sample(position_);
        ++position_;
        return level;
    }

private:
    [[noreturn]] static void invalid(const char* reason) {
        throw std::invalid_argument(reason);
    }
    [[noreturn]] static void unsupported(const char* reason) {
        throw std::runtime_error(reason);
    }
    Metadata meta_{};
    std::vector<std::uint8_t> bytes_;
    std::size_t payload_offset_ = 4;
    std::uint64_t position_ = 0;
};
