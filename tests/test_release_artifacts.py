import hashlib
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
RELEASE = ROOT / 'release/v0.4.0'
REQUIRED = {
    'pyrocore.ino.bootloader.bin',
    'pyrocore.ino.partitions.bin',
    'boot_app0.bin',
    'pyrocore.ino.bin',
    'littlefs.bin',
}


class ReleaseArtifactTests(unittest.TestCase):
    def test_checksums_match_release_files(self):
        sums = RELEASE / 'SHA256SUMS'
        self.assertTrue(sums.is_file(), f'missing {sums}')
        entries = {}
        for line in sums.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            digest, name = line.split(None, 1)
            entries[name.lstrip('*')] = digest
        self.assertEqual(set(entries), REQUIRED)
        for name, digest in entries.items():
            data = (RELEASE / name).read_bytes()
            self.assertEqual(hashlib.sha256(data).hexdigest(), digest, name)


if __name__ == '__main__':
    unittest.main()
