"""Original visibility-oracle guards; not executed-machine/native acceptance."""
import unittest
from test_machine_z_video import (TEXT_CPU_WORDS, TEXT_RGB, expected_pixel,
                                 require_text_visibility, text_visibility_coverage)


class VisibilityTests(unittest.TestCase):
    def test_distinct_text_entries_and_independent_rgb(self):
        self.assertEqual(len(set(TEXT_RGB[1:])), 7)
        self.assertEqual(TEXT_RGB[7], bytes(3))
        for channel in range(3):
            self.assertEqual({rgb[channel] for rgb in TEXT_RGB}, {0, 85, 170, 255})
        for code, word in enumerate(TEXT_CPU_WORDS):
            self.assertEqual(TEXT_RGB[code], bytes((((word >> 2) & 3) * 85,
                                                 ((word >> 4) & 3) * 85,
                                                 (word & 3) * 85)))
        # Every selected writable index must differ from every other writable
        # index, including the black one. Spatial oracle samples are actual
        # glyph ink in the corrected graphics-transparent CPU window.
        samples = {code: expected_pixel(code * 8 + 3, 0, True, "full", 0,
                                       1, True) for code in range(1, 8)}
        self.assertEqual(samples, {code: TEXT_RGB[code] for code in range(1, 8)})
        for code in range(1, 8):
            for replacement in range(1, 8):
                if code != replacement:
                    self.assertNotEqual(samples[code], TEXT_RGB[replacement])

    def test_old_graphics_top_scenes_are_rejected(self):
        for mode, control in (("full", 1), ("paired64", 0x11), ("paired64", 0x19)):
            with self.subTest(mode=mode, control=control):
                old = text_visibility_coverage(mode, 1, control, windows=False)
                self.assertEqual(old["selected_text_colors"], [0] * 8)
                with self.assertRaises(AssertionError):
                    require_text_visibility(old)
                corrected = text_visibility_coverage(mode, 1, control)
                self.assertEqual(corrected["selected_text_colors"], [0] + [36] * 7)
                require_text_visibility(corrected)

    def test_every_nonzero_color_is_required_including_black(self):
        for missing in range(1, 8):
            colors = [0] + [36] * 7
            colors[missing] = 0
            with self.subTest(missing=missing), self.assertRaises(AssertionError):
                require_text_visibility({"selected_text_colors": colors})

    def test_single_selected_and_between_reverse_scenes(self):
        for mode, control, reverse in (("dual64", 1, False), ("paired64", 0x12, False),
                                       ("paired64", 0x1A, True)):
            with self.subTest(mode=mode, control=control, reverse=reverse):
                coverage = text_visibility_coverage(mode, 1, control, reverse)
                require_text_visibility(coverage)
                self.assertGreater(coverage["present_text_masked_by_graphics"], 1000)


if __name__ == "__main__":
    unittest.main()
