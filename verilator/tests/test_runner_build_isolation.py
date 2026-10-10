"""Actual nested-Mdir C++ isolation check; no machine or hardware acceptance."""
import hashlib
import pathlib
import argparse
import re
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
lines = (ROOT / 'Makefile').read_text().splitlines()
recipes = []
command = ''
for line in lines:
    if not line.startswith('\t'):
        command = ''
        continue
    command += line + '\n'
    if line.endswith('\\'):
        continue
    if '$(V_SRC) sim_headless.cpp' in command:
        recipes.append(command)
    command = ''
assert len(recipes) == 31, 'runner recipe coverage changed; review new profiles'
for command in recipes:
    flags = re.findall(r'-MAKEFLAGS "([^"]*)"', command)
    assert len(flags) == 1 and '-B' in flags[0].split(), 'runner must have one preserved make-flags group with -B'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('output', nargs='?', type=pathlib.Path, default=ROOT / 'obj_dir_headless')
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
folder = pathlib.Path(tempfile.mkdtemp(prefix='runner-isolation-', dir=args.output)).resolve()
rtl = folder / 'isolation.sv'
cpp = folder / 'isolation_main.cpp'
rtl.write_text('module isolation #(parameter CODE=17)(output wire [7:0] value); assign value=8\'(CODE); endmodule\n')
cpp.write_text('''#include "Visolation.h"
#include "verilated.h"
#include <cstdio>
int main() { Visolation top; top.eval(); std::printf("%d %u\\n", PROFILE, unsigned(top.value)); return 0; }
''')
parent = folder / 'parent'

def build(directory, profile, code, force):
    command = ['verilator', '--cc', '--exe', '--build', '--top-module', 'isolation',
               '--Mdir', str(directory), '-j', '2', '-GCODE=' + str(code),
               '-CFLAGS', '-DPROFILE=' + str(profile), str(rtl), str(cpp)]
    if force:
        command += ['-MAKEFLAGS', '-B']
    result = subprocess.run(command, capture_output=True, text=True, timeout=120)
    directory.mkdir(parents=True, exist_ok=True)
    (directory / 'build.log').write_text(result.stdout + result.stderr)
    assert result.returncode == 0, (directory, result.stderr)
    executable = directory / 'Visolation'
    if not executable.exists():
        assert not force, ('missing forced local executable', directory)
        assert (parent / 'Visolation').is_file()
        # A partially rebuilt child can silently borrow the whole parent
        # target. Query make's resolved target instead of relying on the
        # original build having printed a no-work message.
        query = subprocess.run(
            ['make', '-C', str(directory), '-f', 'Visolation.mk', '--debug=b',
             '-n', 'Visolation'], capture_output=True, text=True, timeout=30)
        (directory / 'target-query.log').write_text(query.stdout + query.stderr)
        assert query.returncode == 0, ('target query failed', directory, query.stderr)
        assert re.search(r"['`]\.\./Visolation' is up to date\.",
                         query.stdout + query.stderr), ('unproven parent target reuse', directory)
        assert subprocess.check_output([str(parent / 'Visolation')], text=True).strip() == '1 17'
        return 'borrowed parent executable; no child artifact'
    return subprocess.check_output([str(executable)], text=True).strip()

assert build(parent, 1, 17, True) == '1 17'
objects = [parent / 'isolation_main.o', parent / 'Visolation', parent / 'verilated.o']
hashes = {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in objects}
unforced = build(parent / 'unforced', 2, 23, False)
# Some future Verilator could remove its '..' VPATH; report that explicitly,
# never manufacture a borrowed-object failure or relax the forced positive.
assert unforced in ('1 23', '2 23', 'borrowed parent executable; no child artifact'), ('unexpected counterfactual failure', unforced)
assert build(parent / 'forced', 2, 23, True) == '2 23'
assert (parent / 'forced/isolation_main.o').is_file()
assert ' ../isolation_main.o ' not in (parent / 'forced/build.log').read_text()
assert hashes == {str(path): hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest() for path in hashes}
print('PASS actual nested-Mdir isolation: forced child reports own CPP/RTL profile, parent objects/binary unchanged')
print('MATCHED unforced build isolation negative: ' + unforced if unforced != '2 23' else 'NOTE upstream already isolates unforced child; no borrowed-object negative claimed')
print('Evidence:', folder)
