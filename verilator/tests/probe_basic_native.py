"""Repeat a native BASIC disk probe without RAM injection or media writes.

Run from verilator/. Private assets and output stay ignored. A deterministic
run is not a BASIC compatibility pass; inspect the native display and then
qualify real keyboard commands separately. Runner build provenance is external.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('executable', type=Path)
    parser.add_argument('--runner-sha', required=True)
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--rom', type=Path, default=Path('../bios/ipl_x1.hex'))
    parser.add_argument('--keys', type=Path, required=True)
    parser.add_argument('--seconds', type=int, default=8)
    parser.add_argument('--timeout', type=float, default=1800)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.seconds <= 0 or args.timeout <= 0:
        parser.error('positive duration and timeout required')
    manifest = args.manifest.resolve()
    metadata = json.loads(manifest.read_text())
    if len(metadata['records']) != 1:
        parser.error('select a manifest containing exactly one disk')
    disk = Path(metadata['records'][0]['image']).resolve()
    archive = Path(metadata['archive']).resolve()
    exe, rom, keys = (p.resolve() for p in (args.executable, args.rom, args.keys))
    if digest(exe) != args.runner_sha:
        parser.error('runner differs from explicitly selected checkpoint')
    if digest(disk) != metadata['records'][0]['sha256'] or digest(archive) != metadata['archive_sha256']:
        parser.error('private media differs from staging manifest')
    inputs = {str(p): digest(p) for p in (exe, disk, archive, manifest, rom, keys, Path(__file__).resolve())}
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    frozen = output / 'Vtop'
    shutil.copy2(exe, frozen)
    assert digest(frozen) == args.runner_sha
    shutil.copyfile(Path(__file__), output / 'probe_basic_native.py')
    evidence = {'scope': 'native cold/repeat observations, not BASIC acceptance or runner-build provenance',
                'executable_sha256': args.runner_sha, 'inputs_sha256': inputs,
                'duration_seconds': args.seconds, 'runs': [], 'phase': 'running'}
    artifacts = ('.ram', '.text', '.attr', '.subram', '.cpu', '.ppm')
    try:
        for name in ('cold', 'repeat'):
            prefix = output / name
            command = [str(frozen), '--cycles', str(args.seconds * 32000000),
                       '--rom', str(rom), '--disk', str(disk), '--keys', str(keys),
                       '--dump', str(prefix), '--frame', str(prefix) + '.ppm']
            (output / (name + '.command.json')).write_text(json.dumps(command, indent=2) + '\n')
            print('START', name, str(output), flush=True)
            with (output / (name + '.stdout')).open('w') as stdout, (output / (name + '.stderr')).open('w') as stderr:
                result = subprocess.run(command, stdout=stdout, stderr=stderr, timeout=args.timeout)
            record = {'command': command, 'returncode': result.returncode}
            evidence['runs'].append(record)
            result.check_returncode()
            report = json.loads((output / (name + '.stdout')).read_text().splitlines()[-1])
            assert report['disk_writes'] == 0, 'unexpected disk write'
            record.update(report=report, artifacts={s: digest(Path(str(prefix) + s)) for s in artifacts})
            print('COMPLETE', name, flush=True)
        first, second = evidence['runs']
        assert first['report'] == second['report'] and first['artifacts'] == second['artifacts'], 'native probe differs'
        evidence['phase'] = 'repeatable'
    except BaseException as error:
        evidence.update(phase='failed', error=repr(error))
        raise
    finally:
        # Preserve terminal failure evidence even if an input disappears. A
        # changed asset must not leave a misleading "repeatable" phase behind.
        evidence['unchanged_inputs'] = True
        read_errors = {}
        for path, sha in inputs.items():
            try:
                unchanged = digest(Path(path)) == sha
            except OSError as error:
                unchanged = False
                read_errors[path] = repr(error)
            evidence['unchanged_inputs'] &= unchanged
        try:
            evidence['unchanged_runner'] = digest(frozen) == args.runner_sha
        except OSError as error:
            evidence['unchanged_runner'] = False
            read_errors[str(frozen)] = repr(error)
        if read_errors:
            evidence['input_read_errors'] = read_errors
        if not (evidence['unchanged_inputs'] and evidence['unchanged_runner']):
            evidence['phase'] = 'failed'
            evidence.setdefault('error', "AssertionError('probe inputs changed')")
        (output / 'evidence.json').write_text(json.dumps(evidence, indent=2) + '\n')
    assert evidence['unchanged_inputs'] and evidence['unchanged_runner'], 'probe inputs changed'
    print('PASS native BASIC probe repeats; screen/commands require separate acceptance', flush=True)


if __name__ == '__main__':
    main()
