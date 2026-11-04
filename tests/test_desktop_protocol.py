import base64
import json
from pathlib import Path
import random
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from desktop.protocol import (ProtocolError, decode_message, encode_command,
                              pack_pixels, unpack_pixels)


class DesktopProtocolTests(unittest.TestCase):
    def frame(self, **changes):
        message = {'type': 'frame', 'seq': 42, 'width': 64, 'height': 64,
                   'format': 'indexed3-lsb', 'source': 'fpga', 'crc_ok': True,
                   'data': base64.b64encode(bytes(1536)).decode('ascii')}
        message.update(changes)
        return json.dumps(message).encode('utf-8')

    def test_known_bit_packing_order(self):
        pixels = list(range(8)) * 512
        packed = pack_pixels(pixels)
        self.assertEqual(packed[:3], bytes.fromhex('88 c6 fa'))
        self.assertEqual(unpack_pixels(packed), bytes(pixels))

    def test_random_roundtrip(self):
        rng = random.Random(82)
        pixels = [rng.randrange(8) for _ in range(4096)]
        self.assertEqual(unpack_pixels(pack_pixels(pixels)), bytes(pixels))

    def test_decode_validated_frame(self):
        frame = decode_message(self.frame())
        self.assertEqual(frame['seq'], 42)
        self.assertEqual(frame['pixels'], bytes(4096))

    def test_mixed_pistil_colours_survive_frame_transport(self):
        pixels = bytearray(4096)
        for position in (0, 7, 1023):
            pixels[position] = 2
        for position in (63, 64, 4095):
            pixels[position] = 6
        encoded = base64.b64encode(pack_pixels(list(pixels))).decode('ascii')
        self.assertEqual(decode_message(self.frame(data=encoded))['pixels'], pixels)

    def test_reject_untrusted_or_bad_frame(self):
        for changes in ({'source': 'demo'}, {'crc_ok': False}, {'crc_ok': 1},
                        {'seq': -1}, {'seq': 65536}, {'seq': True},
                        {'width': 32}, {'height': True}, {'format': 'rgb'},
                        {'data': 'x'}, {'data': '!' * 2048}):
            with self.subTest(changes=changes), self.assertRaises(ProtocolError):
                decode_message(self.frame(**changes))

    def test_bounded_json(self):
        for line in [b'{}', b'[]', b'not-json', b'\xff', b' ' * 8193]:
            with self.subTest(line=line[:30]), self.assertRaises(ProtocolError):
                decode_message(line)
        self.assertEqual(decode_message(b'{"type":"hello","version":"0.1"}')['version'], '0.1')

    def test_palette_and_lengths(self):
        for pixels in [[], [0] * 4095, [8] * 4096, [-1] * 4096, [True] * 4096]:
            with self.assertRaises(ProtocolError):
                pack_pixels(pixels)
        for payload in [b'', bytes(1535), bytes(1537), 'x' * 1536]:
            with self.assertRaises(ProtocolError):
                unpack_pixels(payload)

    def test_commands(self):
        self.assertEqual(encode_command('launch', material=5, pattern=2),
                         b'{"cmd":"launch","material":5,"pattern":2}\n')
        self.assertEqual(encode_command('launch', material=1, pattern=3),
                         b'{"cmd":"launch","material":1,"pattern":3}\n')
        self.assertEqual(json.loads(encode_command('set', pattern=3))['pattern'], 3)
        self.assertEqual(json.loads(encode_command('stream', enabled=True, fps=5))['fps'], 5)
        for command, fields in [('invalid', {}), ('launch', {'material': 6}),
                                ('set', {'pattern': -1}), ('set', {'pattern': 4}),
                                ('launch', {'pattern': 4}), ('stream', {'fps': 0}),
                                ('stream', {}), ('stream', {'enabled': 1}),
                                ('clear', {'material': 1})]:
            with self.subTest(command=command, fields=fields), self.assertRaises(ProtocolError):
                encode_command(command, **fields)

    def test_stream_rate_range(self):
        for fps in (1, 5, 7, 18, 30):
            with self.subTest(fps=fps):
                self.assertEqual(json.loads(encode_command('stream', enabled=True, fps=fps))['fps'], fps)
        for fps in (0, 31, True, 18.0):
            with self.subTest(fps=fps), self.assertRaises(ProtocolError):
                encode_command('stream', enabled=True, fps=fps)


if __name__ == '__main__':
    unittest.main()
