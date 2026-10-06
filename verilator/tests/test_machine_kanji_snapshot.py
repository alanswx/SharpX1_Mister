"""Native CPU Kanji checkpoint continuity; immutable states/profile isolation."""
import json
import pathlib
import subprocess
import sys
import tempfile
from test_machine_kanji import fixture, pattern


def run(exe, arguments):
    result = subprocess.run([exe, *map(str, arguments)], capture_output=True, text=True, timeout=180)
    assert result.returncode == 0, (arguments, result.stderr)
    return json.loads(result.stdout.splitlines()[-1])


def reject(exe, state):
    result = subprocess.run([exe, "--restore-state", str(state), "--cycles", "20000"],
                            capture_output=True, text=True, timeout=30)
    assert result.returncode == 2 and "snapshot version" in result.stderr, result


def main():
    kanji, plain = (str(pathlib.Path(arg).resolve()) for arg in sys.argv[1:3])
    with tempfile.TemporaryDirectory(prefix="x1-kanji-snapshot-") as directory:
        root = pathlib.Path(directory)
        rom, font = root / "original.rom", root / "synthetic.bin"
        rom.write_bytes(fixture(True))
        font.write_bytes(bytes(pattern(a) for a in range(131072)))
        state, ordinary = root / "kanji.state", root / "ordinary.state"
        before = run(kanji, ["--rom", rom, "--kanji-physical", font, "--cycles", 400000,
                             "--save-state", state])
        assert before["turbo_kanji"] and not before["halted"], before
        reject(plain, state)
        run(plain, ["--cycles", 20000, "--save-state", ordinary])
        reject(kanji, ordinary)
        result = subprocess.run([plain, "--kanji-physical", str(font)], capture_output=True, text=True)
        assert result.returncode == 2 and "opt-in Kanji model" in result.stderr, result
        result = subprocess.run([kanji, "--restore-state", str(state), "--kanji-physical", str(font),
                                 "--cycles", "200000"], capture_output=True, text=True)
        assert result.returncode == 2 and "cannot also download" in result.stderr, result
        resumed, straight = root / "resumed", root / "straight"
        after = run(kanji, ["--restore-state", state, "--cycles", 6000000, "--dump", resumed])
        direct = run(kanji, ["--rom", rom, "--kanji-physical", font, "--cycles", 6400000, "--dump", straight])
        # The runner initializes these host-only accumulators per invocation,
        # not in the serialized RTL. Unlike the old IRQ fixture this program
        # configures a live CRTC, so compare exact additive sync transitions.
        host_window = {"download_bytes", "video_hash", "hs_edges", "vs_edges"}
        for field in ("hs_edges", "vs_edges"):
            assert before[field] + after[field] == direct[field], (field, before, after, direct)
        assert {k: v for k, v in after.items() if k not in host_window} == \
            {k: v for k, v in direct.items() if k not in host_window}, (after, direct)
        assert after["halted"] and after["peek"].startswith(b"KAN!".hex()), after
        for suffix in ("ram", "text", "attr", "subram", "cpu"):
            assert resumed.with_suffix(f".{suffix}").read_bytes() == straight.with_suffix(f".{suffix}").read_bytes(), suffix
    print("PASS: executing CPU/INI checkpoint retains Kanji ROM, exact resumed report/dumps, bidirectional profile rejection")


if __name__ == "__main__":
    main()
