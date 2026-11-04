from contextlib import redirect_stdout
import hashlib
import importlib.util
import io
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

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


class ChecksumVerificationTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.release = Path(temporary.name)
        self.lines = []
        for _, name in flash.LAYOUT:
            payload = ('fixture: ' + name).encode('ascii')
            (self.release / name).write_bytes(payload)
            self.lines.append(f'{hashlib.sha256(payload).hexdigest()}  {name}')
        self.write_manifest(self.lines)

    def write_manifest(self, lines):
        (self.release / 'SHA256SUMS').write_text('\n'.join(lines) + '\n')

    def assert_invalid_manifest(self, lines):
        self.write_manifest(lines)
        with patch.object(flash, 'sha256') as digest:
            with self.assertRaises(SystemExit):
                flash.verify(self.release)
            digest.assert_not_called()

    def test_valid_complete_manifest_and_gnu_binary_checksums(self):
        variants = [self.lines,
                    [line.split()[0].upper() + ' *' + line.split()[1]
                     for line in self.lines]]
        for lines in variants:
            with self.subTest(lines=lines):
                self.write_manifest(['# release checksums', '', *lines])
                with redirect_stdout(io.StringIO()):
                    flash.verify(self.release)

    def test_missing_checksum_file_is_rejected(self):
        (self.release / 'SHA256SUMS').unlink()
        with self.assertRaises(SystemExit):
            flash.verify(self.release)

    def test_empty_manifest_is_rejected_before_hashing(self):
        self.assert_invalid_manifest([])

    def test_partial_manifest_is_rejected_before_hashing(self):
        self.assert_invalid_manifest(self.lines[:-1])

    def test_malformed_checksum_lines_are_rejected_cleanly(self):
        digest, name = self.lines[0].split()
        malformed = [digest, f'{"g" * 64}  {name}',
                     f'{digest[:-1]}  {name}', f'{digest}  {name} trailing']
        for line in malformed:
            with self.subTest(line=line):
                self.assert_invalid_manifest([line, *self.lines[1:]])

    def test_duplicate_filename_is_rejected_before_hashing(self):
        self.assert_invalid_manifest([*self.lines, self.lines[0]])

    def test_unexpected_filename_is_rejected_before_hashing(self):
        self.assert_invalid_manifest([*self.lines, f'{"0" * 64}  unexpected.bin'])

    def test_path_entries_are_rejected_before_hashing(self):
        digest, name = self.lines[0].split()
        paths = ['../' + name, str(self.release / name), './' + name,
                 'nested/' + name, '..\\' + name]
        for name in paths:
            with self.subTest(name=name):
                self.assert_invalid_manifest([f'{digest}  {name}', *self.lines[1:]])

    def test_corrupt_and_missing_images_are_rejected(self):
        image = self.release / flash.LAYOUT[0][1]
        with self.subTest(problem='corrupt'):
            image.write_bytes(b'corrupted image')
            with self.assertRaises(SystemExit):
                flash.verify(self.release)
        with self.subTest(problem='missing'):
            image.unlink()
            with self.assertRaises(SystemExit):
                flash.verify(self.release)

    def test_main_rejects_bad_manifest_before_resolving_or_running_esptool(self):
        for lines in ([], self.lines[:-1], ['malformed', *self.lines[1:]]):
            with self.subTest(lines=lines):
                self.write_manifest(lines)
                arguments = ['flash_release.py', '--port', 'TEST_ONLY',
                             '--dir', str(self.release)]
                with patch.object(sys, 'argv', arguments), \
                     patch.object(flash, 'serial_ports', return_value=[]), \
                     patch.object(flash, 'find_esptool') as find_esptool, \
                     patch.object(flash.subprocess, 'run') as run:
                    with self.assertRaises(SystemExit):
                        flash.main()
                    find_esptool.assert_not_called()
                    run.assert_not_called()


if __name__ == '__main__':
    unittest.main()
