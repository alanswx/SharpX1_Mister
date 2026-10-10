"""Real keyboard arrival after short reset during Z80 RTC/mailbox polling."""
import argparse
import csv
import hashlib
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
from test_rtc_keyboard import CASES, fixture, validate

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from build_mr16_rtc_firmware import build

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def validate_commands(writes):
    before = [d for t, d in writes if t < 15000000000]
    after = [d for t, d in writes if t >= 15010000000]
    assert 0xec in before and 0xec in after, 'two real CPU command boots not observed'
    assert 0xef in before and 0xe6 in before and 0xef in after and 0xe6 in after, 'polling around reset absent'

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('runner', type=pathlib.Path)
    parser.add_argument('--x3', action='store_true')
    args = parser.parse_args()
    runner = args.runner.resolve()
    folder = pathlib.Path(tempfile.mkdtemp(prefix='keyboard-reset-', dir=runner.parent))
    inputs = [pathlib.Path(__file__).resolve(), ROOT/'verilator/tests/test_rtc_keyboard.py',
              ROOT/'verilator/tests/z80_fixture.py', ROOT/'scripts/build_mr16_rtc_firmware.py',
              ROOT/'scripts/assemble_mr16.py', ROOT/'verilator/Makefile', ROOT/'verilator/sim.v',
              ROOT/'verilator/sim_headless.cpp', ROOT/'verilator/frame_capture.h',
              ROOT/'verilator/audio_capture.h', ROOT/'verilator/d88_image.h', ROOT/'rtl/machine.qip',
              ROOT/'verilator/tests/fixtures/rtc_mr16_host_extension.asm',
              ROOT/'verilator/tests/fixtures/rtc_mr16_compact.asm']
    inputs += [ROOT/name for name in re.findall(
        r'^set_global_assignment -name (?:SYSTEMVERILOG_FILE|VERILOG_FILE) (\S+)$',
        (ROOT/'rtl/machine.qip').read_text(), re.M)]
    inputs += sorted((ROOT/'bios/reference/fw_subcpu').glob('*.asm'))
    inputs += sorted((ROOT/'bios/reference/fw_subcpu').glob('*.inc'))
    inputs += [ROOT/'bios/reference/fw_subcpu/verilog/X1SUB.BIN', runner]
    hashes = {str(p): digest(p) for p in inputs}
    for i, p in enumerate(inputs):
        shutil.copy2(p, folder/f'input-{i}-{p.name}')
    frozen = folder/'runner'; shutil.copy2(runner, frozen)
    controller = folder/'controller.bin'; controller.write_bytes(build(receive_only=True)[0])
    assets = [controller]
    # All three keys arrive after the reset. Caps-state retention is not inferred.
    for name, script, expected in CASES[:3]:
        rom = folder/f'{name}.bin'; rom.write_bytes(fixture(expected)); assets.append(rom)
        keys = folder/f'{name}.keys'; keys.write_text(script); assets.append(keys)
    manifest = {'inputs': hashes, 'assets': {str(p): digest(p) for p in assets},
                'x3_requested': args.x3, 'reset_at_ms': 15, 'reset_for_us': 10,
                'scope': 'real PS/2 after in-flight RTC/mailbox short reset; no caps/IRQ/FDC/native/hardware acceptance'}
    (folder/'manifest-before.json').write_text(json.dumps(manifest, indent=2)+'\n')
    for name, _, expected in (*CASES[:3], ('no-reset', '', 0x46)):
        print(f'START: RTC/keyboard short reset {name}', flush=True)
        input_name = 'F' if name == 'no-reset' else name
        reset_args = [] if name == 'no-reset' else ['--reset-at', '15', '--reset-for-us', '10']
        result = subprocess.run([str(frozen), '--rtc-controller', str(controller),
            '--rom', str(folder/f'{input_name}.bin'), '--keys', str(folder/f'{input_name}.keys'),
            '--cycles', '4000000', *reset_args,
            '--dump', str(folder/name), '--bus-trace', str(folder/f'{name}.csv'),
            '--io-only', '--bus-events', '--bus-end-ms', '40'],
            capture_output=True, text=True, cwd=folder)
        (folder/f'{name}.log').write_text(result.stdout+result.stderr)
        assert result.returncode == 0, (folder, result.stderr)
        report = json.loads(result.stdout.splitlines()[-1])
        validate(report, (folder/f'{name}.ram').read_bytes(), expected)
        assert report['rtc_experiment'] and report['intra_assignment_delays']
        assert report['turbo_video_master'] == args.x3
        assert report['sys_hz'] == 32000000 and report['video_hz'] == (42954540 if args.x3 else 28571428)
        assert report['ps2_bytes_sent'] == 1
        assert report['download_bytes'] == 8193+(folder/f'{input_name}.bin').stat().st_size, 'assets reuploaded'
        with (folder/f'{name}.csv').open() as stream:
            writes = [(int(r['time_ps']), int(r['data_out'])) for r in csv.DictReader(stream)
                      if int(r['address']) == 0x1900 and r['iorq_n'] == '0' and r['wr_n'] == '0']
        if name == 'no-reset':
            try:
                validate_commands(writes)
            except AssertionError as error:
                assert str(error) == 'two real CPU command boots not observed', error
            else:
                raise AssertionError('no-reset control falsely passed unchanged reboot oracle')
            print('PASS: no-reset control rejected by unchanged actual-command reboot oracle', flush=True)
        else:
            validate_commands(writes)
            print(f'PASS: RTC/keyboard short reset {name}, actual command boots and retained uploads', flush=True)
    assert hashes == {str(p): digest(p) for p in inputs}
    for i, p in enumerate(inputs):
        assert digest(folder/f'input-{i}-{p.name}') == hashes[str(p)]
    assert digest(frozen) == hashes[str(runner)]
    assert manifest['assets'] == {str(p): digest(p) for p in assets}
    (folder/'manifest-after.json').write_text(json.dumps(manifest, indent=2)+'\n')
    print(f'PASS: immutable RTC/keyboard reset evidence {folder}', flush=True)

if __name__ == '__main__':
    main()
