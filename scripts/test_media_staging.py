"""Original synthetic-media checks; no ROMs or commercial assets required."""
import pathlib
import struct
import tempfile
import unittest
import zipfile
from stage_top32 import members, write_new
from x1_raw2d_to_d88 import raw2d_to_d88


class MediaTests(unittest.TestCase):
    def test_raw_sector_payload_and_order(self):
        raw = b"".join(struct.pack("<H", sector) * 128 for sector in range(1280))
        image = raw2d_to_d88(raw)
        self.assertEqual(len(image), 348848)
        self.assertEqual(struct.unpack_from("<I", image, 28)[0], len(image))
        self.assertEqual(image[26:28], b"\x10\x00")
        for track in range(80):
            offset = struct.unpack_from("<I", image, 32 + track * 4)[0]
            for sector in range(16):
                start = offset + sector * 272
                self.assertEqual(image[start:start+4], bytes((track//2, track%2, sector+1, 1)))
                self.assertEqual(struct.unpack_from("<H", image, start+4)[0], 16)
                self.assertEqual(struct.unpack_from("<H", image, start+14)[0], 256)
                raw_offset = (track * 16 + sector) * 256
                self.assertEqual(image[start+16:start+272], raw[raw_offset:raw_offset+256])
        self.assertEqual(image[32+80*4:688], bytes(688-32-80*4))

    def test_reject_unknown_geometry_and_labels(self):
        for size in (0, 327679, 327681):
            with self.assertRaises(ValueError): raw2d_to_d88(bytes(size))
        for label in ("", "x"*17, "a\0b"):
            with self.assertRaises(ValueError): raw2d_to_d88(bytes(327680), label)

    def test_zip_read_is_path_independent_and_writes_are_exclusive(self):
        with tempfile.TemporaryDirectory() as temp:
            folder = pathlib.Path(temp)
            archive = folder / "fixture.zip"
            with zipfile.ZipFile(archive, "w") as z:
                z.writestr("../../escape.2d", bytes(327680))
                z.writestr("directory/", b"")
            before = archive.read_bytes()
            self.assertEqual(list(members(archive)), [("../../escape.2d", bytes(327680))])
            self.assertEqual(archive.read_bytes(), before)
            target = folder / "safe" / "disk.d88"
            write_new(target, b"first")
            write_new(target, b"first")
            with self.assertRaises(ValueError): write_new(target, b"different")
            self.assertEqual(target.read_bytes(), b"first")


if __name__ == "__main__":
    unittest.main()
