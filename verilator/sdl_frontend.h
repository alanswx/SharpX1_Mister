#pragma once
#include <SDL.h>
#include <array>
#include <cstdint>
#include <stdexcept>
#include <string>
#include <vector>

// Original minimal frontend. Keyboard events become real PS/2 set-2 packets;
// the display uses the same captured RGB raster as the headless runner.
class SdlFrontend {
    SDL_Window *window = nullptr;
    SDL_Renderer *renderer = nullptr;
    SDL_Texture *texture = nullptr;
    unsigned width = 0, height = 0;
    bool joystick_keys;
    std::array<bool, SDL_NUM_SCANCODES> held{};
public:
    explicit SdlFrontend(bool use_joystick_keys = false) : joystick_keys(use_joystick_keys) {
        if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS)) throw std::runtime_error(SDL_GetError());
        window = SDL_CreateWindow("Sharp X1 — RTL simulation", SDL_WINDOWPOS_CENTERED,
                                  SDL_WINDOWPOS_CENTERED, 960, 600, SDL_WINDOW_RESIZABLE);
        if (!window) throw std::runtime_error(SDL_GetError());
        renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_SOFTWARE);
        if (!renderer) throw std::runtime_error(SDL_GetError());
    }
    static uint8_t joystick_mask(SDL_Scancode key) {
        switch (key) {
        case SDL_SCANCODE_UP: return 0x01;
        case SDL_SCANCODE_DOWN: return 0x02;
        case SDL_SCANCODE_LEFT: return 0x04;
        case SDL_SCANCODE_RIGHT: return 0x08;
        case SDL_SCANCODE_SPACE: return 0x20;
        case SDL_SCANCODE_LCTRL: case SDL_SCANCODE_RCTRL: return 0x40;
        default: return 0;
        }
    }
    uint8_t joystick() const {
        uint8_t pressed = 0;
        for (unsigned key = 0; key < held.size(); ++key)
            if (held[key]) pressed |= joystick_mask(static_cast<SDL_Scancode>(key));
        return static_cast<uint8_t>(~pressed);
    }
    ~SdlFrontend() {
        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
    }
    static uint8_t code(SDL_Scancode key) {
        static const uint8_t alphabet[] = {
            0x1c,0x32,0x21,0x23,0x24,0x2b,0x34,0x33,0x43,0x3b,0x42,0x4b,0x3a,
            0x31,0x44,0x4d,0x15,0x2d,0x1b,0x2c,0x3c,0x2a,0x1d,0x22,0x35,0x1a};
        if (key >= SDL_SCANCODE_A && key <= SDL_SCANCODE_Z)
            return alphabet[key - SDL_SCANCODE_A];
        static const uint8_t numbers[] = {0x16,0x1e,0x26,0x25,0x2e,0x36,0x3d,0x3e,0x46,0x45};
        if (key >= SDL_SCANCODE_1 && key <= SDL_SCANCODE_0)
            return numbers[key - SDL_SCANCODE_1];
        switch (key) {
        case SDL_SCANCODE_SPACE: return 0x29;
        case SDL_SCANCODE_RETURN: return 0x5a;
        case SDL_SCANCODE_ESCAPE: return 0x76;
        case SDL_SCANCODE_BACKSPACE: return 0x66;
        case SDL_SCANCODE_CAPSLOCK: return 0x58;
        case SDL_SCANCODE_TAB: return 0x0d;
        case SDL_SCANCODE_LSHIFT: return 0x12;
        case SDL_SCANCODE_RSHIFT: return 0x59;
        case SDL_SCANCODE_LCTRL: case SDL_SCANCODE_RCTRL: return 0x14;
        case SDL_SCANCODE_UP: return 0x75;
        case SDL_SCANCODE_DOWN: return 0x72;
        case SDL_SCANCODE_LEFT: return 0x6b;
        case SDL_SCANCODE_RIGHT: return 0x74;
        case SDL_SCANCODE_F5: return 0x03;
        default: return 0;
        }
    }
    template<class Send> bool poll(Send send) {
        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_QUIT) return false;
            if (event.type == SDL_WINDOWEVENT && event.window.event == SDL_WINDOWEVENT_FOCUS_LOST) {
                held.fill(false);
                continue;
            }
            if (event.type != SDL_KEYDOWN && event.type != SDL_KEYUP) continue;
            if (event.key.repeat) continue;
            auto key = event.key.keysym.scancode;
            if (joystick_keys && joystick_mask(key)) {
                held[key] = event.type == SDL_KEYDOWN;
                continue; // One input path: captured controls are not also PS/2.
            }
            auto byte = code(key);
            if (!byte) continue;
            if (key == SDL_SCANCODE_UP || key == SDL_SCANCODE_DOWN ||
                key == SDL_SCANCODE_LEFT || key == SDL_SCANCODE_RIGHT || key == SDL_SCANCODE_RCTRL)
                send(0xe0);
            if (event.type == SDL_KEYUP) send(0xf0);
            send(byte);
        }
        return true;
    }
    void show(const std::vector<uint32_t> &pixels, unsigned w, unsigned h, uint64_t time) {
        if (!w || !h) return;
        if (w != width || h != height) {
            SDL_DestroyTexture(texture);
            texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888,
                                        SDL_TEXTUREACCESS_STREAMING, w, h);
            if (!texture) throw std::runtime_error(SDL_GetError());
            width = w; height = h;
            SDL_RenderSetLogicalSize(renderer, w, h);
        }
        if (SDL_UpdateTexture(texture, nullptr, pixels.data(), width * sizeof(uint32_t)))
            throw std::runtime_error(SDL_GetError());
        SDL_RenderClear(renderer);
        SDL_RenderCopy(renderer, texture, nullptr, nullptr);
        SDL_RenderPresent(renderer);
        auto title = std::string("Sharp X1 — RTL simulation, ") + std::to_string(double(time) / 1e12) + " simulated seconds";
        SDL_SetWindowTitle(window, title.c_str());
    }
};
