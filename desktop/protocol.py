"""Pure frame packing and USB protocol validation; no GUI dependencies."""
import base64
import binascii
import json

WIDTH = HEIGHT = 64
PIXEL_COUNT = WIDTH * HEIGHT
PAYLOAD_BYTES = PIXEL_COUNT * 3 // 8
MAX_LINE_BYTES = 8192
PALETTE = (
    (0, 0, 0), (255, 78, 100), (70, 230, 148), (87, 145, 255),
    (255, 215, 91), (255, 145, 67), (255, 255, 245), (181, 217, 235),
)
MATERIALS = ('Strontium · red', 'Barium · green', 'Copper · blue',
             'Sodium · yellow', 'Aluminium · white', 'Titanium · silver')
PATTERNS = ('Radial', 'Ring', 'Willow')


class ProtocolError(ValueError):
    pass


def pack_pixels(pixels):
    """Pack 4096 three-bit indices in row-major, LSB-first groups of eight."""
    pixels = list(pixels)
    if len(pixels) != PIXEL_COUNT:
        raise ProtocolError('Expected 4096 pixels')
    if any(type(p) is not int or not 0 <= p <= 7 for p in pixels):
        raise ProtocolError('Palette index must be an integer from 0 to 7')
    result = bytearray()
    for offset in range(0, PIXEL_COUNT, 8):
        word = sum(pixels[offset + bit] << (3 * bit) for bit in range(8))
        result.extend(word.to_bytes(3, 'little'))
    return bytes(result)


def unpack_pixels(payload):
    if not isinstance(payload, (bytes, bytearray)) or len(payload) != PAYLOAD_BYTES:
        raise ProtocolError('Expected 1536 packed frame bytes')
    result = bytearray(PIXEL_COUNT)
    for offset in range(0, PAYLOAD_BYTES, 3):
        word = int.from_bytes(payload[offset:offset + 3], 'little')
        pixel = offset // 3 * 8
        for bit in range(8):
            result[pixel + bit] = (word >> (3 * bit)) & 7
    return bytes(result)


def decode_message(line):
    """Decode one bounded JSON line. Validate frame provenance and payload."""
    if isinstance(line, str):
        line = line.encode('utf-8')
    if not isinstance(line, (bytes, bytearray)) or len(line) > MAX_LINE_BYTES:
        raise ProtocolError('USB message exceeds the size limit')
    try:
        obj = json.loads(bytes(line).decode('utf-8'))
    except (ValueError, UnicodeError) as exc:
        raise ProtocolError('Invalid USB JSON message') from exc
    if not isinstance(obj, dict) or not isinstance(obj.get('type'), str):
        raise ProtocolError('Expected a typed JSON object')
    if obj['type'] == 'frame':
        if obj.get('source') != 'fpga' or obj.get('crc_ok') is not True:
            raise ProtocolError('Frame was not validated as FPGA output')
        if (type(obj.get('width')) is not int or obj['width'] != WIDTH or
                type(obj.get('height')) is not int or obj['height'] != HEIGHT or
                obj.get('format') != 'indexed3-lsb'):
            raise ProtocolError('Unsupported frame dimensions or format')
        if type(obj.get('seq')) is not int or not 0 <= obj['seq'] <= 65535:
            raise ProtocolError('Invalid frame sequence number')
        data = obj.get('data')
        if not isinstance(data, str) or len(data) != 2048:
            raise ProtocolError('Invalid base64 frame length')
        try:
            payload = base64.b64decode(data, validate=True)
        except (ValueError, binascii.Error) as exc:
            raise ProtocolError('Invalid base64 frame data') from exc
        obj['pixels'] = unpack_pixels(payload)
    return obj


def encode_command(command, **fields):
    """Emit only the supported public USB commands with checked value ranges."""
    if command not in {'hello', 'launch', 'set', 'clear', 'stream', 'frame', 'status'}:
        raise ProtocolError('Unsupported command')
    permitted = {'material', 'pattern'} if command in ('launch', 'set') else set()
    if command == 'stream':
        permitted = {'enabled', 'fps'}
    if set(fields) - permitted:
        raise ProtocolError('Unsupported command field')
    for key, maximum in [('material', 5), ('pattern', 2), ('fps', 7)]:
        if key in fields:
            minimum = 1 if key == 'fps' else 0
            if type(fields[key]) is not int or not minimum <= fields[key] <= maximum:
                raise ProtocolError('Invalid ' + key)
    if 'enabled' in fields and type(fields['enabled']) is not bool:
        raise ProtocolError('enabled must be boolean')
    return (json.dumps(dict(cmd=command, **fields), separators=(',', ':')) + '\n').encode('ascii')
