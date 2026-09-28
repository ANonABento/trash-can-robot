# Trash Can Robot

A mobile autonomous trash can robot with ESP32-S3 firmware and a ROS2 stack running on a MacBook Air for inference and control.

## Architecture

```
MacBook Air (M5, 24GB)                    ESP32-S3-WROOM (N16R8)
  ROS2 Humble                              Arduino/PlatformIO
  +-----------------+                      +------------------+
  | camera_node     |<--- MJPEG/HTTP ------|  OV3660 camera   |
  | motor_node      |---- UDP:4210 ------->|  L298N motors    |
  | safety_monitor  |                      +------------------+
  | teleop_key_node |
  +-----------------+
        |
    Foxglove Studio
    (visualization)
```

## Hardware

| Component | Spec |
|---|---|
| MCU | ESP32-S3-WROOM N16R8 (16MB flash, 8MB PSRAM) |
| Camera | OV3660 (VGA MJPEG over HTTP) |
| Motors | 2x 12V 100RPM DC, differential drive |
| Motor Driver | L298N H-bridge |
| Power | 12V from USB-C PD trigger, 5V via LM2596 buck to ESP32 |
| Inference Host | MacBook Air M5 24GB |

## Wiring

### ESP32 GPIO Pin Assignments

Source of truth is `firmware/src/config.h.example`.

| Function | GPIO | Connected To |
|---|---|---|
| **L298N Motor Driver** | | |
| ENA (Left PWM) | 1 | L298N ENA |
| IN1 (Left Dir 1) | 14 | L298N IN1 |
| IN2 (Left Dir 2) | 21 | L298N IN2 |
| ENB (Right PWM) | 47 | L298N ENB |
| IN3 (Right Dir 1) | 41 | L298N IN3 |
| IN4 (Right Dir 2) | 42 | L298N IN4 |
| **Camera (OV3660)** | | |
| PWDN | 38 | CAM PWDN |
| XCLK | 15 | CAM XCLK |
| SIOD | 4 | CAM SDA |
| SIOC | 5 | CAM SCL |
| D7–D0 (Y9–Y2) | 16, 17, 18, 12, 10, 8, 9, 11 | CAM D7–D0 |
| VSYNC | 6 | CAM VSYNC |
| HREF | 7 | CAM HREF |
| PCLK | 13 | CAM PCLK |
| **Status LED** | | |
| LED | 2 | Built-in LED |

Motor pins avoid USB D-/D+ (19, 20), strapping pins (0, 3, 45, 46), UART0 (43, 44), octal PSRAM/flash (26–37) and the RGB LED (48). GPIO 39/40 are free spares.

### Power

- 12V from PD trigger to L298N VCC and LM2596 input
- LM2596 output (5V) to ESP32 VIN
- L298N 5V regulator jumper removed (powered externally)

## Setup

### 1. Firmware (ESP32)

```bash
# Copy config template and fill in WiFi credentials + pin assignments
cp firmware/src/config.h.example firmware/src/config.h
# Edit firmware/src/config.h with your WiFi SSID/password

# Build and flash with PlatformIO
cd firmware
pio run -t upload
pio device monitor  # check serial output
```

The ESP32 joins `WIFI_SSID`. If that fails within 15 s it hosts its own network, `trashcan-bot` (password in `config.h`), at `192.168.4.1` — use that where guest WiFi isolates clients.

Serial test commands (115200 baud), no WiFi needed:

- `MOTOR <l> <r> [ms]` — drive the motors (-255..255) for `ms` (default 1000, max 5000)
- `STOP` — stop the motors
- `CAPTURE` — dump one JPEG as base64 (`python3 capture.py <port>` saves it)

### 2. ROS2 Nodes (MacBook)

```bash
# Install Python dependencies
pip install -r requirements.txt

# Build the ROS2 workspace
cd ros2_ws
colcon build --packages-select trashcan_bot
source install/setup.bash

# Launch all nodes (camera + motor + safety monitor)
ros2 launch trashcan_bot bringup.launch.py esp32_ip:=<YOUR_ESP32_IP>

# In another terminal, launch keyboard teleop
source install/setup.bash
ros2 launch trashcan_bot teleop.launch.py
```

### 3. Foxglove Visualization

```bash
# Install and launch the Foxglove bridge
sudo apt install ros-humble-foxglove-bridge  # or brew on macOS
ros2 launch foxglove_bridge foxglove_bridge.launch.xml
```

Open Foxglove Studio and import `foxglove/trashcan_layout.json`.

## Communication Protocol

### UDP Motor Commands (MacBook -> ESP32)

- Port: 4210
- Format: JSON `{"l": <int>, "r": <int>}`
- Values: -255 to 255 (negative = reverse)
- `l` = left motor PWM, `r` = right motor PWM
- Failsafe: the ESP32 stops both motors if no command arrives for 300 ms. `motor_node` re-sends the latest command at 20 Hz and sends zeros once `/cmd_vel_safe` has been quiet for 0.6 s.

### MJPEG Stream (ESP32 -> MacBook)

- URL: `http://<ESP32_IP>:80/stream`
- Format: multipart JPEG (VGA, quality 12)

### Safety

The ESP32's only safeguard is the command timeout above. There is no obstacle detection yet: the ToF sensors were dropped, and `safety_monitor_node` only clamps speeds. Obstacle gating belongs in that node, between `/cmd_vel` and `/cmd_vel_safe`.
