"""Run isolated Tcl scope mocks. No timing acceptance from these tests."""
import pathlib
import subprocess
import tempfile

root = pathlib.Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix="x1-csync-inventory-") as temporary:
    subprocess.run(["tclsh", str(root / "verilator/tests/csync_board_inventory_tb.tcl"), temporary], check=True)
