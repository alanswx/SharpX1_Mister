#!/usr/bin/env python3
"""Restricted MR16 firmware assembler; not an AASM implementation.

Original Python implementation. Encoding reference: inherited
bios/reference/fw_subcpu/MR16.MAC (AASM 3.71, 2007-03-30) and rtl/mr16core.v.
The inherited firmware and its notices remain unchanged. Require byte parity
before using this tool for firmware changes. Unknown syntax fails closed.
"""
import argparse
import ast
import operator
import pathlib
import re


class AssemblyError(ValueError):
    pass


ALU = {name: i for i, name in enumerate(
    ["", "", "", "", "and", "or", "xor", "mov", "add", "sub", "adc", "sbc", "tst", "cmp", "mlt", "mlh"]) if name}
BRANCH = dict(zip("blo beq bvs bmi bls blt ble unused bhs bne bvc bpl bhi bge bgt bra".split(), range(16)))
BRANCH.pop("unused")  # Reserved prefix index is not an instruction mnemonic.
BRANCH.update(bcs=0, bcc=8)
JUMP = {"j" + name[1:]: value for name, value in BRANCH.items()}
JUMP.pop("jra")
JUMP["jmp"] = 15
# The inherited absolute-Jcc macro does not mask the alias table index.
# Preserve its actual historical bytes, including JCS=16/JCC=24; do not
# silently turn artifact reproduction into an ISA/macro correction.
JUMP.update(jcs=16, jcc=24)
FLAGS = {"clc": 2, "stc": 3, "clz": 4, "stz": 5, "cli": 8, "sti": 9}
OPS = set(ALU) | set(BRANCH) | set(JUMP) | set(FLAGS) | {
    "ldm", "stm", "ldw", "ldb", "stw", "stb", "ret", "pop", "push", "nop", "jsr", "shr",
    "equ", "ds", "defs", "dw", "db", "org", "cseg", "dseg", ".align", "end", "include"}


def expression(text, symbols, pc, unresolved=False):
    text = re.sub(r"\b([0-9][0-9a-f]*)h\b", r"0x\1", text.lower()).replace("$", "__pc")
    operations = {ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul,
                  ast.Div: operator.floordiv, ast.FloorDiv: operator.floordiv,
                  ast.Mod: operator.mod, ast.LShift: operator.lshift, ast.RShift: operator.rshift,
                  ast.BitOr: operator.or_, ast.BitAnd: operator.and_, ast.BitXor: operator.xor}

    def visit(node):
        if isinstance(node, ast.Constant) and type(node.value) is int:
            return node.value
        if isinstance(node, ast.Name):
            if node.id == "__pc":
                return pc
            if node.id in symbols:
                return symbols[node.id]
            if unresolved:
                return 0
            raise AssemblyError(f"undefined symbol {node.id}")
        if isinstance(node, ast.BinOp) and type(node.op) in operations:
            return operations[type(node.op)](visit(node.left), visit(node.right))
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, (ast.UAdd, ast.USub, ast.Invert)):
            return {ast.UAdd: operator.pos, ast.USub: operator.neg, ast.Invert: operator.invert}[type(node.op)](visit(node.operand))
        raise AssemblyError(f"unsupported expression {text!r}")

    try:
        return visit(ast.parse(text, mode="eval").body)
    except (SyntaxError, ZeroDivisionError) as exc:
        raise AssemblyError(f"invalid expression {text!r}") from exc


def reg(text):
    match = re.fullmatch(r"r(\d+)", text.strip().lower())
    if not match or not 0 <= int(match[1]) <= 15:
        raise AssemblyError(f"invalid register {text}")
    return int(match[1])


def arguments(text):
    # Commas inside addressing parentheses are not operand separators.
    return [part.strip() for part in re.split(r",(?![^()]*\))", text)] if text else []


