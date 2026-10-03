"""Measure a Z80-programmed PSG tone from actual RTL audio output."""
import json
import pathlib
import statistics
import struct
import subprocess
import sys
import tempfile
import wave
from z80_fixture import Program

p = Program()
p.emit(0xF3)
for register, value in ((0, 125), (1, 0), (7, 0x3E), (8, 15), (9, 0), (10, 0)):
    p.word(0x01, 0x1C00)
    p.emit(0x3E, register, 0xED, 0x79)
    p.word(0x01, 0x1B00)
    p.emit(0x3E, value, 0xED, 0x79)
p.emit(0x76)

exe = str(pathlib.Path(sys.argv[1]).resolve())
with tempfile.TemporaryDirectory(prefix="x1-audio-") as folder:
    folder = pathlib.Path(folder)
    rom = folder / "tone.bin"
    rom.write_bytes(p.finish())
    capture = folder / "tone.wav"
    result = subprocess.run([exe, "--cycles", "2000000", "--rom", str(rom),
                             "--audio", str(capture)], check=True, capture_output=True, text=True)
    report = json.loads(result.stdout.splitlines()[-1])
    assert report["halted"], report
    with wave.open(str(capture)) as sound:
        assert sound.getnchannels() == 1 and sound.getsampwidth() == 2
        assert sound.getframerate() == 48000 and sound.getnframes() == 3000
        samples = struct.unpack("<3000h", sound.readframes(3000))
    assert max(samples) - min(samples) > 1000
    rises = [i for i in range(481, len(samples)) if samples[i - 1] <= 0 < samples[i]]
    periods = [right - left for left, right in zip(rises, rises[1:])]
    assert len(periods) > 30, (len(periods), report)
    frequency = 48000 / statistics.mean(periods)
    assert 990 < frequency < 1010, frequency
    # Repeat exactly, including reset/download and the integer DC blocker.
    original = capture.read_bytes()
    subprocess.run([exe, "--cycles", "2000000", "--rom", str(rom),
                    "--audio", str(capture)], check=True, capture_output=True)
    assert original == capture.read_bytes(), "nondeterministic waveform"
print(f"PASS: PSG address/data writes and 2 MHz clock produce deterministic {frequency:.1f} Hz PCM tone")
