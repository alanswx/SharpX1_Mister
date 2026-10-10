"""Freeze actual-CPU Kanji pixel collector and source-derived RTC combination."""
import hashlib
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'scripts'))
from build_mr16_rtc_firmware import build

def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    runner = pathlib.Path(sys.argv[1]).resolve()
    folder = pathlib.Path(tempfile.mkdtemp(prefix='kanji-pixels-', dir=runner.parent))
    inputs = [pathlib.Path(__file__).resolve(), ROOT/'verilator/tests/test_machine_kanji_render.py',
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
    for i, p in enumerate(inputs):shutil.copy2(p, folder/f'input-{i}-{p.name}')
    frozen = folder/'runner'; shutil.copy2(runner, frozen)
    for name in ('test_machine_kanji_render.py', 'z80_fixture.py'):
        shutil.copy2(ROOT/'verilator/tests'/name, folder/name)
    controller = folder/'controller.bin'; controller.write_bytes(build(receive_only=True)[0])
    manifest = {'inputs': hashes, 'controller_sha256': digest(controller),
                'scope': 'synthetic original-CPU Kanji pixels with RTC controller running; no native game/ASIC/battery/hardware acceptance'}
    (folder/'manifest-before.json').write_text(json.dumps(manifest, indent=2)+'\n')
    result = subprocess.run([sys.executable, str(folder/'test_machine_kanji_render.py'),
        str(frozen), '--rtc-controller', str(controller), '--output', str(folder/'pixels')],
        capture_output=True, text=True, cwd=ROOT/'verilator')
    (folder/'pixels.log').write_text(result.stdout+result.stderr)
    print(result.stdout, end='', flush=True)
    assert result.returncode == 0, (folder, result.stderr)
    assert result.stdout.count('PASS actual CPU Kanji RGB:') == 10
    assert hashes == {str(p): digest(p) for p in inputs}
    for i, p in enumerate(inputs):assert digest(folder/f'input-{i}-{p.name}') == hashes[str(p)]
    for name in ('test_machine_kanji_render.py', 'z80_fixture.py'):
        assert digest(folder/name) == hashes[str(ROOT/'verilator/tests'/name)]
    assert digest(frozen) == hashes[str(runner)] and digest(controller) == manifest['controller_sha256']
    (folder/'manifest-after.json').write_text(json.dumps(manifest, indent=2)+'\n')
    print(f'PASS: immutable combined RTC/Kanji pixel evidence {folder}', flush=True)

if __name__ == '__main__':
    main()
