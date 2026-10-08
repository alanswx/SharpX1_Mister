"""Optional local old/new DMA runner compatibility check; never patch states.

Pass frozen old and current savable executables with the SAME DMA/IRQ profile.
This checks format identity, not native boot or DMA transfer correctness.
"""
import argparse
import hashlib
import json
import pathlib
import struct
import subprocess
import tempfile


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def invoke(exe, *args):
    return subprocess.run([str(exe), *map(str, args)], capture_output=True,
                          text=True, timeout=120)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("old", type=pathlib.Path)
    parser.add_argument("current", type=pathlib.Path)
    args = parser.parse_args()
    runners = [args.old.resolve(), args.current.resolve()]
    hashes = [digest(p) for p in runners]
    assert hashes[0] != hashes[1], "must supply distinct frozen runners"
    with tempfile.TemporaryDirectory(prefix="x1-dma-version-") as folder:
        states = [pathlib.Path(folder) / f"version-{i}.state" for i in range(2)]
        reports = []
        for exe, state in zip(runners, states):
            result = invoke(exe, "--cycles", 20000, "--save-state", state)
            assert result.returncode == 0, result.stderr
            report = json.loads(result.stdout.splitlines()[-1])
            assert report["turbo_dma"], "requires an actual DMA profile"
            reports.append(report)
        for key in ("turbo_dma_irq", "sys_hz", "video_hz", "turbo_video_master"):
            assert reports[0][key] == reports[1][key], (key, "different profiles are not a revision test")
        # This specific revision adds only bit 41 to the application identity.
        # Requiring that exact delta also rules out a different capability
        # profile, including options absent from an older JSON report.
        headers = [p.read_bytes()[:24] for p in states]
        assert all(h[:16] == b"verilatorsave02\n" for h in headers)
        delta = struct.unpack("<Q", headers[0][16:24])[0] ^ struct.unpack("<Q", headers[1][16:24])[0]
        assert delta == 1 << 41, (hex(delta), "not the revision-6/revision-7 same-profile pair")
        state_hashes = [digest(p) for p in states]
        for i, exe in enumerate(runners):
            own = invoke(exe, "--restore-state", states[i], "--cycles", 20000)
            assert own.returncode == 0, own.stderr
            other = invoke(exe, "--restore-state", states[1-i], "--cycles", 20000)
            assert other.returncode == 2 and "snapshot version" in other.stderr, other
        assert hashes == [digest(p) for p in runners]
        assert state_hashes == [digest(p) for p in states]
        print(json.dumps({"runners_sha256": hashes, "states_sha256": state_hashes}))
        print("PASS: same-profile old/new DMA revisions reject each other; each resumes its own unchanged state")


if __name__ == "__main__":
    main()
