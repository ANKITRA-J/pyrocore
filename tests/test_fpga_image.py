import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('fpga_builder',ROOT/'tools/build_fpga.py')
builder=importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class PeripheralHeaderTests(unittest.TestCase):
    def project(self,folder,config):
        p=Path(folder)/'test.ffpga'
        values=' '.join(f'{x:X}' for x in config)
        p.write_text(f'<GPDProject><chip><nvmData>{values}</nvmData></chip></GPDProject>')
        return p

    def test_preserves_project_settings_and_enables_bram(self):
        config=bytearray(60)
        config[24]=2  # BRAM retention setting, independent of power enable.
        config[28:32]=bytes.fromhex('22222222')
        with tempfile.TemporaryDirectory() as folder:
            header=builder.configuration_header(self.project(folder,config))
        encoded=struct.pack('>10I',*header)
        self.assertEqual(encoded[:4],bytes.fromhex('aa22ff11'))
        self.assertEqual(encoded[4:],bytes(config[24:60]))
        # MCU preamble is320words; byte1300 is register320/321's byte.
        image=bytes(1280)+encoded
        self.assertEqual(image[1300]&3,0)
        self.assertEqual(header[1],0x02000000)

    def test_rejects_default_powered_down_banks(self):
        config=bytearray(60);config[40]=3
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaisesRegex(ValueError,'powered down'):
                builder.configuration_header(self.project(folder,config))

    def test_rejects_wrong_configuration_size(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaisesRegex(ValueError,'480-bit'):
                builder.configuration_header(self.project(folder,bytes(59)))


if __name__=='__main__':unittest.main()
