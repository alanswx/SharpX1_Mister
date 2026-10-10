"""Exact linkage/layout checks, not execution or native acceptance."""
import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from assemble_mr16 import assemble
from build_mr16_rtc_firmware import build, SOURCE


class LinkTest(unittest.TestCase):
    def test_both_inherited_profiles_only_redirect_five_words(self):
        for receive_only in (False, True):
            with self.subTest(receive_only=receive_only):
                defines = {"ps2_receive_only": 1} if receive_only else {}
                baseline, old, _ = assemble(SOURCE / "x1sub.asm", defines)
                image, symbols = build(receive_only)
                self.assertEqual(len(image), 8192)
                self.assertEqual(symbols["code_end"], 0x0fea)
                self.assertEqual(symbols["rtc_buffer"], 0x1156)
                self.assertEqual(symbols["rtc_extension_end"], 0x4180)
                expected = bytearray(baseline)
                patches = [(0, "rtc_boot")]
                patches += [(old["cmd_tbl"] + i * 4, f"rtc_cmd_{c}")
                            for i, c in zip(range(12, 16), ("ec", "ed", "ee", "ef"))]
                for address, name in patches:
                    self.assertGreaterEqual(symbols[name], 0x4000)
                    expected[address:address+2] = symbols[name].to_bytes(2, "little")
                self.assertEqual(image[:4096], expected)
                # All old callback argument words, FDC/DMA, IRQ vectors and
                # keyboard code stay exact; no blob byte-patching workaround.
                self.assertEqual(image[0x0fe9:4096], bytes(4096-0x0fe9))
                self.assertEqual(image[0x1180:], bytes(0x0e80))
                self.assertEqual({name: symbols[name] for name in old}, old)


if __name__ == "__main__":
    unittest.main()
