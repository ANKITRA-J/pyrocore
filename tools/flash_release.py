#!/usr/bin/env python3
"""Flash a prebuilt PyroCore release image. No Arduino toolchain required.

The release folder contains the application, bootloader, partition table and
LittleFS image. This helper verifies their SHA-256 checksums and writes them to
an ESP32-S3 over native USB with esptool.
"""
import argparse
import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_RELEASE = ROOT / 'release/v0.4.0'
LAYOUT = [
    ('0x0', 'pyrocore.ino.bootloader.bin'),
    ('0x8000', 'pyrocore.ino.partitions.bin'),
    ('0xe000', 'boot_app0.bin'),
    ('0x10000', 'pyrocore.ino.bin'),
    ('0x670000', 'littlefs.bin'),
]
ESP32_VIDS = {0x303A, 0x10C4, 0x1A86, 0x0403, 0x067B, 0x2341}


def is_noise(port):
    description = (port.description or '').lower()
    device = (port.device or '').lower()
    return ('bluetooth' in description or 'debug-console' in device
            or 'debug console' in description)


def rank_port(port):
    """Score likely board ports; higher is a better match."""
    score = 0
    if port.vid == 0x303A:
        score += 100
    elif port.vid in ESP32_VIDS:
        score += 50
    description = (port.description or '').lower()
    if 'usb' in description or 'serial' in description:
        score += 10
    return score


def serial_ports():
    try:
        from serial.tools import list_ports
    except ImportError as error:
        raise SystemExit(
            'pyserial is required to list ports. Install it with:\n'
            '  python -m pip install -r tools/requirements-flash.txt'
        ) from error
    return list(list_ports.comports())


def format_port(port):
    ids = f'{port.vid:04X}:{port.pid:04X}' if port.vid is not None else 'no USB ID'
    return f'{port.device}  [{ids}]  {port.description}'


def select_port(ports, requested=None, ask=input, out=print, interactive=None):
    """Return the requested port, or auto-pick / prompt from detected ports."""
    if requested:
        return requested
    if interactive is None:
        interactive = sys.stdin.isatty()
    usable = sorted((p for p in ports if not is_noise(p)),
                    key=lambda p: (-rank_port(p), p.device))
    if not usable:
        raise SystemExit(
            'No serial ports found. Connect the board to its native USB port, '
            'use a data cable, then try again. Or pass --port NAME.'
        )
    usb = [p for p in usable if p.vid is not None]
    pool = usb or usable
    espressif = [p for p in pool if p.vid == 0x303A]
    if len(espressif) == 1:
        out(f'Using {format_port(espressif[0])}')
        return espressif[0].device
    if len(pool) == 1:
        out(f'Using {format_port(pool[0])}')
        return pool[0].device
    out('Select the PyroCore board port:')
    for index, port in enumerate(pool, 1):
        out(f'  {index}. {format_port(port)}')
    if not interactive:
        raise SystemExit('Multiple serial ports found. Re-run with --port NAME.')
    while True:
        answer = ask(f'Port [1-{len(pool)}]: ').strip()
        if answer.isdigit() and 1 <= int(answer) <= len(pool):
            return pool[int(answer) - 1].device
        out(f'Enter a number from 1 to {len(pool)}.')


def arduino_data():
    if sys.platform == 'darwin':
        return Path.home() / 'Library/Arduino15'
    if sys.platform == 'win32':
        return Path(os.environ.get('LOCALAPPDATA', Path.home() / 'AppData/Local')) / 'Arduino15'
    return Path.home() / '.arduino15'


