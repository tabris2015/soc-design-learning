#!/usr/bin/env python3
"""Log in on the DE25-Nano serial console, run commands, log out.

    console.py <tty> <user> <password> <command>...

Standard library only. Prints everything the board sends back.
"""
import os
import sys
import termios
import time

tty, user, password, *commands = sys.argv[1:]
fd = os.open(tty, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
attrs = termios.tcgetattr(fd)
attrs[0] = 0                                   # iflag: raw
attrs[1] = 0                                   # oflag
attrs[2] = termios.CS8 | termios.CREAD | termios.CLOCAL
attrs[3] = 0                                   # lflag: no echo, no canonical
attrs[4] = attrs[5] = termios.B115200
termios.tcsetattr(fd, termios.TCSANOW, attrs)
termios.tcflush(fd, termios.TCIOFLUSH)

seen = b""


def read_until(markers, timeout):
    global seen
    end = time.time() + timeout
    while time.time() < end:
        try:
            chunk = os.read(fd, 4096)
        except BlockingIOError:
            chunk = b""
        if chunk:
            seen += chunk
            sys.stdout.write(chunk.decode(errors="replace").replace("\r", ""))
            sys.stdout.flush()
            if any(m in seen[-200:] for m in markers):
                return True
        else:
            time.sleep(0.05)
    return False


def send(text):
    os.write(fd, text.encode())


send("\n")
if read_until([b"login:"], 5):
    send(user + "\n")
    read_until([b"assword:"], 5)
    send(password + "\n")
if not read_until([b"$ ", b"# "], 10):
    sys.exit("no shell prompt")
for i, cmd in enumerate(commands):
    send(f"{cmd}; echo __DONE{i}__\n")
    read_until([f"__DONE{i}__\n".encode(), f"__DONE{i}__\r".encode()], 20)
    read_until([b"$ ", b"# "], 3)
send("exit\n")
read_until([b"login:"], 5)
os.close(fd)
