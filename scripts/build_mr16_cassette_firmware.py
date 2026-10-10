#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Original cassette-only replacement-MR16 extension linker.

Not Sharp MCU firmware, native deck timing, or an enabled machine feature.
Inherited sources/notices remain intact in disposable derived copies. OP5 is
exclusive to this RTC-disabled experiment. No host mailbox is synthesized.
"""
import argparse
import hashlib
import json
import pathlib
import re
import shutil
import tempfile

from assemble_mr16 import AssemblyError, assemble, encode

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / "bios/reference/fw_subcpu"
BASE_SHA = "2d9c9745e0a1a09d98c0e14ace627c03cd39d71ceb21e3fef5957e7a62428c01"

# Original extension, deliberately no new RAM allocation. GPIO input PORT1
# preserves bits5:0; bits7:6 are applied mode, bits15:8 are live sensor byte.
# EB 00/03/02 and zero upper bits are provisional read-only virtual-deck policy.
EXTENSION = """
; SPDX-License-Identifier: GPL-2.0-only
; Original cassette-only extension; not native 80C49 or CZ-8RL1 firmware.
; PORT5 OUTPUT: command[7:0], commit[8]. PORT5 INPUT remains HWD_CLR.
; PORT1 INPUT: applied mode[7:6], live EB[15:8], inherited status[5:0].
    cseg
    org 4000h
cassette_start:
    mov r0,#CMT_STOP:8
    jsr cassette_set
    jmp start

; r0=request; clobbers r0/r2 and arithmetic flags, preserves r1/r3..r14.
; POP FLAG does not restore IF in mr16core: restore saved bit4 explicitly.
; No wait or host access while interrupts are disabled.
cassette_set:
    cmp r0,#CMT_EJECT:8
    beq cassette_set_supported
    cmp r0,#CMT_STOP:8
    beq cassette_set_supported
    cmp r0,#CMT_PLAY:8
    beq cassette_set_supported
    ret
