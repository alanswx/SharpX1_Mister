"""Shared CPU restart handlers, buffered addresses and executing snapshots.

Original IPL and real WR0/WR4/WR6/IM2/HALT/RETI; no private assets, forced
interrupts, debug writes, grants or edited/converted state.
"""
import argparse
import hashlib
import json
import pathlib
import subprocess
import tempfile
from test_machine_dma import Fixture
import dma_visible


def diagnostic(a_source, mode, delay=10000, pending_delay=0, visible=False):
    f = Fixture()
    p = f.p
    if visible:
        dma_visible.initialize(f)
    old = bytes(0x31+i*13 for i in range(4))
    new = bytes(0xa7+i*7 for i in range(4))
    for address in (0xf000, 0xf010, 0xf011, 0xf012):
        p.store(address, 0)
    for base, data in ((0x9000, old), (0x9200, new)):
        for i, byte in enumerate(data):
            p.store(base+i, byte)
    for base in (0x9100, 0x9300):
        for i in range(6):
            p.store(base+i, 0xee)
    p.store(0x80d0, 0)
    p.store(0x80d1, 0x10)
    p.emit(0x3e, 0x80, 0xed, 0x47, 0xed, 0x5e)  # I=80; IM2
    a, b = (0x9000, 0x9100) if a_source else (0x9100, 0x9000)
    for value in (0xc3, 0x7d if a_source else 0x79, a&255, a>>8,
                  3, 0, 0x14, 0x10, 0x80, 0x9d|(mode<<5), b&255, b>>8,
                  0x12, 0xd0, 0xba, 0xcf, 0xab, 0x87):
        f.out(0x1f80, value)
    if pending_delay:
        # Keep the CPU genuinely DI while the first auto-restart event waits
        # for ACK. No forced IEI, interrupt pins or stopped machine clocks.
        p.store(0xf012, 2)
        p.word(0x11, pending_delay)
        p.label("pending_delay")
        p.emit(0x1b, 0x7a, 0xb3)
        p.jump(0xc2, "pending_delay")
        p.store(0xf012, 0)
    p.emit(0xfb)
    p.label("main_wait")
    p.emit(0x76, 0xf3)
    p.word(0x3a, 0xf010)
    p.emit(0xfe, 3)
    p.jump(0xca, "complete")
    p.emit(0xfb)
    p.jump(0xc3, "main_wait")
    p.label("complete")
    for i, byte in enumerate(old):
        p.compare_memory(0x9100+i, byte)
    for i, byte in enumerate(new):
        p.compare_memory(0x9300+i, byte)
    for base in (0x9100, 0x9300):
        for i in (4, 5):
            p.compare_memory(base+i, 0xee)
    for i, byte in enumerate(b"RST!"):
        p.store(0xf000+i, byte)
    if visible:
        dma_visible.result(f, True)
    p.emit(0x76)
    p.label("fail")
    p.store(0xf000, 0xee)
    if visible:
        dma_visible.result(f, False)
    p.emit(0xf3, 0x76)
    assert len(p.code) < 0x1000
    p.code.extend(bytes(0x1000-len(p.code)))
    p.emit(0xf5, 0xc5, 0xd5)  # preserve AF/BC/DE in genuine handler
    f.out(0x1f80, 0xbf)
    f.check(0x1f80, 0x38, 0x38)  # EOB remains clear, IP cleared by ACK
    p.word(0x3a, 0xf010)
    p.emit(0x3c)
    p.word(0x32, 0xf010)
    p.emit(0xfe, 1)
    p.jump(0xc2, "after_update")
    na, nb = (0x9200, 0x9300) if a_source else (0x9300, 0x9200)
    for value in (0x1d if a_source else 0x19, na&255, na>>8,
                  0x8d|(mode<<5), nb&255, nb>>8, 0xbb, 0x7e, 0xa7):
        f.out(0x1f80, value)
    for value in (0, 0, a&255, a>>8, b&255, b>>8):
        f.check(0x1f80, value)
    p.store(0xf012, 1)
    p.word(0x11, delay)
    p.label("service_delay")
    p.emit(0x1b, 0x7a, 0xb3)
    p.jump(0xc2, "service_delay")
    p.store(0xf012, 0)
    p.label("after_update")
    # Check the second block before a third could conceal a redirected write.
    p.word(0x3a, 0xf010)
    p.emit(0xfe, 2)
    p.jump(0xc2, "choose_resume")
    for i in range(6):
        p.compare_memory(0x9300+i, 0xee)
    for i, byte in enumerate(old):
        p.compare_memory(0x9100+i, byte)
    p.label("choose_resume")
    p.word(0x3a, 0xf010)
    p.emit(0xfe, 3)
    p.jump(0xca, "stop_dma")
    f.out(0x1f80, 0x87)
    p.jump(0xc3, "return")
    p.label("stop_dma")
    f.out(0x1f80, 0x83)
    p.label("return")
    p.emit(0xd1, 0xc1, 0xf1, 0xfb, 0xed, 0x4d)
    return p.finish()


