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
# Sensor bit 7 carries applied mode bit 2 (REW/APSS 4-6): EA reads modes 0-6.
EXTENSION = """
; SPDX-License-Identifier: GPL-2.0-only
; Original cassette-only extension; not native 80C49 or CZ-8RL1 firmware.
; PORT5 OUTPUT: command[7:0], commit[8]. PORT5 INPUT remains HWD_CLR.
; PORT1 INPUT: applied mode[1:0] at [7:6], live EB[14:8], mode bit 2 at [15],
; inherited status[5:0].
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
    cmp r0,#CMT_FF:8
    beq cassette_set_supported
    cmp r0,#CMT_REW:8
    beq cassette_set_supported
    cmp r0,#CMT_APSS_F:8
    beq cassette_set_supported
    cmp r0,#CMT_APSS_R:8
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
    tst r2,#8000h
    beq cassette_refresh_mode
    or r0,#4:8
cassette_refresh_mode:
    stm (r13,#cmt_ctrl-X1_WORK_BASE),r0
    mov r0,r2
    shr r0,#8
    and r0,#07fh:8
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
; Running clock for EF (time read): the inherited 500-ms ISR only toggled
; the 1-Hz blink bit (its clock branch is commented out and has no target),
; so EF always read 00:00:00 and Rally-X seeded its generator with zero.
; Replaces the ISR's "add r0,#500000/8"; r0 is the next compare value and
; must come back as the inherited add left it. Called with interrupts off.
; time bytes (host_w order): +0 hour, +1 minute, +2 second, all BCD.
cassette_clock:
    add r0,#500000/8
    push r0
    push r1
    push r2
    push r3
    ; once a second: the blink bit is still set here and cleared after us
    ldm r1,(r14,#HOST_CTRL-R14_BASE)
    tst r1,#CLK_1HZ:8
    beq cassette_clock_done
    mov r0,#time+2
    ldm r3,(r0)
    mov r1,r3
    and r1,#0ffh:8
    mov r2,#60h:8
    jsr cassette_bcd_inc
    and r3,#0ff00h
    or r3,r1
    stm (r0),r3
    cmp r1,#0:8
    bne cassette_clock_done
    mov r0,#time
    ldm r3,(r0)
    mov r1,r3
    shr r1,#8
    mov r2,#60h:8
    jsr cassette_bcd_inc
    mlt r1,#100h
    and r3,#0ffh:8
    or r3,r1
    cmp r1,#0:8
    bne cassette_clock_store
    mov r1,r3
    mov r2,#24h:8
    jsr cassette_bcd_inc
    mov r3,r1
cassette_clock_store:
    stm (r0),r3
cassette_clock_done:
    pop r3
    pop r2
    pop r1
    pop r0
    ret

; r1 = BCD byte (upper byte zero), r2 = wrap value; r1 = next, 0 at the wrap.
; Clobbers r3 and flags.
cassette_bcd_inc:
    mov r3,r1
    and r3,#0fh:8
    cmp r3,#9:8
    beq cassette_bcd_ten
    add r1,#1:8
    bra cassette_bcd_wrap
cassette_bcd_ten:
    add r1,#7:8
cassette_bcd_wrap:
    cmp r1,r2
    bne cassette_bcd_return
    mov r1,#0:8
cassette_bcd_return:
    ret
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
                                ("jsr", "brk_ctrl", "cassette_brk_ctrl"),
                                ("add", "r0,#500000/8", "cassette_clock")):
        old = instruction(op, operand, symbols)
        matches = [i for i in range(0, 4096 - len(old) + 1, 2)
                   if baseline[i:i + len(old)] == old]
        if len(old) != 4 or len(matches) != 1:
            raise AssemblyError(f"ambiguous/non-wide hook site: {operand}")
        sites.append((matches[0], op, operand, target))
    return sites


# Optional board defaults, each exactly one changed low-ROM instruction:
# - joystick: start with PS/2 joystick emulation off. MiSTer joysticks already
#   drive the PSG ports, and the emulation consumes A/Z/X/C and the keypad
#   (C is the IPL's CMT key); F12, which toggles it, opens the MiSTer OSD.
# - caps: start with CAPS LOCK released, as on MAME/real keyboards; with CAPS
#   on, the E6 game-key status reads F7 and games (Dione) stall.
OPTIONAL_PATCHES = {
    "joystick": (r"(?m)^(\s*mov\s+r0,\s*#)JOY_EN \| (IND_REQ:8.*)$",
                 ("mov", "r0,#JOY_EN | IND_REQ:8"), ("mov", "r0,#IND_REQ:8")),
    "caps": (r"(?m)^(\s*mov\s+r0,\s*#0ffffh) \^ SFT_CAPS(.*)$",
             ("mov", "r0,#0ffffh ^ SFT_CAPS"), ("mov", "r0,#0ffffh")),
}


def optional_site(baseline, defines, symbols, name):
    """Locate one optional patch by assembling the substituted source."""
    pattern, old_op, new_op = OPTIONAL_PATCHES[name]
    text = (SOURCE / "x1sub.asm").read_text(encoding="latin1")
    text, count = re.subn(pattern, r"\1\2", text)
    if count != 1:
        raise AssemblyError(f"missing/ambiguous {name} default source line")
    with tempfile.TemporaryDirectory(prefix="x1-cassette-option-") as directory:
        scratch = pathlib.Path(directory)
        for glob in ("*.inc", "*.asm"):
            for item in SOURCE.glob(glob):
                shutil.copy2(item, scratch / item.name)
        (scratch / "x1sub.asm").write_text(text, encoding="latin1")
        patched, _, _ = assemble(scratch / "x1sub.asm", defines)
    changed = [i for i in range(len(baseline)) if patched[i] != baseline[i]]
    old = instruction(*old_op, symbols)
    new = instruction(*new_op, symbols)
    if not changed or len(old) != len(new):
        raise AssemblyError(f"{name} patch has no single-instruction effect")
    # The change may sit in an immediate word: find where the encoding starts.
    starts = [a for a in range((changed[0] & ~1) - len(old) + 2, (changed[0] & ~1) + 1, 2)
              if a >= 0 and baseline[a:a + len(old)] == old and patched[a:a + len(new)] == new]
    address = starts[0] if len(starts) == 1 else -1
    if address < 0 or changed[-1] >= address + len(old):
        raise AssemblyError(f"{name} patch is not exactly one instruction")
    return name, address, len(old)


def validate(image, symbols, baseline, original, sites, options=()):
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
        replacement = (instruction("mov", "r0,#" + target, symbols) if op == "mov"
                       else instruction("jsr", target, symbols))
        if len(replacement) != 4:
            raise AssemblyError("hook instruction changed size")
        expected[address:address + 4] = replacement
        allowed.update(range(address, address + 4))
    for name, address, size in options:
        expected[address:address + size] = instruction(*OPTIONAL_PATCHES[name][2], symbols)
        allowed.update(range(address, address + size))
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


def build(receive_only=False, with_report=False, joystick_off=False, caps_off=False):
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
    chosen = [n for n, on in (("joystick", joystick_off), ("caps", caps_off)) if on]
    options = [optional_site(baseline, defines, original, n) for n in chosen]
    text = (SOURCE / "x1sub.asm").read_text(encoding="latin1")
    substitutions = [
        (r"(?m)^(\s*mov\s+r0,\s*#)start(\s*;entry point.*)$", r"\1cassette_start\2"),
        (r"(?m)^(\s*jsr\s+)key_irq(\s*)$", r"\1cassette_key_irq\2"),
        (r"(?m)^(\s*jsr\s+)brk_ctrl(\s*)$", r"\1cassette_brk_ctrl\2"),
        (r"(?m)^(\s*)add(\s+)r0,#500000/8(\s*;next 500ms.*)$", r"\1jsr\2cassette_clock\3"),
    ]
    for command, handler, pointer in (("e9", "CMD_E9", "cmt_ctrl"),
                                      ("ea", "host_w", "cmt_ctrl"),
                                      ("eb", "host_w", "cmt_sens")):
        substitutions.append((rf"(?mi)^(\s*dw\s+){handler}(\s*,\s*{pointer}\s*;{command}\b.*)$",
                              rf"\1cassette_cmd_{command}\2"))
    for name in chosen:
        substitutions.append((OPTIONAL_PATCHES[name][0], r"\1\2"))
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
    allowed, changed = validate(image, symbols, baseline, original, sites, options)
    for name, digest in frozen.items():
        if hashlib.sha256((ROOT / name).read_bytes()).hexdigest() != digest:
            raise AssemblyError(f"source changed during cassette link: {name}")
    report = {"scope": "static link/parity only; MR16/machine execution unqualified",
              "receive_only": receive_only, "joystick_off": joystick_off, "caps_off": caps_off, "image_sha256": hashlib.sha256(image).hexdigest(),
              "baseline_sha256": hashlib.sha256(baseline).hexdigest(),
              "allowed_low_bytes": allowed, "changed_low_bytes": changed,
              "sites": sites, "extension_end": symbols["cassette_extension_end"],
              "ram_allocation_end": linked_locations["dseg"],
              "inputs": frozen}
    return (image, symbols, report) if with_report else (image, symbols)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--receive-only", action="store_true")
    parser.add_argument("--joystick-off", action="store_true",
                        help="board default: PS/2 joystick emulation starts disabled")
    parser.add_argument("--caps-off", action="store_true",
                        help="board default: CAPS LOCK starts released (E6 status FF)")
    parser.add_argument("--output-dir", type=pathlib.Path,
                        help="new directory under /tmp or ignored repository output_files")
    args = parser.parse_args()
    image, symbols, report = build(args.receive_only, with_report=True, joystick_off=args.joystick_off, caps_off=args.caps_off)
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
