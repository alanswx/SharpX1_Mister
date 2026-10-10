"""Release/profile-specific native BASIC command and RGB acceptance oracle.

Requires terminal cold/repeat evidence, unchanged assets and the checked-in
8x8 ANK source. No image editing, CPU injection or private BASIC bytes.
This qualifies PRINT 6*7, not general BASIC, disk writes or Turbo Z.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

FONT_SHA = '68aa689abd81c1a620980b5318b669b292a72d4877916ec43dc2461d713c831b'
REQUIRED_INPUT_FLAGS = ('--rom', '--disk', '--keys')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def font_bytes(source):
    assert digest(source) == FONT_SHA, 'checked ANK source changed'
    glyphs = {int(a, 16): int(b, 2) for a, b in re.findall(
        r"11'h([0-9A-Fa-f]+):cg8_rom = 8'b([01]{8})", source.read_text())}
    assert len(glyphs) == 2048, 'incomplete ANK source'
    return glyphs


def check_frame(text, ppm, glyphs):
    assert len(text) == 2048, 'unexpected text-bank size'
    magic, dimensions, maximum, pixels = ppm.split(b'\n', 3)
    assert (magic, dimensions, maximum) == (b'P6', b'640 200', b'255'), 'unexpected native raster'
    assert len(pixels) == 640 * 200 * 3, 'incomplete native raster'
    rows = [text[i * 80:(i + 1) * 80] for i in range(25)]
    assert b'SHARP-HuBASIC CZ-8FB01 V1.0' in b''.join(rows), 'native BASIC banner absent'
    # This key stream holds Shift with the inherited startup CAPS-on state.
    # Pin its actual lowercase echo; do not accept arbitrary case variants.
    candidates = [i for i in range(23) if rows[i].strip(b' ') == b'print 6*7'
                  and rows[i + 1].strip(b' ') == b'42'
                  and rows[i + 2].strip(b' ') == b'Ok']
    assert len(candidates) == 1, 'native command/result/prompt sequence absent or ambiguous'
    first = candidates[0]
    # Independently render the three complete white-on-black ANK text rows.
    # Raw text presence alone cannot qualify a visible arithmetic result.
    checked, ink = 0, 0
    for row in range(first, first + 3):
        for column, character in enumerate(rows[row]):
            for y in range(8):
                bits = glyphs[character * 8 + y]
                for x in range(8):
                    on = bool(bits & (128 >> x))
                    expected = b'\xff\xff\xff' if on else b'\x00\x00\x00'
                    offset = ((row * 8 + y) * 640 + column * 8 + x) * 3
                    assert pixels[offset:offset + 3] == expected, (
                        'native BASIC rendered glyph mismatch', row, column, x, y)
                    checked += 1
                    ink += int(on)
    assert ink > 0, 'vacuous native glyph check'
    return {'command_row': first, 'result_row': first + 1, 'prompt_row': first + 2,
            'checked_pixels': checked, 'ink_pixels': ink}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('evidence', type=Path)
    parser.add_argument('--font', type=Path, default=Path(__file__).resolve().parents[2] / 'rtl/legacy/x1_cg8.v')
    args = parser.parse_args()
    evidence = json.loads(args.evidence.read_text())
    assert evidence['phase'] == 'repeatable' and evidence['unchanged_inputs'] and evidence['unchanged_runner'], 'non-terminal or changed native probe'
    assert len(evidence['runs']) == 2, 'cold/repeat pair required'
    assert isinstance(evidence['inputs_sha256'], dict) and evidence['inputs_sha256'], 'native input manifest absent'
    first, second = evidence['runs']
    assert first['report'] == second['report'] and first['artifacts'] == second['artifacts'], 'native reports/artifacts differ'
    glyphs = font_bytes(args.font)
    folder = args.evidence.resolve().parent
    assert digest(folder / 'Vtop') == evidence['executable_sha256'], 'frozen runner changed'
    for path, sha in evidence['inputs_sha256'].items():
        assert digest(Path(path)) == sha, ('native input changed', path)
    checks = []
    for name, run in zip(('cold', 'repeat'), evidence['runs']):
        assert run['returncode'] == 0, 'failed native child'
        command = run['command']
        assert command[0] == str(folder / 'Vtop'), 'native command runner differs'
        assert '--restore-state' not in command and '--ram' not in command and '--disk-output' not in command, 'not a read-only native cold boot'
        for flag in REQUIRED_INPUT_FLAGS:
            assert command.count(flag) == 1, ('native input command missing/duplicate', flag)
            path = command[command.index(flag) + 1]
            assert path in evidence['inputs_sha256'], ('native input absent from manifest', flag)
        report = run['report']
        assert report['machine'] == 'sharpx1' and report['ps2_bytes_sent'] == 36, 'unexpected machine/key sequence'
        assert report['time_ps'] == 12000000000000 and report['sys_hz'] == 32000000 and report['video_hz'] == 28571428, 'unexpected native duration/clocks'
        assert report['fdc_timing_experiment'] and report['fdc_clock_hz'] == 1000000 and report['disk_writes'] == 0, 'unexpected disk profile/write'
        assert (report['frame_width'], report['frame_height']) == (640, 200), 'unexpected native display'
        assert set(run['artifacts']) == {'.ram', '.text', '.attr', '.subram', '.cpu', '.ppm'}, 'incomplete native artifact manifest'
        for suffix, sha in run['artifacts'].items():
            assert digest(folder / (name + suffix)) == sha, ('native artifact changed', name, suffix)
        checks.append(check_frame((folder / (name + '.text')).read_bytes(),
                                  (folder / (name + '.ppm')).read_bytes(), glyphs))
    assert checks[0] == checks[1], 'native command acceptance differs'
    print(json.dumps({'scope': 'CZ-8FB01 PRINT 6*7 cold/repeat CPU text and exact native RGB',
                      'font_sha256': FONT_SHA, 'runs': checks}, sort_keys=True))
    print('PASS native BASIC PRINT 6*7 produces visible 42 and returns to Ok')


if __name__ == '__main__':
    main()
