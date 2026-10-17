#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Freeze the public-port renderer validity LOAD test and two matched faults."""
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
        raise SystemExit('TEXT_PACKET_OPTIMIZED_PYTHON')
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    root = Path(__file__).resolve().parents[2]
    files = ['rtl/legacy/x1_vid.v', 'rtl/legacy/crtc/crtc6845s.v', 'rtl/x1_video_timing.sv',
             'rtl/x1_text_raster.sv', 'verilator/tests/x1_text_packet_load_tb.sv',
             'verilator/tests/test_text_packet_load.py']
    out = Path(tempfile.mkdtemp(prefix='x1-text-packet-load-')).resolve()
    print('EVIDENCE=' + str(out), flush=True)
    hashes = {n: sha(root / n) for n in files}
    for n in files:
        p = out / 'sources' / n
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes((root / n).read_bytes())
    report = {'status': 'running', 'sources': hashes, 'cases': []}

    def save():
        (out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')

    source = out / 'sources' / files[0]
    original = source.read_text()
    variants = [
        ('positive', None, None, None),
        ('validity-at-capture', 'else if(video_step & ~QP & QA & ~QD & ~QC & ~QB) blank<=!I_TEXT_PACKET_VALID;',
         'else if(video_step & ~QP & QA & ~QD & QC & ~QB) blank<=!I_TEXT_PACKET_VALID;', 'TEXT_PACKET_LATE_LOAD'),
        ('missing-final-mask', 'z_glyph_blank || text_packet_blank ||', 'z_glyph_blank ||', 'TEXT_PACKET_COLOR'),
    ]
    save()
    try:
        for name, before, after, rejection in variants:
            folder = out / name
            folder.mkdir()
            variant = source
            if before is not None:
                assert original.count(before) == 1
                variant = folder / 'x1_vid.v'
                variant.write_text(original.replace(before, after))
            obj = folder / 'obj'
            command = ['verilator', '--binary', '--timing', '--assert', '-Wno-fatal',
                       '--top-module', 'x1_text_packet_load_tb', '--Mdir', str(obj), '-j', '4',
                       str(variant), *[str(out / 'sources' / n) for n in files[1:-1]]]
            case = {'name': name, 'command': command, 'expected_rejection': rejection}
            report['cases'].append(case)
            save()
            with (folder / 'build.log').open('w') as log:
                result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=180)
            assert result.returncode == 0
            warnings = re.findall(r'^%Warning[^\n]+', (folder / 'build.log').read_text(), re.M)
            assert not any('x1_text_packet_load_tb.sv:' in w for w in warnings)
            assert not any(re.search(r'%Warning-(IMPLICIT|MULTIDRIVEN|LATCH|UNOPTFLAT):', w) for w in warnings)
            case['warnings'] = warnings
            exe = obj / 'Vx1_text_packet_load_tb'
            case['executable_sha256'] = sha(exe)
            with (folder / 'run.log').open('w') as log:
                result = subprocess.run([str(exe)], stdout=log, stderr=subprocess.STDOUT, timeout=30)
            text = (folder / 'run.log').read_text()
            assert 'TEXT_PACKET_TIMEOUT' not in text
            if rejection:
                assert result.returncode != 0 and re.findall(r'Assertion failed[^\n]*?: (\w+)', text) == [rejection], text
            else:
                assert result.returncode == 0 and re.findall(r'^PASS TEXT_PACKET_LOAD cases=(\d+)$', text, re.M) == ['34'], text
            case.update(verified=True, artifacts={p.name: sha(p) for p in folder.iterdir() if p.is_file()})
            save()
            print('PASS TEXT_PACKET_LOAD', name, flush=True)
        assert all(sha(root / n) == sha(out / 'sources' / n) == h for n, h in hashes.items())
        report['status'] = 'pass'
        save()
    except BaseException as error:
        report.update(status='fail', error=repr(error))
        save()
        raise


if __name__ == '__main__':
    main()
