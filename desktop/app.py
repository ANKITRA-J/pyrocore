#!/usr/bin/env python3
"""PyroCore control panel. Run --demo for an explicitly labelled software preview."""
import argparse
from collections import deque
import math
from pathlib import Path
import random
import sys
import time

from PySide6.QtCore import Qt, QTimer, QRectF
from PySide6.QtGui import QColor, QFont, QImage, QPainter, QPen
from PySide6.QtWidgets import (QApplication, QComboBox, QFrame, QHBoxLayout,
    QLabel, QMainWindow, QPushButton, QSizePolicy, QVBoxLayout, QWidget)
from serial.tools import list_ports

try:
    from .protocol import MATERIALS, PALETTE, PATTERNS, encode_command
    from .serial_worker import SerialWorker
except ImportError:
    from protocol import MATERIALS, PALETTE, PATTERNS, encode_command
    from serial_worker import SerialWorker

STYLE = '''
QMainWindow, QWidget { background: #0b101b; color: #e8edf5; font-family: 'Inter', 'Arial'; font-size: 13px; }
QLabel { background: transparent; }
QFrame#card { background: #111927; border: 1px solid #223047; border-radius: 14px; }
QFrame#separator { background: #223047; border: none; }
QLabel#muted { color: #8d9cb1; }
QLabel#eyebrow { color: #ffad64; font-size: 11px; font-weight: 700; }
QLabel#title { font-size: 30px; font-weight: 800; letter-spacing: 2px; }
QLabel#section { font-size: 17px; font-weight: 700; }
QLabel#badge { color: #98a9bf; background: #172334; border: 1px solid #2b3c54; border-radius: 10px; padding: 7px 10px; font-size: 11px; }
QLabel#demo { color: #ffcf89; background: #33271c; border: 1px solid #72512b; border-radius: 8px; padding: 9px; font-size: 12px; }
QComboBox { background: #0c1421; border: 1px solid #2d3c51; border-radius: 8px; padding: 10px; min-height: 18px; }
QComboBox::drop-down { border: none; width: 25px; }
QComboBox QAbstractItemView { background: #172334; selection-background-color: #385479; }
QPushButton { background: #1a283b; border: 1px solid #31445f; border-radius: 8px; padding: 10px 14px; font-weight: 600; }
QPushButton:hover { background: #263b55; border-color: #527292; }
QPushButton:pressed { background: #365271; }
QPushButton:disabled { color: #55677d; background: #111927; border-color: #223047; }
QPushButton#launch { background: #ff9a50; color: #1b1110; border: 1px solid #ffb677; font-size: 15px; padding: 13px; }
QPushButton#launch:hover { background: #ffb677; }
QPushButton#launch:disabled { background: #4d3525; color: #96765a; border-color: #5f4430; }
'''


def label(text, name=None):
    widget = QLabel(text)
    if name:
        widget.setObjectName(name)
    return widget


def card():
    widget = QFrame()
    widget.setObjectName('card')
    return widget


class PixelCanvas(QWidget):
    def __init__(self):
        super().__init__()
        self.image = None
        self.setMinimumSize(420, 420)
        self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)

    def set_pixels(self, pixels):
        rgb = bytearray()
        for pixel in pixels:
            rgb.extend(PALETTE[pixel])
        self.image = QImage(bytes(rgb), 64, 64, 64 * 3, QImage.Format_RGB888).copy()
        self.update()

    def clear(self):
        self.image = None
        self.update()

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)
        size = min(self.width(), self.height()) - 28
        rect = QRectF((self.width() - size) / 2, (self.height() - size) / 2, size, size)
        painter.setPen(QPen(QColor('#263c54'), 1))
        painter.setBrush(QColor('#000000'))
        painter.drawRoundedRect(rect, 10, 10)
        inner = rect.adjusted(8, 8, -8, -8)
        if self.image is not None:
            painter.setRenderHint(QPainter.SmoothPixmapTransform, False)
            painter.drawImage(inner, self.image)
        else:
            painter.setPen(QColor('#74869d'))
            painter.setFont(QFont('Arial', 16))
            painter.drawText(inner, Qt.AlignCenter, 'Ready for a spark\n\nConnect your Shrike-Fi to display FPGA frames')


