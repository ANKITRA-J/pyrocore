#!/usr/bin/env python3
"""Check a connected board running PyroCore; never compile or upload firmware."""
import argparse
import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from desktop.protocol import MAX_LINE_BYTES, ProtocolError, decode_message, encode_command


class BoardError(RuntimeError):
    pass


class Connection:
    def __init__(self, port):
        self.port = port
        self.pending = bytearray()
        self.discarding = False
        self.ignored_lines = 0

    def send(self, command, **fields):
        self.port.write(encode_command(command, **fields))
        self.port.flush()

    def receive(self, wanted, seconds=2.0, allow_errors=False):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            char = self.port.read(1)
            if not char:
                continue
            if char == b'\n':
                line = bytes(self.pending)
                self.pending.clear()
                discard, self.discarding = self.discarding, False
                if discard or not line:
                    continue
                try:
                    message = decode_message(line)
                except ProtocolError:
                    self.ignored_lines += 1
                    continue
                kind = message['type']
                if kind == 'error' and not allow_errors:
                    raise BoardError(message.get('message', 'Firmware reported an error'))
                if kind in wanted:
                    return message
            elif not self.discarding:
                self.pending.extend(char)
                if len(self.pending) > MAX_LINE_BYTES:
                    self.pending.clear()
                    self.discarding = True
                    self.ignored_lines += 1
        raise BoardError('Timed out waiting for ' + '/'.join(sorted(wanted)))

    def frame(self):
        self.send('frame')
        return self.receive({'frame'})


def summary(frame):
    pixels = frame['pixels']
    return {'seq': frame['seq'], 'lit_pixels': sum(bool(p) for p in pixels),
            'colours': sorted(set(pixels) - {0}),
            'lit_positions': [i for i, p in enumerate(pixels) if p][:16]}


def check(port, duration, report, fps=5):
    link = Connection(port)
    # Native USB connection may coincide with startup. Require a PyroCore status
    # object before sending any scene commands to the board.
    hello = None
    deadline = time.monotonic() + 8
    while time.monotonic() < deadline and hello is None:
        link.send('hello')
        try:
            candidate = link.receive({'hello'}, seconds=0.6, allow_errors=True)
        except BoardError:
            continue
        if candidate.get('version') != '0.1.0' or 'fpga_verified' not in candidate:
            raise BoardError('The connected device is not running PyroCore firmware v0.1.0')
        hello = candidate
    if hello is None:
        raise BoardError('No PyroCore hello response; use the native USB port and PyroCore firmware')
    if not hello.get('fpga_loaded'):
        raise BoardError(hello.get('loader_message', 'FPGA image was not loaded'))

    report['hello'] = hello
    try:
        link.send('stream', enabled=False)
        link.receive({'ack'})
        # Let a transfer already in progress finish. Discard its complete USB
        # lines before the first manual frame request.
        time.sleep(0.25)
        port.reset_input_buffer()
        link.pending.clear()
        first = link.frame()
        report['first_frame'] = summary(first)

        link.send('launch', material=1, pattern=1)
        link.receive({'ack'})
        moving = []
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline and len(moving) < 2:
            time.sleep(0.08)
            frame = link.frame()
            info = summary(frame)
            if info['colours'] == [2] and 1 <= info['lit_pixels'] <= 8:
                if not moving or (info['seq'] != moving[-1]['seq'] and
                                  info['lit_positions'] != moving[-1]['lit_positions']):
                    moving.append(info)
        if len(moving) != 2:
            raise BoardError('Expected two advancing green-particle frames after Launch')
        report['motion_frames'] = moving

        link.send('clear')
        link.receive({'ack'})
        clear_frame = None
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            time.sleep(0.08)
            frame = link.frame()
            if not any(frame['pixels']):
                clear_frame = summary(frame)
                break
        if clear_frame is None:
            raise BoardError('Clear did not produce an all-black complete frame')
        report['clear_frame'] = clear_frame

        link.send('stream', enabled=True, fps=fps)
        link.receive({'ack'})
        arrivals, sequences = [], []
        deadline = time.monotonic() + duration
        while time.monotonic() < deadline:
            frame = link.receive({'frame'}, seconds=1.2)
            arrivals.append(time.monotonic())
            sequences.append(frame['seq'])
        if len(arrivals) < 2 or len(set(sequences)) < 2:
            raise BoardError('Streaming did not deliver advancing complete frames')
        report['streaming'] = {'frames': len(arrivals), 'target_fps': fps,
            'measured_fps': round((len(arrivals)-1)/(arrivals[-1]-arrivals[0]), 3),
            'first_seq': sequences[0], 'last_seq': sequences[-1]}
        link.send('status')
        status = link.receive({'status'})
        report['final_status'] = status
        if not status.get('fpga_verified'):
            raise BoardError('Firmware has not verified a complete FPGA frame')
        for name in ('crc_errors', 'header_errors', 'timeouts'):
            if status.get(name, 0) > hello.get(name, 0):
                raise BoardError(f'{name} increased during the board run')
        report['ignored_lines'] = link.ignored_lines
        return report
    finally:
        # Restore settings rather than leaving a diagnostic stream configuration.
        try:
            link.send('set', material=hello.get('material', 0), pattern=hello.get('pattern', 0))
            link.send('stream', enabled=bool(hello.get('streaming', True)),
                      fps=int(hello.get('fps_target', 5)))
        except (OSError, ProtocolError) as exc:
            report['restore_error'] = str(exc)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', help='Native USB CDC port; omit to list available ports')
    parser.add_argument('--duration', type=float, default=3, help='Streaming measurement in seconds (1–30)')
    parser.add_argument('--fps', type=int, choices=range(1,8), default=5, help='Requested stream rate (1–7)')
    parser.add_argument('--output', type=Path, default=ROOT/'build/hardware/latest.json')
    args = parser.parse_args()
    try:
        import serial
        from serial.tools import list_ports
    except ImportError:
        parser.exit(2, 'Install desktop/requirements.txt in .venv first.\n')
    if not args.port:
        for p in list_ports.comports():
            print(f'{p.device}: {p.description}')
        print('Choose the board native USB port with --port. Nothing was opened.')
        return
    if not 1 <= args.duration <= 30:
        parser.error('--duration must be between 1 and 30 seconds')
    report = {'started_utc': datetime.now(timezone.utc).isoformat(),
              'port': args.port, 'uploaded_by_this_tool': False, 'status': 'failed'}
    result = 0
    try:
        with serial.Serial(args.port, 115200, timeout=0.1, write_timeout=1) as port:
            check(port, args.duration, report, args.fps)
        report['status'] = 'passed'
        print(f"PASS: Launch, moving green particles, Clear and {report['streaming']['measured_fps']:.2f} FPS streaming")
    except (BoardError, serial.SerialException, OSError) as exc:
        report['error'] = str(exc)
        print('Board run incomplete:', exc, file=sys.stderr)
        result = 1
    finally:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2)+'\n')
        print('Report:', args.output)
    return result


if __name__ == '__main__':
    raise SystemExit(main())
