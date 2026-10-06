"""Check original JT51 FM notes: stereo isolation, pitch, repeatability, WAVs."""
import csv
import pathlib
import struct
import sys
import wave

prefix = pathlib.Path(sys.argv[1])
frames = []
for profile in range(5):
    source = pathlib.Path(f"{prefix}-{profile}.csv")
    with source.open() as stream:
        values = [tuple(map(int, row)) for row in csv.reader(stream)]
    assert len(values) == 6250 and all(len(row) == 2 for row in values), source
    assert all(-32768 <= value <= 32767 for row in values for value in row), source
    left, right = zip(*values)
    if profile in (0, 4):
        assert min(left) < -50 and max(left) > 50 and set(right) == {0}, source
    elif profile == 1:
        assert min(right) < -50 and max(right) > 50 and set(left) == {0}, source
    elif profile == 2:
        assert left == right and min(left) < -50 and max(left) > 50, source
    else:
        assert set(left) == {0} and set(right) == {0}, source
    if profile != 3:
        signal = right if profile == 1 else left
        crossings = [i - signal[i-1] / (signal[i] - signal[i-1])
                     for i in range(1, len(signal)) if signal[i-1] <= 0 < signal[i]]
        assert len(crossings) > 40, source
        frequency = (len(crossings)-1) * 62500 / (crossings[-1]-crossings[0])
        # Yamaha application manual printed p6: A4=440Hz at 3.579545MHz,
        # KC=0x4a, KF=0, MUL=1, no detune/PMS. Scale to provisional 4MHz.
        expected = 440 * 4000000 / 3579545
        assert abs(frequency / expected - 1) < 0.005, (source, frequency, expected)
        print(f"PASS FM profile={profile}: stereo/pitch {frequency:.3f} Hz")
    with wave.open(str(source.with_suffix(".wav")), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(62500)
        output.writeframes(b"".join(struct.pack("<hh", *row) for row in values))
    frames.append(values)
assert frames[0] == frames[4], "reset/reprogrammed FM waveform is not repeatable"
print("PASS FM exact repeatability, silent routing, native-resolution signed stereo WAVs")
