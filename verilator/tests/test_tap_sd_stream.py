"""Board TAP SD streamer + real cassette transport: synthetic images only.

Checks sample order/levels/cadence against an independent TAP decoder,
admission rejections, empty media, remount rewind and a bit-order mutant.
Not native loading or hardware acceptance.
"""
import hashlib
import json
from pathlib import Path
import random
import shutil
import struct
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
FILES = ('rtl/x1_tap_sd_stream.sv', 'rtl/x1_cassette_transport.sv',
         'verilator/tests/tap_sd_stream_tb.sv', 'verilator/tests/test_tap_sd_stream.py')
folder = Path(tempfile.mkdtemp(prefix='x1-tap-sd-stream-'))
for name in FILES:
    (folder / name).parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / name, folder / name)
(folder / 'sources.json').write_text(json.dumps(
    {n: hashlib.sha256((folder / n).read_bytes()).hexdigest() for n in FILES}, indent=2) + '\n')
print('Frozen TAP stream evidence:', folder, flush=True)


def new_tap(bits, payload=None, rate=8000, fmt=1, wp=0, pos=0, extra=0):
    nbytes = (bits + 7) // 8
    if payload is None:
        payload = bytes(random.getrandbits(8) for _ in range(nbytes))
    title = b'synthetic'.ljust(17, b'\0')
    head = b'TAPE' + title + b'\0' * 5 + bytes([wp, fmt]) + struct.pack('<III', rate, bits, pos)
    assert len(head) == 40
    return head + payload + b'\x5a' * extra


def old_tap(nbytes, rate=8000):
    return struct.pack('<I', rate) + bytes(random.getrandbits(8) for _ in range(nbytes))


