"""Original CPU DIP checkpoint: exact continuation and raw-config rejection."""
import pathlib
import sys
import tempfile
from test_machine_turbo_dsw import fixture
from test_machine_kanji_snapshot import run, reject


def main():
    f1, f5 = (str(pathlib.Path(arg).resolve()) for arg in sys.argv[1:3])
    with tempfile.TemporaryDirectory(prefix="x1-dsw-state-") as temp:
        root = pathlib.Path(temp)
        for raw, exe, other in ((241, f1, f5), (245, f5, f1)):
            rom = root / f"original-{raw}.rom"
            rom.write_bytes(fixture(raw))
            state = root / f"raw-{raw}.state"
            before = run(exe, ["--rom", rom, "--cycles", 2000, "--save-state", state])
            assert not before["halted"], before
            reject(other, state)  # Native generated state, never patch headers.
            resumed, straight = root / f"resumed-{raw}", root / f"direct-{raw}"
            after = run(exe, ["--restore-state", state, "--cycles", 198000, "--dump", resumed])
            direct = run(exe, ["--rom", rom, "--cycles", 200000, "--dump", straight])
            host = {"download_bytes", "video_hash", "hs_edges", "vs_edges"}
            assert {k: v for k, v in after.items() if k not in host} == \
                {k: v for k, v in direct.items() if k not in host}, (after, direct)
            assert after["halted"] and after["peek"].startswith(b"DSW!".hex()), after
            for field in ("hs_edges", "vs_edges"):
                assert before[field] + after[field] == direct[field]
            for suffix in ("ram", "text", "attr", "subram", "cpu"):
                assert resumed.with_suffix(f".{suffix}").read_bytes() == \
                    straight.with_suffix(f".{suffix}").read_bytes(), suffix
    print("PASS DIP snapshot: executing F1/F5 continuations, exact CPU/dumps/reports, bidirectional raw-config rejection")


if __name__ == "__main__":
    main()
