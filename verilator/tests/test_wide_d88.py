"""Actual CPU wide-address D88 reads/writes; no claim to native 2HD mechanics."""
import argparse
import hashlib
import json
import pathlib
import shutil
import struct
import subprocess
import tempfile
from z80_fixture import Program

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('wide', type=pathlib.Path)
parser.add_argument('ordinary', type=pathlib.Path)
parser.add_argument('--timeout', type=float, default=600)
parser.add_argument('--geometry', action='store_true',
                    help='exercise emulator-derived 77x2x26x256 geometry, not native 2HD timing')
parser.add_argument('--capacity-match', action='store_true',
                    help='exercise CPU selection and RNF for mismatched medium class')
parser.add_argument('--media-type', type=lambda v:int(v,0), choices=(0,0x10,0x20), default=0x20)
args = parser.parse_args()
source = args.wide.resolve()
folder = pathlib.Path(tempfile.mkdtemp(prefix='cpu-wide-', dir=source.parent))
runner = folder / 'Vtop'
ordinary = folder / 'ordinary-Vtop'
shutil.copy2(source, runner)
shutil.copy2(args.ordinary.resolve(), ordinary)

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def media():
    if args.geometry:
        image = bytearray(688)
        image[:8] = b'WIDE HD\0'
        image[27] = args.media_type
        for track in range(154):
            struct.pack_into('<I', image, 32+4*track, len(image))
            for sector in range(1, 27):
                header_at = len(image)
                header = bytearray(16)
                header[:4] = bytes((track//2, track%2, sector, 1))
                struct.pack_into('<H', header, 4, 26)
                struct.pack_into('<H', header, 14, 256)
                if track == 153 and sector == 26:
                    header[7:9] = bytes((0x10, 0xb0))
                image.extend(header)
                payload = bytes((i*37 + track*13 + sector*29) & 255 for i in range(256))
                data_at = len(image)
                image.extend(payload)
        struct.pack_into('<I', image, 28, len(image))
        assert len(image) == 1089776 and header_at > (1 << 20)
        return image, header_at, data_at, payload
    # Both addresses exceed the ordinary 20-bit space. Mark/status bytes
    # straddle SD blocks; the data spans three SD blocks.
    header_at = (1 << 20) + 504
    data_at = header_at + 16
    image = bytearray(data_at + 1024)
    image[:8] = b'WIDE X1\0'
    if args.capacity_match:
        image[27] = args.media_type
    struct.pack_into('<I', image, 28, len(image))
    struct.pack_into('<I', image, 32, header_at)
    image[header_at:header_at+4] = bytes((0, 0, 1, 3))
    struct.pack_into('<H', image, header_at+4, 1)
    image[header_at+7] = 0x10
    image[header_at+8] = 0xb0
    struct.pack_into('<H', image, header_at+14, 1024)
    payload = bytes((i*37 + (i//256)*13 + 29) & 255 for i in range(1024))
    image[data_at:] = payload
    return image, header_at, data_at, payload

def program():
    p = Program()
    count = 256 if args.geometry else 1024
    p.emit(0xf3);p.word(0x31, 0xffff)
    serial = 0

    def label(name):
        nonlocal serial
        serial += 1
        return name + str(serial)

    def out(port, value):
        p.word(0x01, port);p.emit(0x3e, value, 0xed, 0x79)

    def wait(mask, want):
        name = label('wait')
        p.word(0x01, 0xff8);p.label(name)
        p.emit(0xed, 0x78, 0xe6, mask, 0xfe, want)
        p.jump(0xc2, name)

    def status(expected):
        p.word(0x01, 0xff8);p.emit(0xed, 0x78)
        p.word(0x32, 0xf010)
        p.emit(0xe6, 0xfc, 0xfe, expected);p.jump(0xc2, 'fail')

    def transfer(address, write=False):
        out(0xffa, 26 if args.geometry else 1);out(0xff8, 0xa0 if write else 0x80)
        p.word(0x21, address);p.word(0x11, count)
        loop = label('transfer');p.label(loop)
        wait(2, 2)
        p.word(0x01, 0xffb)
        if write:
            p.emit(0x7e, 0xee, 0x5a, 0xed, 0x79)
        else:
            p.emit(0xed, 0x78, 0x77)
        p.emit(0x23, 0x1b, 0x7a, 0xb3);p.jump(0xc2, loop)
        wait(1, 0)

    # Actual IN sees scanner readiness; no fixed delay substitutes for it.
    out(0xffc, 0x80);wait(0x80, 0)
    out(0xff9, 0)
    if args.geometry:
        # A real Type-I SEEK moves the internal head; a track-register write
        # alone would not qualify the last track/head index lookup.
        out(0xffb, 76);out(0xff8, 0x10);wait(1, 0)
        out(0xffc, 0x90)
    if args.capacity_match:
        def select(port):
            p.word(0x01, port);p.emit(0xed,0x78,0xfe,0xff);p.jump(0xc2,'fail')
        high = args.media_type == 0x20
        select(0xfff if high else 0xffe)
        out(0xffa,26 if args.geometry else 1)
        for command in (0x80,0xa0,0xc0):
            out(0xff8,command);wait(1,0);status(0x10)
        select(0xffe if high else 0xfff)
    # Retained IPL covers the entire lower 32 KiB, although its asset is 8 KiB.
    # Writes there reach shadow RAM but CPU reads still see IPL. Use visible
    # upper RAM so the CPU itself reads the previously transferred payload.
    transfer(0x9000);status(0x28)  # Deleted data + CRC from real index metadata.
    transfer(0x9000, write=True);status(0)
    transfer(0x9800);status(0)
    p.word(0x21, 0x9000);p.word(0x11, 0x9800);p.word(0x01, count)
    loop = label('compare');p.label(loop)
    p.emit(0x1a, 0xee, 0x5a, 0xbe);p.jump(0xc2, 'fail')
    p.emit(0x23, 0x13, 0x0b, 0x78, 0xb1);p.jump(0xc2, loop)
    for i, value in enumerate(b'WIDE'):
        p.store(0xf000+i, value)
    p.emit(0x76)
    p.label('fail');p.store(0xf000, 0xee);p.emit(0x76)
    return p.finish().ljust(8192, b'\0')

disk, header_at, data_at, payload = media()
disk_path = folder / 'original.d88'
disk_path.write_bytes(disk)
rom = folder / 'original-generated.ipl'
rom.write_bytes(program())
inputs = {str(p): digest(p) for p in (runner, ordinary, rom, disk_path,
                                      pathlib.Path(__file__), pathlib.Path(__file__).with_name('z80_fixture.py'))}
(folder / 'inputs.json').write_text(json.dumps(inputs, indent=2) + '\n')
output = folder / 'written-copy.d88'
prefix = folder / 'actual'
# The high-address gap requires over 2,050 block scans. The original two-
# second run ended in the real not-ready poll after 1,924 requests, before
# any sector transfer. Allow four seconds for scanning, seek and all I/O;
# retain the exact completion/data/status checks rather than accepting a poll.
command = [str(runner), '--cycles', '128000000', '--rom', str(rom),
           '--disk', str(disk_path), '--disk-output', str(output), '--dump', str(prefix)]
run = subprocess.run(command, capture_output=True, text=True, timeout=args.timeout)
prefix.with_suffix('.stdout').write_text(run.stdout)
prefix.with_suffix('.stderr').write_text(run.stderr)
assert run.returncode == 0, run.stderr
report = json.loads(run.stdout.splitlines()[-1])
assert report['d88_wide_experiment'] and report['d88_address_bits'] == 24
assert report['d88_index_bits'] == 12 and report['d88_sector_limit'] == 4095
assert bool(report.get('hd_media_experiment',False)) == args.capacity_match
assert report['turbo_foundation'] and report['intra_assignment_delays']
assert report['sys_hz'] == 32000000 and report['video_hz'] == 28571428
assert report['halted'] and report['peek'].startswith('57494445'), report
# The data-port observer counts the real SEEK target write as well as payload.
assert report['cpu_fdc_data_reads'] == 2*len(payload), report
assert report['cpu_fdc_data_writes'] == len(payload)+(1 if args.geometry else 0), report
assert report['disk_writes'] > 0 and report['dma_reads'] == report['dma_writes'] == 0
ram = prefix.with_suffix('.ram').read_bytes()
assert ram[0x9000:0x9000+len(payload)] == payload
assert ram[0x9800:0x9800+len(payload)] == bytes(v ^ 0x5a for v in payload)
expected = bytearray(disk)
expected[data_at:] = bytes(v ^ 0x5a for v in payload)
expected[header_at+7] = expected[header_at+8] = 0
assert output.read_bytes() == expected, 'write changed gap/header/adjacent data or missed high-address metadata'

# Ordinary admission must still reject the exact same large selected volume
# before creating any disk copy or RAM output.
negative = folder / 'ordinary-rejected'
run = subprocess.run([str(ordinary), '--cycles', '128', '--disk', str(disk_path),
                      '--disk-output', str(negative)+'.d88', '--dump', str(negative)],
                     capture_output=True, text=True, timeout=30)
reason = 'sector index capacity exceeded' if args.geometry else 'selected volume exceeds 20-bit'
assert run.returncode == 2 and reason in run.stderr, run.stderr
assert not list(folder.glob('ordinary-rejected.*'))
for option in ('--save-state', '--restore-state'):
    sentinel = folder / (option[2:] + '.state')
    sentinel.write_bytes(b'unchanged state sentinel')
    run = subprocess.run([str(runner), '--cycles', '128', option, str(sentinel)],
                         capture_output=True, text=True, timeout=30)
    assert run.returncode == 2 and 'wide D88 experiment is non-savable' in run.stderr
    assert sentinel.read_bytes() == b'unchanged state sentinel'
assert inputs == {path: digest(pathlib.Path(path)) for path in inputs}
print(f'PASS actual CPU wide D88: {2*len(payload)} reads/{len(payload)} writes beyond 1MiB, '
      f'geometry={args.geometry}, capacity-match={args.capacity_match}, requested-type={args.media_type:#x}, '
      'exact payload/mark/CRC, default20/snapshot rejections, unchanged originals')
print('Evidence:', folder)
