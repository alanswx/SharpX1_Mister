#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Freeze base-ANK packet tests and matched mutations; no machine/board claim."""
import hashlib
import json
from pathlib import Path
import re
import resource
import subprocess
import tempfile


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    if not __debug__:
        raise SystemExit('PARTIAL_ANK_OPTIMIZED_PYTHON')
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    root = Path(__file__).resolve().parents[2]
    adapter = 'rtl/x1_z_kanji_video.sv'
    unit = 'verilator/tests/x1_z_partial_ank_tb.sv'
    checker = 'verilator/tests/test_z_partial_ank.py'
    out = Path(tempfile.mkdtemp(prefix='x1-partial-ank-')).resolve()
    print('EVIDENCE=' + str(out), flush=True)
    hashes = {n: sha(root / n) for n in (adapter, unit, checker)}
    for name in hashes:
        p = out / 'sources' / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes((root / name).read_bytes())
    report = {'status': 'running', 'sources': hashes, 'cases': []}

    def save():
        (out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')

    source = out / 'sources' / adapter
    original = source.read_text()
    variants = [('positive', None, None, None)]
    variants += [
        ('missing-text-attribute', "cache_response_descriptor[31:24]==8'h03", "cache_response_descriptor[31:24]!=8'h00", 'PARTIAL_ANK_BLANK'),
        ('dirty-unknown-kan', " && cache_response_descriptor[23:16]==8'd0", '', 'PARTIAL_ANK_BLANK'),
        ('live-request-permission', 'ALLOW_PARTIAL_ANK && held_partial_allowed && allow_partial_ank', 'ALLOW_PARTIAL_ANK && (held_partial_allowed || !prefetch_start) && allow_partial_ank', 'PARTIAL_ANK_BLANK'),
        ('missing-reply-permission', 'ALLOW_PARTIAL_ANK && held_partial_allowed && allow_partial_ank', 'ALLOW_PARTIAL_ANK && held_partial_allowed', 'PARTIAL_ANK_BLANK'),
        ('held-permission-not-revoked', 'if(packet_partial && !allow_partial_ank)', "if(1'b0 && packet_partial && !allow_partial_ank)", 'PARTIAL_ANK_BLANK'),
        ('partial-kanji-glyph', "glyph_data<=known ? cache_response_data : 8'd0", 'glyph_data<=cache_response_data', 'PARTIAL_ANK_PACKET'),
    ]
    save()
    try:
        for name, before, after, marker in variants:
            folder = out / name
            folder.mkdir()
            variant = source
            if before is not None:
                assert original.count(before) == 1
                variant = folder / Path(adapter).name
                variant.write_text(original.replace(before, after))
            obj = folder / 'obj'
            command = ['verilator', '--binary', '--timing', '--assert', '-Wall', '--top-module',
                       'x1_z_partial_ank_tb', '--Mdir', str(obj), '-j', '2', str(variant),
                       str(out / 'sources' / unit)]
            case = {'name': name, 'expected_rejection': marker, 'command': command}
            report['cases'].append(case)
            save()
            with (folder / 'build.log').open('w') as log:
                result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=180)
            assert result.returncode == 0, 'compile failure is not a rejection'
            assert '%Warning' not in (folder / 'build.log').read_text()
            exe = obj / 'Vx1_z_partial_ank_tb'
            case['executable_sha256'] = sha(exe)
            with (folder / 'run.log').open('w') as log:
                result = subprocess.run([str(exe)], stdout=log, stderr=subprocess.STDOUT, timeout=30)
            text = (folder / 'run.log').read_text()
            assert 'PARTIAL_ANK_TIMEOUT' not in text
            if marker:
                assert result.returncode != 0 and re.findall(r'Assertion failed[^\n]*?: (\w+)', text) == [marker]
            else:
                assert result.returncode == 0 and re.findall(r'^PASS PARTIAL_ANK cases=(\d+)$', text, re.M) == ['778']
            case.update(verified=True, artifacts={p.name: sha(p) for p in folder.iterdir() if p.is_file()})
            save()
            print('PASS PARTIAL_ANK', name, flush=True)
        assert all(sha(root / n) == sha(out / 'sources' / n) == h for n, h in hashes.items())
        report['status'] = 'pass'
        save()
    except BaseException as error:
        report.update(status='fail', error=repr(error))
        save()
        raise


if __name__ == '__main__':
    main()
