"""Check opt-in machine signed stereo WAV, left FM + centered PSG both sides."""
import pathlib
import argparse
import json
import statistics
import struct
import sys
import wave

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('wav', type=pathlib.Path)
parser.add_argument('report', type=pathlib.Path)
parser.add_argument('--rtc-dma-kanji-fm', action='store_true',
                    help='require the separate non-savable X3 coexistence profile, not ordinary FM')
parser.add_argument('--ram', type=pathlib.Path, help='actual CPU RAM dump; required for coexistence')
args = parser.parse_args()
if args.rtc_dma_kanji_fm and not args.ram:
    parser.error('--rtc-dma-kanji-fm requires --ram')
source = args.wav
report = json.loads(args.report.read_text().splitlines()[-1])
assert report["turbo_fm_cpu"] and report["turbo_foundation"]
if args.rtc_dma_kanji_fm:
    assert report['rtc_experiment'] and report['rtc_controller_bytes'] == 8192
    assert report['turbo_dma'] and report['dma_kanji_experiment'] and report['turbo_kanji']
    assert report['turbo_video_master'] and report['intra_assignment_delays']
    assert not report['turbo_dma_irq']
    assert report['video_hz'] == 42954540 and report['download_bytes'] == 16385
    assert all(report[name] == 4 for name in ('dma_reads', 'dma_writes', 'dma_grants'))
    memory = args.ram.read_bytes()
    assert len(memory) == 65536 and memory[0x4000] == 0xaa
    assert memory[0x4100:0x4104] == bytes((0, 1, 0, 0xff))
    assert memory[0x8000:0x8004] == memory[0x9000:0x9004] == bytes((0x31, 0x32, 0x33, 0x34))
else:
    assert not report["turbo_dma"]  # Ordinary C++ audio profile does not qualify DMA.
    assert report['video_hz'] == 28571428 and report['download_bytes'] == 8192
assert report["sys_hz"] == 32000000 and report["time_ps"] == 800000000000
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
