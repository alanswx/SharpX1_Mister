#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Original generated-asset checks, not a native software loading qualification.

Explicit --build-only freezes sources/builds only; --run additionally executes
synthetic IPL/controller/waveforms. Never reads private software. No Make edits.
Evidence and failed logs are retained. No automatic retries.
"""
import argparse
import csv
import hashlib
import importlib.util
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


def generated_ipl(Program, play, columns=None):
    """Original CPU PPI/CRTC/text/palette/mailbox writes, no host replies.

    Optional video uses the existing base-clock register contract, with a new
    four-character/color/reverse address pattern. No private ANK or RAM upload.
    All code executes inside the base IPL aperture; no debug RAM bootstrap.
    """
    p = Program()
    p.emit(0xF3)
    p.word(0x31, 0xFFFF)
    p.word(0x01, 0x1A03)
    p.emit(0x3E, 0x82, 0xED, 0x79)  # PB input
    p.word(0x01, 0x1A01)
    p.emit(0xED, 0x78)             # IN clears actual DAM
    if columns is not None:
        assert columns in (40, 80)

        def out(port, value):
            p.word(0x01, port)
            p.emit(0x3E, value, 0xED, 0x79)

        out(0x1A02, 0x40 if columns == 40 else 0)
        p.word(0x01, 0x1A01)
        p.emit(0xED, 0x78)         # clear any control-write DAM transition
        # Original physical-plane readback sentinels. Real CPU OUTs only;
        # palette black below keeps them out of the text pixel oracle.
        for bank, first in ((0x4000, 0x31), (0x8000, 0x57), (0xC000, 0xA4)):
            for i, address in enumerate((0, 7, 8, 0x1FFF, 0x2000, 0x3FFF)):
                out(bank + address, (first + 13 * i) & 255)
        for attribute, base in ((True, 0x2000), (False, 0x3000)):
            label = 'attributes' if attribute else 'characters'
            p.word(0x01, base)
            p.word(0x11, 2048)
            p.label(label)
            p.emit(0x79, 0xE6, 15 if attribute else 3) # LD A,C; AND mask
            if not attribute:
                p.emit(0xC6, 0x41) # ADD A,'A': four original diagnostic glyphs
            p.emit(0xED, 0x79, 0x03, 0x1B, 0x7A, 0xB3)
            p.jump(0xC2, label)
        # Mask EVERY graphics color to black, independently of uninitialized
        # GRAM. Text attributes supply the known foreground/reverse colors.
        for port in (0x1000, 0x1100, 0x1200, 0x1300):
            out(port, 0)
        registers = (55 if columns == 40 else 111, columns,
                     46 if columns == 40 else 92, 0x28, 31, 2, 25, 28,
                     0, 7, 0, 0, 0, 0, 0, 0)
        for register, value in enumerate(registers):
            out(0x1800, register)
            out(0x1801, value)
        for offset, value in enumerate(b'CVID'):
            p.store(0xF000 + offset, value)
    if play:
        for idx, value in enumerate((0xE9, 2)):
            p.word(0x01, 0x1A01)
            p.label(f'send-{idx}')
            p.emit(0xED, 0x78, 0xE6, 0x40)
            p.jump(0xC2, f'send-{idx}')
            p.word(0x01, 0x1900)
            p.emit(0x3E, value, 0xED, 0x79)
    p.store(0xF010, 0x5A)
    p.emit(0x76)
    data = p.finish()
    assert len(data) <= 4096
    return data + bytes(4096 - len(data))


def check_video(folder, result, columns, font, font_hash):
    """Independent full-raster formula from written cells + captured ANK.

    Does not read renderer state or infer pixels from the observed frame. FNV
    uses the public FrameCapture contract (packed RGB24, not PPM byte hashing).
    """
    width, height = columns * 8, 200
    assert result['sys_hz'] == 32000000 and result['video_hz'] == 28571428
    assert not result['turbo'] and not result['rtc'] and not result['dma']
    assert result['cpu_halt_n'] == 0 and result['frames'] >= 3
    assert (result['width'], result['height']) == (width, height)
    # 56*8*4 or 112*8*2 master edges/line; 32*8+2 lines/frame.
    for field, edges in (('hs_period_ps', 1792), ('vs_period_ps', 1792 * 258)):
        expected = (edges * 10**12 + 28571428 // 2) // 28571428
        assert abs(result[field] - expected) <= 31251, (field, result[field], expected)
    ram = (folder / 'ram.bin').read_bytes()
    assert len(ram) == 65536 and ram[0xF000:0xF004] == b'CVID'
    assert (folder / 'text.bin').read_bytes() == bytes(0x41 + (i & 3) for i in range(2048))
    assert (folder / 'attr.bin').read_bytes() == bytes(i & 15 for i in range(2048))
    for plane, first in (('b', 0x31), ('r', 0x57), ('g', 0xA4)):
        gram = (folder / f'gram-{plane}.bin').read_bytes()
        assert len(gram) == 16384, 'CASSETTE_GRAM_DUMP_WIDTH'
        for i, address in enumerate((0, 7, 8, 0x1FFF, 0x2000, 0x3FFF)):
            assert gram[address] == (first + 13 * i) % 256, 'CASSETTE_CPU_GRAM_DUMP'
        # Only size is qualified here; this IPL does not program PCG glyphs.
        assert len((folder / f'pcg-{plane}.bin').read_bytes()) == 2048, 'CASSETTE_PCG_DUMP_WIDTH'
    expected_pixels = bytearray()
    fnv, colors = 14695981039346656037, set()
    for y in range(height):
        for x in range(width):
            cell = ((y // 8) * columns + x // 8) & 0x7FF
            character, attr = 0x41 + (cell & 3), cell & 15
            dot = font[character * 8 + y % 8] & (0x80 >> (x % 8))
            color = ((attr & 7) if dot else 0) ^ (7 if attr & 8 else 0)
            colors.add(color)
            rgb = bytes((255 if color & 2 else 0, 255 if color & 4 else 0, 255 if color & 1 else 0))
            expected_pixels.extend(rgb)
            fnv = ((fnv ^ int.from_bytes(rgb, 'big')) * 1099511628211) & ((1 << 64) - 1)
    header, dimensions, maximum, pixels = (folder / 'frame.ppm').read_bytes().split(b'\n', 3)
    assert (header, maximum, dimensions.split()) == (b'P6', b'255', [str(width).encode(), b'200'])
    assert colors == set(range(8)), 'raster oracle must exercise every base color'
    assert pixels == expected_pixels, 'CASSETTE_RUNNER_VIDEO_PIXELS: entire rendered raster differs'
    assert result['frame_fnv64'] == fnv, 'CASSETTE_RUNNER_VIDEO_FNV: report/frame mismatch'
    proof = {'scope': 'original CPU-written base raster, not native tape software',
             'columns': columns, 'pixels': width * height, 'ank_source_sha256': font_hash,
             'expected_rgb_sha256': hashlib.sha256(expected_pixels).hexdigest(),
             'expected_fnv64': fnv, 'ppm_sha256': sha(folder / 'frame.ppm')}
    (folder / 'video-oracle.json').write_text(json.dumps(proof, indent=2) + '\n')


def read_events(folder):
    with (folder / 'events.csv').open() as f:
        return list(csv.DictReader(f))


def check_ps2_stream(folder, result, bits, ctrl_c):
    """Real PS/2 script outcome against accepted public waveform ledger.

    F12 is necessary: inherited JOY_EN otherwise consumes C before ASCII.
    The CPU HALTs after PLAY: there is NO later E9 STOP or host deck override.
    STOP is experimental normalized BREAK, not native read-cleared CMT STOP.
    """
    assert result['ps2_bytes_sent'] == (9 if ctrl_c else 6) and result['ps2_pending'] == 0
    assert result['cpu_halt_n'] == 0
    assert not result['underflow'] and not result['producer_exhausted'] and not result['playback_eof']
    assert result['sensor'] == 3 and result['mode'] == (1 if ctrl_c else 2)
    events = read_events(folder)
    records = [row for row in events if row['event'] == 'accept']
    count = len(records)
    assert 100 < count < len(bits), 'nonvacuous PLAY required before stopped/continuing result'
    assert result['accepted_samples'] == result['accepted_sample_cursor'] == count
    assert [int(row['cursor']) for row in records] == list(range(count))
    assert [int(row['level']) for row in records] == bits[:count]
    assert all(row['last'] == '0' for row in records), 'test must stop before the physical final sample'
    times = [int(row['time_ps']) for row in records]
    assert times[0] < 100 * 10**9, 'IPL must launch before the first physical key'
    assert all(b - a == 125000000 for a, b in zip(times, times[1:]))
    states = [row for row in events if row['event'] == 'state']
    plays = [row for row in states if row['mode'] == '2']
    assert len(plays) == 1
    play_time = int(plays[0]['time_ps'])
    assert times[0] == play_time + 31250, 'first sample arrives on the next SYS edge, not key pacing'
    stops = [row for row in states if row['mode'] == '1' and int(row['time_ps']) > play_time]
    if ctrl_c:
        assert len(stops) == 1, 'one actual BREAK stop required'
        stop_time = int(stops[0]['time_ps'])
        assert 123 * 10**9 <= stop_time < 135 * 10**9, 'stop must follow C make, before release script'
        assert times[-1] < stop_time < result['time_ps'] - 50 * 10**9
        assert all(int(row['time_ps']) < stop_time for row in records), 'no sample consumption while stopped'
    else:
        assert not stops, 'CASSETTE_RUNNER_PLAIN_C_FALSE_STOP'
        stop_time = None
        assert 200 * 10**9 < times[-1] <= result['time_ps'], 'plain C must keep the physical stream running'
    expected_wave, level = [], 0
    for when, sample in zip(times, bits):
        if sample != level:
            expected_wave.append((when, sample))
            level = sample
    if ctrl_c and level:
        expected_wave.append((stop_time, 0))
    actual_wave = [(int(row['time_ps']), int(row['level'])) for row in events if row['event'] == 'waveform']
    assert actual_wave == expected_wave, 'CASSETTE_RUNNER_PS2_WAVEFORM: accepted source/stop ledger mismatch'
    proof = {'scope': 'public PS2/mode/waveform; PB0/native pin and keyboard release state not exposed here',
             'ctrl_c': ctrl_c, 'packets_transmitted': result['ps2_bytes_sent'],
             'accepted_samples': count, 'stop_time_ps': stop_time,
             'source_sample_count': len(bits), 'script_finished': result['ps2_pending'] == 0}
    (folder / 'ps2-oracle.json').write_text(json.dumps(proof, indent=2) + '\n')


def check_warm_stream(folder, result, bits, resets_ms, control=None):
    """Public cursor + integer active-edge slot oracle, no private phase read.

    Integer-ms reset edges are SYS32 falling edges. STOP begins at the next
    consuming SYS rise; reset-release and reboot do not reload/rewind media.
    This does NOT qualify a reset tied to a rising-edge acceptance. Reset CSV
    'level' is currently the reset flag; waveform has separate public events.
    """
    sys_ps, slot_edges = 31250, 4000
    assert result['uploads_accepted'] == 12288, 'warm reset must not reupload IPL/controller'
    assert result['warm_reset_assertions'] == result['warm_reset_releases'] == len(resets_ms)
    assert result['warm_reset_edges_pending'] == 0
    assert result['warm_reset_width_us'] == (100 if resets_ms else 10)
    assert result['cpu_halt_n'] == 0 and result['ps2_bytes_sent'] == result['ps2_pending'] == 0
    assert result['accepted_samples'] == result['accepted_sample_cursor'] == len(bits)
    assert result['producer_exhausted'] and result['playback_eof'] and not result['underflow']
    assert (result['mode'], result['sensor']) == (1, 2)
    events = read_events(folder)
    records = [row for row in events if row['event'] == 'accept']
    assert [int(row['cursor']) for row in records] == list(range(len(bits))), 'warm reset rewound/skipped accepted samples'
    assert [int(row['level']) for row in records] == bits
    assert [int(row['last']) for row in records] == [0] * (len(bits) - 1) + [1]
    times = [int(row['time_ps']) for row in records]
    asserts = [row for row in events if row['event'] == 'reset_assert']
    releases = [row for row in events if row['event'] == 'reset_release']
    assert [int(row['time_ps']) for row in asserts] == [ms * 10**9 for ms in resets_ms]
    assert [int(row['time_ps']) for row in releases] == [ms * 10**9 + 100 * 10**6 for ms in resets_ms]
    for begin, end in zip(asserts, releases):
        at, until = int(begin['time_ps']), int(end['time_ps'])
        assert begin['cursor'] == end['cursor'], 'cursor changed inside asserted reset'
        assert begin['sensor'] == end['sensor'] == '3', 'reset must retain non-ended medium'
        assert 0 < int(begin['cursor']) < len(bits), 'reset must interrupt an actual stream'
        assert not any(at <= when < until for when in times), 'producer advanced while reset held'
        assert int(begin['cursor']) == sum(when < at for when in times)
    states = [row for row in events if row['event'] == 'state']
    eof = [int(row['time_ps']) for row in states if row['sensor'] == '2']
    assert len(eof) == 1
    plays = [int(row['time_ps']) for row in states if row['mode'] == '2']
    assert len(plays) == len(resets_ms) + 1, 'missing/extra actual PLAY transition'
    stops = [int(row['time_ps']) for row in states
             if row['mode'] == '1' and plays[0] < int(row['time_ps']) < eof[0]]
    assert len(plays) == len(resets_ms) + 1 and len(stops) == len(resets_ms)
    assert stops == [ms * 10**9 + sys_ps // 2 for ms in resets_ms], 'reset STOP must take effect on next SYS rise'
    assert times[0] == plays[0] + sys_ps
    segments = list(zip(plays, stops + [eof[0]]))

    def active_edges(start, finish):
        count = 0
        for play, stop in segments:
            # PLAY command edge is excluded. Reset STOP edge is excluded;
            # the final EOF edge DOES consume the end of the last slot.
            low, high = max(start, play), min(finish, stop if stop == eof[0] else stop - sys_ps)
            if high > low:
                assert (high - low) % sys_ps == 0
                count += (high - low) // sys_ps
        return count

    for start, finish in zip(times, times[1:] + eof):
        assert active_edges(start, finish) == slot_edges, 'CASSETTE_RUNNER_WARM_SLOT_PHASE: reset/service rephased a physical slot'
    resume_witnesses = []
    for stop, play in zip(stops, plays[1:]):
        before = [when for when in times if when < stop]
        after = [when for when in times if when > play]
        assert before and after, 'reset must pause an issued sample before a subsequent arrival'
        last_accept, next_accept = before[-1], after[0]
        retained_ps = stop - last_accept - sys_ps
        assert 0 < retained_ps < slot_edges * sys_ps, 'reset must retain a nonzero partial slot'
        expected_next = play + slot_edges * sys_ps - retained_ps
        assert next_accept == expected_next, 'CASSETTE_RUNNER_WARM_SLOT_PHASE: next arrival discarded retained phase'
        resume_witnesses.append({'last_accept_ps': last_accept, 'stop_ps': stop,
                                 'play_ps': play, 'retained_phase_ps': retained_ps,
                                 'expected_next_accept_ps': expected_next,
                                 'actual_next_accept_ps': next_accept})
    # Held sample survives STOP and appears immediately at resumed PLAY, before
    # the next arrival. Independently predict every public waveform transition.
    held, mode, wave = 0, 0, 0
    expected_wave = []
    for row in events:
        if row['event'] == 'accept':
            held = bits[int(row['cursor'])]
        elif row['event'] == 'state':
            mode = int(row['mode'])
        else:
            continue
        expected = held if mode == 2 else 0
        if expected != wave:
            expected_wave.append((int(row['time_ps']), expected))
            wave = expected
    actual_wave = [(int(row['time_ps']), int(row['level'])) for row in events if row['event'] == 'waveform']
    assert actual_wave == expected_wave, 'CASSETTE_RUNNER_WARM_HELD_WAVEFORM'
    pause_ps = sum(resume - stop + sys_ps for resume, stop in zip(plays[1:], stops))
    proof = {'scope': 'public falling-edge reset/retained IPL/media; no rising-edge tie/native qualification',
             'accepted_samples': len(bits), 'first_accept_ps': times[0], 'eof_ps': eof[0],
             'resets_ms': resets_ms, 'inactive_plus_command_edges_ps': pause_ps,
             'resume_phase_witnesses': resume_witnesses,
             'checked_slot_edges': slot_edges, 'uploads_accepted': result['uploads_accepted']}
    if control is not None:
        assert times[0] == control['first_accept_ps']
        assert eof[0] - control['eof_ps'] == pause_ps, 'warm duration must differ ONLY by measured inactive/command edges'
        proof['control_eof_ps'] = control['eof_ps']
    (folder / 'warm-oracle.json').write_text(json.dumps(proof, indent=2) + '\n')
    return proof


def tap(bits, start=0, rate=8000, flag=1):
    header = bytearray(40)
    header[:4] = b'TAPE'
    header[27] = flag
    for at, n in ((28, rate), (32, len(bits)), (36, start)):
        header[at:at+4] = n.to_bytes(4, 'little')
    payload = bytearray((len(bits)+7)//8)
    for i, bit in enumerate(bits):
        if bit:
            payload[i//8] |= 0x80 >> (i%8)
    return bytes(header+payload)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    actions = parser.add_mutually_exclusive_group(required=True)
    actions.add_argument('--build-only', action='store_true')
    actions.add_argument('--run', action='store_true')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--jobs', type=int, default=2)
    parser.add_argument('--wall-seconds', type=float, default=600)
    args = parser.parse_args()
    if args.jobs < 1 or args.wall_seconds <= 0:
        parser.error('positive jobs/wall-seconds required')
    root = Path(__file__).resolve().parents[2]
    out = args.output.resolve() if args.output else Path(tempfile.mkdtemp(prefix='x1-cassette-runner-')).resolve()
    if args.output:
        allowed = (Path(tempfile.gettempdir()).resolve(), (root/'output_files').resolve())
        if not any(out != base and out.is_relative_to(base) for base in allowed):
            parser.error('output must be new tmp/ignored-output subdirectory')
        out.mkdir(parents=True, exist_ok=False)
    print(f'EVIDENCE={out}', flush=True)
    order = re.findall(r'^set_global_assignment -name (?:SYSTEMVERILOG_FILE|VERILOG_FILE) (\S+)\s*$',
                       (root/'rtl/machine.qip').read_text(), re.M)
    if not order or len(order) != len(set(order)):
        raise RuntimeError('machine manifest missing/duplicate sources')
    inputs = list(dict.fromkeys(order + [
        'rtl/machine.qip', 'verilator/sim_cassette.v', 'verilator/cassette_main.cpp',
        'verilator/frame_capture.h', 'verilator/x1_tap_image.h',
        'rtl/legacy/x1_cg8.v',  # checked-in ANK captured BEFORE compile/import/run
        'verilator/tests/test_cassette_runner.py', 'verilator/tests/z80_fixture.py',
        'scripts/build_mr16_cassette_firmware.py', 'scripts/assemble_mr16.py',
    ] + [str(p.relative_to(root)) for p in sorted((root/'bios/reference/fw_subcpu').rglob('*'))
         if p.is_file() and p.suffix.lower() in ('.asm', '.inc', '.bin')]))
    hashes = {rel: sha(root/rel) for rel in inputs}
    frozen = out/'sources'
    for rel in inputs:
        dest = frozen/rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes((root/rel).read_bytes())
        if sha(dest) != hashes[rel]:
            raise RuntimeError(f'input changed during freeze: {rel}')
    def verify():
        for rel, digest in hashes.items():
            if sha(root/rel) != digest or sha(frozen/rel) != digest:
                raise RuntimeError(f'source mutation: {rel}')
    def manifest(name):
        (out/name).write_text(''.join(f'{hashes[rel]}  {rel}\n' for rel in inputs))
    manifest('source.before.sha256')
    terminal = {'phase': 'failed', 'scope': 'generated-assets-only', 'checks': 0,
                'planned_checks': 25}
    try:
        command = ['verilator', '--cc', '--exe', '--build', '--timing',
                   '--top-module', 'cassette_top', '--Mdir', str(out/'obj'),
                   '-j', str(args.jobs), '-CFLAGS', '-std=c++20 -O2',
                   '-MAKEFLAGS', '-B', '-Wno-fatal', 'verilator/sim_cassette.v',
                   *order, str(frozen/'verilator/cassette_main.cpp'), '-o', 'cassette_runner']
        (out/'build-command.json').write_text(json.dumps(command, indent=2)+'\n')
        with (out/'build.log').open('w') as log:
            result = subprocess.run(command, cwd=frozen, stdout=log, stderr=subprocess.STDOUT,
                                    timeout=args.wall_seconds, check=False)
        if result.returncode:
            raise RuntimeError(f'build exit {result.returncode}; see build.log')
        warnings = [line for line in (out/'build.log').read_text().splitlines()
                    if 'warning' in line.lower()]
        (out/'warnings.json').write_text(json.dumps(warnings, indent=2)+'\n')
        terminal['warning_lines'] = len(warnings)
        verify()
        exe = out/'obj/cassette_runner'
        executable_hash = sha(exe)
        terminal['executable_sha256'] = executable_hash
        if args.run:
            sys.path.insert(0, str(frozen/'scripts'))
            load(frozen/'scripts/assemble_mr16.py', 'assemble_mr16')
            builder = load(frozen/'scripts/build_mr16_cassette_firmware.py', 'cassette_runner_builder')
            emitter = load(frozen/'verilator/tests/z80_fixture.py', 'cassette_runner_emitter')
            controller, _, report = builder.build(receive_only=True, with_report=True)
            assets = out/'generated'
            assets.mkdir()
            (assets/'controller.bin').write_bytes(controller)
            (assets/'controller-source-report.json').write_text(json.dumps(report, indent=2)+'\n')
            (assets/'play.bin').write_bytes(generated_ipl(emitter.Program, True))
            (assets/'stop.bin').write_bytes(generated_ipl(emitter.Program, False))
            (assets/'play8.bin').write_bytes((assets/'play.bin').read_bytes()+bytes([0xA5])*4096)
            for columns in (40, 80):
                (assets/f'video-{columns}.bin').write_bytes(generated_ipl(emitter.Program, False, columns))
            (assets/'video-play.bin').write_bytes(generated_ipl(emitter.Program, True, 40))
            # Parse only the captured source used by this build, not a live ANK
            # file after execution. No other fixture module imports are added.
            ank = frozen/'rtl/legacy/x1_cg8.v'
            font = {int(address, 16): int(value, 2) for address, value in re.findall(
                r"11'h([0-9A-Fa-f]+):cg8_rom = 8'b([01]{8})", ank.read_text())}
            assert len(font) == 2048 and set(font) == set(range(2048)), 'captured ANK table incomplete/duplicate'
            assert sha(ank) == hashes['rtl/legacy/x1_cg8.v']
            # Actual PS/2 F12 make/release turns inherited JOY_EN off. Then
            # Ctrl+C has SIX packets, plus the THREE F12 packets = NINE total.
            key_sequences = {
                'ctrl-c': ((100, 0x07), (103, 0xF0), (106, 0x07),
                           (120, 0x14), (123, 0x21), (135, 0xF0),
                           (138, 0x21), (141, 0xF0), (144, 0x14)),
                'plain-c': ((100, 0x07), (103, 0xF0), (106, 0x07),
                            (120, 0x21), (135, 0xF0), (138, 0x21)),
            }
            for name, rows in key_sequences.items():
                (assets/f'{name}.keys').write_text(''.join(f'{ms} {byte:02x}\n' for ms, byte in rows))
            bits = [0, 1, 1, 0, 1, 0, 0, 1, 0, 1, 1, 0, 1]
            (assets/'tape.tap').write_bytes(tap(bits, start=3))
            original_assets = {str(p): sha(p) for p in assets.iterdir() if p.is_file()}
            def invoke(name, ipl='play.bin', data=None, extra=(), ok=True, cycles=3000000, rejection=None):
                tape_path = assets/'tape.tap'
                if data is not None:
                    tape_path = assets/(name+'.tap')
                    tape_path.write_bytes(data)
                    original_assets[str(tape_path)] = sha(tape_path)
                destination = out/name
                cmd = [str(exe), '--ipl', str(assets/ipl), '--controller', str(assets/'controller.bin'),
                       '--tape', str(tape_path), '--cycles', str(cycles), '--output', str(destination),
                       '--marker-address', '0xf010', *extra]
                (out/(name+'.command.json')).write_text(json.dumps(cmd, indent=2)+'\n')
                with (out/(name+'.log')).open('w') as log:
                    r = subprocess.run(cmd, cwd=frozen, stdout=log, stderr=subprocess.STDOUT,
                                       timeout=args.wall_seconds, check=False)
                if ok:
                    if r.returncode:
                        raise AssertionError(f'{name} exit {r.returncode}')
                    result = json.loads((destination/'report.json').read_text())
                    assert result['inputs_unchanged'] and result['terminal_exit'] == 0
                    assert result['intra_assignment_delays'] is True, 'standard collector requires delay-aware VM_TIMING'
                    assert result['executable_sha256'] == executable_hash
                    assert result['controller_sha256'] == sha(assets/'controller.bin')
                    assert result['ipl_sha256'] == sha(assets/ipl)
                    assert result['tape_sha256'] == sha(tape_path)
                    assert result['time_ps'] == cycles*31250
                    assert result['marker_value'] == 0x5A
                    terminal['checks'] += 1
                    return result
                assert rejection is not None, 'negative requires an exact diagnostic'
                assert r.returncode == 1 and not destination.exists(), name
                assert rejection in (out/(name+'.log')).read_text(), name
                terminal['checks'] += 1
            for name, data, rejection in (
                ('truncated', b'TAPE', 'truncated new header'),
                ('bad-rate', tap(bits, rate=44100), 'only 8000 Hz supported'),
                ('format-zero', tap(bits, flag=0), 'format-zero waveform semantics unresolved'),
                ('unknown-format', tap(bits, flag=2), 'unknown encoding flags'),
                ('bad-position', tap(bits, start=14), 'position exceeds sample count'),
                ('bad-count', tap(bits)[:-1], 'declared bit count does not match payload length')):
                invoke(name, data=data, ok=False, rejection=rejection)
            invoke('short-duration', ok=False, cycles=12352,
                   rejection='cycles must exceed 12352 startup cycles')
            invoke('snapshot-refused', ok=False, extra=('--restore', 'unused'),
                   rejection='unsupported option: --restore')
            for name, rom in (('play4', 'play.bin'), ('play8', 'play8.bin')):
                r = invoke(name, ipl=rom)
                assert r['uploads_accepted'] == 12288 and r['ipl_mapped_bytes'] == 4096
                assert r['accepted_samples'] == 10 and r['accepted_sample_cursor'] == 13
                assert r['playback_eof'] and not r['underflow'] and r['mode'] == 1
                with (out/name/'events.csv').open() as f:
                    events = list(csv.DictReader(f))
                records = [row for row in events if row['event'] == 'accept']
                assert [int(row['cursor']) for row in records] == list(range(3, 13))
                assert [int(row['level']) for row in records] == bits[3:]
                assert [int(row['last']) for row in records] == [0]*9+[1]
                times = [int(row['time_ps']) for row in records]
                assert all(b-a == 125000000 for a, b in zip(times, times[1:]))
                eof = [int(row['time_ps']) for row in events
                       if row['event'] == 'state' and row['sensor'] == '2']
                assert eof == [times[-1]+125000000], 'final sample must receive its full physical slot'
                expected_wave, level = [], 0
                for when, sample in zip(times, bits[3:]):
                    if sample != level:
                        expected_wave.append((when, sample))
                        level = sample
                if level:
                    expected_wave.append((eof[0], 0))
                wave = [(int(row['time_ps']), int(row['level'])) for row in events
                        if row['event'] == 'waveform']
                assert wave == expected_wave, 'public waveform transitions differ from accepted held samples'
            stopped = invoke('stopped', ipl='stop.bin')
            assert stopped['accepted_samples'] == 0 and stopped['accepted_sample_cursor'] == 3
            empty = invoke('empty', data=tap([], start=0))
            assert empty['accepted_samples'] == 0 and empty['playback_eof']
            # Exact original rendered cells at both base widths, public RGB
            # capture plus actual executed text/attribute storage readback.
            for columns in (40, 80):
                name = f'video-{columns}'
                result = invoke(name, ipl=f'{name}.bin', cycles=8000000)
                assert result['accepted_samples'] == 0 and (result['mode'], result['sensor']) == (1, 3)
                check_video(out/name, result, columns, font, hashes['rtl/legacy/x1_cg8.v'])
            # Original half-second waveform; physical keys arrive well before
            # EOF, after CPU video initialization/PLAY. No host STOP commands.
            long_bits = [((i // 5) ^ (i // 37)) & 1 for i in range(4096)]
            for ctrl_c, name in ((True, 'ctrl-c'), (False, 'plain-c')):
                result = invoke(name, ipl='video-play.bin', data=tap(long_bits), cycles=8000000,
                                extra=('--keys', str(assets/f'{name}.keys')))
                check_video(out/name, result, 40, font, hashes['rtl/legacy/x1_cg8.v'])
                check_ps2_stream(out/name, result, long_bits, ctrl_c)
            # Fixed SYS32/MS reset interface: 4ms/8ms interrupt real playback;
            # 128 samples provide 16ms active playback plus paused reboot gaps.
            # Compare with an independently executed no-reset control, not a
            # stretched deadline or invented fixed firmware restart latency.
            warm_bits = [((i // 3) ^ (i // 11)) & 1 for i in range(128)]
            warm_control = invoke('warm-control', data=tap(warm_bits))
            control = check_warm_stream(out/'warm-control', warm_control, warm_bits, [])
            for name, resets in (('warm-single', [4]), ('warm-repeat', [4, 8])):
                options = tuple(value for ms in resets for value in ('--reset-at', str(ms)))
                result = invoke(name, data=tap(warm_bits), extra=options + ('--reset-for-us', '100'))
                check_warm_stream(out/name, result, warm_bits, resets, control)
            for name, extra, rejection in (
                ('reset-orphan-width', ('--reset-for-us', '100'),
                 'reset width requires events and 1..1000000 us'),
                ('reset-zero-width', ('--reset-at', '4', '--reset-for-us', '0'),
                 'reset width requires events and 1..1000000 us'),
                ('reset-overlap', ('--reset-at', '4', '--reset-at', '5', '--reset-for-us', '1500'),
                 'overlapping or touching reset events'),
                ('reset-touch', ('--reset-at', '4', '--reset-at', '5', '--reset-for-us', '1000'),
                 'overlapping or touching reset events'),
                ('reset-startup', ('--reset-at', '0'),
                 'reset must fit strictly after startup and before duration'),
                ('reset-end', ('--reset-at', '30'),
                 'reset must fit strictly after startup and before duration')):
                invoke(name, extra=extra, ok=False, cycles=960000, rejection=rejection)
            for p, digest in original_assets.items():
                assert sha(Path(p)) == digest, f'generated original changed: {p}'
            assert sha(exe) == executable_hash
            assert terminal['checks'] == terminal['planned_checks']
        verify()
        terminal['phase'] = 'synthetic-pass' if args.run else 'build-only'
    finally:
        try:
            verify()
            manifest('source.after.sha256')
            terminal['sources_unchanged'] = True
        except Exception:
            terminal['sources_unchanged'] = False
            terminal['phase'] = 'failed'
            raise
        finally:
            (out/'terminal.json').write_text(json.dumps(terminal, indent=2)+'\n')
            (out/'evidence.sha256').write_text(''.join(
                f'{sha(p)}  {p.relative_to(out)}\n' for p in sorted(out.rglob('*'))
                if p.is_file() and p.name != 'evidence.sha256' and not p.is_relative_to(out/'obj')))
    print(json.dumps(terminal), flush=True)


if __name__ == '__main__':
    main()
