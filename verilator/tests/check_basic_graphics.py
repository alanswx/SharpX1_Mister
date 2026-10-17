# SPDX-License-Identifier: GPL-2.0-only
"""Fixed native HuBASIC point/diagonal pixels and independent GRAM addresses."""
from check_basic_reference import BANNER, check_rows


def command(kind, x=400):
    assert kind in ('point', 'line') and x in (400, 401)
    return f'PSET({x},160)' if kind == 'point' else f'LINE({x},160)-({x + 15},175)'


def coordinates(kind, x=400):
    assert kind in ('point', 'line') and x in (400, 401)
    return {(x + i, 160 + i) for i in range(16 if kind == 'line' else 1)}


def check_window(dimensions, pixels, kind=None, x=400, vertical=1):
    assert vertical in (1, 2) and dimensions == (640, 200 * vertical)
    assert len(pixels) == 640 * 200 * vertical * 3
    points = coordinates(kind, x) if kind is not None else set()
    ink = 0
    for y in range(152 * vertical, 184 * vertical):
        for column in range(392, 424):
            on = (column, y // vertical) in points
            start = (y * 640 + column) * 3
            assert pixels[start:start + 3] == bytes((255 if on else 0,)) * 3, (
                'BASIC_GRAPHICS_PIXEL', column, y)
            ink += int(on)
    assert ink == len(points) * vertical
    return dict(checked_pixels=1024 * vertical, ink_pixels=ink,
                x=392, y=152, width=32, height=32, vertical=vertical)


def check_completion(dimensions, pixels, font, kind, x=400, vertical=1, lower=False):
    text = command(kind, x)
    if lower:
        text = text.lower()
    return dict(banner=check_rows(dimensions, pixels, font, 4, (BANNER,), vertical),
                transcript=check_rows(dimensions, pixels, font, 13, (text.encode(), b'Ok'), vertical),
                graphics=check_window(dimensions, pixels, kind, x, vertical))


def expected_writes(kind, x=400):
    result = []
    for column, y in sorted(coordinates(kind, x), key=lambda xy: xy[1]):
        address = ((y & 7) << 11) + (y // 8) * 80 + column // 8
        result.extend((plane + address, 128 >> (column & 7)) for plane in (0x4000, 0x8000, 0xc000))
    return result
