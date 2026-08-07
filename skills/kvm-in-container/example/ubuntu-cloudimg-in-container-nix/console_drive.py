#!/usr/bin/env python3
"""Drive a VM serial console pty non-interactively: wait for the login
prompt, log in, run commands, print captured output.

Usage: console_drive.py $(virsh ttyconsole NAME)

virsh console is interactive-only; this opens the pty behind it directly,
which is how an agent (or CI) controls the guest without a human at the
keyboard. Nudges with newlines until "login:" appears, so it works both on
a fresh boot and on an already-idle console.
"""
import os, re, select, sys, termios, time, tty

PTY = sys.argv[1]
fd = os.open(PTY, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
tty.setraw(fd)

buf = b""

def read_for(seconds):
    global buf
    end = time.time() + seconds
    out = b""
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.2)
        if r:
            try:
                chunk = os.read(fd, 4096)
            except OSError:
                break
            if not chunk:
                break
            out += chunk
    buf += out
    return out

def send(s):
    os.write(fd, s.encode())

def wait_for(pattern, timeout, nudge=None):
    global buf
    end = time.time() + timeout
    last_nudge = 0.0
    while time.time() < end:
        if re.search(pattern, buf[-4096:].decode("utf-8", "replace")):
            return True
        if nudge and time.time() - last_nudge > 5:
            send(nudge)
            last_nudge = time.time()
        read_for(1)
    return False

def die(msg):
    print(msg)
    print(buf[-2000:].decode("utf-8", "replace"))
    sys.exit(1)

# cloud-init applies the seed's password on first boot; allow time for that
if not wait_for(r"login:", 180, nudge="\n"):
    die("NO LOGIN PROMPT; last output:")
send("ubuntu\n")
if not wait_for(r"Password:", 30):
    die("NO PASSWORD PROMPT")
send("ubuntu\n")
if not wait_for(r"\$", 30):
    die("NO SHELL PROMPT")

buf = b""
send("echo CONSOLE-OK $(hostname) $(uname -r)\n")
read_for(3)
send("id\n")
read_for(3)
print(buf.decode("utf-8", "replace"))