def encode(op, operands, value, pc, strict):
    args = arguments(operands)
    if pc & 1:
        raise AssemblyError("instruction at odd address")
    if op in ALU:
        if len(args) != 2:
            raise AssemblyError("ALU requires two operands")
        dest = reg(args[0])
        if not args[1].startswith("#"):
            return [0x3000 | dest << 8 | reg(args[1]) << 4 | ALU[op]]
        immediate = args[1][1:]
        size = None
        if ":" in immediate:
            immediate, size = immediate.rsplit(":", 1)
            size = value(size)
            if size not in (8, 16):
                raise AssemblyError("immediate width must be 8 or 16")
        number = value(immediate)
        wide = size == 16 or size is None and not 0 <= number <= 255
        if strict and (not -32768 <= number <= 65535 or size == 8 and not 0 <= number <= 255):
            raise AssemblyError("immediate out of range")
        tail = ALU[op] << 12 | dest << 8 | number & 255
        return [0x2700 | (number >> 8 & 255), tail] if wide else [tail]
    if op in {"ldm", "stm", "ldw", "ldb", "stw", "stb"}:
        store = op.startswith("st")
        if len(args) != 2:
            raise AssemblyError("memory instruction requires two operands")
        memory, register = args if store else args[::-1]
        match = re.fullmatch(r"\(\s*(r\d+)\s*(?:,\s*#([^()]+))?\)", memory)
        if not match:
            raise AssemblyError(f"invalid memory operand {memory}")
        base, other = reg(match[1]), reg(register)
        displacement = value(match[2]) if match[2] else 0
        if op in {"ldm", "stm"}:
            if strict and (displacement & 1 or not 0 <= displacement < 32):
                raise AssemblyError("DISP4 must be even and in 0..30")
            return [(0x1000 if store else 0) | base << 8 | other << 4 | displacement >> 1 & 15]
        if strict and not -1024 <= displacement < 1024:
            raise AssemblyError("DISP11 out of range")
        byte = op in {"ldb", "stb"}
        return [0x2700 | byte << 7 | (displacement & 1) << 6 | (displacement & 0x7e0) >> 5,
                # Historical _MEM_DISP11 macro places registers here, unlike
                # unprefixed LDM/STM. This reproduces the macro, not a claim
                # that these inherited LDW/STW encodings work on mr16core.v.
                (0x1000 if store else 0) | base << 12 | other << 8 | (displacement & 30) >> 1]
    if op in BRANCH:
        target = value(operands)
        delta = target - pc
        if strict and (delta & 1 or not -256 <= delta < 256):
            raise AssemblyError("relative branch out of range or odd")
        return [0x2000 | BRANCH[op] << 8 | (delta >> 1 & 255)]
    if op in JUMP or op == "jsr":
        call = op == "jsr"
        condition = 15 if call else JUMP[op]
        if re.fullmatch(r"r\d+", operands):
            return [0x3002 | (condition & 15) << 8 | reg(operands) << 4 | call]
        target = value(operands)
        if strict and (target & 1 or not 0 <= target <= 65534):
            raise AssemblyError("absolute target out of range or odd")
        return [0x2700 | target >> 8 & 255, 0x2000 | condition << 8 | target & 254 | call]
    if op in {"push", "pop"}:
        source = 15 if operands == "flag" else reg(operands)
        return [(0x1f01 if op == "push" else 0x0f01) | source << 4]
    if op == "ret":
        if operands and operands not in FLAGS:
            raise AssemblyError("unsupported return flag")
        return [0x0f00 | (FLAGS[operands] << 4 if operands else 0)]
    if op in FLAGS or op == "nop":
        if operands:
            raise AssemblyError("unexpected flag/NOP operands")
        return [0x3f00 | (FLAGS[op] << 4 if op in FLAGS else 0)]
    if op == "shr":
        if len(args) != 2 or not args[1].startswith("#"):
            raise AssemblyError("invalid shift operands")
        dest, count = reg(args[0]), value(args[1][1:])
        if not 0 <= count <= 16:
            raise AssemblyError("shift out of range")
        if count == 0:
            return [0xe001 | dest << 8]
        tail = 0xf000 | dest << 8 | (0x10000 >> count & 255)
        return [0x2700 | (0x100 >> count & 255), tail] if count <= 8 else [tail]
    raise AssemblyError(f"unsupported instruction {op}")


