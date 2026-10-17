"""Asset-free failure controls for exact native BASIC reference pixels."""
import unittest

from check_basic_reference import check_csp
from check_basic_warm_reset import check_terminal


FONT = bytes(0 if ch == 32 else ((ch * 17 + y * 29) & 255)
             for ch in range(256) for y in range(8))
TRANSCRIPTS = {
    'arithmetic': (b'print 6*7', b' 42', b'Ok'),
    'warm': (b'print 9*9', b' 81', b'Ok'),
    'program': (b'10 print 9', b'list', b'10 PRINT 9', b'Ok', b'run', b' 9', b'Ok'),
}


def frame(sequence='warm'):
    pixels = bytearray(640 * 400 * 3)
    # Independent whole-cell fixture; do not call the acceptance renderer.
    for row, text in [(4, b'      SHARP-HuBASIC CZ-8FB01 V1.0'), *enumerate(TRANSCRIPTS[sequence], 13)]:
        for c, ch in enumerate(text):
            for y in range(8):
                for x in range(8):
                    if FONT[ch * 8 + y] & (128 >> x):
                        for dy in (0, 1):
                            start = ((row * 16 + y * 2 + dy) * 640 + c * 8 + x) * 3
                            pixels[start:start + 3] = b'\xff\xff\xff'
    return pixels


class BasicReferenceOracleTests(unittest.TestCase):
    def test_exact_sequences(self):
        for sequence in TRANSCRIPTS:
            result = check_csp((640, 400), frame(sequence), FONT, sequence)
            self.assertEqual(result['transcript']['checked_pixels'], len(TRANSCRIPTS[sequence]) * 10240)

    def test_old_arithmetic_cannot_qualify_warm(self):
        with self.assertRaises(AssertionError):
            check_csp((640, 400), frame('arithmetic'), FONT, 'warm')

    def test_echo_without_result(self):
        p = frame()
        start = 14 * 16 * 640 * 3
        p[start:start + 16 * 640 * 3] = bytes(16 * 640 * 3)
        with self.assertRaises(AssertionError):
            check_csp((640, 400), p, FONT, 'warm')

    def test_padding_is_checked(self):
        p = frame()
        p[(13 * 16 * 640 + 79 * 8) * 3] = 255
        with self.assertRaises(AssertionError):
            check_csp((640, 400), p, FONT, 'warm')

    def test_second_vertical_sample_is_checked(self):
        p = frame()
        i = (14 * 16 + 1) * 640 * 3
        p[i] ^= 255
        with self.assertRaises(AssertionError):
            check_csp((640, 400), p, FONT, 'warm')

    def test_banner_and_geometry(self):
        p = frame()
        p[4 * 16 * 640 * 3] = 255
        with self.assertRaises(AssertionError):
            check_csp((640, 400), p, FONT, 'warm')
        with self.assertRaises(AssertionError):
            check_csp((640, 200), frame(), FONT, 'warm')

    def test_rtl_requires_text_and_pixels(self):
        text = bytearray(b' ' * 2048)
        for row, value in [(4, b'      SHARP-HuBASIC CZ-8FB01 V1.0'),
                           (13, b'print 9*9'), (14, b' 81'), (15, b'Ok')]:
            text[row * 80:(row + 1) * 80] = value.ljust(80, b' ')
        doubled = frame()
        pixels = b''.join(doubled[y * 2 * 1920:(y * 2 + 1) * 1920] for y in range(200))
        ppm = b'P6\n640 200\n255\n' + pixels
        check_terminal(text, ppm, FONT, 'warm')
        wrong_text = bytearray(text)
        wrong_text[14 * 80 + 1] = ord('4')
        with self.assertRaises(AssertionError):
            check_terminal(wrong_text, ppm, FONT, 'warm')
        damaged = bytearray(pixels)
        damaged[14 * 8 * 640 * 3] ^= 255
        with self.assertRaises(AssertionError):
            check_terminal(text, b'P6\n640 200\n255\n' + damaged, FONT, 'warm')


if __name__ == '__main__':
    unittest.main()