class DemoScene:
    """Optional UI preview only. Never used by the connected frame path."""
    def __init__(self):
        self.rng = random.Random(143)
        self.particles = []
        self.frame = 0

    def launch(self, material=0, pattern=0):
        colours = [1, 2, 3, 4, 6, 7]
        cx, cy = self.rng.randrange(18, 46), self.rng.randrange(15, 32)
        for index in range(56):
            angle = 2 * math.pi * index / 56
            speed = 0.65 if pattern == 1 else self.rng.uniform(0.3, 0.9)
            vy = math.sin(angle) * speed
            if pattern == 2:
                vy -= 0.35
            self.particles.append([float(cx), float(cy), math.cos(angle) * speed,
                                   vy, self.rng.randrange(35, 72), colours[material]])

    def step(self):
        pixels = bytearray(4096)
        living = []
        for particle in self.particles:
            x, y, vx, vy, life, colour = particle
            for back in range(3):
                px, py = round(x - vx * back), round(y - vy * back)
                if 0 <= px < 64 and 0 <= py < 64 and (life > 12 or self.frame % 2):
                    pixels[py * 64 + px] = colour if back == 0 else (5 if colour in (1, 4, 5) else colour)
            x += vx
            y += vy
            vy += 0.018
            if life > 0:
                living.append([x, y, vx, vy, life - 1, colour])
        self.particles = living
        self.frame += 1
        return pixels


