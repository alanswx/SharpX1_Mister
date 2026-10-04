"""Key-script comments must not silently discard actual PS/2 events."""
import argparse
import json
import pathlib
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("executable", type=pathlib.Path)
parser.add_argument("--timeout", type=float, default=180)
args = parser.parse_args()
exe = str(args.executable.resolve())

with tempfile.TemporaryDirectory(prefix="x1-key-script-") as temporary:
    folder = pathlib.Path(temporary)
    rom = folder / "loop.bin"
    rom.write_bytes(bytes((0xC3, 0, 0)))  # Original Z80 JP 0000; native sub-CPU runs.

    def run(name, contents, valid=True):
        keys, dump = folder / (name + ".keys"), folder / name
        keys.write_text(contents)
        result = subprocess.run([exe, "--cycles", "4000000" if valid else "128",
                                 "--rom", str(rom), "--keys", str(keys),
                                 "--dump", str(dump)], capture_output=True, text=True,
                                timeout=args.timeout)
        if not valid:
            assert result.returncode != 0, (contents, result.stdout)
            assert "key" in result.stderr.lower(), result.stderr
            return
        assert result.returncode == 0, result.stderr
        return json.loads(result.stdout.splitlines()[-1]), dump.with_suffix(".subram").read_bytes()

    neutral = run("neutral", "")
    plain = run("plain", "25 2b\n")
    commented = run("commented", "# full line\n\n  # indented\n25 2b # F make\n# end\n")
    assert plain == commented, "comments changed events or firmware results"
    assert plain[0]["ps2_bytes_sent"] == 1 and neutral[0]["ps2_bytes_sent"] == 0
    assert plain[1] != neutral[1], "F event did not reach native sub-CPU RAM"
    for index, contents in enumerate(("oops\n", "25\n", "25 2b extra\n", "25 zz\n",
                                      "25 100\n", "25 2b\n24 2b\n", "-1 2b\n")):
        run(f"invalid{index}", contents, valid=False)
print("PASS: comment-bearing scripts deliver identical PS/2 events; malformed lines are rejected")
