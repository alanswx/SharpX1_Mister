"""Original Z80 IM2 diagnostic: CTC timers/cascade and native MR16 coexistence.

No commercial ROM, snapshots or CPU internals are used. Deterministic cold
repeat includes full RAM/report; PASS is not authentic Turbo boot evidence.
"""
import json
import pathlib
import subprocess
import sys
import tempfile
from z80_fixture import Program


def output(p, port, value):
    p.word(0x01, port)
    p.emit(0x3E, value, 0xED, 0x79)


def fixture(keyboard):
    p = Program(0x8000)
    p.emit(0xF3)
    p.word(0x31, 0xFFFF)
    for address in range(0xF000, 0xF040):
        p.store(address, 0)
    for ch in range(4):
        handler = 0x8500 + ch * 0x40
        p.store(0x9040 + ch * 2, handler & 255)
        p.store(0x9041 + ch * 2, handler >> 8)
    p.store(0x9052, 0)
    p.store(0x9053, 0x86)
    output(p, 0x1A03, 0x82)
    p.word(0x01, 0x1A02)
    p.emit(0xED, 0x78)  # Clear DAM.
    # A stopped trigger-wait timer must retain its loaded constant; mirror
    # readback also catches accidental repeated writes of the same bus strobe.
    output(p, 0x1FA0, 0x1F)
    output(p, 0x1FA8, 0x37)
    for port in (0x1FA0, 0x1FA8):
        p.word(0x01, port)
        p.emit(0xED, 0x78, 0xFE, 0x37)
        p.jump(0xC2, "fail")
    output(p, 0x1FA0, 0x03)
    # Integrated channels 1/2 see the board's continuous 2 MHz triggers.
    # Exercise both edge polarities with interrupts masked, then replace them
    # with the timer setup below. Rate/phase contract is separately documented.
    for ch, control in ((1, 0x57), (2, 0x47)):
        output(p, 0x1FA0 + ch, control)
        output(p, 0x1FA8 + ch, 0)
        for sample in range(4):
            p.word(0x01, 0x1FA0 + ch)
            p.emit(0xED, 0x78)
            p.word(0x32, 0xF040 + (ch-1)*4 + sample)
    if keyboard:
        for index, value in enumerate((0xE4, 0x52)):
            p.word(0x01, 0x1A01)
            p.label(f"tx{index}")
            p.emit(0xED, 0x78, 0xE6, 0x40)
            p.jump(0xC2, f"tx{index}")
            output(p, 0x1900, value)
    output(p, 0x1FA8, 0x40)  # Vector channel 0 via mirror.
    output(p, 0x1FA3, 0xD7)  # Counter/rising, IRQ; two ch0 terminal pulses.
    output(p, 0x1FAB, 2)
    for ch, constant in enumerate((128, 160, 224)):
        output(p, 0x1FA0 + ch, 0xB7)  # Auto timer /256, IRQ, new constant.
        output(p, 0x1FA8 + ch, constant)
    p.emit(0x3E, 0x90, 0xED, 0x47, 0xED, 0x5E)  # I=90; IM2.
    p.store(0xF000, ord("C"))
    p.emit(0xFB)
    p.label("loop")
    p.emit(0x76)
    p.jump(0xC3, "loop")
    p.label("fail")
    p.store(0xF000, 0xEE)
    p.emit(0x76)
    for ch in range(4):
        address = 0x8500 + ch * 0x40
        assert len(p.code) <= address - p.origin
        p.code.extend(bytes(address - p.origin - len(p.code)))
        p.emit(0xF5)
        p.word(0x3A, 0xF010 + ch)
        p.emit(0x3C)
        p.word(0x32, 0xF010 + ch)
        if ch == 1:
            p.emit(0xDD, 0x21, 0x00, 0xF2)  # IX=F200
            p.emit(0xDD, 0xCB, 0x00, 0x46)  # BIT 0,(IX), non-M1 tail
        if ch == 2:
            p.emit(0xFD, 0x21, 0x00, 0xF2)  # IY=F200
            p.emit(0xFD, 0xCB, 0x00, 0x46)  # BIT 0,(IY)
        p.emit(0xF1, 0xFB, 0xED, 0x4D)
    p.code.extend(bytes(0x8600 - p.origin - len(p.code)))
    p.emit(0xF5, 0xC5, 0xE5)
    for index in range(2):
        p.word(0x01, 0x1A01)
        p.label(f"rx{index}")
        p.emit(0xED, 0x78, 0xE6, 0x20)
        p.jump(0xC2, f"rx{index}")
        p.word(0x01, 0x1900)
        p.emit(0xED, 0x78)
        p.word(0x32, 0xF030 + index)
    p.word(0x3A, 0xF020)
    p.emit(0x87, 0x6F, 0x26, 0xF1)
    for index in range(2):
        p.word(0x3A, 0xF030 + index)
        p.emit(0x77, 0x23)
    p.word(0x3A, 0xF020)
    p.emit(0x3C)
    p.word(0x32, 0xF020)
    p.emit(0xE1, 0xC1, 0xF1, 0xFB, 0xED, 0x4D)
    return p.finish()


exe = str(pathlib.Path(sys.argv[1]).resolve())
with tempfile.TemporaryDirectory(prefix="x1-ctc-") as directory:
    root = pathlib.Path(directory)
    keys = root / "cold.keys"
    keys.write_text("25 2b\n45 f0\n47 2b\n60 43\n80 f0\n82 43\n100 3b\n120 f0\n122 3b\n")
    for keyboard in (False, True):
        ram = root / "ctc.bin"
        ram.write_bytes(fixture(keyboard))
        evidence = []
        for repeat in range(2):
            dump = root / f"{int(keyboard)}-{repeat}"
            args = [exe, "--cycles", "4800000", "--ram", str(ram), "--dump", str(dump)]
            if keyboard:
                args += ["--keys", str(keys)]
            result = subprocess.run(args, check=True, capture_output=True, text=True, timeout=180)
            report = json.loads(result.stdout.splitlines()[-1])
            memory = dump.with_suffix(".ram").read_bytes()
            assert report["turbo_foundation"], report
            assert memory[0xF000] == ord("C"), (report, memory[0xF000:0xF040].hex())
            counts = list(memory[0xF010:0xF014])
            assert all(value >= 5 for value in counts), (counts, report)
            assert counts[0] >= counts[1] >= counts[2], counts
            assert abs(counts[0] - 2 * counts[3]) <= 1, counts
            for start in (0xF040, 0xF044):
                assert len(set(memory[start:start+4])) >= 3, memory[0xF040:0xF048].hex()
            if keyboard:
                expected = bytes.fromhex("b746f700b749f700b74af700")
                assert memory[0xF020] == 6, (memory[0xF020], report)
                assert memory[0xF100:0xF10C] == expected, memory[0xF100:0xF110].hex()
                assert report["ps2_bytes_sent"] == 9, report
            evidence.append((report, memory))
        assert evidence[0] == evidence[1], "cold repeats differ"
        print(json.dumps({"keyboard": keyboard, "irq_counts": counts,
                          "sys_hz": report["sys_hz"], "duration_ps": report["time_ps"]}), flush=True)
print("PASS: CPU CTC mirrored register writes/readback, all four IM2 vectors, periodic RETI, channel0/3 cascade and native cold F/I/J make/break coexistence")
