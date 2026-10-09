"""Check opt-in machine signed stereo WAV, left FM + centered PSG both sides."""
import pathlib
import json
import statistics
import struct
import sys
import wave

source = pathlib.Path(sys.argv[1])
report = json.loads(pathlib.Path(sys.argv[2]).read_text().splitlines()[-1])
assert report["turbo_fm_cpu"] and report["turbo_foundation"]
assert not report["turbo_dma"]  # This C++ audio profile does not qualify DMA.
assert report["sys_hz"] == 32000000 and report["video_hz"] == 28571428
assert report["time_ps"] == 800000000000 and report["download_bytes"] == 8192
assert report["halted"] and report["peek"].startswith("aa")
assert report["disk_writes"] == report["disk_requests"] == 0
with wave.open(str(source)) as capture:
    assert capture.getnchannels() == 2 and capture.getsampwidth() == 2
    assert capture.getframerate() == 48000
    assert capture.getnframes() == 38400
    data = struct.unpack("<76800h", capture.readframes(38400))
# Final 300 ms after CPU programming and digital coupling settle.
left = data[48000::2]
right = data[48001::2]
fm = [l-r for l, r in zip(left, right)]


def frequency(signal):
    rises = [i for i in range(1, len(signal)) if signal[i-1] <= 0 < signal[i]]
    assert len(rises) > 100
    return 48000 / statistics.mean(b-a for a, b in zip(rises, rises[1:]))


pf = frequency(right)
ff = frequency(fm)
assert 990 < pf < 1010, pf
assert abs(ff / (440 * 4000000 / 3579545) - 1) < 0.005, ff
assert min(right) < -1000 and max(right) > 1000
assert min(fm) < -50 and max(fm) > 50
assert abs(statistics.mean(right)) < 100
assert max(left) < 32767 and min(left) > -32768, "fixture unexpectedly clips"
print(f"PASS signed machine stereo WAV: 38400 frames, PSG {pf:.3f} Hz, isolated FM {ff:.3f} Hz")
