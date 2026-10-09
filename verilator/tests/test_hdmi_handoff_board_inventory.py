"""Portable temporary-directory owner for the Tcl mock, not native timing."""
import pathlib
import subprocess
import tempfile

with tempfile.TemporaryDirectory(prefix="x1-handoff-inventory-") as directory:
    subprocess.run(["tclsh", str(pathlib.Path(__file__).with_name("hdmi_handoff_board_inventory_tb.tcl")), directory], check=True)