def expected_samples(image):
    """Independent decode: (bits list) or None when the image must be rejected."""
    if len(image) >= 4 and image[:4] == b'TAPE':
        if len(image) < 40:
            return None
        wp, fmt = image[26], image[27]
        rate, bits, _ = struct.unpack('<III', image[28:40])
        if wp & ~0x10 or fmt != 1 or rate != 8000 or (bits + 7) // 8 != len(image) - 40:
            return None
        data, count = image[40:], bits
    else:
        if len(image) < 4 or struct.unpack('<I', image[:4])[0] != 8000:
            return None
        data, count = image[4:], (len(image) - 4) * 8
    return [(data[i // 8] >> (7 - i % 8)) & 1 for i in range(count)]


def build(tag, sys_hz, latency, source=None):
    obj = folder / ('obj-' + tag)
    cmd = ['verilator', '--binary', '--timing', '--top-module', 'tap_sd_stream_tb',
           '-Wall', '-Wno-DECLFILENAME', '-Wno-UNUSEDSIGNAL', '-Wno-WIDTHEXPAND', '-Wno-WIDTHTRUNC', '-Wno-PROCASSINIT',
           '-GSYS_HZ=' + str(sys_hz), '-GLATENCY=' + str(latency), '--Mdir', str(obj),
           str(source or folder / FILES[0]), str(folder / FILES[1]), str(folder / FILES[2])]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    (folder / (tag + '.build.log')).write_text(result.stdout + result.stderr)
    assert result.returncode == 0, result.stdout + result.stderr
    return obj / 'Vtap_sd_stream_tb'


def run(exe, tag, image, mode='play', remount=0):
    hexfile = folder / (tag + '.hex')
    hexfile.write_text(''.join('%02x\n' % b for b in image) or '00\n')
    log = folder / (tag + '.log')
    args = [str(exe), '+image=' + str(hexfile), '+size=' + str(len(image)), '+log=' + str(log),
            '+mode=' + mode, '+remount=' + str(remount)]
    result = subprocess.run(args, capture_output=True, text=True, timeout=600)
    (folder / (tag + '.run.log')).write_text(result.stdout + result.stderr)
    assert result.returncode == 0 and 'DONE tap stream' in result.stdout, result.stdout + result.stderr
    rows = [line.split() for line in log.read_text().splitlines()]
    return rows


def check_play(rows, image, sys_hz, remount=0):
    want = expected_samples(image)
    assert want is not None
    mounts = [r for r in rows if r[0] == 'M']
    accepts = [(int(r[1]), int(r[3]), int(r[4])) for r in rows if r[0] == 'A']
    end = [r for r in rows if r[0] == 'E'][-1]
    sensor, mode, underflow = int(end[2]), int(end[3]), int(end[4])
    assert underflow == 0, 'producer underflow'
    # Eject then present mount for each mount request.
    assert [m[2:] for m in mounts] == [['0', '0'], ['1', '1' if not want else '0']] * (2 if remount else 1), mounts
    if not want:
        assert not accepts and sensor == 2 and mode == 1, (accepts, end)
        return 0
    if remount:
        first, second = accepts[:remount], accepts[remount:]
        assert [a[1] for a in first] == want[:remount], 'first pass levels'
        accepts = second
    levels = [a[1] for a in accepts]
    assert len(levels) == len(want), (len(levels), len(want))
    assert levels == want, 'sample levels differ at %d' % next(i for i, (a, b) in enumerate(zip(levels, want)) if a != b)
    assert [a[2] for a in accepts] == [0] * (len(want) - 1) + [1], 'last flag'
    period = sys_hz // 8000
    gaps = {accepts[i + 1][0] - accepts[i][0] for i in range(len(accepts) - 1)}
    assert gaps <= {period}, ('cadence', sorted(gaps)[:5])
    assert sensor == 2 and mode == 1, end
    return len(levels)


random.seed(20261018)
checks = []
SYS = 64000
exe = build('main', SYS, 200)
cases = [
    ('new-5003', new_tap(5003)),
    ('new-exact-sector', new_tap((512 * 3 - 40) * 8)),
    ('old-1300', old_tap(1300)),
    ('new-wp10', new_tap(4000, wp=0x10, pos=1234)),
    ('new-empty', new_tap(0)),
    ('old-empty', old_tap(0)),
]
for tag, image in cases:
    n = check_play(run(exe, tag, image), image, SYS)
    checks.append((tag, n))
    print('PASS', tag, n, flush=True)

rejects = [
    ('rej-rate', new_tap(800, rate=44100)),
    ('rej-176k', new_tap(800, rate=176400)),
    ('rej-format0', new_tap(800, fmt=0)),
    ('rej-wp-unknown', new_tap(800, wp=0x01)),
    ('rej-long', new_tap(800, extra=1)),
    ('rej-short', new_tap(800)[:-1]),
    ('rej-old-rate', old_tap(100, rate=0)),
    ('rej-tiny', b'TAP'),
]
for tag, image in rejects:
    assert expected_samples(image) is None, tag
    rows = run(exe, tag, image)
    load = [r for r in rows if r[0] == 'L'][0]
    end = [r for r in rows if r[0] == 'E'][-1]
    assert load[3] == '1' and load[2] == '0', load
    assert not [r for r in rows if r[0] == 'A'], 'rejected image produced samples'
    assert [r[2:] for r in rows if r[0] == 'M'] == [['0', '0']], 'rejected image must stay ejected'
    assert end[2] == '0' and end[3] == '0', ('rejected media must remain ejected', end)
    checks.append((tag, 0))
    print('PASS', tag, flush=True)

image = new_tap(9000)
n = check_play(run(exe, 'remount', image, mode='remount', remount=3000), image, SYS, remount=3000)
checks.append(('remount-rewind', n))
print('PASS remount-rewind', n, flush=True)

slow = build('slow', SYS, 20000)
image = old_tap(2600)
n = check_play(run(slow, 'slow-sd', image), image, SYS)
checks.append(('slow-sd-20000', n))
print('PASS slow-sd', n, flush=True)

real = build('sys32m', 32000000, 2000)
image = new_tap(700)
n = check_play(run(real, 'sys32m', image), image, 32000000)
checks.append(('sys32m', n))
print('PASS sys32m', n, flush=True)

# Matched mutant: LSB-first bit order must be caught by the level oracle.
source = (folder / FILES[0]).read_text()
old = "byte_reg[3'd7 - cur_bit[2:0]]"
assert source.count(old) == 1
mutant = folder / 'mutant' / 'x1_tap_sd_stream.sv'
mutant.parent.mkdir()
mutant.write_text(source.replace(old, 'byte_reg[cur_bit[2:0]]'))
mexe = build('mutant', SYS, 200, source=mutant)
image = new_tap(2000)
try:
    check_play(run(mexe, 'mutant', image), image, SYS)
except AssertionError as error:
    assert 'sample levels differ' in str(error), error
    print('PASS mutant rejected:', error, flush=True)
    checks.append(('mutant-lsb-first', 'rejected'))
else:
    sys.exit('FAIL bit-order mutant was accepted')

(folder / 'summary.json').write_text(json.dumps(checks, indent=2) + '\n')
print('PASS tap sd stream:', len(checks), 'checks', flush=True)