def assemble(source, defines=None, rom_size=4096):
    source = pathlib.Path(source).resolve()
    previous = dict(defines or {})

    def run(strict):
        symbols = dict(defines or {})
        locations = {"cseg": 0, "dseg": 0}
        segment = "cseg"
        image = bytearray([255]) * rom_size
        occupied = set()
        include_stack = []

        def file(path):
            nonlocal segment
            if path in include_stack:
                raise AssemblyError("recursive include")
            include_stack.append(path)
            conditionals = []
            else_seen = []
            # Shift-JIS comments contain bytes such as 0x85; these are not NEL
            # source separators. Only actual newline delimiters split lines.
            for line_no, raw in enumerate(path.read_text(encoding="latin1").split("\n"), 1):
                text = raw.split(";", 1)[0].strip().lower()
                if not text:
                    continue
                try:
                    active = all(conditionals)
                    parts = text.split(None, 1)
                    head, rest = parts[0], parts[1] if len(parts) == 2 else ""
                    if head in {".ifdef", ".ifndef"}:
                        conditionals.append(active and ((rest in symbols) == (head == ".ifdef")))
                        else_seen.append(False)
                        continue
                    if head == ".if":
                        conditionals.append(active and bool(expression(rest, symbols, locations[segment])))
                        else_seen.append(False)
                        continue
                    if head == ".else":
                        if not conditionals or else_seen[-1]:
                            raise AssemblyError("unmatched/duplicate else")
                        else_seen[-1] = True
                        conditionals[-1] = all(conditionals[:-1]) and not conditionals[-1]
                        continue
                    if head == ".endif":
                        if not conditionals:
                            raise AssemblyError("unmatched endif")
                        conditionals.pop()
                        else_seen.pop()
                        continue
                    if not active:
                        continue
                    pc = locations[segment]
                    label = None
                    if head.endswith(":"):
                        label, text = head[:-1], rest
                    elif head not in OPS:
                        label, text = head, rest
                    parts = text.split(None, 1)
                    op = parts[0] if parts else ""
                    operands = parts[1] if len(parts) == 2 else ""

                    def value(expr):
                        return expression(expr, previous | symbols, pc, not strict)

                    if label:
                        if not re.fullmatch(r"[a-z_][\w]*", label) or label in symbols:
                            raise AssemblyError(f"invalid/duplicate symbol {label}")
                        symbols[label] = value(operands) if op == "equ" else pc
                    if not op or op == "equ":
                        if op == "equ" and not label:
                            raise AssemblyError("EQU without symbol")
                        continue
                    if op == "include":
                        match = re.fullmatch(r'"([^"\\]+)"', operands)
                        if not match:
                            raise AssemblyError("invalid include")
                        file((path.parent / match[1]).resolve())
                        continue
                    if op in locations:
                        segment = op
                        continue
                    if op == "org":
                        target = value(operands)
                        if not 0 <= target <= (rom_size if segment == "cseg" else 65535):
                            raise AssemblyError("origin out of range")
                        locations[segment] = target
                        continue
                    if op in {"ds", "defs", ".align"}:
                        count = value(operands)
                        if count < 0 or op == ".align" and count == 0:
                            raise AssemblyError("invalid allocation/alignment")
                        locations[segment] += (-pc % count) if op == ".align" else count
                        if segment == "cseg" and locations[segment] > rom_size:
                            raise AssemblyError("ROM allocation overflow")
                        continue
                    if op == "end":
                        if operands:
                            raise AssemblyError("unexpected END operands")
                        continue
                    if op in {"dw", "db"}:
                        data = bytearray()
                        width = 2 if op == "dw" else 1
                        for expr in arguments(operands):
                            number = value(expr)
                            if strict and not 0 <= number < 1 << (8 * width):
                                raise AssemblyError("data out of range")
                            data += (number & ((1 << (8 * width)) - 1)).to_bytes(width, "little")
                    else:
                        data = b"".join(word.to_bytes(2, "little") for word in encode(op, operands, value, pc, strict))
                    if segment == "cseg":
                        if pc < 0 or pc + len(data) > rom_size:
                            raise AssemblyError("ROM overflow")
                        for address in range(pc, pc + len(data)):
                            if address in occupied:
                                raise AssemblyError("overlapping ROM emission")
                            occupied.add(address)
                        image[pc:pc + len(data)] = data
                    locations[segment] += len(data)
                except (AssemblyError, OSError) as exc:
                    raise AssemblyError(f"{path}:{line_no}: {exc}") from exc
            if conditionals:
                raise AssemblyError(f"{path}: unterminated conditional")
            include_stack.pop()

        file(source)
        # Match the saved HEX->BIN conversion: internal holes FF, then the
        # bin2ver converter pads from the last emitted byte to ROM size with 0.
        end = max(occupied, default=-1) + 1
        image[end:] = bytes(rom_size - end)
        return bytes(image), symbols, locations

    for _ in range(64):
        image, symbols, locations = run(False)
        if symbols == previous:
            final = run(True)
            if final != (image, symbols, locations):
                raise AssemblyError("final strict pass changed output")
            return final
        previous = symbols
    raise AssemblyError("symbol/layout convergence failed")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=pathlib.Path)
    parser.add_argument("--check-rom", type=pathlib.Path, help="compare all 2048 literal ROM words; no writes")
    parser.add_argument("--output-mem-new", type=pathlib.Path, help="exclusive new simulation readmemh file; never overwrite")
    args = parser.parse_args()
    image, symbols, locations = assemble(args.source)
    if args.check_rom:
        words = re.findall(r"11'h([0-9a-f]+):rom=16'h([0-9a-f]+);", args.check_rom.read_text(), re.I)
        if len(words) != 2048 or {int(a, 16) for a, _ in words} != set(range(2048)):
            raise AssemblyError("reference must contain exactly 2048 distinct ROM words")
        expected = bytearray(4096)
        for address, word in words:
            offset = int(address, 16) * 2
            expected[offset:offset + 2] = int(word, 16).to_bytes(2, "little")
        differences = [i for i in range(4096) if image[i] != expected[i]]
        if differences:
            raise AssemblyError(f"ROM mismatch: {len(differences)} bytes; first offset {differences[0]:04x}")
        print("PASS: all 4096 assembled bytes match the inherited literal ROM; receive-only override is separate")
    if args.output_mem_new:
        destination = args.output_mem_new.resolve()
        root = pathlib.Path(__file__).resolve().parents[1]
        if any(destination.is_relative_to(root / name) for name in ("bios", "rtl", "sys")):
            raise AssemblyError("generated ROM must stay outside source/firmware trees")
        with destination.open("x", encoding="ascii") as output:
            output.writelines(f"{int.from_bytes(image[i:i+2], 'little'):04x}\n" for i in range(0, len(image), 2))
    print(f"MR16 layout: code_end={symbols.get('code_end', locations['cseg']):04x}, data_end={locations['dseg']:04x}; no firmware changed")


if __name__ == "__main__":
    main()
