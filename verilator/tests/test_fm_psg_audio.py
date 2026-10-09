"""Original concurrent JT49/JT51 waveform checks, no private audio assets."""
import csv
import argparse
import pathlib
import struct
import wave


def clip(value):
    return max(-32768, min(32767, value))


def frequency(signal):
    crossings = [i - signal[i - 1] / (signal[i] - signal[i - 1])
                 for i in range(1, len(signal)) if signal[i - 1] <= 0 < signal[i]]
    assert len(crossings) > 40, len(crossings)
    return (len(crossings) - 1) * 62500 / (crossings[-1] - crossings[0])


parser = argparse.ArgumentParser()
parser.add_argument("prefix", type=pathlib.Path)
parser.add_argument("--profiles", type=int, nargs="+", default=list(range(5)))
args = parser.parse_args()
prefix = args.prefix
assert 0 in args.profiles and 4 in args.profiles, "reset repeat profiles 0/4 required"
captures = {}
for profile in args.profiles:
    source = pathlib.Path(f"{prefix}-{profile}.csv")
    with source.open() as stream:
        values = [tuple(map(int, row)) for row in csv.reader(stream)]
    assert len(values) == 6250 and all(len(row) == 7 for row in values), source
    fl, fr, raw, psg, left, right, mono = zip(*values)
    assert all(0 <= x <= 1023 for x in raw)
    assert all(-32768 <= x <= 32767 for row in values for x in row)
    assert min(psg) < -1000 and max(psg) > 1000, source
    pf = frequency(psg)
    assert abs(pf / 1000 - 1) < 0.005, (source, pf)
    assert abs(sum(psg) / len(psg)) < 100, (source, sum(psg) / len(psg))
    if profile in (0, 4):
        assert set(fr) == {0} and min(fl) < -50 and max(fl) > 50
        assert right == psg
    elif profile == 1:
        assert set(fl) == {0} and min(fr) < -50 and max(fr) > 50
        assert left == psg
    elif profile == 2:
        assert fl == fr and left == right
    else:
        assert set(fl) == set(fr) == {0}
        assert left == right == mono == psg
    if profile != 3:
        ff = frequency(fr if profile == 1 else fl)
        expected = 440 * 4000000 / 3579545
        assert abs(ff / expected - 1) < 0.005, (source, ff, expected)
    for f_l, f_r, _, p, l, r, m in values:
        assert (l, r, m) == (clip(f_l + p), clip(f_r + p), clip(f_l + f_r + p)), source
    with wave.open(str(source.with_suffix(".wav")), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(62500)
        output.writeframes(b"".join(struct.pack("<hh", row[4], row[5]) for row in values))
    captures[profile] = values
    print(f"PASS concurrent PSG/FM profile={profile}: PSG={pf:.3f} Hz, exact sample-aligned stereo/mono")
assert captures[0] == captures[4], "mixed reset/reprogrammed waveform changed"
print("PASS genuine concurrent JT49/JT51 mix: panning, DC, pitch, reset repeatability, WAVs")