def find_esptool():
    """Prefer the installed esptool, then the one bundled with Arduino."""
    try:
        import esptool  # noqa: F401
        return [sys.executable, '-m', 'esptool']
    except ImportError:
        pass
    found = shutil.which('esptool')
    if found:
        return [found]
    data = Path(os.environ.get('ARDUINO_DIRECTORIES_DATA') or arduino_data())
    name = 'esptool.exe' if sys.platform == 'win32' else 'esptool'
    candidates = sorted((data / 'packages/esp32/tools/esptool_py').glob('*/' + name))
    if candidates:
        return [str(candidates[-1])]
    raise SystemExit(
        'esptool was not found. Install it with:\n'
        '  python -m pip install -r tools/requirements-flash.txt\n'
        'or install the Arduino ESP32 core so its bundled esptool is available.'
    )


def write_command(command):
    """esptool 5 uses write-flash; esptool 4 uses write_flash."""
    try:
        result = subprocess.run([*command, 'version'], capture_output=True,
                                text=True, check=True)
    except (OSError, subprocess.CalledProcessError):
        return 'write-flash'
    match = re.search(r'(\d+)\.\d+\.\d+', result.stdout)
    return 'write-flash' if match and int(match.group(1)) >= 5 else 'write_flash'


def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b''):
            digest.update(chunk)
    return digest.hexdigest()


def verify(release):
    sums = release / 'SHA256SUMS'
    if not sums.is_file():
        raise SystemExit(f'Missing checksum file: {sums}')
    required = {name for _, name in LAYOUT}
    expected = {}
    for number, line in enumerate(sums.read_text().splitlines(), 1):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        fields = line.split(None, 1)
        if len(fields) != 2 or not re.fullmatch(r'[0-9a-fA-F]{64}', fields[0]):
            raise SystemExit(f'Invalid checksum entry on line {number} of SHA256SUMS')
        digest, name = fields
        if name.startswith('*'):
            name = name[1:]
        if name not in required:
            raise SystemExit(f'Unexpected checksum filename: {name}')
        if name in expected:
            raise SystemExit(f'Duplicate checksum entry: {name}')
        expected[name] = digest.lower()
    missing = sorted(required - expected.keys())
    if missing:
        raise SystemExit('Missing release checksums: ' + ', '.join(missing))
    bad = [name for name, digest in expected.items()
           if not (release / name).is_file() or sha256(release / name) != digest]
    if bad:
        raise SystemExit('Release checksum mismatch: ' + ', '.join(bad))
    print(f'Verified {len(expected)} release files against SHA256SUMS')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', help='Native USB port, e.g. /dev/cu.usbmodem1101 or COM5. Omit to auto-detect or pick from a list.')
    parser.add_argument('--list-ports', action='store_true', help='List detected serial ports and exit')
    parser.add_argument('--dir', type=Path, default=DEFAULT_RELEASE, help='Release folder (default: release/v0.4.0)')
    parser.add_argument('--baud', type=int, default=460800, help='Upload baud (default: 460800)')
    parser.add_argument('--dry-run', action='store_true', help='Verify files and print the command without flashing')
    args = parser.parse_args()

    ports = serial_ports()
    if args.list_ports:
        usable = [p for p in ports if not is_noise(p)]
        if not usable:
            print('No serial ports found.')
        for port in sorted(usable, key=lambda p: (-rank_port(p), p.device)):
            print(format_port(port))
        return

    release = args.dir.resolve()
    missing = [name for _, name in LAYOUT if not (release / name).is_file()]
    if missing:
        raise SystemExit('Missing release files: ' + ', '.join(missing))
    verify(release)

    port = select_port(ports, args.port)
    esptool = find_esptool()
    command = [*esptool, '--chip', 'esp32s3', '--port', port,
               '--baud', str(args.baud), write_command(esptool)]
    for address, name in LAYOUT:
        command += [address, str(release / name)]

    print('Running:', ' '.join(command), flush=True)
    if args.dry_run:
        print('Dry run: no board was accessed.')
        return
    subprocess.run(command, check=True)
    print('\nFlash complete. Start the desktop app with:')
    print('  .venv/bin/python desktop/app.py')


if __name__ == '__main__':
    main()
