"""Native-programmed DMA IUS save/restore and DMA/IRQ profile rejection.

No snapshot edits, debug injection, forced interrupts or private firmware.
CPU publishes a phase marker then spends real instructions in its handler;
snapshots must resume both real DMA service and subsequent CPU blocks.
"""
import json
import pathlib
import subprocess
import sys
import tempfile
from test_machine_dma_irq import diagnostic


def run(exe, args):
    result = subprocess.run([exe, *map(str, args)], capture_output=True, text=True, timeout=300)
    assert result.returncode == 0, (args, result.stderr)
    return json.loads(result.stdout.splitlines()[-1])


def reject(exe, state):
    result = subprocess.run([exe, "--restore-state", str(state), "--cycles", "20000"],
                            capture_output=True, text=True, timeout=30)
    assert result.returncode == 2 and "snapshot version" in result.stderr, result


def main():
    irq_exe, plain_exe = (str(pathlib.Path(arg).resolve()) for arg in sys.argv[1:3])
    with tempfile.TemporaryDirectory(prefix="x1-dma-irq-state-") as directory:
        root = pathlib.Path(directory)
        ordinary = root / "ordinary.state"
        run(plain_exe, ["--cycles", 20000, "--save-state", ordinary])
        reject(irq_exe, ordinary)
        for profile in range(4):
            rom = root / f"profile-{profile}.rom"
            code, payload, reads, writes, flags = diagnostic(profile, handler_delay=10000)
            rom.write_bytes(code)
            state = root / f"profile-{profile}.state"
            saved = root / f"saved-{profile}"
            before = run(irq_exe, ["--rom", rom, "--cycles", 200000, "--save-state", state,
                                   "--dump", saved])
            ram = saved.with_suffix(".ram").read_bytes()
            assert ram[0xF010] == 0 and ram[0xF012] == 1 and not before["halted"], \
                (profile, before, ram[0xF010:0xF013].hex())
            reject(plain_exe, state)
            resumed, straight = root / f"resumed-{profile}", root / f"straight-{profile}"
            after = run(irq_exe, ["--restore-state", state, "--cycles", 7800000, "--dump", resumed])
            direct = run(irq_exe, ["--rom", rom, "--cycles", 8000000, "--dump", straight])
            # These host accumulators describe this invocation's window, not
            # serialized machine state. Compare every other report field.
            host_window = {"download_bytes", "video_hash"}
            assert {k: v for k, v in after.items() if k not in host_window} == \
                {k: v for k, v in direct.items() if k not in host_window}, (profile, after, direct)
            assert after["turbo_dma_irq"] and after["halted"] and after["peek"].startswith(b"IRQ!".hex()), after
            assert (after["dma_reads"], after["dma_writes"], after["dma_grants"]) == \
                (2 * reads, 2 * writes, 4 if profile == 2 else 2), after
            for suffix in ("ram", "text", "attr", "subram", "cpu"):
                assert resumed.with_suffix(f".{suffix}").read_bytes() == \
                    straight.with_suffix(f".{suffix}").read_bytes(), (profile, suffix)
            final_ram = resumed.with_suffix(".ram").read_bytes()
            assert final_ram[0xF010] == 2 and final_ram[0xF011] & 0x38 == flags and final_ram[0xF012] == 0
            assert final_ram[0x9000:0x9006] == payload
            assert final_ram[0x9100:0x9106] == payload[:writes] + bytes([0xCC] * (6 - writes))
            print(f"PASS DMA IRQ snapshot profile={profile}: native handler service checkpoint, "
                  "two complete blocks/RETI/guards, exact report and all RAM/CPU dumps, bidirectional profile rejection", flush=True)


if __name__ == "__main__":
    main()
