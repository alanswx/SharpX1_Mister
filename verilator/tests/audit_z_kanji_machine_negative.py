#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Read-only provenance audit of frozen synthetic Z machine negatives.

No collector, compiler or runner is executed. Frozen original emitters are
loaded only after caller-bound source verification, to reproduce public assets.
This is evidence auditing, not native font, ASIC, storage or FPGA acceptance.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys

if not __debug__:
    raise RuntimeError('Z_NEG_AUDIT_OPTIMIZED_EXECUTION_FORBIDDEN')
sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[2]
PROFILES = {'disabled': ('probe', 5, 'probe', 'Z_ORDERED_UPLOAD_ADMISSION'),
            'half-major': ('probe', 5, 'probe', 'Z_CPU_EXECUTED_DATA_ORACLE'),
            'display-miss': ('render80', 1, 'render', 'Z_SUPPORTED_DISPLAY_MISS')}
ROM = 'rtl/x1_z_kanji_rom.sv'
TB = 'verilator/tests/z_kanji_machine_tb.sv'
OLD = 'assign display_valid=display_selected && loaded_video && !video_reset;'
NEW = "assign display_valid=1'b0;"
OWN = [TB, 'verilator/tests/z_kanji_machine_assets.py',
       'verilator/tests/test_machine_z_kanji.py', 'verilator/tests/z80_fixture.py']


def require(condition, marker):
    if not condition:
        raise RuntimeError(marker)


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def artifacts(folder):
    result = {}
    for path in sorted(folder.rglob('*')):
        require(not path.is_symlink(), 'Z_NEG_AUDIT_SYMLINK')
        if path.is_file():
            result[str(path.relative_to(folder))] = sha(path)
    return result


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def physical_pattern(address):
    return (167 * (address >> 17) + 13 * ((address >> 13) & 15) +
            37 * ((address >> 5) & 255) + 29 * ((address >> 1) & 15) +
            83 * (address & 1)) & 255


def read_hex(path):
    words = path.read_text().split()
    require(all(re.fullmatch('[0-9a-fA-F]{2}', word) for word in words), 'Z_NEG_AUDIT_HEX_ENCODING')
    return bytes(int(word, 16) for word in words)


