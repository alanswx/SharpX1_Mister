"""Actual Verilator/GNU-make object isolation; not machine/hardware evidence."""
import hashlib
import pathlib
import re
import subprocess
import tempfile

base = pathlib.Path(__file__).resolve().parents[1]
outputs = base / "obj_dir_headless"
outputs.mkdir(exist_ok=True)


def execute(command):
    result = subprocess.run(command, cwd=base, text=True, capture_output=True, timeout=90)
    assert result.returncode == 0, (command, result.stdout[-4000:], result.stderr[-4000:])
    return result.stdout


with tempfile.TemporaryDirectory(prefix="z-build-isolation-", dir=outputs) as directory:
    root = pathlib.Path(directory)
    parent = root / "parent"
    child = parent / "child"
    # Bind the actual selected Z recipe rather than hard-code its correction.
    dry = execute(["make", "-n", "turbo-z-video", f"Z_VIDEO_DIR={root / 'recipe'}",
                   "Z_MULTIMODE=1", "Z_INTERNAL8=1", "Z_TEXT_CPU=1"])
    matches = re.findall(r'-MAKEFLAGS "([^"]+)"', dry)
    assert len(matches) == 1 and "-B" in matches[0].split(), "Z recipe lost local-object rebuild"
    selected_flags = matches[0]

    def build(destination, profile, flags):
        return execute(["verilator", "--cc", "--exe", "--build", "-j", "2",
                        "--top-module", "top", "--Mdir", str(destination),
                        f"-GTAG={profile}",
                        "-CFLAGS", f"-std=c++20 -DTEST_BUILD_PROFILE={profile}",
                        "-MAKEFLAGS", flags, str(base / "tests/build_profile_tb.sv"),
                        str(base / "tests/build_profile_tb.cpp")])

    build(parent, 0, "OPT_FAST=-O3")
    assert execute([str(parent / "Vtop")]).strip() == "0"
    preserved = {name: hashlib.sha256((parent / name).read_bytes()).hexdigest()
                 for name in ("Vtop", "build_profile_tb.o")}
    broken = build(child, 1, "OPT_FAST=-O3")
    assert execute([str(child / "Vtop")]).strip() == "0", "negative did not reproduce parent-object contamination"
    assert "../build_profile_tb.o" in broken, "negative did not actually link the parent object"
    corrected = build(child, 1, selected_flags)
    assert execute([str(child / "Vtop")]).strip() == "1", "selected recipe reused the wrong profile"
    assert "-o build_profile_tb.o" in corrected and "../build_profile_tb.o" not in corrected
    assert (child / "build_profile_tb.o").is_file()
    assert preserved == {name: hashlib.sha256((parent / name).read_bytes()).hexdigest()
                         for name in preserved}, "child rebuild altered parent artifacts"
print("PASS: actual nested Verilator wrong-profile control reproduced; selected Z recipe builds local objects without changing parent")
