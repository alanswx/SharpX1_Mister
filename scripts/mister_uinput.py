#!/usr/bin/env python3
"""Send explicit Linux key taps through a temporary MiSTer uinput keyboard.

Run as root on an available test MiSTer only. No service or configuration is
installed. Codes are Linux input codes (88=F12, 57=Space, 28=Enter).
"""
import argparse
import fcntl
import os
import struct
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("codes", type=int, nargs="+")
    parser.add_argument("--hold", type=float, default=0.08)
    parser.add_argument("--gap", type=float, default=0.15)
    parser.add_argument("--chord", action="store_true", help="hold all codes together, then release in reverse order")
    args = parser.parse_args()
    if any(not 1 <= code <= 255 for code in args.codes):
        parser.error("key codes must be 1..255")
    if not 0.01 <= args.hold <= 5 or not 0.01 <= args.gap <= 5:
        parser.error("hold/gap must be 0.01..5 seconds")
    fd = os.open("/dev/uinput", os.O_WRONLY | os.O_NONBLOCK)
    created = False
    held = []

    def event(kind, code, value):
        # Native timeval uses 32-bit longs on MiSTer's ARM Linux.
        os.write(fd, struct.pack("@llHHi", 0, 0, kind, code, value))

    def key(code, value):
        event(1, code, value)
        event(0, 0, 0)

    try:
        fcntl.ioctl(fd, 0x40045564, 1)  # UI_SET_EVBIT / EV_KEY
        # Main classifies keyboards from their capabilities; a Space-only
        # device is not necessarily recognized as a keyboard.
        for code in range(1, 256):
            fcntl.ioctl(fd, 0x40045565, code)  # UI_SET_KEYBIT
        # struct uinput_setup: USB input_id, device name, no FF effects.
        setup = struct.pack("@HHHH80sI", 3, 0x1209, 0x5831, 1,
                            b"SharpX1 isolated test keyboard", 0)
        fcntl.ioctl(fd, 0x405C5503, setup)
        fcntl.ioctl(fd, 0x5501)  # UI_DEV_CREATE
        created = True
        time.sleep(2)
        if args.chord:
            for code in args.codes:
                key(code, 1)
                held.append(code)
            time.sleep(args.hold)
        else:
            for code in args.codes:
                key(code, 1)
                held.append(code)
                time.sleep(args.hold)
                key(code, 0)
                held.pop()
                time.sleep(args.gap)
    finally:
        if created:
            for code in reversed(held):
                key(code, 0)
            fcntl.ioctl(fd, 0x5502)  # UI_DEV_DESTROY
        os.close(fd)


if __name__ == "__main__":
    main()
