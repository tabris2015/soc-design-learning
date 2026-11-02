#!/usr/bin/env python3
"""Wait, without typing anything, until the DE25-Nano console shows a login prompt.

    wait-login.py <tty> [timeout seconds]

Sending a key while U-Boot counts down stops the boot, so this only reads.
Exits 0 once "login:" appears, 1 on timeout. Echoes the boot log as it goes.
"""
import os
import sys
import termios
import time

tty = sys.argv[1]
timeout = float(sys.argv[2]) if len(sys.argv) > 2 else 600
fd = os.open(tty, os.O_RDONLY | os.O_NOCTTY | os.O_NONBLOCK)
attrs = termios.tcgetattr(fd)
attrs[0] = attrs[1] = attrs[3] = 0
attrs[2] = termios.CS8 | termios.CREAD | termios.CLOCAL
attrs[4] = attrs[5] = termios.B115200
termios.tcsetattr(fd, termios.TCSANOW, attrs)

tail = b""
end = time.time() + timeout
while time.time() < end:
    try:
        chunk = os.read(fd, 4096)
    except BlockingIOError:
        chunk = b""
    if not chunk:
        time.sleep(0.1)
        continue
    sys.stdout.write(chunk.decode(errors="replace").replace("\r", ""))
    sys.stdout.flush()
    tail = (tail + chunk)[-64:]
    if b"login:" in tail:
        sys.exit(0)
sys.exit(1)
