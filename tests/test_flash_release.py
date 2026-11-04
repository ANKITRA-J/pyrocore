import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('flash_release', ROOT / 'tools/flash_release.py')
flash = importlib.util.module_from_spec(spec)
spec.loader.exec_module(flash)


class FakePort:
    def __init__(self, device, vid=None, pid=None, description=''):
        self.device = device
        self.vid = vid
        self.pid = pid
        self.description = description


class PortSelectionTests(unittest.TestCase):
    def test_requested_port_wins(self):
        self.assertEqual(flash.select_port([], requested='/dev/custom'), '/dev/custom')

    def test_single_candidate_is_auto_selected(self):
        board = FakePort('/dev/cu.usbmodem1101', 0x303A, 0x1001, 'USB JTAG/serial debug unit')
        output = []
        self.assertEqual(flash.select_port([board], out=output.append), board.device)
        self.assertTrue(any('Using' in line for line in output))

    def test_bluetooth_and_debug_ports_are_excluded(self):
        ports = [
            FakePort('/dev/cu.Bluetooth-Incoming-Port', description='n/a'),
            FakePort('/dev/cu.debug-console', description='n/a'),
            FakePort('/dev/cu.usbmodem1101', 0x303A, 0x1001, 'USB JTAG/serial debug unit'),
        ]
        self.assertEqual(flash.select_port(ports, out=lambda *_: None),
                         '/dev/cu.usbmodem1101')

    def test_multiple_ports_are_ranked_and_selectable(self):
        first = FakePort('COM3', 0x10C4, 0xEA60, 'USB serial')
        second = FakePort('COM4', 0x1A86, 0x7523, 'USB serial')
        answers = iter(['0', '2'])
        selected = flash.select_port([first, second], ask=lambda _: next(answers),
                                     out=lambda *_: None, interactive=True)
        self.assertEqual(selected, 'COM4')

    def test_unique_espressif_port_wins_without_prompt(self):
        generic = FakePort('COM3', 0x10C4, 0xEA60, 'Silicon Labs CP210x')
        board = FakePort('COM7', 0x303A, 0x1001, 'USB JTAG/serial debug unit')
        self.assertEqual(flash.select_port([generic, board], out=lambda *_: None),
                         'COM7')

    def test_non_usb_port_does_not_force_a_prompt(self):
        board = FakePort('/dev/cu.usbmodem1101', 0x303A, 0x1001, 'USB JTAG/serial debug unit')
        other = FakePort('/dev/cu.HTWS008', description='n/a')
        self.assertEqual(flash.select_port([other, board], out=lambda *_: None),
                         board.device)

    def test_multiple_ports_without_terminal_requires_port(self):
        ports = [FakePort('COM3', 0x10C4, 0xEA60, 'CP210x'),
                 FakePort('COM4', 0x1A86, 0x7523, 'CH340')]
        with self.assertRaises(SystemExit):
            flash.select_port(ports, out=lambda *_: None, interactive=False)


if __name__ == '__main__':
    unittest.main()
