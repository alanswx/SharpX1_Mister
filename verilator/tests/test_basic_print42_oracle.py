"""Asset-free oracle tests, not native BASIC execution or compatibility proof.

The literal lowercase echo follows Main's observed startup CAPS/Shift case;
the initial uppercase expectation was an oracle assumption, not an RTL bug.
All evidence here is generated from original ASCII and the public checked ANK.
"""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest


CHECKER = Path(__file__).with_name('check_basic_print42.py')
FONT = Path(__file__).resolve().parents[2] / 'rtl/legacy/x1_cg8.v'
SPEC = importlib.util.spec_from_file_location('basic_print42_checker', CHECKER)
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)
SUFFIXES = ('.ram', '.text', '.attr', '.subram', '.cpu', '.ppm')
HEADER = b'P6\n640 200\n255\n'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def put_row(text, row, value):
    assert len(value) <= 80
    text[row * 80:(row + 1) * 80] = value.ljust(80, b' ')


def synthetic_text():
    text = bytearray(b' ' * 2048)
    put_row(text, 0, b'SHARP-HuBASIC CZ-8FB01 V1.0')
    for row, value in zip((13, 14, 15), (b'print 6*7', b' 42', b'Ok')):
        put_row(text, row, value)
    return text


def render(text, font):
    # External renderer: character-major ROM bytes, MSB at the leftmost dot.
    # Render every cell, independently of check_frame's candidate-row search.
    pixels = bytearray(640 * 200 * 3)
    for row in range(25):
        for column in range(80):
            code = text[row * 80 + column]
            for scan in range(8):
                pattern = font[code * 8 + scan]
                for dot in range(8):
                    if pattern & (1 << (7 - dot)):
                        offset = ((row * 8 + scan) * 640 + column * 8 + dot) * 3
                        pixels[offset:offset + 3] = b'\xff' * 3
    return HEADER + pixels


