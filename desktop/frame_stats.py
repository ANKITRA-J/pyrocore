"""Time-based statistics for complete received frames, including black frames."""
from collections import deque
from dataclasses import dataclass
import time


@dataclass(frozen=True)
class FrameSnapshot:
    state: str
    fps: object
    frames: int
    sequence: object
    lit_pixels: int


class FrameStats:
    def __init__(self, clock=time.monotonic, window=3.0, warmup=1.0, stale=2.5):
        self.clock, self.window, self.warmup, self.stale = clock, window, warmup, stale
        self.reset()

    def reset(self, connected=False):
        self.connected = connected
        self.frames = 0
        self.sequence = None
        self.lit_pixels = 0
        self._arrivals = deque()
        self._started = self._last = None

    def disconnect(self):
        self.connected = False

    def record(self, sequence, pixels):
        now = self.clock()
        if self._last is None or now - self._last >= self.stale:
            self._arrivals.clear()
            self._started = now
        self.connected = True
        self._arrivals.append(now)
        self._last = now
        self.frames += 1
        self.sequence = sequence
        self.lit_pixels = sum(pixel != 0 for pixel in pixels)
        self._trim(now)

    def _trim(self, now):
        cutoff = now - self.window
        while self._arrivals and self._arrivals[0] <= cutoff + 1e-9:
            self._arrivals.popleft()

    def snapshot(self):
        now = self.clock()
        if not self.connected:
            return FrameSnapshot('offline', 0.0, self.frames, self.sequence, self.lit_pixels)
        if self._last is None:
            return FrameSnapshot('warming', None, self.frames, self.sequence, self.lit_pixels)
        if now - self._last >= self.stale:
            return FrameSnapshot('stale', 0.0, self.frames, self.sequence, self.lit_pixels)
        self._trim(now)
        age = now - self._started
        if age < self.warmup or len(self._arrivals) < 2:
            fps = None
        elif age < self.window:
            fps = max(0, len(self._arrivals) - 1) / age
        else:
            fps = len(self._arrivals) / self.window
        return FrameSnapshot('warming' if fps is None else 'live', fps,
                             self.frames, self.sequence, self.lit_pixels)
