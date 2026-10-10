// Independent synthetic waveform vectors only; no ROM/private tape bytes.
#include "../x1_tap_image.h"
#include <iostream>
#include <limits>
#include <string>

static unsigned checks = 0;
static void check(bool value) {
    ++checks;
    if (!value) throw std::runtime_error("synthetic TAP assertion failed");
}
template<class Exception, class Function>
static void rejects(Function function, const char* message) {
    ++checks;
    try { function(); } catch (const Exception& e) {
        if (std::string(e.what()) == message) return;
        throw;
    }
    throw std::runtime_error("expected exact TAP failure");
}
static void le32(std::vector<std::uint8_t>& b, std::size_t at, std::uint32_t n) {
    for (unsigned i = 0; i < 4; ++i) b.at(at + i) = std::uint8_t(n >> (8 * i));
}
static std::vector<std::uint8_t> modern(std::uint32_t bits, std::uint32_t position = 0) {
    std::vector<std::uint8_t> b(40 + (bits / 8) + (bits % 8 != 0), 0);
    b[0] = 'T'; b[1] = 'A'; b[2] = 'P'; b[3] = 'E';
    le32(b, 28, 8000); le32(b, 32, bits); le32(b, 36, position);
    return b;
}
int main() {
    try {
        std::vector<std::uint8_t> old(6);
        le32(old, 0, 8000); old[4] = 0xa6; old[5] = 0x59;
        const auto original = old;
        X1TapImage tape(old);
        const std::array<bool, 16> oracle{1,0,1,0,0,1,1,0,0,1,0,1,1,0,0,1};
        check(!tape.metadata().new_header && tape.metadata().sample_count == 16);
        for (std::size_t i = 0; i < oracle.size(); ++i) {
            check(tape.sample(i) == oracle[i]); check(tape.next_sample() == oracle[i]);
        }
        check(tape.eof() && old == original);
        rejects<std::out_of_range>([&]{ tape.next_sample(); }, "TAP sample index outside samples");
        check(tape.position() == 16);
        rejects<std::out_of_range>([&]{ tape.sample(UINT64_MAX); }, "TAP sample index outside samples");
        rejects<std::out_of_range>([&]{ tape.seek(UINT64_MAX); }, "TAP position outside samples");
        tape.reset(); check(tape.position() == 0);
        old[4] = 0; check(tape.sample(0)); // Owned copy, not a live source view.
        for (unsigned bits = 0; bits <= 17; ++bits) {
            auto b = modern(bits, bits);
            for (std::size_t i = 40; i < b.size(); ++i) b[i] = 0xff;
            const auto frozen = b;
            X1TapImage t(b); check(t.eof()); t.rewind();
            for (unsigned i = 0; i < bits; ++i) check(t.next_sample());
            check(t.eof() && b == frozen);
            rejects<std::out_of_range>([&]{ t.sample(bits); }, "TAP sample index outside samples");
            t.reset(); check(t.position() == bits);
        }
        auto b = modern(9, 3); b[40] = 0xa6; b[41] = 0x7f;
        for (unsigned i = 0; i < 17; ++i) b[4 + i] = std::uint8_t('A' + i);
        for (unsigned i = 0; i < 5; ++i) b[21 + i] = std::uint8_t(i + 1);
        b[26] = 0x10;
        X1TapImage partial(b);
        check(partial.metadata().title[16] == 'Q' && partial.metadata().reserved[4] == 5);
        check(partial.metadata().write_protected() && partial.position() == 3);
        check(!partial.sample(8)); // Only MSB of final byte; low padding bits ignored.
        partial.next_sample(); partial.reset(); check(partial.position() == 3);
        b[27] = 1; X1TapImage speed(b);
        check(speed.metadata().speed_limit_method() && !speed.sampling_supported());
        rejects<std::runtime_error>([&]{ speed.next_sample(); }, "speed-limit waveform semantics unresolved");
        check(speed.position() == 3);
        for (unsigned n = 0; n < 4; ++n) {
            std::vector<std::uint8_t> short_old(n);
            rejects<std::invalid_argument>([&]{ X1TapImage t(short_old); }, "truncated header");
        }
        for (unsigned n = 4; n < 40; ++n) {
            auto short_new = modern(0); short_new.resize(n);
            rejects<std::invalid_argument>([&]{ X1TapImage t(short_new); }, "truncated new header");
        }
        b = modern(9); b.pop_back();
        rejects<std::invalid_argument>([&]{ X1TapImage t(b); }, "declared bit count does not match payload length");
        b = modern(8); b.push_back(0);
        rejects<std::invalid_argument>([&]{ X1TapImage t(b); }, "declared bit count does not match payload length");
        b = modern(0); le32(b, 32, UINT32_MAX);
        rejects<std::invalid_argument>([&]{ X1TapImage t(b); }, "declared bit count does not match payload length");
        b = modern(8, 9);
        rejects<std::invalid_argument>([&]{ X1TapImage t(b); }, "position exceeds sample count");
        b = modern(8); le32(b, 28, 44100);
        rejects<std::runtime_error>([&]{ X1TapImage t(b); }, "only 8000 Hz supported");
        le32(old, 0, 0);
        rejects<std::runtime_error>([&]{ X1TapImage t(old); }, "only 8000 Hz supported");
        b = modern(8); b[27] = 2;
        rejects<std::runtime_error>([&]{ X1TapImage t(b); }, "unknown encoding flags");
        b[27] = 0; b[26] = 1;
        rejects<std::runtime_error>([&]{ X1TapImage t(b); }, "unknown write-protect flags");
        auto wrong_magic = modern(0); wrong_magic[3] = 'X';
        rejects<std::runtime_error>([&]{ X1TapImage t(wrong_magic); }, "only 8000 Hz supported");
        std::vector<std::uint8_t> maximum(X1TapImage::max_image_bytes);
        le32(maximum, 0, 8000); X1TapImage bounded(maximum);
        check(bounded.metadata().sample_count == (std::uint64_t(maximum.size()) - 4) * 8);
        check(!bounded.sample(bounded.metadata().sample_count - 1));
        maximum.push_back(0);
        rejects<std::invalid_argument>([&]{ X1TapImage t(maximum); }, "image exceeds bounded capacity");
        std::cout << "PASS " << checks << " synthetic TAP parser/sample checks; not transport/baud/loading acceptance\n";
    } catch (const std::exception& e) {
        std::cerr << e.what() << '\n'; return 1;
    }
}
