#include "../sdl_frontend.h"
#include <cassert>
#include <vector>

int main() {
    auto event = [](SDL_Scancode key, bool pressed) {
        SDL_Event input{};
        input.type = pressed ? SDL_KEYDOWN : SDL_KEYUP;
        input.key.keysym.scancode = key;
        assert(SDL_PushEvent(&input) == 1);
    };
    {
    SdlFrontend display;
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
    {
    SdlFrontend display(true);
    const SDL_Scancode controls[] = {SDL_SCANCODE_UP, SDL_SCANCODE_DOWN,
        SDL_SCANCODE_LEFT, SDL_SCANCODE_RIGHT, SDL_SCANCODE_SPACE, SDL_SCANCODE_LCTRL};
    const uint8_t masks[] = {1, 2, 4, 8, 0x20, 0x40};
    std::vector<uint8_t> packets;
    auto send = [&](uint8_t byte) { packets.push_back(byte); };
    for (unsigned combination = 0; combination < 64; ++combination) {
        uint8_t pressed = 0;
        for (unsigned key = 0; key < 6; ++key) {
            event(controls[key], combination & (1 << key));
            if (combination & (1 << key)) pressed |= masks[key];
        }
        assert(display.poll(send));
        assert(display.joystick() == static_cast<uint8_t>(~pressed));
        assert(packets.empty()); // No duplicate PS/2 route for joystick keys.
    }
    for (auto key : controls) event(key, false);
    event(SDL_SCANCODE_LCTRL, true); event(SDL_SCANCODE_RCTRL, true);
    event(SDL_SCANCODE_LCTRL, false);
    assert(display.poll(send) && display.joystick() == 0xbf);
    event(SDL_SCANCODE_RCTRL, false);
    event(SDL_SCANCODE_I, true); event(SDL_SCANCODE_I, false);
    assert(display.poll(send) && display.joystick() == 0xff);
    assert((packets == std::vector<uint8_t>{0x43,0xf0,0x43}));
    event(SDL_SCANCODE_LEFT, true);
    assert(display.poll(send) && display.joystick() == 0xfb);
    SDL_Event focus{}; focus.type = SDL_WINDOWEVENT;
    focus.window.event = SDL_WINDOWEVENT_FOCUS_LOST;
    assert(SDL_PushEvent(&focus) == 1);
    assert(display.poll(send) && display.joystick() == 0xff);
    SDL_Log("PASS: 64 joystick-key combinations, release, modifier aliases, focus loss and keyboard isolation");
    }
}
