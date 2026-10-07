"""Real renderer checkpoint continuity and CPU-only/render profile isolation."""
import pathlib
import sys
import tempfile
from test_machine_kanji_render import fixture, pattern
from test_machine_kanji_snapshot import run, reject


def main():
    render, cpu_only = (str(pathlib.Path(arg).resolve()) for arg in sys.argv[1:3])
    with tempfile.TemporaryDirectory(prefix="x1-kanji-render-snapshot-") as directory:
        root = pathlib.Path(directory)
        font, rom = root / "original.physical", root / "original.rom"
        font.write_bytes(bytes(pattern(address) for address in range(131072)))
        rom.write_bytes(fixture(True))
        state, old = root / "render.state", root / "cpu-only.state"
        before = run(render, ["--rom", rom, "--kanji-physical", font, "--cycles", 6400000,
                              "--save-state", state])
        assert before["frames"] > 0 and before["halted"], before
        reject(cpu_only, state)
        run(cpu_only, ["--cycles", 20000, "--save-state", old])
        reject(render, old)
        resumed, direct = root / "resumed", root / "direct"
        after = run(render, ["--restore-state", state, "--cycles", 3200000,
                             "--frame", root / "resumed.ppm", "--dump", resumed])
        straight = run(render, ["--rom", rom, "--kanji-physical", font, "--cycles", 9600000,
                                "--frame", root / "direct.ppm", "--dump", direct])
        # Frame and sync accumulators are per invocation; the last completed
        # frame is real renderer output and must be byte-identical.
        for field in ("hs_edges", "vs_edges"):
            assert before[field] + after[field] == straight[field], (field, before, after, straight)
        host_only = {"download_bytes", "video_hash", "hs_edges", "vs_edges", "frames"}
        assert {k: v for k, v in after.items() if k not in host_only} == \
            {k: v for k, v in straight.items() if k not in host_only}, (after, straight)
        assert (root / "resumed.ppm").read_bytes() == (root / "direct.ppm").read_bytes()
        for suffix in ("ram", "text", "attr", "subram", "cpu"):
            assert resumed.with_suffix(f".{suffix}").read_bytes() == direct.with_suffix(f".{suffix}").read_bytes(), suffix
    print("PASS actual Kanji renderer snapshot: exact resumed RGB/report/dumps, additive sync edges, bidirectional CPU-only rejection")


if __name__ == "__main__":
    main()
