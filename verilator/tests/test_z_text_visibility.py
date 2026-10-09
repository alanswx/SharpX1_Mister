"""Original visibility-oracle guards; not executed-machine/native acceptance."""
import unittest
from test_machine_z_video import require_text_visibility, text_visibility_coverage


class VisibilityTests(unittest.TestCase):
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
