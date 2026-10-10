#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Original static cassette-firmware verifier, NOT MR16 execution acceptance.

Checks generated instruction bytes against an independent bounded word oracle,
plus exact inherited patch/address parity and rejecting controls. No GPIO/host
completion is simulated, and no machine or private core state is changed.
Run: python3 verilator/tests/test_mr16_cassette_firmware.py -v
"""
import hashlib
import json
import pathlib
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
import build_mr16_cassette_firmware as cassette
from assemble_mr16 import AssemblyError, assemble


class CassetteFirmwareTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.products = {}
        cls.frozen = {}
        for receive_only in (False, True):
            image, symbols, report = cassette.build(receive_only, with_report=True)
            baseline, old_symbols, locations = assemble(
                cassette.SOURCE / "x1sub.asm",
                {"ps2_receive_only": 1} if receive_only else {})
            cls.products[receive_only] = image, symbols, report, baseline, old_symbols, locations
            cls.frozen.update(report["inputs"])
        for path in [pathlib.Path(__file__), ROOT / "scripts/build_mr16_rtc_firmware.py"]:
            cls.frozen[str(path.relative_to(ROOT))] = hashlib.sha256(path.read_bytes()).hexdigest()

    @classmethod
    def tearDownClass(cls):
        for name, expected in cls.frozen.items():
            actual = hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
            if actual != expected:
                raise AssertionError(f"frozen source changed: {name}")
        print("CASSETTE_STATIC_FIRMWARE_MANIFEST " + json.dumps({
            "profiles": {str(mode): product[2] for mode, product in cls.products.items()},
            "verifier_sha256": cls.frozen[str(pathlib.Path(__file__).relative_to(ROOT))],
            "scope": "static byte/link oracle; real MR16/GPIO/host execution remains open"}, sort_keys=True))

    def test_baseline_and_exact_patch_ledger(self):
        for mode, (image, symbols, report, baseline, old, locations) in self.products.items():
            with self.subTest(receive_only=mode):
                self.assertEqual(len(image), 8192)
                if not mode:
                    self.assertEqual(hashlib.sha256(baseline).hexdigest(), cassette.BASE_SHA)
                self.assertEqual(locations["dseg"], 0x1156)
                self.assertEqual((old["ram_end"], old["stack_end"]), (0x1800, 0x1800))
                self.assertEqual({name: symbols[name] for name in old}, old)
                self.assertEqual(report["ram_allocation_end"], 0x1156)
                # Independent exact low-bank construction: no general patch allowance.
                expected = bytearray(baseline)
                allowed = set()
                for address, op, _, target in report["sites"]:
                    dest = symbols[target]
                    tail = (0x7000 if op == "mov" else 0x2F01) | (dest & 255)
                    patch = (0x2700 | (dest >> 8)).to_bytes(2, "little") + tail.to_bytes(2, "little")
                    expected[address:address + 4] = patch
                    allowed.update(range(address, address + 4))
                for command in (9, 10, 11):
                    at = old["cmd_tbl"] + 4 * command
                    expected[at:at + 2] = symbols[f"cassette_cmd_e{command:x}"].to_bytes(2, "little")
                    allowed.update((at, at + 1))
                self.assertEqual(image[:4096], expected)
                self.assertEqual(report["allowed_low_bytes"], sorted(allowed))
                self.assertEqual(len(allowed), 18)
                self.assertEqual(image[:2], baseline[:2])  # original reset vector
                for command in (12, 13, 14, 15):
                    at = old["cmd_tbl"] + command * 4
                    self.assertEqual(image[at:at + 4], baseline[at:at + 4])
                end = symbols["cassette_extension_end"]
                self.assertLess(end, 0x5000)
                # Assembler zero-pads after the final emitted byte; FF is its
                # internal-hole policy, not its trailing converter padding.
                self.assertEqual(image[end - 0x3000:], bytes(0x5000 - end))

    def test_independent_hook_instruction_oracle(self):
        for mode, (image, s, _, _, _, _) in self.products.items():
            with self.subTest(receive_only=mode):
                def words(at, count):
                    offset = at if at < 0x1000 else at - 0x3000
                    return [int.from_bytes(image[i:i + 2], "little")
                            for i in range(offset, offset + 2 * count, 2)]

                def check(at, expected):
                    self.assertEqual(words(at, len(expected)), expected, hex(at))

                def transfer(at, target, call=False):
                    check(at, [0x2700 | (s[target] >> 8),
                               0x2F00 | (s[target] & 255) | int(call)])

                def branch(at, target, condition):
                    delta = s[target] - at
                    self.assertEqual(delta & 1, 0)
                    self.assertTrue(-256 <= delta < 256)
                    check(at, [0x2000 | condition << 8 | ((delta // 2) & 255)])

                check(s["cassette_start"], [0x7001])
                transfer(s["cassette_start"] + 2, "cassette_set", True)
                transfer(s["cassette_start"] + 6, "start")
                at = s["cassette_set"]
                for value in (0, 1, 2):
                    check(at, [0xD000 | value])
                    branch(at + 2, "cassette_set_supported", 1)
                    at += 4
                check(at, [0x0F00])  # unsupported: return, no output store
                at = s["cassette_set_supported"]
                check(at, [0x1FF1, 0x3F80, 0x1E05, 0x2701, 0x5000,
                           0x1E05, 0x0F21, 0xC210])
                branch(at + 16, "cassette_set_return", 1)
                check(at + 18, [0x3F90, 0x0F00])  # conditional STI only
                # Exact refresh: sole GPIO read is PORT1; output writes only RAM.
                check(s["cassette_refresh"], [0x0E21, 0x3027, 0x2704, 0xF000,
                      0x4003, 0x1D04, 0x3027, 0x2701, 0xF000, 0x40FF, 0x1D05, 0x0F00])
                at = s["cassette_cmd_e9"]
                transfer(at, "host_r", True)
                check(at + 4, [0x0D04, 0x40FF])
                transfer(at + 8, "cassette_set", True)
                transfer(at + 12, "cassette_refresh")
                for name, pointer in (("cassette_cmd_ea", 0x1088), ("cassette_cmd_eb", 0x108A)):
                    at = s[name]
                    transfer(at, "cassette_refresh", True)
                    check(at + 4, [0x2710, 0x7000 | (pointer & 255), 0x7101])
                    transfer(at + 10, "host_w")
                at = s["cassette_key_irq"]
                check(at, [0x1F01, 0x1F21])
                transfer(at + 4, "cassette_refresh", True)
                check(at + 8, [0x0F21, 0x0F01])
                transfer(at + 12, "key_irq")
                at = s["cassette_brk_ctrl"]
                self.assert_break_normalization(image, s)
                check(at, [0x2701, 0xF000, 0x40FF, 0xD003])
                branch(at + 8, "cassette_brk_tail", 9)
                check(at + 10, [0x1F01, 0x1F21, 0x7001])
                transfer(at + 16, "cassette_set", True)
                check(at + 20, [0x0F21, 0x0F01])
                transfer(at + 24, "brk_ctrl")
                self.assertEqual(at + 28, s["cassette_extension_end"])
                # :8 encodes the immediate, not a byte-wide compare. The
                # inherited whole-register CMP remains unchanged at D003.
                check(s["brk_ctrl"], [0xD003])

    def assert_break_normalization(self, image, symbols):
        at = symbols["cassette_brk_ctrl"] - 0x3000
        expected = bytes.fromhex("012700f0ff40")
        self.assertEqual(image[at:at + 6], expected, "BREAK normalization instruction oracle")

    def test_break_packing_contract_and_reject_normalization_mutants(self):
        # Exhaustive packing arithmetic, NOT executed core or PS/2 evidence.
        for ascii_byte in range(256):
            for ctrl_byte in range(256):
                packed = ascii_byte * 256 | ctrl_byte
                forwarded = (packed >> 8) & 255
                self.assertEqual(forwarded, ascii_byte)
                self.assertEqual(forwarded == 3, ascii_byte == 3)
        self.assertNotEqual(0x0300, 3)  # old whole-word predicate misses Ctrl+C
        self.assertEqual((0x0300 >> 8) & 255, 3)
        self.assertNotEqual((0x4303 >> 8) & 255, 3)  # low CTRL bits cannot trigger
        image, symbols, _, _, _, _ = self.products[True]
        at = symbols["cassette_brk_ctrl"] - 0x3000
        for delta in (0, 4):  # corrupt shift prefix or AND mask
            bad = bytearray(image)
            bad[at + delta] ^= 1
            with self.assertRaisesRegex(AssertionError, "BREAK normalization instruction oracle"):
                self.assert_break_normalization(bytes(bad), symbols)

    def test_reject_exact_ledger_and_address_mutants(self):
        image, symbols, report, baseline, old, _ = self.products[True]
        sites = cassette.patch_sites(baseline, old)
        # Changed unapproved byte and wrong callback even inside allowed region.
        for address in (0, old["cmd_tbl"] + 9 * 4):
            bad = bytearray(image)
            bad[address] ^= 1
            with self.assertRaisesRegex(AssemblyError, "exact hook patch ledger"):
                cassette.validate(bytes(bad), symbols, baseline, old, sites)
        bad_symbols = dict(symbols, cmt_ctrl=symbols["cmt_ctrl"] + 2)
        with self.assertRaisesRegex(AssemblyError, "inherited symbol moved: cmt_ctrl"):
            cassette.validate(image, bad_symbols, baseline, old, sites)
        bad_symbols = dict(symbols, cassette_extension_end=0x5000)
        with self.assertRaisesRegex(AssemblyError, "exceeds upper ROM bank"):
            cassette.validate(image, bad_symbols, baseline, old, sites)
        with self.assertRaisesRegex(AssemblyError, "exactly 8192"):
            cassette.validate(image[:-1], symbols, baseline, old, sites)

    def test_disposable_cli_and_no_overwrite(self):
        with tempfile.TemporaryDirectory(prefix="x1-cassette-firmware-verify-") as folder:
            dest = pathlib.Path(folder) / "derived"
            command = [sys.executable, str(ROOT / "scripts/build_mr16_cassette_firmware.py"),
                       "--receive-only", "--output-dir", str(dest)]
            result = subprocess.run(command, capture_output=True, text=True, check=True)
            manifest = json.loads(result.stdout)
            self.assertEqual((dest / "cassette-controller.bin").read_bytes(), self.products[True][0])
            self.assertEqual(json.loads((dest / "manifest.json").read_text()), manifest)
            failed = subprocess.run(command, capture_output=True, text=True)
            self.assertNotEqual(failed.returncode, 0)
            self.assertIn("FileExistsError", failed.stderr)
            self.assertEqual((dest / "cassette-controller.bin").read_bytes(), self.products[True][0])


if __name__ == "__main__":
    program = unittest.main(exit=False)
    if program.result.wasSuccessful():
        print("CASSETTE_STATIC_FIRMWARE_PASS")
    sys.exit(0 if program.result.wasSuccessful() else 1)
