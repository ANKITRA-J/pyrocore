import unittest
from desktop.frame_stats import FrameStats


class FrameStatsTests(unittest.TestCase):
    def setUp(self):
        self.now = 0.0
        self.stats = FrameStats(clock=lambda: self.now)
        self.stats.reset(connected=True)

    def frame(self, time, active=False):
        self.now = time
        self.stats.record(int(time * 100), bytes([2 if active else 0]) + bytes(4095))

    def test_startup_is_calculating(self):
        self.assertIsNone(self.stats.snapshot().fps)
        self.frame(0)
        self.frame(0.01)
        self.assertIsNone(self.stats.snapshot().fps)

    def test_black_frames_count_at_five_fps(self):
        for i in range(21):
            self.frame(i / 5)
        snap = self.stats.snapshot()
        self.assertAlmostEqual(snap.fps, 5.0)
        self.assertEqual(snap.frames, 21)
        self.assertEqual(snap.lit_pixels, 0)

    def test_scene_content_does_not_change_stream_rate(self):
        for i in range(29):
            self.frame(i / 7, active=(i % 2 == 0))
        snap = self.stats.snapshot()
        self.assertAlmostEqual(snap.fps, 7.0)
        self.assertEqual(snap.lit_pixels, 1)

    def test_rate_decays_without_new_arrivals_then_stops(self):
        for i in range(21):
            self.frame(i / 5)
        self.now = 5
        self.assertAlmostEqual(self.stats.snapshot().fps, 10 / 3)
        self.now = 6.5
        self.assertEqual(self.stats.snapshot().fps, 0)
        self.assertEqual(self.stats.snapshot().state, 'stale')

    def test_disconnect_sets_zero_and_retains_last_image_details(self):
        self.frame(0, active=True)
        self.stats.disconnect()
        snap = self.stats.snapshot()
        self.assertEqual(snap.fps, 0)
        self.assertEqual(snap.state, 'offline')
        self.assertEqual(snap.frames, 1)
        self.assertEqual(snap.lit_pixels, 1)

    def test_resumed_stream_warms_up_again(self):
        self.frame(0)
        self.now = 3
        self.assertEqual(self.stats.snapshot().state, 'stale')
        self.frame(4)
        self.assertIsNone(self.stats.snapshot().fps)
        self.assertEqual(self.stats.snapshot().frames, 2)


if __name__ == '__main__':
    unittest.main()
