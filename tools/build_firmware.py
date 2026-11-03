#!/usr/bin/env python3
"""Build PyroCore ESP32 firmware and its LittleFS FPGA image; upload only with --port."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
FQBN = 'esp32:esp32:esp32s3:CDCOnBoot=cdc,FlashSize=8M,PartitionScheme=default_8MB'

def cli_default():
    found = shutil.which('arduino-cli')
    if found:
        return found
    bundled = Path('/Applications/Arduino IDE.app/Contents/Resources/app/lib/backend/resources/arduino-cli')
    return str(bundled) if bundled.is_file() else 'arduino-cli'

def arduino_data():
    if sys.platform == 'darwin':
        return Path.home()/'Library/Arduino15'
    if sys.platform == 'win32':
        return Path(os.environ.get('LOCALAPPDATA', Path.home()/'AppData/Local'))/'Arduino15'
    return Path.home()/'.arduino15'

def find_tool(parent, name):
    executable = name + ('.exe' if sys.platform == 'win32' else '')
    choices = [p for p in parent.glob('*/'+executable) if p.is_file()]
    if not choices:
        raise SystemExit(f'Missing {name} under {parent}; install ESP32 Arduino core 3.3.12')
    return max(choices, key=lambda p: tuple(int(n) for n in re.findall(r'\d+', p.parent.name)))

def run(command):
    print('Running:', ' '.join(str(p) for p in command), flush=True)
    subprocess.run([str(p) for p in command], check=True)

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--bitstream', type=Path, required=True, help='Vendor MCU-format FPGA .bin')
    p.add_argument('--arduino-cli', default=cli_default())
    p.add_argument('--esp32-tools', type=Path, default=arduino_data()/'packages/esp32/tools')
    p.add_argument('--libraries', type=Path)
    p.add_argument('--build', type=Path, default=ROOT/'build/firmware')
    p.add_argument('--port', help='Upload the application AND filesystem only when explicitly supplied')
    p.add_argument('--jobs', type=int, default=4)
    a = p.parse_args()
    image_path = a.bitstream.resolve()
    image = image_path.read_bytes()
    if image_path.suffix.lower() != '.bin' or len(image) < 1024 or len(image) > 128*1024:
        raise SystemExit('Expected a real vendor MCU-format FPGA binary (1–128 KiB)')
    if any(part in image_path.name.upper() for part in ['OTP', 'FLASH_MEM']):
        raise SystemExit('Use FPGA_bitstream_MCU.bin; OTP and FLASH_MEM images are incompatible')
    build = a.build.resolve()
    build.mkdir(parents=True, exist_ok=True)
    # Keep the compiler cache in the project; do not require global cache writes.
    config = build.parent/'arduino-cli-local.yaml'
    cache = build.parent/'arduino-cache'
    config.write_text('build_cache:\n  path: '+json.dumps(str(cache))+'\n')
    command = [a.arduino_cli, '--config-file', config, 'compile', '--fqbn', FQBN,
               '--build-path', build, '--jobs', str(a.jobs), ROOT/'firmware/pyrocore']
    if a.libraries:
        command += ['--libraries', a.libraries.resolve()]
    run(command)
    data = build/'littlefs-data'
    data.mkdir(exist_ok=True)
    (data/'fpga_bitstream.bin').write_bytes(image)
    rows = [line.split(',') for line in (build/'partitions.csv').read_text().splitlines()
            if line.strip() and not line.lstrip().startswith('#')]
    partition = next((row for row in rows if row[0].strip() == 'spiffs'), None)
    if not partition:
        raise SystemExit('Compiled partition table has no filesystem partition')
    offset, size = int(partition[3].strip(), 0), int(partition[4].strip(), 0)
    filesystem = build/'littlefs.bin'
    run([find_tool(a.esp32_tools/'mklittlefs', 'mklittlefs'), '-c', data,
         '-b', '4096', '-p', '256', '-s', str(size), filesystem])
    manifest = {
        'fqbn': FQBN, 'bitstream_source': str(image_path),
        'bitstream_sha256': hashlib.sha256(image).hexdigest(), 'bitstream_bytes': len(image),
        'filesystem_offset': hex(offset), 'filesystem_size': hex(size),
        'uploaded': False, 'physical_validation': 'not performed by the build helper',
    }
    (build/'build-manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    print(f'Built PyroCore firmware and LittleFS in {build}')
    if not a.port:
        print('Build only. No board was accessed. Add --port only when an upload is intended.')
        return
    run([find_tool(a.esp32_tools/'esptool_py', 'esptool'), '--chip', 'esp32s3',
         '--port', a.port, '--baud', '460800', 'write-flash',
         '0x0', build/'pyrocore.ino.bootloader.bin',
         '0x8000', build/'pyrocore.ino.partitions.bin', '0xe000', build/'boot_app0.bin',
         '0x10000', build/'pyrocore.ino.bin', hex(offset), filesystem])
    manifest['uploaded'] = True
    (build/'build-manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')

if __name__ == '__main__':
    main()