class MainWindow(QMainWindow):
    def __init__(self, demo=False):
        super().__init__()
        self.demo = demo
        self.scene = DemoScene() if demo else None
        self.worker = None
        self.arrivals = deque(maxlen=30)
        self.frame_count = 0
        self.rng = random.Random()
        self.setWindowTitle('PyroCore — FPGA Fireworks Engine' + (' · SOFTWARE PREVIEW' if demo else ''))
        self.resize(1120, 840)
        self.setMinimumSize(960, 760)
        self.setStyleSheet(STYLE)
        body = QWidget()
        self.setCentralWidget(body)
        root = QVBoxLayout(body)
        root.setContentsMargins(28, 24, 28, 18)
        root.setSpacing(18)
        header = QHBoxLayout()
        brand = QVBoxLayout()
        brand.setSpacing(1)
        brand.addWidget(label('PYROCORE', 'title'))
        brand.addWidget(label('SMALL FPGA. REAL SPARKS.', 'eyebrow'))
        header.addLayout(brand)
        header.addStretch()
        header.addWidget(label('SHRIKE-FI  /  64 × 64  /  3-BIT COLOUR', 'badge'))
        root.addLayout(header)

        self.banner = label('SOFTWARE PREVIEW · Simulated particles, FPGA disconnected' if demo else
                            'Connect the board to view frames generated by the FPGA.', 'demo' if demo else 'badge')
        root.addWidget(self.banner)
        content = QHBoxLayout()
        content.setSpacing(20)
        sidebar = QVBoxLayout()
        sidebar.setSpacing(16)
        controls = card()
        controls.setFixedWidth(310)
        controls_layout = QVBoxLayout(controls)
        controls_layout.setContentsMargins(20, 20, 20, 20)
        controls_layout.setSpacing(11)
        controls_layout.addWidget(label('Launch control', 'section'))
        controls_layout.addWidget(label('Material', 'muted'))
        self.material = QComboBox()
        self.material.addItems(MATERIALS)
        controls_layout.addWidget(self.material)
        controls_layout.addWidget(label('Burst pattern', 'muted'))
        self.pattern = QComboBox()
        self.pattern.addItems(PATTERNS)
        controls_layout.addWidget(self.pattern)
        controls_layout.addSpacing(8)
        self.launch_button = QPushButton('Launch firework')
        self.launch_button.setObjectName('launch')
        self.launch_button.clicked.connect(self.launch)
        controls_layout.addWidget(self.launch_button)
        self.random_button = QPushButton('Start random show')
        self.random_button.setCheckable(True)
        self.random_button.toggled.connect(self.random_show)
        controls_layout.addWidget(self.random_button)
        self.clear_button = QPushButton('Clear scene')
        self.clear_button.clicked.connect(self.clear_scene)
        controls_layout.addWidget(self.clear_button)
        controls_layout.addSpacing(6)
        note = label('Physics and pixel rendering run on the FPGA.\nThe laptop displays completed frames.', 'muted')
        note.setWordWrap(True)
        controls_layout.addWidget(note)
        sidebar.addWidget(controls)

        connection = card()
        connection.setFixedWidth(310)
        conn_layout = QVBoxLayout(connection)
        conn_layout.setContentsMargins(20, 20, 20, 20)
        conn_layout.setSpacing(10)
        conn_layout.addWidget(label('Board connection', 'section'))
        ports_line = QHBoxLayout()
        self.ports = QComboBox()
        self.ports.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        self.refresh_button = QPushButton('↻')
        self.refresh_button.setFixedWidth(42)
        self.refresh_button.setToolTip('Refresh serial ports')
        self.refresh_button.clicked.connect(self.refresh_ports)
        ports_line.addWidget(self.ports)
        ports_line.addWidget(self.refresh_button)
        conn_layout.addLayout(ports_line)
        self.connect_button = QPushButton('Connect')
        self.connect_button.clicked.connect(self.toggle_connection)
        conn_layout.addWidget(self.connect_button)
        self.status_label = label('Preview mode' if demo else 'Disconnected', 'muted')
        self.status_label.setWordWrap(True)
        conn_layout.addWidget(self.status_label)
        rate = label('Initial hardware stream: 5 FPS\nUSB → ESP32 → FPGA UART', 'muted')
        conn_layout.addWidget(rate)
        sidebar.addWidget(connection)
        sidebar.addStretch()
        content.addLayout(sidebar)

        display = card()
        display_layout = QVBoxLayout(display)
        display_layout.setContentsMargins(16, 16, 16, 16)
        display_heading = QHBoxLayout()
        display_heading.addWidget(label('Software preview' if demo else 'FPGA framebuffer', 'section'))
        display_heading.addStretch()
        self.live_label = label('DEMO' if demo else 'WAITING', 'badge')
        display_heading.addWidget(self.live_label)
        display_layout.addLayout(display_heading)
        self.canvas = PixelCanvas()
        display_layout.addWidget(self.canvas, 1)
        self.frame_label = label('No hardware frames received', 'muted')
        display_layout.addWidget(self.frame_label)
        palette_row = QHBoxLayout()
        palette_row.setSpacing(8)
        palette_row.addWidget(label('PALETTE', 'muted'))
        for rgb in PALETTE:
            swatch = QLabel()
            swatch.setFixedSize(20, 20)
            swatch.setStyleSheet('background: rgb(%d,%d,%d); border: 1px solid #496079; border-radius: 5px;' % rgb)
            palette_row.addWidget(swatch)
        palette_row.addStretch()
        palette_row.addWidget(label('8 entries · background included', 'muted'))
        display_layout.addLayout(palette_row)
        content.addWidget(display, 1)
        root.addLayout(content, 1)
        self.event_label = label('Ready.' if demo else 'Ready. No serial port is opened until you connect.', 'muted')
        self.event_label.setWordWrap(True)
        root.addWidget(self.event_label)

        self.random_timer = QTimer(self)
        self.random_timer.setInterval(1700)
        self.random_timer.timeout.connect(self.random_launch)
        self.freshness_timer = QTimer(self)
        self.freshness_timer.setInterval(1000)
        self.freshness_timer.timeout.connect(self.check_freshness)
        self.freshness_timer.start()
        self.refresh_ports()
        self.set_controls(demo)
        if demo:
            for widget in (self.ports, self.refresh_button, self.connect_button):
                widget.setEnabled(False)
            self.scene.launch(3, 0)
            self.scene.launch(2, 2)
            self.preview_timer = QTimer(self)
            self.preview_timer.setInterval(33)
            self.preview_timer.timeout.connect(self.demo_tick)
            self.preview_timer.start()
            self.demo_tick()

    def set_controls(self, enabled):
        for widget in (self.launch_button, self.random_button, self.clear_button):
            widget.setEnabled(enabled)

    def refresh_ports(self):
        current = self.ports.currentData()
        self.ports.clear()
        for port in list_ports.comports():
            self.ports.addItem(f'{port.device} · {port.description}', port.device)
        if self.ports.count() == 0:
            self.ports.addItem('No serial ports found', None)
        selected = self.ports.findData(current)
        if selected >= 0:
            self.ports.setCurrentIndex(selected)

    def toggle_connection(self):
        if self.worker is not None:
            self.disconnect()
            return
        port = self.ports.currentData()
        if not port:
            self.event_label.setText('Connect a Shrike-Fi and refresh the serial-port list.')
            return
        self.canvas.clear()
        self.arrivals.clear()
        self.frame_count = 0
        self.worker = SerialWorker(port, self)
        self.worker.opened.connect(self.on_opened)
        self.worker.message.connect(self.on_message)
        self.worker.warning.connect(self.on_warning)
        self.worker.disconnected.connect(self.on_disconnected)
        self.worker.finished.connect(self.worker.deleteLater)
        self.worker.start()
        self.connect_button.setText('Connecting…')
        self.ports.setEnabled(False)
        self.refresh_button.setEnabled(False)

    def on_opened(self, port):
        self.status_label.setText('USB connected. Waiting for FPGA frames…')
        self.connect_button.setText('Disconnect')
        self.set_controls(True)
        self.send('hello')
        self.send('stream', enabled=True, fps=5)
        QTimer.singleShot(1500, self.confirm_stream)

    def confirm_stream(self):
        if self.worker is not None and self.worker.isRunning():
            self.send('hello')
            self.send('stream', enabled=True, fps=5)

    def send(self, command, **fields):
        if self.worker is not None:
            self.worker.send(encode_command(command, **fields))

    def launch(self):
        material, pattern = self.material.currentIndex(), self.pattern.currentIndex()
        if self.demo:
            self.scene.launch(material, pattern)
            self.event_label.setText('Software preview burst. No FPGA command was sent.')
        else:
            self.send('launch', material=material, pattern=pattern)
            self.event_label.setText(f'Launch command sent · {MATERIALS[material]} · {PATTERNS[pattern]}')

    def random_launch(self):
        self.material.setCurrentIndex(self.rng.randrange(6))
        self.pattern.setCurrentIndex(self.rng.randrange(3))
        self.launch()

    def random_show(self, running):
        self.random_button.setText('Stop random show' if running else 'Start random show')
        if running:
            self.random_launch()
            self.random_timer.start()
        else:
            self.random_timer.stop()

    def clear_scene(self):
        if self.demo:
            self.scene.particles.clear()
            self.demo_tick()
        else:
            self.send('clear')
            self.event_label.setText('Clear command sent; awaiting the next complete FPGA frame.')

    def on_message(self, message):
        if message['type'] == 'frame':
            self.canvas.set_pixels(message['pixels'])
            now = time.monotonic()
            self.arrivals.append(now)
            self.frame_count += 1
            fps = (len(self.arrivals) - 1) / (now - self.arrivals[0]) if len(self.arrivals) > 1 else 0
            self.frame_label.setText(f'Frame {message["seq"]:05d}   ·   {fps:.1f} received FPS   ·   {self.frame_count} frames   ·   CRC verified')
            self.status_label.setText('FPGA communication verified by a complete frame')
            self.live_label.setText('LIVE FPGA')
            self.banner.setText('FPGA frames · 64 × 64 pixels · 1,536 bytes per frame')
        elif message['type'] in ('hello', 'status'):
            self.event_label.setText('Bridge v' + str(message.get('version', '?')) +
                (' · FPGA image transferred; waiting for frames' if message.get('fpga_loaded') else ' · FPGA image unavailable'))
        elif message['type'] == 'error':
            self.on_warning(str(message.get('message', 'Unknown bridge error')))

    def on_warning(self, text):
        self.event_label.setText('Connection: ' + text[:220])

    def check_freshness(self):
        if not self.demo and self.worker is not None and self.arrivals and time.monotonic() - self.arrivals[-1] > 2.5:
            self.live_label.setText('FRAME STALE')
            self.status_label.setText('No recent complete frame. Last image retained.')

    def demo_tick(self):
        self.canvas.set_pixels(self.scene.step())
        self.frame_label.setText(f'Software preview frame {self.scene.frame:05d}   ·   Not connected to an FPGA')

    def disconnect(self):
        self.random_button.setChecked(False)
        self.set_controls(False)
        if self.worker is not None:
            self.worker.stop()
            self.worker.wait(1500)

    def on_disconnected(self, reason):
        self.worker = None
        self.connect_button.setText('Connect')
        self.ports.setEnabled(True)
        self.refresh_button.setEnabled(True)
        self.status_label.setText('Disconnected')
        self.live_label.setText('OFFLINE')
        self.set_controls(False)
        self.event_label.setText(reason[:220])
        self.random_button.setChecked(False)

    def closeEvent(self, event):
        self.disconnect()
        event.accept()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--demo', action='store_true', help='labelled offline software preview')
    parser.add_argument('--screenshot', type=Path, help='save a window screenshot, then quit')
    args = parser.parse_args()
    app = QApplication(sys.argv[:1])
    window = MainWindow(demo=args.demo)
    window.show()
    if args.screenshot:
        def capture():
            args.screenshot.parent.mkdir(parents=True, exist_ok=True)
            if not window.grab().save(str(args.screenshot)):
                raise RuntimeError('Could not save screenshot')
            window.close()
            app.quit()
        QTimer.singleShot(600, capture)
    return app.exec()


if __name__ == '__main__':
    sys.exit(main())
