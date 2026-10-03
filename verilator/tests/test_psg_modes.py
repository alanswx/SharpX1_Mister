"""Exercise real machine PSG channels, mixer, noise and all envelope shapes.

Original Z80 fixtures; no game/BIOS assets. Invert the runner's integer DC
blocker exactly for these unclipped single-channel signals, so envelope
levels can be tested from the exported WAV rather than internal RTL state.
"""
import json
import pathlib
import statistics
import struct
import subprocess
import sys
import tempfile
import wave
from z80_fixture import Program

exe = str(pathlib.Path(sys.argv[1]).resolve())


def fixture(registers):
    p = Program()
    p.emit(0xF3)
    for register, value in registers:
        p.word(0x01, 0x1C00)
        p.emit(0x3E, register, 0xED, 0x79)
        p.word(0x01, 0x1B00)
        p.emit(0x3E, value, 0xED, 0x79)
    p.emit(0x76)
    return p.finish()


with tempfile.TemporaryDirectory(prefix="x1-psg-modes-") as directory:
    folder = pathlib.Path(directory)
    rom, wav = folder / "psg.bin", folder / "psg.wav"

    def run(registers):
        rom.write_bytes(fixture(registers))
        command = [exe, "--cycles", "960000", "--rom", str(rom), "--audio", str(wav)]
        report = json.loads(subprocess.run(command, check=True, capture_output=True,
                                           text=True).stdout.splitlines()[-1])
        assert report["halted"], report
        data = wav.read_bytes()
        with wave.open(str(wav)) as sound:
            assert (sound.getnchannels(), sound.getsampwidth(), sound.getframerate(),
                    sound.getnframes()) == (1, 2, 48000, 1440)
            samples = struct.unpack("<1440h", sound.readframes(1440))
        raw, previous, value = [], 0, 0
        for sample in samples:
            # C++ integer division truncates toward zero, unlike Python //.
            feedback = (abs(previous) * 255 // 256) * (1 if previous >= 0 else -1)
            value += sample - feedback
            raw.append(value)
            previous = sample
        assert min(raw) >= 0 and max(raw) <= 8160, (min(raw), max(raw))
        return raw, data, command

    # Independently select all three tone channels. Muting their volume must
    # remove the signal rather than merely changing a provisional hash.
    for channel in range(3):
        values = [(7, 0x3F ^ (1 << channel)), (8, 0), (9, 0), (10, 0),
                  (2 * channel, 125), (2 * channel + 1, 0), (8 + channel, 15)]
        raw, _, _ = run(values)
        rises = [i for i in range(241, len(raw)) if raw[i - 1] < 4000 <= raw[i]]
        frequency = 48000 / statistics.mean(b - a for a, b in zip(rises, rises[1:]))
        assert len(rises) >= 20 and 990 < frequency < 1010, (channel, frequency)
        muted, _, _ = run(values + [(8 + channel, 0)])
        assert max(muted[240:]) == 0, channel

    transitions = []
    for period in (8, 16):
        raw, data, command = run([(7, 0x37), (6, period), (8, 15), (9, 0), (10, 0)])
        levels = raw[240:]
        assert set(levels) == {0, 8160}, set(levels)
        changes = sum(a != b for a, b in zip(levels, levels[1:]))
        assert changes > 20, changes
        transitions.append(changes)
        subprocess.run(command, check=True, capture_output=True)
        assert data == wav.read_bytes(), "noise is not repeatable after reset"
    assert 1.7 < transitions[0] / transitions[1] < 2.3, transitions

    # Shape truth table: non-continuing shapes fall to zero; HOLD/ALT decide
    # the endpoint for continuing shapes. Repeating shapes must keep changing.
    held_high = {11, 13}
    repeating = {8, 10, 12, 14}
    for shape in range(16):
        raw, data, command = run([(7, 0x3F), (8, 16), (9, 0), (10, 0),
                                  (11, 32), (12, 0), (13, shape)])
        assert max(raw) == 8160 and len(set(raw)) >= 16, (shape, set(raw))
        tail = raw[960:]  # Last 10 ms: beyond the first complete 4.096 ms ramp.
        if shape in repeating:
            assert len(set(tail)) >= 16, (shape, set(tail))
            up = sum(a < b for a, b in zip(tail, tail[1:]))
            down = sum(a > b for a, b in zip(tail, tail[1:]))
            if shape == 8:
                assert down > 5 * up > 0, (shape, up, down)
            elif shape == 12:
                assert up > 5 * down > 0, (shape, up, down)
            else:
                assert up > 20 and down > 20 and 0.5 < up / down < 2, (shape, up, down)
        else:
            assert set(tail) == ({8160} if shape in held_high else {0}), (shape, set(tail))
        if shape in (10, 13):
            subprocess.run(command, check=True, capture_output=True)
            assert data == wav.read_bytes(), "envelope is not repeatable after reset"

    for period in (32, 64):
        raw, _, _ = run([(7, 0x3F), (8, 16), (9, 0), (10, 0),
                         (11, period), (12, 0), (13, 8)])
        wraps = [i for i in range(241, len(raw)) if raw[i] - raw[i - 1] > 4000]
        measured = statistics.mean(b - a for a, b in zip(wraps, wraps[1:])) / 48000
        expected = 256 * period / 2000000
        assert len(wraps) >= 3 and abs(measured - expected) < 1 / 48000, (period, measured, expected)

print("PASS: three 1 kHz channels, mute, deterministic period-scaled noise, all 16 envelope shapes and envelope timing")
