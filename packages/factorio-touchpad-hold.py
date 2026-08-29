#!/usr/bin/env python3
"""Turn a stationary two-finger touch into an RMB hold in Factorio."""

import json
import os
import select
import signal
import struct
import subprocess
import sys
import time


DEVICE = "/dev/input/factorio-touchpad"
HOLD_SECONDS = 0.7
# The touchpad reports 31 units/mm. Allow normal contact jitter, but cancel
# before a deliberate two-finger scroll gets underway.
MOVE_THRESHOLD = 50

EV_KEY = 0x01
EV_ABS = 0x03
EV_SYN = 0x00
SYN_REPORT = 0
BTN_TOOL_DOUBLETAP = 333
ABS_MT_SLOT = 47
ABS_MT_POSITION_X = 53
ABS_MT_POSITION_Y = 54
ABS_MT_TRACKING_ID = 57

EVENT = struct.Struct("llHHi")


class HoldGesture:
    def __init__(self):
        self.slot = 0
        self.positions = {}
        self.start_positions = None
        self.two_fingers = False
        self.started_at = None
        self.cancelled = False
        self.pressed = False
        self.next_focus_check = 0.0

    def handle(self, event_type, code, value):
        if event_type == EV_ABS:
            if code == ABS_MT_SLOT:
                self.slot = value
            elif code == ABS_MT_TRACKING_ID and value < 0:
                self.positions.pop(self.slot, None)
            elif code in (ABS_MT_POSITION_X, ABS_MT_POSITION_Y):
                x, y = self.positions.get(self.slot, (None, None))
                if code == ABS_MT_POSITION_X:
                    x = value
                else:
                    y = value
                self.positions[self.slot] = (x, y)
        elif event_type == EV_KEY and code == BTN_TOOL_DOUBLETAP:
            if value:
                self.two_fingers = True
                self.started_at = time.monotonic()
                self.start_positions = None
                self.cancelled = False
            else:
                self.two_fingers = False
                self.started_at = None
                self.start_positions = None
                self.cancelled = False
                self.release()
        elif event_type == EV_SYN and code == SYN_REPORT:
            self.finish_frame()

    def finish_frame(self):
        if not self.two_fingers or self.cancelled:
            return

        complete = {
            slot: position
            for slot, position in self.positions.items()
            if position[0] is not None and position[1] is not None
        }
        if len(complete) < 2:
            return
        if self.start_positions is None:
            self.start_positions = complete.copy()
            return

        for slot, (start_x, start_y) in self.start_positions.items():
            current = complete.get(slot)
            if current is None:
                self.cancelled = True
                return
            if abs(current[0] - start_x) > MOVE_THRESHOLD or abs(current[1] - start_y) > MOVE_THRESHOLD:
                self.cancelled = True
                return

    def tick(self):
        now = time.monotonic()

        if self.pressed and now >= self.next_focus_check:
            self.next_focus_check = now + 0.25
            if not factorio_is_active():
                self.release()
                self.cancelled = True
                return

        if (
            self.two_fingers
            and not self.cancelled
            and not self.pressed
            and self.started_at is not None
            and self.start_positions is not None
            and now - self.started_at >= HOLD_SECONDS
        ):
            if factorio_is_active() and send_button("0x41"):
                self.pressed = True
                self.next_focus_check = now + 0.25
                print("Factorio two-finger hold: RMB down", flush=True)
            else:
                self.cancelled = True

    def release(self):
        if self.pressed:
            send_button("0x81")
            self.pressed = False
            self.next_focus_check = 0.0
            print("Factorio two-finger hold: RMB up", flush=True)


def factorio_is_active():
    try:
        result = subprocess.run(
            ["hyprctl", "activewindow", "-j"],
            check=True,
            capture_output=True,
            text=True,
            timeout=0.5,
        )
        window = json.loads(result.stdout)
    except (OSError, subprocess.SubprocessError, json.JSONDecodeError):
        return False

    identity = " ".join(
        str(window.get(field, ""))
        for field in ("class", "initialClass", "title", "initialTitle")
    ).lower()
    return "factorio" in identity


def send_button(button):
    try:
        subprocess.run(
            ["ydotool", "click", button],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            timeout=0.5,
        )
        return True
    except (OSError, subprocess.SubprocessError) as error:
        print(f"Could not inject {button}: {error}", file=sys.stderr, flush=True)
        return False


def main():
    gesture = HoldGesture()
    stopping = False

    def stop(_signum, _frame):
        nonlocal stopping
        stopping = True

    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)

    with open(DEVICE, "rb", buffering=0) as device:
        buffered = b""
        while not stopping:
            readable, _, _ = select.select([device], [], [], 0.05)
            if readable:
                chunk = os.read(device.fileno(), EVENT.size * 64)
                if not chunk:
                    break
                buffered += chunk
                while len(buffered) >= EVENT.size:
                    raw, buffered = buffered[: EVENT.size], buffered[EVENT.size :]
                    _sec, _usec, event_type, code, value = EVENT.unpack(raw)
                    gesture.handle(event_type, code, value)
            gesture.tick()

    gesture.release()


if __name__ == "__main__":
    main()
