"""Asset-free CLI safety checks: rejected requests must not reach SSH."""
import pathlib
import subprocess
import sys
import unittest


class MatrixSafetyTests(unittest.TestCase):
    def reject(self, arguments, message):
        script = pathlib.Path(__file__).with_name("mister_matrix.py")
        result = subprocess.run([sys.executable, str(script), *arguments],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn(message, result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_reserved_board_is_not_a_target(self):
        self.reject(["--host", "mister192"], "invalid choice")

    def test_reset_requires_explicit_execution(self):
        self.reject(["--host", "mister126", "--warm-reset"],
                    "--warm-reset requires --execute")

    def test_explicit_rbf_location(self):
        self.reject(["--host", "mister126", "--rbf-path", "/tmp/core.rbf"],
                    "RBF must be an explicit file")

    def test_rbf_identity_is_required(self):
        for value in ("", "abc", "g" * 64):
            self.reject(["--host", "mister126", "--rbf-sha256", value],
                        "RBF SHA-256 must be 64 lowercase hex digits")

    def test_native_and_synthetic_selection_are_exclusive(self):
        self.reject(["--host", "mister126", "--title", "01_CROSS_Chase",
                     "--video-ipl", "/nonexistent"], "not generated video IPLs")


if __name__ == "__main__":
    unittest.main()
