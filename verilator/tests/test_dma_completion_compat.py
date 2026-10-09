"""Unmodified executing completion states across pre/post restart integration.

Supply two frozen revision-7 completion-only savable runners. No conversion,
patched headers, native/private firmware or assumption of layout compatibility.
"""
import hashlib
import pathlib
import sys
import tempfile
from test_machine_dma_irq import diagnostic
from test_machine_dma_irq_snapshot import run


def main():
    runners = [pathlib.Path(arg).resolve() for arg in sys.argv[1:]]
    assert len(runners) == 2
    hashes = [hashlib.sha256(path.read_bytes()).hexdigest() for path in runners]
    for path, digest in zip(runners, hashes):
        print(str(path)+" sha256="+digest, flush=True)
    with tempfile.TemporaryDirectory(prefix="x1-completion-compatible-") as temporary:
        root = pathlib.Path(temporary)
        rom = root/"completion.rom"
        rom.write_bytes(diagnostic(0, handler_delay=10000)[0])
        for index, source in enumerate(runners):
            target = runners[1-index]
            state, saved = root/"live.state", root/"saved"
            before = run(str(source), ["--rom", rom, "--cycles", 200000, "--save-state", state, "--dump", saved])
            ram = saved.with_suffix(".ram").read_bytes()
            assert not before["halted"] and ram[0xf010] == 0 and ram[0xf012] == 1
            state_hash = hashlib.sha256(state.read_bytes()).hexdigest()
            continued, fresh = root/"continued", root/"fresh"
            after = run(str(target), ["--restore-state", state, "--cycles", 7800000, "--dump", continued])
            direct = run(str(target), ["--rom", rom, "--cycles", 8000000, "--dump", fresh])
            excluded = {"download_bytes", "video_hash"}
            assert {k:v for k,v in after.items() if k not in excluded} == {k:v for k,v in direct.items() if k not in excluded}
            assert after["halted"] and after["peek"].startswith(b"IRQ!".hex()), after
            assert (after["dma_reads"], after["dma_writes"], after["dma_grants"]) == (8,8,2), after
            for suffix in ("ram", "text", "attr", "subram", "cpu", "dma"):
                assert continued.with_suffix("."+suffix).read_bytes() == fresh.with_suffix("."+suffix).read_bytes(), suffix
            assert hashlib.sha256(state.read_bytes()).hexdigest() == state_hash
            assert [hashlib.sha256(path.read_bytes()).hexdigest() for path in runners] == hashes
            print(f"PASS completion compatibility direction={index}: executing IUS continuation, two blocks/guards/RETI, exact dumps", flush=True)


if __name__ == "__main__":
    main()
