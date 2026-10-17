"""Exact, release-specific HuBASIC transcript pixels for CSP and RTL.

No OCR, crop, image scaling or case folding. Expected cells are rendered from
the separately hashed font used by each implementation, including backgrounds.
"""

BANNER = b'      SHARP-HuBASIC CZ-8FB01 V1.0'
SEQUENCES = {
    'arithmetic': (b'print 6*7', b' 42', b'Ok'),
    'warm': (b'print 9*9', b' 81', b'Ok'),
    'program': (b'10 print 9', b'list', b'10 PRINT 9', b'Ok', b'run', b' 9', b'Ok'),
}


def check_rows(dimensions, pixels, font, first, rows, vertical=2):
    assert vertical in (1, 2)
    assert dimensions == (640, 200 * vertical), 'unexpected native raster'
    assert len(pixels) == 640 * 200 * vertical * 3, 'incomplete RGB'
    assert len(font) == 2048, 'incomplete ANK8'
    assert 0 <= first < first + len(rows) <= 25
    checked, ink = 0, 0
    for row, value in enumerate(rows, first):
        assert len(value) <= 80
        for y in range(8 * vertical):
            for column, character in enumerate(value.ljust(80, b' ')):
                bits = font[character * 8 + y // vertical]
                for x in range(8):
                    on = bool(bits & (128 >> x))
                    expected = bytes((255 if on else 0,)) * 3
                    offset = ((row * 8 * vertical + y) * 640 + column * 8 + x) * 3
                    assert pixels[offset:offset + 3] == expected, (
                        'native glyph/background mismatch', row, column, x, y)
                    checked += 1
                    ink += int(on)
    assert ink > 0, 'vacuous glyph check'
    return {'first_row': first, 'row_count': len(rows), 'checked_pixels': checked, 'ink_pixels': ink}


def check_csp(dimensions, pixels, font, sequence):
    assert sequence in SEQUENCES
    banner = check_rows(dimensions, pixels, font, 4, (BANNER,))
    transcript = check_rows(dimensions, pixels, font, 13, SEQUENCES[sequence])
    return {'banner': banner, 'transcript': transcript}
