# SPDX-License-Identifier: GPL-2.0-only
"""Fixed HuBASIC PSET color/neighbor and PRESET oracle, independent of traces."""
from check_basic_reference import BANNER, check_rows


SEED = ('PSET(400,160,7)', 'PSET(401,160,7)')


def command(kind, color=1, x=400):
    assert kind in ('point', 'erase') and 0 <= color <= 7 and x in (400, 401)
    return f'PSET({x},160,{color})' if kind == 'point' else f'PRESET({x},160)'


def check_window(dimensions, pixels, colors, vertical=2):
    assert vertical in (1, 2) and dimensions == (640, 200 * vertical)
    assert len(pixels) == 640 * 200 * vertical * 3
    assert set(colors) <= {400, 401} and all(0 <= c <= 7 for c in colors.values())
    ink = 0
    for y in range(152 * vertical, 184 * vertical):
        for x in range(392, 424):
            color = colors.get(x, 0) if y // vertical == 160 else 0
            # Native digital color bits: blue=0, red=1, green=2.
            expected = bytes(255 if color & (1 << bit) else 0 for bit in (1, 2, 0))
            start = (y * 640 + x) * 3
            assert pixels[start:start + 3] == expected, ('BASIC_COLOR_PIXEL', x, y, color)
            ink += int(color != 0)
    return dict(checked_pixels=1024 * vertical, ink_pixels=ink, vertical=vertical,
                x=392, y=152, width=32, height=32)


def state(kind, color=1, x=400):
    result = {400: 7, 401: 7}
    result[x] = color if kind == 'point' else 0
    return result


def check(dimensions, pixels, font, stage, kind='point', color=1, x=400):
    assert stage in ('before', 'seed', 'pending', 'final')
    result = dict(banner=check_rows(dimensions, pixels, font, 4, (BANNER,)))
    if stage == 'before':
        result['prompt'] = check_rows(dimensions, pixels, font, 12, (b'Ok',))
        colors = {}
    else:
        rows = tuple(value for cmd in SEED for value in (cmd.lower().encode(), b'Ok'))
        if stage == 'final':
            rows += (command(kind, color, x).lower().encode(), b'Ok')
        result['transcript'] = check_rows(dimensions, pixels, font, 13, rows)
        colors = state(kind, color, x) if stage == 'final' else {400: 7, 401: 7}
    result['graphics'] = check_window(dimensions, pixels, colors)
    return result


def expected_writes(kind, color=1, x=400, pending=False):
    """CPU RMW writes: two shared-byte seeds, then precisely one operation."""
    assert kind in ('point', 'erase') and 0 <= color <= 7 and x in (400, 401)
    address = ((160 & 7) << 11) + (160 // 8) * 80 + 400 // 8
    planes = (0x4000, 0x8000, 0xc000)
    result = [(plane + address, 0x80) for plane in planes]
    result += [(plane + address, 0xc0) for plane in planes]
    if not pending:
        colors = state(kind, color, x)
        for bit, plane in enumerate(planes):
            value = sum((0x80 >> (col & 7)) for col, c in colors.items() if c & (1 << bit))
            result.append((plane + address, value))
    return result