def run(exe, args):
    result = subprocess.run([str(exe), *map(str, args)], capture_output=True, text=True, timeout=300)
    assert result.returncode == 0, result.stderr
    return json.loads(result.stdout.splitlines()[-1])


def reject(exe, state):
    result = subprocess.run([str(exe), "--restore-state", str(state), "--cycles", "20000"],
                            capture_output=True, text=True, timeout=30)
    assert result.returncode == 2 and "snapshot version" in result.stderr, result.stderr


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=pathlib.Path)
    parser.add_argument("--sys-hz", type=int, default=32000000)
    parser.add_argument("--completion-only", type=pathlib.Path,
                        help="savable runner: test service snapshot and cross-profile rejection")
    args = parser.parse_args()
    exe = args.executable.resolve()
    digest = hashlib.sha256(exe.read_bytes()).hexdigest()
    print("runner_sha256="+digest, flush=True)
    control_digest = None
    if args.completion_only:
        control_digest = hashlib.sha256(args.completion_only.read_bytes()).hexdigest()
        print("completion_only_sha256="+control_digest, flush=True)
    with tempfile.TemporaryDirectory(prefix="x1-restart-service-") as temporary:
        root = pathlib.Path(temporary)
        ordinary = root/"ordinary.state"
        if args.completion_only:
            run(args.completion_only.resolve(), ["--cycles", 20000, "--save-state", ordinary])
            reject(exe, ordinary)
        for mode in (0, 1, 2):
            for a_source in (False, True):
                rom = root/"diag.rom"
                rom.write_bytes(diagnostic(a_source, mode))
                print(json.dumps({"mode": mode, "a_source": a_source, "sys_hz": args.sys_hz,
                                  "reference_cycles": 8000000,
                                  "ipl_sha256": hashlib.sha256(rom.read_bytes()).hexdigest()}), flush=True)
                direct = root/"direct"
                report = run(exe, ["--rom", rom, "--cycles", 8000000, "--dump", direct])
                assert report["sys_hz"] == args.sys_hz, report
                assert report["peek"].startswith(b"RST!".hex()) and report["halted"], report
                assert (report["dma_reads"], report["dma_writes"], report["dma_grants"]) == (12,12,12 if mode==0 else 3), report
                assert direct.with_suffix(".ram").read_bytes()[0xf010:0xf013] == b"\x03\x00\x00"
                if args.completion_only:
                    state, saved, resumed = root/"service.state", root/"saved", root/"resumed"
                    before = run(exe, ["--rom", rom, "--cycles", 200000,
                                       "--save-state", state, "--dump", saved])
                    ram = saved.with_suffix(".ram").read_bytes()
                    assert ram[0xf010]==1 and ram[0xf012]==1 and not before["halted"], before
                    evidence = {k:int(v,16) for k,v in (line.split("=") for line in saved.with_suffix(".dma").read_text().splitlines())}
                    assert evidence == dict(start_a=0x9200 if a_source else 0x9300,
                                            start_b=0x9300 if a_source else 0x9200,
                                            counter_a=0x9000 if a_source else 0x9100,
                                            counter_b=0x9100 if a_source else 0x9000,
                                            reload_destination=1, restart_profile=1, pending=0, in_service=1), evidence
                    saved_hash = hashlib.sha256(state.read_bytes()).hexdigest()
                    reject(args.completion_only.resolve(), state)
                    after = run(exe, ["--restore-state", state, "--cycles", 7800000, "--dump", resumed])
                    excluded = {"download_bytes", "video_hash"}
                    assert {k:v for k,v in after.items() if k not in excluded} == {k:v for k,v in report.items() if k not in excluded}
                    for suffix in ("ram", "text", "attr", "subram", "cpu", "dma"):
                        assert resumed.with_suffix("."+suffix).read_bytes() == direct.with_suffix("."+suffix).read_bytes(), suffix
                    assert hashlib.sha256(state.read_bytes()).hexdigest() == saved_hash
                    # Also serialize the new terminal event BEFORE ACK, not
                    # only its cleared value during the subsequent handler.
                    rom.write_bytes(diagnostic(a_source, mode, pending_delay=10000))
                    print(json.dumps({"mode": mode, "a_source": a_source, "snapshot_phase": "pending",
                                      "ipl_sha256": hashlib.sha256(rom.read_bytes()).hexdigest()}), flush=True)
                    pending = root/"pending.state"
                    pre = run(exe, ["--rom", rom, "--cycles", 200000,
                                    "--save-state", pending, "--dump", saved])
                    ram = saved.with_suffix(".ram").read_bytes()
                    assert ram[0xf010]==0 and ram[0xf012]==2 and not pre["halted"], pre
                    assert (pre["dma_reads"], pre["dma_writes"]) == (4,4), pre
                    values = {k:int(v,16) for k,v in (line.split("=") for line in saved.with_suffix(".dma").read_text().splitlines())}
                    assert values == dict(start_a=0x9000 if a_source else 0x9100,
                                          start_b=0x9100 if a_source else 0x9000,
                                          counter_a=0x9000 if a_source else 0x9100,
                                          counter_b=0x9100 if a_source else 0x9000,
                                          reload_destination=1, restart_profile=1, pending=1, in_service=0), values
                    state_hash = hashlib.sha256(pending.read_bytes()).hexdigest()
                    reject(args.completion_only.resolve(), pending)
                    after = run(exe, ["--restore-state", pending, "--cycles", 7800000, "--dump", resumed])
                    fresh = run(exe, ["--rom", rom, "--cycles", 8000000, "--dump", direct])
                    assert after["halted"] and after["peek"].startswith(b"RST!".hex()), after
                    assert {k:v for k,v in after.items() if k not in excluded} == {k:v for k,v in fresh.items() if k not in excluded}
                    assert (after["dma_reads"], after["dma_writes"]) == (12,12), after
                    for suffix in ("ram", "text", "attr", "subram", "cpu", "dma"):
                        assert resumed.with_suffix("."+suffix).read_bytes() == direct.with_suffix("."+suffix).read_bytes(), suffix
                    assert hashlib.sha256(pending.read_bytes()).hexdigest() == state_hash
                assert hashlib.sha256(exe.read_bytes()).hexdigest() == digest
                if args.completion_only:
                    assert hashlib.sha256(args.completion_only.read_bytes()).hexdigest() == control_digest
                print(f"PASS shared restart mode={mode} A_source={a_source}: 3 blocks/handlers/RETI, buffered guards"
                      + (", executing pending/IUS/reload snapshots and profile rejection" if args.completion_only else ""), flush=True)


if __name__ == "__main__":
    main()
