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
    expected = {}
    for line in sums.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        digest, name = line.split(None, 1)
        expected[name.lstrip('*')] = digest
    bad = [name for name, digest in expected.items()
           if not (release / name).is_file() or sha256(release / name) != digest]
    if bad:
        raise SystemExit('Release checksum mismatch: ' + ', '.join(bad))
    print(f'Verified {len(expected)} release files against SHA256SUMS')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', required=True, help='Native USB port, e.g. /dev/cu.usbmodem1101 or COM5')
    parser.add_argument('--dir', type=Path, default=DEFAULT_RELEASE, help='Release folder (default: release/v0.4.0)')
    parser.add_argument('--baud', type=int, default=460800, help='Upload baud (default: 460800)')
    parser.add_argument('--dry-run', action='store_true', help='Verify files and print the command without flashing')
    args = parser.parse_args()

    release = args.dir.resolve()
    missing = [name for _, name in LAYOUT if not (release / name).is_file()]
    if missing:
        raise SystemExit('Missing release files: ' + ', '.join(missing))
    verify(release)

    esptool = find_esptool()
    command = [*esptool, '--chip', 'esp32s3', '--port', args.port,
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
