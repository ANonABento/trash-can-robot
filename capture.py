#!/usr/bin/env python3
"""Grab a single JPEG frame from the ESP32 over serial and save it."""
import sys, serial, base64, time

PORT = sys.argv[1] if len(sys.argv) > 1 else "/dev/cu.usbserial-0001"
BAUD = 115200
OUT  = "capture.jpg"

print(f"Opening {PORT} at {BAUD}…")
with serial.Serial(PORT, BAUD, timeout=15) as ser:
    time.sleep(0.5)          # let the port settle
    ser.reset_input_buffer()
    ser.write(b"CAPTURE\n")
    print("Sent CAPTURE, waiting for frame…")

    b64data = []
    capturing = False

    while True:
        line = ser.readline().decode("utf-8", errors="ignore").strip()
        if not line:
            continue
        if line == "FRAME_START":
            capturing = True
            print("Receiving frame data…")
        elif line == "FRAME_END" and capturing:
            break
        elif line.startswith("CAPTURE_ERR"):
            print(f"Error from ESP32: {line}")
            sys.exit(1)
        elif capturing:
            b64data.append(line)

img = base64.b64decode("".join(b64data))
with open(OUT, "wb") as f:
    f.write(img)
print(f"Saved {len(img):,} bytes → {OUT}")
print("Open capture.jpg to verify the camera is working.")
