"""Generated consumer-only bypass must fail the unchanged live measurement oracle."""
import hashlib
import pathlib
import subprocess
import sys
import tempfile

root = pathlib.Path(__file__).resolve().parents[2]
output = pathlib.Path(sys.argv[1]).resolve()
output.mkdir(parents=True, exist_ok=True)
folder = pathlib.Path(tempfile.mkdtemp(prefix='consumer-bypass-', dir=output))
original = root / 'sys/hps_io.sv'
fixture = root / 'verilator/tests/hps_hdmi_measure_tb.sv'
original_hash = hashlib.sha256(original.read_bytes()).hexdigest()
fixture_hash = hashlib.sha256(fixture.read_bytes()).hexdigest()
source = original.read_text()
needle = 'old_vs <= measured_hdmi_vs;'
assert source.count(needle) == 1, 'review changed measurement consumer before generating negative'
# Only the actual edge-detector consumer is changed in a disposable copy.
# Keep the dedicated synchronizer and its exposed output intact. No force,
# no native image, no edits to production RTL or weakening of the oracle.
mutated = folder / 'hps_io_consumer_bypass.sv'
mutated.write_text(source.replace(needle, 'old_vs <= vs_hdmi;'))
frozen_fixture = folder / fixture.name
frozen_fixture.write_bytes(fixture.read_bytes())
command = ['verilator', '--binary', '--timing', '--assert', '--top-module',
           'hps_hdmi_measure_tb', '--Mdir', str(folder / 'build'), '-j', '4',
           str(mutated), str(root / 'rtl/x1_cdc_snapshot.sv'), str(frozen_fixture), '-Wno-fatal']
build = subprocess.run(command, capture_output=True, text=True, timeout=120)
(folder / 'build.log').write_text(build.stdout + build.stderr)
assert build.returncode == 0, 'consumer negative must compile; inspect retained build log'
run = subprocess.run([str(folder / 'build/Vhps_hdmi_measure_tb')],
                     capture_output=True, text=True, timeout=30)
(folder / 'run.log').write_text(run.stdout + run.stderr)
assert run.returncode != 0 and 'HDMI measurement consumer bypassed stage two or changed period' \
    in run.stdout + run.stderr, 'consumer bypass did not fail the exact update-edge oracle'
assert hashlib.sha256(original.read_bytes()).hexdigest() == original_hash
assert hashlib.sha256(fixture.read_bytes()).hexdigest() == fixture_hash
print('PASS actual consumer-only HDMI bypass rejected at exact update-edge assertion; production source/fixture unchanged')
print('Evidence:', folder)
