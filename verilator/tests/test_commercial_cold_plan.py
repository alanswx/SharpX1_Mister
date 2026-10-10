"""Asset-free schedule/player-symbol checks, not commercial gameplay results."""
import pathlib
import subprocess
import sys
import unittest
import test_commercial_cold_gameplay as cold


class ColdPlan(unittest.TestCase):
    def test_original_segment_times_and_controls(self):
        expected = {
            "druaga": (30550, [(16000, 0xdf), (16250, 0xff), (30250, 0xfb)]),
            "mappy": (27300, [(27000, 0xfb)]),
            "galaga": (33300, [(16000, 0xdf), (16500, 0xff), (20500, 0xdf),
                                (20750, 0xff), (23750, 0xdf), (24000, 0xff), (33000, 0xf7)]),
        }
        for title, (duration, events) in expected.items():
            self.assertEqual(cold.plan(title, True), (duration, events))
            self.assertEqual(cold.plan(title, False), (duration, events[:-1] + [(duration - 300, 0xff)]))
            invocation = cold.command('exe', title, 'disk', 'rom', 'keys', 'prefix', True)
            self.assertEqual(invocation[2], str(duration * 32000))
            self.assertEqual(invocation.count('--joy-at'), len(events))
            self.assertFalse(set(invocation) & {'--ram', '--restore-state', '--save-state', '--entry', '--disk-output'})
        with self.assertRaises(ValueError):
            cold.plan('unqualified', True)

    def test_original_key_times_and_mappy_repeated_start(self):
        root = pathlib.Path(__file__).parent
        boot = (root / 'commercial_boot.keys').read_text()
        start = (root / 'mappy_start.keys').read_text()
        expected = [(1000, 0x2b), (1200, 0xf0), (1202, 0x2b),
                    (4000, 0x29), (4100, 0xf0), (4102, 0x29)]
        self.assertEqual(cold.cold_keys('druaga', boot), expected)
        self.assertEqual(cold.cold_keys('galaga', boot), expected)
        self.assertEqual(cold.cold_keys('mappy', boot, start), expected +
                         [(18050, 0x29), (18300, 0xf0), (18302, 0x29),
                          (24050, 0x29), (24300, 0xf0), (24302, 0x29)])
        for text in ('1 ff extra', '1 100', '-1 ff', '2 ff\n1 ff'):
            with self.assertRaises(AssertionError):
                cold.key_events(text)
        with self.assertRaises(AssertionError):
            cold.cold_keys('druaga', '16000 29')
        with self.assertRaises(AssertionError):
            cold.cold_keys('mappy', boot, '3000 29')

    def test_release_symbols_and_invalid_native_structures(self):
        for title in cold.MEDIA:
            memory = bytearray(65536)
            if title == 'druaga':
                memory[0xF828:0xF82A] = bytes((68, 32))
                expected = (68, 32)
            elif title == 'mappy':
                memory[0xF800] = 3
                memory[0xF80B], memory[0xF809] = 129, 84
                expected = (129, 84)
            else:
                memory[0xDD3] = memory[0x230F] = 1
                memory[0x2311], memory[0x2313] = 32, 24
                expected = (32, 24)
            self.assertEqual(cold.player(title, memory), expected)
            with self.assertRaises(AssertionError):
                cold.player(title, bytes(65536))
            with self.assertRaises(AssertionError):
                cold.player(title, memory[:-1])

    def test_missing_mappy_key_arg_refused_before_assets(self):
        result = subprocess.run([sys.executable, cold.__file__, '/nonexistent', 'mappy', '/nonexistent',
                                 '--rom', '/nonexistent', '--keys', '/nonexistent', '--output', '/nonexistent'],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 2)
        self.assertIn('Mappy start keys', result.stderr)
        self.assertNotIn('Traceback', result.stderr)


if __name__ == '__main__':
    unittest.main()
