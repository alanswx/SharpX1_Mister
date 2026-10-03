#include "../sdl_frontend.h"
#include <cassert>
#include <vector>

int main() {
    SdlFrontend display;
    auto event = [](SDL_Scancode key, bool pressed) {
        SDL_Event input{};
        input.type = pressed ? SDL_KEYDOWN : SDL_KEYUP;
        input.key.keysym.scancode = key;
        assert(SDL_PushEvent(&input) == 1);
    };
    event(SDL_SCANCODE_I, true); event(SDL_SCANCODE_I, false);
    event(SDL_SCANCODE_SPACE, true); event(SDL_SCANCODE_CAPSLOCK, true);
    event(SDL_SCANCODE_LEFT, true); event(SDL_SCANCODE_LEFT, false);
    std::vector<uint8_t> packets;
    assert(display.poll([&](uint8_t byte) { packets.push_back(byte); }));
    assert((packets == std::vector<uint8_t>{0x43,0xf0,0x43,0x29,0x58,0xe0,0x6b,0xe0,0xf0,0x6b}));
    display.show(std::vector<uint32_t>(4, 0xff000000), 2, 2, 1000000000);
    SDL_Event quit{}; quit.type = SDL_QUIT;
    assert(SDL_PushEvent(&quit) == 1);
    assert(!display.poll([](uint8_t) {}));
    SDL_Log("PASS: frontend make/break/extended packets, CAPS, display upload and quit");
}
