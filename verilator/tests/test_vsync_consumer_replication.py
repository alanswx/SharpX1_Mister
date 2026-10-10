#!/usr/bin/env python3
"""Frozen VSYNC declaration/QSF scope and matched negatives; not fit acceptance.

Historical framework bytes are read from immutable Git, never rebound to the
new source. Strict input SDC and the separate clock-controller allowlist stay
unchanged. No synthesis, board access or historical report modification.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile


class ScopeAssertion(AssertionError):
    pass


def require(condition, message):
    if not condition:
        raise ScopeAssertion(message)


def uncomment(text):
    return re.sub(r'/\*.*?\*/|//[^\n]*', '', text, flags=re.S)


def declaration_block(source):
    pattern = r'^`ifdef X1_TURBO_Z_VIDEO_EXPERIMENT\n(.*?)^`else\n(.*?)^`endif[^\n]*'
    return [m for m in re.finditer(pattern, source, re.M | re.S)
            if 'dont_replicate' in m.group(1)]


def verify_source(source, historical):
    blocks = declaration_block(source)
    require(len(blocks) == 1, 'GUARD: exactly one experimental declaration block')
    block = blocks[0]
    expected = 'reg vs_d0; (* dont_replicate *) reg vs_d1; reg vs_d2;'
    require(' '.join(uncomment(block.group(1)).split()) == expected,
            'DECLARATION: ordered uninitialized d0/d1/d2; attribute only d1')
    require(' '.join(uncomment(block.group(2)).split()) == 'reg vs_d0,vs_d1,vs_d2;',
            'DEFAULT: original uninitialized grouped declaration')
    require(len(re.findall(r'\bdont_replicate\b', uncomment(source))) ==
            len(re.findall(r'\bdont_replicate\b', uncomment(historical))) + 1,
            'ATTRIBUTES: no unconditional or additional replication controls')
    # Replacing just the new guarded declaration with the original declaration
    # must recover the historical framework BYTE FOR BYTE, including all logic,
    # reset/init policy, process-local scope, source ordering and HPS paths.
    old = re.findall(r'^\treg        vs_d0,vs_d1,vs_d2;$', historical, re.M)
    require(len(old) == 1, 'BASELINE: unique original declaration')
    restored = source[:block.start()] + old[0] + source[block.end():]
    require(restored == historical, 'LOGIC: framework differs beyond declaration split')


def verify_qsf(qsfs):
    def expand(name, stack=()):
        require(name in qsfs and name not in stack, 'QSF: missing or cyclic source')
        macros = []
        for raw in qsfs[name].splitlines():
            line = raw.strip()
            if line.startswith('source ') and line.endswith('.qsf'):
                macros += expand(line.split()[1], (*stack, name))
            match = re.fullmatch(r'set_global_assignment -name VERILOG_MACRO "?([^"\n]+)"?', line)
            if match and match.group(1).startswith('X1_TURBO_Z_VIDEO_EXPERIMENT'):
                macros.append(match.group(1))
        return macros
    enabled = {name: expand(name) for name in qsfs if expand(name)}
    require(enabled == {'sharpx1_turbo_z_video.qsf': ['X1_TURBO_Z_VIDEO_EXPERIMENT=1'],
                        'sharpx1_turbo_z_handoff.qsf': ['X1_TURBO_Z_VIDEO_EXPERIMENT=1']},
            'QSF_SCOPE: experiment enabled exactly once on the two Z revisions only')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', default='5afb059')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    commit = subprocess.check_output(['git', 'rev-parse', f'{args.baseline}^{{commit}}'],
                                     cwd=root, text=True).strip()
    historical = subprocess.check_output(['git', 'show', f'{commit}:sys/sys_top.v'], cwd=root)
    paths = ['sys/sys_top.v', 'verilator/tests/test_vsync_consumer_replication.py',
             'verilator/tests/vsync_sys_input_sdc_tb.tcl',
             'scripts/constraints/vsync_sys_input_candidate.sdc',
             'verilator/tests/test_hdmi_handoff_board_profile.py']
    paths += sorted(p.name for p in root.glob('*.qsf'))
    frozen = {p: (root / p).read_bytes() for p in paths}
    sdc = 'scripts/constraints/vsync_sys_input_candidate.sdc'
    require(frozen[sdc] == subprocess.check_output(['git','show',f'{commit}:{sdc}'],cwd=root),
            'SDC: strict input guard changed from historical baseline')
    out = Path(tempfile.mkdtemp(prefix='x1-vsync-consumer-replication-'))
    for path, data in frozen.items():
        target = out / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    (out / 'historical_sys_top.v').write_bytes(historical)
    sha = lambda data: hashlib.sha256(data).hexdigest()
    report = {'scope': __doc__, 'historical_commit': commit,
              'historical_sys_top_sha256': sha(historical),
              'sources': {p: sha(data) for p, data in frozen.items()},
              'negative': [], 'status': 'running'}
    def save():
        (out / 'comparison.json').write_text(json.dumps(report, indent=2) + '\n')
    def negative(name, verifier, value, diagnostic, filename):
        (out / filename).write_text(value if isinstance(value, str) else json.dumps(value, indent=2))
        try:
            verifier(value)
        except ScopeAssertion as error:
            require(str(error) == diagnostic, f'{name}: wrong rejection: {error}')
        else:
            raise AssertionError(f'{name}: mutation escaped')
        report['negative'].append({'name': name, 'diagnostic': diagnostic,
                                   'sha256': sha((out / filename).read_bytes())})
        print('PASS negative', name, diagnostic, flush=True)
    print('Frozen source/scope evidence:', out, flush=True)
    save()
    try:
        source = frozen['sys/sys_top.v'].decode()
        old = historical.decode()
        qsfs = {p: frozen[p].decode() for p in paths if p.endswith('.qsf')}
        verify_source(source, old)
        verify_qsf(qsfs)
        report['positive'] = 'exact historical logic/default declaration and two-revision macro scope'
        block = declaration_block(source)[0]
        candidates = [
            ('broad-attribute', source.replace('(* dont_replicate *) reg vs_d1;',
                 '(* dont_replicate *) reg vs_d0,vs_d1,vs_d2;'),
                 'DECLARATION: ordered uninitialized d0/d1/d2; attribute only d1'),
            ('initializer', source.replace('reg vs_d1;', 'reg vs_d1 = 0;'),
                 'DECLARATION: ordered uninitialized d0/d1/d2; attribute only d1'),
            ('unconditional', source[:block.start()] + block.group(1) + source[block.end():],
                 'GUARD: exactly one experimental declaration block'),
            ('extra-attribute', source.replace('reg  [4:0] acx_att;',
                 '(* dont_replicate *) reg  [4:0] acx_att;'),
                 'ATTRIBUTES: no unconditional or additional replication controls'),
            ('default-init', source.replace('reg        vs_d0,vs_d1,vs_d2;',
                 'reg        vs_d0,vs_d1,vs_d2 = 0;'),
                 'DEFAULT: original uninitialized grouped declaration'),
            ('default-logic', source.replace('vs_d2 <= vs_d1;', 'vs_d2 <= vs_d0;'),
                 'LOGIC: framework differs beyond declaration split'),
            ('reset-added', source.replace('vs_d0 <= hdmi_vs_sys;',
                 'if(reset) vs_d1 <= 0;\n\tvs_d0 <= hdmi_vs_sys;'),
                 'LOGIC: framework differs beyond declaration split'),
        ]
        for name, mutant, diagnostic in candidates:
            require(mutant != source, f'MUTATION: {name} did not change source')
            negative(name, lambda value: verify_source(value, old), mutant,
                     diagnostic, name + '.v')
        for name, target, before, after in [
            ('ordinary-profile', 'sharpx1.qsf', '', '\nset_global_assignment -name VERILOG_MACRO "X1_TURBO_Z_VIDEO_EXPERIMENT=1"\n'),
            ('missing-experiment', 'sharpx1_turbo_z_video.qsf',
             'set_global_assignment -name VERILOG_MACRO "X1_TURBO_Z_VIDEO_EXPERIMENT=1"', ''),
        ]:
            mutant = dict(qsfs)
            mutant[target] = mutant[target] + after if not before else mutant[target].replace(before, after)
            require(mutant != qsfs, f'MUTATION: {name} did not change QSF')
            negative(name, verify_qsf, mutant,
                     'QSF_SCOPE: experiment enabled exactly once on the two Z revisions only', name + '.json')
        command = ['tclsh', str(out / 'verilator/tests/vsync_sys_input_sdc_tb.tcl')]
        result = subprocess.run(command, text=True, capture_output=True, timeout=30)
        (out / 'input-guard.command.json').write_text(json.dumps(command) + '\n')
        (out / 'input-guard.log').write_text(result.stdout + result.stderr)
        result.check_returncode()
        require('20 invalid inventories reject' in result.stdout, 'MOCK: incomplete input guard coverage')
        report['input_mock_exit'] = result.returncode
        for path, data in frozen.items():
            require((root / path).read_bytes() == data and (out / path).read_bytes() == data,
                    'STABILITY: source changed: ' + path)
        report['inputs_stable'] = True
        report['status'] = 'pass'
        print(result.stdout, end='', flush=True)
        print('PASS VSYNC split source/QSF scope; nine matched mutants; no fitted acceptance', flush=True)
    except Exception as error:
        report['status'] = 'fail'
        report['error'] = str(error)
        raise
    finally:
        save()


if __name__ == '__main__':
    main()