cassette_set_supported:
    push flag
    cli
    stm (r14,#PORT5-R14_BASE),r0
    or r0,#100h
    stm (r14,#PORT5-R14_BASE),r0
    pop r2
    tst r2,#10h:8
    beq cassette_set_return
    sti
cassette_set_return:
    ret

; One coherent GPIO read. Never read PORT5 for sensors (that clears HWD).
; r0/r2 clobbered; no host flag or GPIO output store.
cassette_refresh:
    ldm r2,(r14,#HOST_STS-R14_BASE)
    mov r0,r2
    shr r0,#6
    and r0,#3:8
    stm (r13,#cmt_ctrl-X1_WORK_BASE),r0
    mov r0,r2
    shr r0,#8
    and r0,#0ffh:8
    stm (r13,#cmt_sens-X1_WORK_BASE),r0
    ret

cassette_cmd_e9:
    jsr host_r
    ; host_r has advanced r0 and cleared r1. Reload the actual received word.
    ldm r0,(r13,#cmt_ctrl-X1_WORK_BASE)
    and r0,#0ffh:8
    jsr cassette_set
    jmp cassette_refresh
cassette_cmd_ea:
    jsr cassette_refresh
    mov r0,#cmt_ctrl
    mov r1,#1:8
    jmp host_w
cassette_cmd_eb:
    jsr cassette_refresh
    mov r0,#cmt_sens
    mov r1,#1:8
    jmp host_w

; Refresh before inherited PLAY/REC keyboard-IRQ suppression, including EOF.
cassette_key_irq:
    push r0
    push r2
    jsr cassette_refresh
    pop r2
    pop r0
    jmp key_irq

; Caller packs ASCII[15:8] and CTRL[7:0], but inherited brk_ctrl expects ASCII.
; Normalize ONLY this cassette extension, then preserve its host/IRQ code.
; Forward normalized ASCII, including the non-BREAK release path.
cassette_brk_ctrl:
    shr r0,#8
    and r0,#0ffh:8
    cmp r0,#03h:8
    bne cassette_brk_tail
    push r0
    push r2
    mov r0,#CMT_STOP:8
    jsr cassette_set
    pop r2
    pop r0
cassette_brk_tail:
    jmp brk_ctrl
cassette_extension_end:
"""


def instruction(op, operands, symbols):
    """Exact assembler encoding used for bounded redirection-site validation."""
    from assemble_mr16 import expression
    words = encode(op, operands, lambda value: expression(value, symbols, 0), 0, True)
    return b"".join(word.to_bytes(2, "little") for word in words)


def patch_sites(baseline, symbols):
    sites = []
    for op, operand, target in (("mov", "r0,#start", "cassette_start"),
                                ("jsr", "key_irq", "cassette_key_irq"),
                                ("jsr", "brk_ctrl", "cassette_brk_ctrl")):
        old = instruction(op, operand, symbols)
        matches = [i for i in range(0, 4096 - len(old) + 1, 2)
                   if baseline[i:i + len(old)] == old]
        if len(old) != 4 or len(matches) != 1:
            raise AssemblyError(f"ambiguous/non-wide hook site: {operand}")
        sites.append((matches[0], op, operand, target))
    return sites


def validate(image, symbols, baseline, original, sites):
    if len(image) != 8192:
        raise AssemblyError("cassette image must be exactly 8192 packed bytes")
    for name, address in original.items():
        if symbols.get(name) != address:
            raise AssemblyError(f"inherited symbol moved: {name}")
    if not 0x4000 < symbols["cassette_extension_end"] < 0x5000:
        raise AssemblyError("cassette extension exceeds upper ROM bank")
    if (symbols["cmt_ctrl"], symbols["cmt_sens"]) != (0x1088, 0x108A):
        raise AssemblyError("inherited cassette work allocation changed")
    expected = bytearray(baseline)
    allowed = set()
    for address, op, operand, target in sites:
        replacement = instruction(op, "r0,#" + target if op == "mov" else target, symbols)
        if len(replacement) != 4:
            raise AssemblyError("hook instruction changed size")
        expected[address:address + 4] = replacement
        allowed.update(range(address, address + 4))
    for command in (9, 10, 11):
        address = original["cmd_tbl"] + 4 * command
        expected[address:address + 2] = symbols[f"cassette_cmd_e{command:x}"].to_bytes(2, "little")
        allowed.update((address, address + 1))
    if image[:4096] != expected:
        raise AssemblyError("low ROM differs from exact hook patch ledger")
    changed = {i for i in range(4096) if image[i] != baseline[i]}
    if not changed or not changed <= allowed:
        raise AssemblyError("low ROM change outside allowlist")
    return sorted(allowed), sorted(changed)


def build(receive_only=False, with_report=False):
    inputs = [pathlib.Path(__file__), ROOT / "scripts/assemble_mr16.py"] + \
             sorted(SOURCE.glob("*.asm")) + sorted(SOURCE.glob("*.inc")) + \
             [SOURCE / "verilog/X1SUB.BIN"]
    frozen = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
    defines = {"ps2_receive_only": 1} if receive_only else {}
    pristine, _, _ = assemble(SOURCE / "x1sub.asm")
    if hashlib.sha256(pristine).hexdigest() != BASE_SHA:
        raise AssemblyError("inherited firmware no longer matches saved artifact")
    baseline, original, locations = assemble(SOURCE / "x1sub.asm", defines)
    if locations["dseg"] != 0x1156 or original["ram_end"] != 0x1800:
        raise AssemblyError("inherited 2KiB RAM/allocation contract changed")
    sites = patch_sites(baseline, original)
    text = (SOURCE / "x1sub.asm").read_text(encoding="latin1")
    substitutions = [
        (r"(?m)^(\s*mov\s+r0,\s*#)start(\s*;entry point.*)$", r"\1cassette_start\2"),
        (r"(?m)^(\s*jsr\s+)key_irq(\s*)$", r"\1cassette_key_irq\2"),
        (r"(?m)^(\s*jsr\s+)brk_ctrl(\s*)$", r"\1cassette_brk_ctrl\2"),
    ]
    for command, handler, pointer in (("e9", "CMD_E9", "cmt_ctrl"),
                                      ("ea", "host_w", "cmt_ctrl"),
                                      ("eb", "host_w", "cmt_sens")):
        substitutions.append((rf"(?mi)^(\s*dw\s+){handler}(\s*,\s*{pointer}\s*;{command}\b.*)$",
                              rf"\1cassette_cmd_{command}\2"))
    for pattern, replacement in substitutions:
        text, count = re.subn(pattern, replacement, text)
        if count != 1:
            raise AssemblyError("missing/ambiguous cassette firmware source hook")
    with tempfile.TemporaryDirectory(prefix="x1-cassette-firmware-link-") as directory:
        scratch = pathlib.Path(directory)
        for pattern in ("*.inc", "*.asm"):
            for item in SOURCE.glob(pattern):
                shutil.copy2(item, scratch / item.name)
        (scratch / "x1sub.asm").write_text(text + "\n" + EXTENSION, encoding="latin1")
        flat, symbols, linked_locations = assemble(scratch / "x1sub.asm", defines, rom_size=0x5000)
    if linked_locations["dseg"] != locations["dseg"]:
        raise AssemblyError("extension added or moved work RAM")
    if flat[0x1000:0x4000] != b"\xff" * 0x3000:
        raise AssemblyError("ROM emission in RAM/unmapped holes")
    padding = len((SOURCE / "verilog/X1SUB.BIN").read_bytes())
    if padding != 0x0FE9 or baseline[padding:] != bytes(4096 - padding):
        raise AssemblyError("inherited converter padding changed")
    low = bytearray(flat[:4096])
    low[padding:] = baseline[padding:]
    image = bytes(low) + flat[0x4000:0x5000]
    allowed, changed = validate(image, symbols, baseline, original, sites)
    for name, digest in frozen.items():
        if hashlib.sha256((ROOT / name).read_bytes()).hexdigest() != digest:
            raise AssemblyError(f"source changed during cassette link: {name}")
    report = {"scope": "static link/parity only; MR16/machine execution unqualified",
              "receive_only": receive_only, "image_sha256": hashlib.sha256(image).hexdigest(),
              "baseline_sha256": hashlib.sha256(baseline).hexdigest(),
              "allowed_low_bytes": allowed, "changed_low_bytes": changed,
              "sites": sites, "extension_end": symbols["cassette_extension_end"],
              "ram_allocation_end": linked_locations["dseg"],
              "inputs": frozen}
    return (image, symbols, report) if with_report else (image, symbols)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--receive-only", action="store_true")
    parser.add_argument("--output-dir", type=pathlib.Path,
                        help="new directory under /tmp or ignored repository output_files")
    args = parser.parse_args()
    image, symbols, report = build(args.receive_only, with_report=True)
    if args.output_dir:
        dest = args.output_dir.resolve()
        roots = (pathlib.Path(tempfile.gettempdir()).resolve(), pathlib.Path("/tmp").resolve(),
                 (ROOT / "output_files").resolve())
        if not any(root in dest.parents for root in roots):
            parser.error("output directory must be disposable tmp or ignored output_files")
        dest.mkdir(parents=True, exist_ok=False)
        (dest / "cassette-controller.bin").write_bytes(image)
        (dest / "symbols.json").write_text(json.dumps(symbols, sort_keys=True, indent=2) + "\n")
        (dest / "manifest.json").write_text(json.dumps(report, sort_keys=True, indent=2) + "\n")
    print(json.dumps(report, sort_keys=True))


if __name__ == "__main__":
    main()
