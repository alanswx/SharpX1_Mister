#!/usr/bin/env python3
"""Guard CONF_STR ordering, including optional preprocessor branches."""
import re
import unittest
from pathlib import Path


def check_order(config):
    joystick_seen = False
    for entry in config.split(";"):
        entry = entry.strip()
        if not entry:
            continue
        if entry[0] in "Jj":
            joystick_seen = True
        elif joystick_seen:
            raise ValueError(f"OSD entry follows J/j joystick entries: {entry}")
        # Main strips H/h/D/d flags before the page prefix (menu.cpp); after
        # it, "P2H1O[8]" is not an option and the row never shows.
        if re.match(r"P[0-9][HhDd][0-9]", entry):
            raise ValueError(f"hide/disable flag after page prefix: {entry}")


class ConfigOrderTest(unittest.TestCase):
    def test_wrapper(self):
        source = (Path(__file__).resolve().parents[1] / "sharpx1.sv").read_text()
        source = re.sub(r"/\*.*?\*/|//[^\n]*", "", source, flags=re.S)
        match = re.search(r"localparam\s+CONF_STR\s*=\s*\{(.*?)\};", source, re.S)
        self.assertIsNotNone(match, "CONF_STR missing")
        # Include every conditional literal: no build profile may append a
        # menu/version entry after joystick metadata. BUILD_DATE is non-menu data.
        literals = re.findall(r'"((?:\\.|[^"\\])*)"', match.group(1))
        check_order("".join(literals))

    def test_last_entries(self):
        check_order("SharpX1;;T[0],Reset;V,vDATE;J,Fire;jn,A,B;")
        check_order("SharpX1;;T[0],Reset;V,vDATE")

    def test_flag_before_page(self):
        check_order("SharpX1;;H1P2O[8],Monitor,A,B;h1P2-;")
        for bad in ("P2H1O[8],Monitor,A,B", "P5h1-"):
            with self.subTest(entry=bad):
                with self.assertRaises(ValueError):
                    check_order(f"SharpX1;;{bad};")

    def test_bad_order(self):
        for joystick in ("J,Fire", "j1,Fire", "jn,A,B"):
            for later in ("T[0],Reset", "V,vDATE", "S0,D88,Drive A"):
                with self.subTest(joystick=joystick, later=later):
                    with self.assertRaises(ValueError):
                        check_order(f"SharpX1;;{joystick};{later};")


if __name__ == "__main__":
    unittest.main()