def audit(folder, binding, negative):
    require(sha(folder / 'inputs.json') == binding, 'Z_NEG_AUDIT_INPUT_BINDING')
    inputs = json.loads((folder / 'inputs.json').read_text())
    root_before = {}
    for name, digest in inputs.items():
        relative = Path(name)
        require(not relative.is_absolute() and '..' not in relative.parts, 'Z_NEG_AUDIT_SOURCE_PATH')
        require((ROOT / name).resolve().is_relative_to(ROOT), 'Z_NEG_AUDIT_SOURCE_PATH')
        require(sha(folder / 'sources' / name) == digest, 'Z_NEG_AUDIT_FROZEN_SOURCE: ' + name)
        require(sha(ROOT / name) == digest, 'Z_NEG_AUDIT_ROOT_SOURCE: ' + name)
        root_before[name] = digest
    before = artifacts(folder)
    try:
        qip = (folder / 'sources/rtl/machine.qip').read_text()
        order = re.findall(r'^set_global_assignment -name (?:SYSTEMVERILOG_FILE|VERILOG_FILE) (\S+)\s*$', qip, re.M)
        require(order and len(order) == len(set(order)), 'Z_NEG_AUDIT_SOURCE_ORDER')
        expected_names = list(dict.fromkeys(order + OWN +
                                           ['rtl/machine.qip', 'bios/reference/fw_subcpu/verilog/X1SUB.BIN']))
        require(list(inputs) == expected_names, 'Z_NEG_AUDIT_INPUT_ROSTER')
        require(json.loads((folder / 'source-order.json').read_text()) == order, 'Z_NEG_AUDIT_SOURCE_ORDER')
        case, scenario, kind, marker = PROFILES[negative]
        state = json.loads((folder / 'status.json').read_text())
        require(state.get('phase') == 'exact-negative-pass' and state.get('negative') == negative and
                state.get('sources_unchanged') is True, 'Z_NEG_AUDIT_TERMINAL')
        require([run['case'] for run in state['runs']] == [case], 'Z_NEG_AUDIT_RUN_ROSTER')
        paths = {name: folder / 'sources' / name for name in order}
        mutant_files = {str(path.relative_to(folder / 'mutation')) for path in
                        (folder / 'mutation').rglob('*') if path.is_file()}
        if negative == 'display-miss':
            require(mutant_files == {ROM}, 'Z_NEG_AUDIT_MUTATION_ROSTER')
            mutation = json.loads((folder / 'mutation.json').read_text())
            require(set(mutation) == {ROM}, 'Z_NEG_AUDIT_MUTATION_ROSTER')
            original = (folder / 'sources' / ROM).read_bytes()
            require(original.count(OLD.encode()) == 1, 'Z_NEG_AUDIT_MUTATION_NEEDLE')
            mutant = folder / 'mutation' / ROM
            require(mutant.read_bytes() == original.replace(OLD.encode(), NEW.encode()),
                    'Z_NEG_AUDIT_MUTATION_BYTES')
            require(sha(mutant) == mutation[ROM], 'Z_NEG_AUDIT_MUTATION_HASH')
            paths[ROM] = mutant
        else:
            require(not mutant_files and not (folder / 'mutation.json').exists(),
                    'Z_NEG_AUDIT_UNEXPECTED_MUTATION')
        build = state['build']
        expected_build = ['verilator', '--binary', '--timing', '--assert', '-Wno-fatal',
                          '--top-module', 'z_kanji_machine_tb', '--Mdir', str(folder / 'build'),
                          '-j', '2', f'-GENABLED={0 if negative == "disabled" else 1}',
                          *[str(paths[name]) for name in order], str(folder / 'sources' / TB)]
        require(build['command'] == expected_build, 'Z_NEG_AUDIT_BUILD_COMMAND')
        require(build['phase'] == 'terminal' and type(build['returncode']) is int and build['returncode'] == 0,
                'Z_NEG_AUDIT_BUILD_TERMINAL')
        require(Path(build['log']).resolve() == folder / 'build.log', 'Z_NEG_AUDIT_BUILD_LOG')
        executable = folder / 'build/Vz_kanji_machine_tb'
        require(sha(executable) == state['executable_sha256'], 'Z_NEG_AUDIT_EXECUTABLE')
        generated = json.loads((folder / 'generated.json').read_text())
        require(set(generated) == {'font.bin', 'font.hex', 'absent.hex', case + '.ipl.bin', case + '.ipl.hex'},
                'Z_NEG_AUDIT_GENERATED_ROSTER')
        for name, digest in generated.items():
            require(sha(folder / name) == digest, 'Z_NEG_AUDIT_GENERATED_HASH: ' + name)
        font = bytes(physical_pattern(address) for address in range(262144))
        require((folder / 'font.bin').read_bytes() == font, 'Z_NEG_AUDIT_FONT_BINARY')
        # The wrong upload is ONLY the half-major ordering, with physical font
        # bytes otherwise unchanged: level/half/bank/character/row.
        uploaded = (bytes(font[level * 131072 + bank * 8192 + character * 32 + row * 2 + half]
                          for level in range(2) for half in range(2) for bank in range(16)
                          for character in range(256) for row in range(16))
                    if negative == 'half-major' else font)
        require(read_hex(folder / 'font.hex') == uploaded, 'Z_NEG_AUDIT_FONT_HEX')
        emitter = load(folder / 'sources/verilator/tests/z80_fixture.py', 'z_negative_emitter')
        assets = load(folder / 'sources/verilator/tests/z_kanji_machine_assets.py', 'z_negative_assets')
        program = assets.program(emitter.Program, kind, 80)
        require((folder / (case + '.ipl.bin')).read_bytes() == program, 'Z_NEG_AUDIT_IPL_PROGRAM')
        require(read_hex(folder / (case + '.ipl.hex')) == program, 'Z_NEG_AUDIT_IPL_HEX')
        require(read_hex(folder / 'absent.hex') == assets.program(emitter.Program, 'probe', absent=True),
                'Z_NEG_AUDIT_ABSENT_IPL')
        run = state['runs'][0]
        expected_command = [str(executable), f'+FONT={folder / "font.hex"}',
                            f'+IPL={folder / (case + ".ipl.hex")}', f'+ABSENT_IPL={folder / "absent.hex"}',
                            f'+OUTPUT={folder / case}', f'+SCENARIO={scenario}',
                            '+COLUMNS=80', '+LOAD_KIND=0', '+DELAY=1']
        require(run['command'] == expected_command, 'Z_NEG_AUDIT_RUN_COMMAND')
        require(run['phase'] == 'terminal' and type(run['returncode']) is int and run['returncode'] != 0,
                'Z_NEG_AUDIT_RUN_CODE')
        require(run.get('exact_rejection') == marker, 'Z_NEG_AUDIT_REJECTION_BINDING')
        require(Path(run['log']).resolve() == folder / (case + '.log'), 'Z_NEG_AUDIT_LOG_CONTAINMENT')
        log = (folder / (case + '.log')).read_text()
        require('PASS' not in log and 'TIMEOUT' not in log, 'Z_NEG_AUDIT_LOG_PASS_OR_TIMEOUT')
        lines = [line for line in log.splitlines() if line.strip()]
        require(len(lines) == 3, 'Z_NEG_AUDIT_FAILURE_LOG_SHAPE')
        fatal = re.fullmatch(r'\[(\d+)\] %Fatal: z_kanji_machine_tb\.sv:(\d+): Assertion failed in '
                             r'(z_kanji_machine_tb(?:\.[A-Za-z0-9_]+)*): (Z_[A-Z0-9_]+)', lines[0])
        require(fatal is not None and fatal.group(4) == marker, 'Z_NEG_AUDIT_FAILURE_MARKER')
        line_number = int(fatal.group(2))
        tb_lines = (folder / 'sources' / TB).read_text().splitlines()
        require(1 <= line_number <= len(tb_lines) and
                re.search(r'\$fatal\(1,\s*"' + re.escape(marker) + '"', tb_lines[line_number - 1]) is not None,
                'Z_NEG_AUDIT_FAILURE_SOURCE_LINE')
        require(lines[1] == f'%Error: {folder / "sources" / TB}:{line_number}: Verilog $stop' and
                lines[2] == 'Aborting...', 'Z_NEG_AUDIT_FAILURE_TERMINAL')
        result = {'scope': 'read-only synthetic negative provenance, not native/hardware',
                  'negative': negative, 'case': case, 'exact_rejection': marker,
                  'inputs_sha256': binding, 'executable_sha256': sha(executable),
                  'artifact_files': len(before), 'artifact_sha256': before}
    finally:
        require(before == artifacts(folder), 'Z_NEG_AUDIT_ARTIFACT_CHANGED')
        require(all(sha(ROOT / name) == digest for name, digest in root_before.items()),
                'Z_NEG_AUDIT_ROOT_CHANGED')
    result.update(artifacts_unchanged=True, sources_unchanged=True)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--folder', type=Path, required=True)
    parser.add_argument('--expected-inputs-sha256', required=True)
    parser.add_argument('--negative', required=True, choices=PROFILES)
    args = parser.parse_args()
    require(re.fullmatch('[0-9a-f]{64}', args.expected_inputs_sha256) is not None, 'Z_NEG_AUDIT_HASH_FORMAT')
    require(not args.folder.is_symlink(), 'Z_NEG_AUDIT_SYMLINK')
    print(json.dumps(audit(args.folder.resolve(strict=True), args.expected_inputs_sha256, args.negative)))


if __name__ == '__main__':
    main()
