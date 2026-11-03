"""Serial work stays on a thread; the UI never waits for a line or a timeout."""
import queue
import threading

import serial
from PySide6.QtCore import QThread, Signal

try:
    from .protocol import MAX_LINE_BYTES, ProtocolError, decode_message
except ImportError:
    from protocol import MAX_LINE_BYTES, ProtocolError, decode_message


class SerialWorker(QThread):
    message = Signal(dict)
    opened = Signal(str)
    disconnected = Signal(str)
    warning = Signal(str)

    def __init__(self, port, parent=None):
        super().__init__(parent)
        self.port_name = port
        self._stop = threading.Event()
        self._commands = queue.Queue(maxsize=64)
        self._port = None

    def send(self, command):
        try:
            self._commands.put_nowait(command)
        except queue.Full:
            self.warning.emit('Command queue is full; please wait')

    def stop(self):
        self._stop.set()
        port = self._port
        if port is not None:
            for name in ('cancel_read', 'cancel_write'):
                try:
                    getattr(port, name)()
                except (AttributeError, OSError, serial.SerialException):
                    pass

    def run(self):
        reason = 'Disconnected'
        try:
            with serial.Serial(self.port_name, 115200, timeout=0.05, write_timeout=0.5) as port:
                self._port = port
                self.opened.emit(self.port_name)
                pending = bytearray()
                discarding = False
                while not self._stop.is_set():
                    for _ in range(8):
                        if self._stop.is_set():
                            break
                        try:
                            command = self._commands.get_nowait()
                        except queue.Empty:
                            break
                        port.write(command)
                    chunk = port.read(min(max(port.in_waiting, 1), 4096))
                    for char in chunk:
                        if char == 10:
                            if not discarding and pending:
                                try:
                                    self.message.emit(decode_message(pending))
                                except ProtocolError as exc:
                                    self.warning.emit(str(exc))
                            pending.clear()
                            discarding = False
                        elif not discarding:
                            pending.append(char)
                            if len(pending) > MAX_LINE_BYTES:
                                pending.clear()
                                discarding = True
                                self.warning.emit('Discarded an oversized USB message')
        except (serial.SerialException, OSError) as exc:
            reason = str(exc)
        finally:
            self._port = None
        self.disconnected.emit(reason)