class BasicPrint42OracleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source_hashes = (sha(CHECKER), sha(FONT))
        assert cls.source_hashes[1] == checker.FONT_SHA
        entries = re.findall(r"11'h([0-9a-fA-F]+):cg8_rom = 8'b([01]{8})", FONT.read_text())
        cls.font = bytearray(2048)
        assert len(entries) == 2048 and {int(a, 16) for a, _ in entries} == set(range(2048))
        for address, bits in entries:
            cls.font[int(address, 16)] = int(bits, 2)
        cls.glyphs = checker.font_bytes(FONT)

    @classmethod
    def tearDownClass(cls):
        assert cls.source_hashes == (sha(CHECKER), sha(FONT)), 'checker/font changed during unit gate'

    def setUp(self):
        self.text = synthetic_text()
        self.ppm = render(self.text, self.font)

    def reject_frame(self, text, ppm, diagnostic, exception=AssertionError):
        with self.assertRaisesRegex(exception, diagnostic):
            checker.check_frame(bytes(text), bytes(ppm), self.glyphs)

    def test_complete_rows_positive(self):
        result = checker.check_frame(bytes(self.text), self.ppm, self.glyphs)
        self.assertEqual(result, {'command_row': 13, 'result_row': 14,
                                 'prompt_row': 15, 'checked_pixels': 15360,
                                 'ink_pixels': 164})

    def test_text_false_evidence(self):
        cases = {
            'echo-only': ((14, b''), (15, b'')),
            'wrong-answer': ((14, b' 43'),),
            'missing-Ok': ((15, b''),),
            'uppercase-echo': ((13, b'PRINT 6*7'),),
            'result-elsewhere': ((14, b''), (20, b'42')),
            'prompt-elsewhere': ((15, b''), (20, b'Ok')),
            'duplicate-triplet': ((19, b'print 6*7'), (20, b'42'), (21, b'Ok')),
        }
        for label, edits in cases.items():
            with self.subTest(label=label):
                text = self.text.copy()
                for row, value in edits:
                    put_row(text, row, value)
                self.reject_frame(text, render(text, self.font), 'sequence absent or ambiguous')

    def test_blank_and_other_row_text(self):
        self.reject_frame(b' ' * 2048, HEADER + bytes(640 * 200 * 3), 'banner absent')
        text = self.text.copy()
        for row in (13, 14, 15):
            put_row(text, row, b'other text')
        self.reject_frame(text, render(text, self.font), 'sequence absent or ambiguous')

    def test_wrong_text_byte_count(self):
        for text in (self.text[:-1], self.text + b' '):
            self.reject_frame(text, self.ppm, 'text-bank size')

    def test_wrong_byte_with_unchanged_raster(self):
        # Shift the result's text bytes while retaining the old raster. The
        # stripped result is still 42, so only the pixel oracle rejects it.
        text = self.text.copy()
        put_row(text, 14, b'  42')
        self.reject_frame(text, self.ppm, 'rendered glyph mismatch')

    def test_complete_row_padding_is_checked(self):
        # Padding in all three rows is covered, including the last pixel.
        for row in (13, 14, 15):
            with self.subTest(row=row):
                ppm = bytearray(self.ppm)
                offset = len(HEADER) + (((row + 1) * 8 - 1) * 640 + 639) * 3
                ppm[offset] = 255
                self.reject_frame(self.text, ppm, 'rendered glyph mismatch')

    def test_raster_headers_and_missing_data(self):
        for header in (b'P3\n640 200\n255\n', b'P6\n320 200\n255\n', b'P6\n640 200\n15\n'):
            self.reject_frame(self.text, header + self.ppm[len(HEADER):], 'unexpected native raster')
        for pixels in (b'', self.ppm[len(HEADER):-1]):
            self.reject_frame(self.text, HEADER + pixels, 'incomplete native raster')
        self.reject_frame(self.text, b'', 'not enough values', ValueError)

    def test_result_glyph_and_blank_raster(self):
        on = next((x, y) for y in range(8) for x in range(8)
                  if self.font[ord('4') * 8 + y] & (128 >> x))
        x, y = on
        ppm = bytearray(self.ppm)
        offset = len(HEADER) + ((14 * 8 + y) * 640 + 8 + x) * 3
        ppm[offset:offset + 3] = b'\x00' * 3
        self.reject_frame(self.text, ppm, 'rendered glyph mismatch')
        self.reject_frame(self.text, HEADER + bytes(640 * 200 * 3), 'rendered glyph mismatch')

    def test_cli_terminal_source_and_artifact_guards(self):
        with tempfile.TemporaryDirectory(prefix='basic-print42-oracle-') as directory:
            folder = Path(directory).resolve()
            runner, source = folder / 'Vtop', folder / 'synthetic-input'
            runner.write_bytes(b'original synthetic non-executable runner evidence')
            source.write_bytes(b'original synthetic input, no firmware/media')
            inputs = {}
            for flag in ('--rom', '--disk', '--keys'):
                path = folder / ('synthetic' + flag[1:])
                path.write_bytes(b'original synthetic input: ' + flag.encode())
                inputs[flag] = path
            manifest = {str(path): sha(path) for path in (runner, source, *inputs.values())}
            artifacts = {}
            for suffix in SUFFIXES:
                data = bytes(self.text) if suffix == '.text' else self.ppm if suffix == '.ppm' else b'synthetic artifact'
                for name in ('cold', 'repeat'):
                    (folder / (name + suffix)).write_bytes(data)
                artifacts[suffix] = sha(folder / ('cold' + suffix))
            report = dict(machine='sharpx1', ps2_bytes_sent=36, time_ps=12000000000000,
                          sys_hz=32000000, video_hz=28571428, fdc_timing_experiment=True,
                          fdc_clock_hz=1000000, disk_writes=0, frame_width=640, frame_height=200)
            evidence = dict(phase='repeatable', unchanged_inputs=True, unchanged_runner=True,
                            executable_sha256=sha(runner), inputs_sha256=manifest,
                            runs=[dict(returncode=0, report=copy.deepcopy(report), artifacts=artifacts.copy(),
                                       command=[str(runner), '--cycles', '384000000',
                                                '--rom', str(inputs['--rom']), '--disk', str(inputs['--disk']),
                                                '--keys', str(inputs['--keys']), '--dump', str(folder / name),
                                                '--frame', str(folder / (name + '.ppm'))])
                                  for name in ('cold', 'repeat')])

            def invoke(value):
                path = folder / 'evidence.json'
                path.write_text(json.dumps(value))
                return subprocess.run([sys.executable, '-B', str(CHECKER), str(path)],
                                      capture_output=True, text=True, timeout=10)

            result = invoke(evidence)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('"checked_pixels": 15360', result.stdout)
            mutations = []
            altered = copy.deepcopy(evidence); altered['inputs_sha256'] = {}
            mutations.append(('empty-input-manifest', altered, 'native input manifest absent'))
            for flag in ('--rom', '--disk', '--keys'):
                altered = copy.deepcopy(evidence)
                del altered['inputs_sha256'][str(inputs[flag])]
                mutations.append(('missing-manifest-' + flag, altered, 'native input absent from manifest'))
                for action in ('missing', 'duplicate'):
                    altered = copy.deepcopy(evidence)
                    command = altered['runs'][0]['command']
                    if action == 'missing':
                        index = command.index(flag)
                        del command[index:index + 2]
                    else:
                        command.extend([flag, str(inputs[flag])])
                    mutations.append((action + flag, altered, 'native input command missing/duplicate'))
            for flag in ('--restore-state', '--ram', '--disk-output'):
                altered = copy.deepcopy(evidence)
                altered['runs'][0]['command'].extend([flag, str(source)])
                mutations.append((flag, altered, 'not a read-only native cold boot'))
            altered = copy.deepcopy(evidence)
            altered['runs'][0]['command'][0] = str(source)
            mutations.append(('wrong-command-runner', altered, 'native command runner differs'))
            for field, value in (('phase', 'running'), ('unchanged_inputs', False), ('unchanged_runner', False)):
                altered = copy.deepcopy(evidence); altered[field] = value
                mutations.append((field, altered, 'non-terminal or changed native probe'))
            altered = copy.deepcopy(evidence); altered['runs'].pop()
            mutations.append(('missing-repeat', altered, 'cold/repeat pair required'))
            altered = copy.deepcopy(evidence); altered['runs'][1]['returncode'] = 7
            mutations.append(('child-failed', altered, 'failed native child'))
            altered = copy.deepcopy(evidence); altered['runs'][1]['report']['disk_writes'] = 1
            mutations.append(('report-disagreement', altered, 'native reports/artifacts differ'))
            altered = copy.deepcopy(evidence); altered['runs'][1]['artifacts']['.text'] = '0' * 64
            mutations.append(('artifact-disagreement', altered, 'native reports/artifacts differ'))
            for field, value, diagnostic in (
                ('machine', 'other', 'unexpected machine/key sequence'),
                ('ps2_bytes_sent', 35, 'unexpected machine/key sequence'),
                ('time_ps', 1, 'unexpected native duration/clocks'),
                ('fdc_clock_hz', 2000000, 'unexpected disk profile/write'),
                ('disk_writes', 1, 'unexpected disk profile/write'),
                ('frame_width', 320, 'unexpected native display')):
                altered = copy.deepcopy(evidence)
                for run in altered['runs']: run['report'][field] = value
                mutations.append((field, altered, diagnostic))
            for remove in (SUFFIXES, ('.ppm',)):
                altered = copy.deepcopy(evidence)
                for run in altered['runs']:
                    for suffix in remove: del run['artifacts'][suffix]
                mutations.append(('missing-artifacts', altered, 'incomplete native artifact manifest'))
            for label, altered, diagnostic in mutations:
                with self.subTest(label=label):
                    result = invoke(altered)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(diagnostic, result.stderr)
                    self.assertNotIn('PASS native BASIC', result.stdout)
            for path, diagnostic in ((runner, 'frozen runner changed'), (source, 'native input changed'),
                                     (folder / 'cold.ppm', 'native artifact changed')):
                with self.subTest(changed=path.name):
                    original = path.read_bytes()
                    path.write_bytes(original + b'changed')
                    result = invoke(evidence)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(diagnostic, result.stderr)
                    path.write_bytes(original)


if __name__ == '__main__':
    unittest.main()
