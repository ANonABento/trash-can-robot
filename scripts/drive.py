#!/usr/bin/env python3
"""Drive the robot over UDP without ROS.

  scripts/drive.py 255 0          left motor full forward for 1 s
  scripts/drive.py -150 -150 3    both motors reverse at 150 for 3 s
  scripts/drive.py --keys         keyboard teleop (WASD, space = stop, q = quit)

Commands are repeated at 20 Hz because the ESP32 stops the motors after
300 ms without one. The robot is found by its mDNS name, trashcam.local;
set ROBOT_IP (or --ip) to use an address instead.
"""
import argparse
import curses
import json
import os
import socket
import time

PORT = 4210
PERIOD = 0.05  # 20 Hz

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)


def send(ip, l, r):
    sock.sendto(json.dumps({"l": int(l), "r": int(r)}).encode(), (ip, PORT))


def stop(ip):
    for _ in range(5):
        send(ip, 0, 0)
        time.sleep(PERIOD)


def drive(ip, l, r, seconds):
    end = time.time() + seconds
    try:
        while time.time() < end:
            send(ip, l, r)
            time.sleep(PERIOD)
    finally:
        stop(ip)


def teleop(screen, ip, speed):
    curses.curs_set(0)
    screen.nodelay(True)
    l = r = 0
    try:
        while True:
            key = screen.getch()
            if key in (ord("q"), 27):
                break
            if key == ord("w"):
                l, r = speed, speed
            elif key == ord("s"):
                l, r = -speed, -speed
            elif key == ord("a"):
                l, r = -speed, speed
            elif key == ord("d"):
                l, r = speed, -speed
            elif key == ord(" "):
                l = r = 0
            elif key in (ord("+"), ord("=")):
                speed = min(255, speed + 25)
            elif key == ord("-"):
                speed = max(0, speed - 25)
            screen.erase()
            screen.addstr(0, 0, f"robot {ip}   speed {speed}   (+/- to change)")
            screen.addstr(1, 0, "w fwd  s back  a/d spin  space stop  q quit")
            screen.addstr(3, 0, f"L {l:5d}   R {r:5d}")
            send(ip, l, r)
            time.sleep(PERIOD)
    finally:
        stop(ip)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("l", nargs="?", type=int, help="left PWM, -255..255")
    p.add_argument("r", nargs="?", type=int, help="right PWM, -255..255")
    p.add_argument("seconds", nargs="?", type=float, default=1.0)
    p.add_argument("--keys", action="store_true", help="keyboard teleop")
    p.add_argument("--speed", type=int, default=200, help="teleop speed (default 200)")
    p.add_argument("--ip", default=os.environ.get("ROBOT_IP", "trashcam.local"))
    a = p.parse_args()
    # Resolve once: sendto() with a .local name would do an mDNS lookup per packet.
    try:
        a.ip = socket.gethostbyname(a.ip)
    except OSError:
        p.error(f"can't resolve {a.ip}; is the robot on the same network? Try ROBOT_IP=<address>")

    if a.keys:
        curses.wrapper(teleop, a.ip, a.speed)
    elif a.l is not None and a.r is not None:
        drive(a.ip, max(-255, min(255, a.l)), max(-255, min(255, a.r)), a.seconds)
    else:
        p.error("give <l> <r> [seconds], or --keys")


if __name__ == "__main__":
    main()
