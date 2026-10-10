"""Artifact parity and restricted syntax tests, not native firmware acceptance."""
import hashlib
import pathlib
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from assemble_mr16 import AssemblyError, assemble, encode, expression


class MR16AssemblerTest(unittest.TestCase):
    def snippet(self, text):
        with tempfile.TemporaryDirectory(prefix="x1-mr16-assembler-") as folder:
            source = pathlib.Path(folder) / "test.asm"
            source.write_text(text)
            return assemble(source)

    def test_inherited_source_hex_binary_parity(self):
        folder = ROOT / "bios/reference/fw_subcpu"
        image, symbols, locations = assemble(folder / "x1sub.asm")
        self.assertEqual(symbols["code_end"], 0x0fea)
        self.assertEqual(locations["dseg"], 0x1156)
        # Independently decode the saved Intel HEX, including checksums, data
        # inventory, internal FF holes and final bin2ver zero padding.
        reference = bytearray([255]) * 4096
        addresses = set()
        records = 0
        eof = False
        for line in (folder / "x1sub.HEX").read_text().splitlines():
            self.assertTrue(line.startswith(":"))
            record = bytes.fromhex(line[1:])
            self.assertEqual(sum(record) & 255, 0)
            size = record[0]
            self.assertEqual(len(record), size + 5)
            address = int.from_bytes(record[1:3], "big")
            if record[3] == 1:
                self.assertEqual((size, address), (0, 0))
                self.assertFalse(eof)
                eof = True
                continue
            self.assertEqual(record[3], 0)
            self.assertFalse(eof)
            records += 1
            for offset, value in enumerate(record[4:-1], address):
                self.assertNotIn(offset, addresses)
                addresses.add(offset)
                reference[offset] = value
        self.assertTrue(eof)
        self.assertEqual((records, len(addresses), max(addresses)), (255, 4071, 0xfe8))
        end = max(addresses) + 1
        self.assertEqual(reference[:end], (folder / "verilog/X1SUB.BIN").read_bytes())
        reference[end:] = bytes(4096 - end)
        self.assertEqual(image, reference)
        self.assertEqual(hashlib.sha256(image).hexdigest(),
                         "2d9c9745e0a1a09d98c0e14ace627c03cd39d71ceb21e3fef5957e7a62428c01")

    def test_encoding_literal_vectors(self):
        # Fixed literal vectors from MR16.MAC/listing, independent of emitter.
        cases = [("mov", "r14,#2000h", [0x2720, 0x7e00]),
                 ("mov", "r0,r3", [0x3037]),
                 ("ldm", "r0,(r14,#2)", [0x0e01]),
                 ("stm", "(r14,#10),r0", [0x1e05]),
                 ("bne", "0", [0x29fe]),
                 ("jsr", "r3", [0x3f33]),
                 ("jsr", "0734h", [0x2707, 0x2f35]),
                 ("jcs", "0734h", [0x2707, 0x3034]),
                 ("stw", "(r7,#32),r1", [0x2701, 0x7100]),
                 ("push", "flag", [0x1ff1]),
                 ("ret", "sti", [0x0f90]),
                 ("shr", "r0,#1", [0x2780, 0xf000])]
        for op, args, expected in cases:
            with self.subTest(op=op, args=args):
                self.assertEqual(encode(op, args, lambda s: expression(s, {}, 4), 4, True), expected)

    def test_layout_forward_relocation_and_segments(self):
        image, symbols, locations = self.snippet("""
            dseg
            org 1000h
        work ds 4
            cseg
            dw entry
        entry: mov r0,#after
            bra after
            db 5
            .align 2
        after: nop
        code_end
        """)
        self.assertEqual(symbols["work"], 0x1000)
        self.assertEqual(symbols["entry"], 2)
        self.assertEqual(symbols["after"], 8)
        self.assertEqual(image[:10], bytes.fromhex("02000870022f05ff003f"))
        self.assertEqual(locations, {"cseg": 10, "dseg": 0x1004})

    def test_conditional_comment_bytes(self):
        # NEL byte within an inherited Shift-JIS comment must not split code.
        image, _, _ = self.snippet("; comment\x85not code\n.ifndef disabled\n.if 1\nnop\n.else\ninvalid r0\n.endif\n.endif\n")
        self.assertEqual(image[:2], bytes.fromhex("003f"))

    def test_fail_closed(self):
        cases = {"undefined": "mov r0,#missing",
                 "width": "mov r0,#256:8",
                 "register": "mov r16,#0",
                 "memory": "ldm r0,(r1,#1)",
                 "branch": "bra 256",
                 "odd_target": "jmp 3",
                 "data": "db 256",
                 "overlap": "dw 1\norg 0\ndw 2",
                 "overflow": "org 4096\ndw 1",
                 "allocation": "ds 4097",
                 "odd_instruction": "db 1\nnop",
                 "syntax": "unsupported r0",
                 "duplicate_symbol": "label:\nlabel:",
                 "duplicate_else": ".if 1\n.else\n.else\n.endif",
                 "unclosed": ".ifdef missing",
                 "unmatched": ".endif",
                 "unsafe_expression": "dw __import__('os')"}
        for name, source in cases.items():
            with self.subTest(name=name), self.assertRaises(AssemblyError):
                self.snippet(source)

    def test_recursive_include_rejects(self):
        with tempfile.TemporaryDirectory(prefix="x1-mr16-include-") as folder:
            source = pathlib.Path(folder) / "recursive.asm"
            source.write_text('include "recursive.asm"')
            with self.assertRaisesRegex(AssemblyError, "recursive include"):
                assemble(source)


if __name__ == "__main__":
    unittest.main()
