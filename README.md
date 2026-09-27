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

| Function | GPIO | Connected To |
|---|---|---|
| **L298N Motor Driver** | | |
| ENA (Left PWM) | 6 | L298N ENA |
| IN1 (Left Dir 1) | 7 | L298N IN1 |
| IN2 (Left Dir 2) | 15 | L298N IN2 |
| ENB (Right PWM) | 16 | L298N ENB |
| IN3 (Right Dir 1) | 17 | L298N IN3 |
| IN4 (Right Dir 2) | 18 | L298N IN4 |
| **Camera (OV3660)** | | |
| XCLK | 10 | CAM XCLK |
| SIOD | 40 | CAM SDA |
| SIOC | 39 | CAM SCL |
| D7 | 48 | CAM D7 |
| D6 | 11 | CAM D6 |
| D5 | 12 | CAM D5 |
| D4 | 14 | CAM D4 |
| D3 | 13 | CAM D3 |
| D2 | 47 | CAM D2 |
| D1 | 21 | CAM D1 |
| D0 | 38 | CAM D0 |
| VSYNC | 46 | CAM VSYNC |
| HREF | 45 | CAM HREF |
| PCLK | 41 | CAM PCLK |
| **Status LED** | | |
| LED | 2 | Built-in LED |

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

### MJPEG Stream (ESP32 -> MacBook)

- URL: `http://<ESP32_IP>:80/stream`
- Format: multipart JPEG (VGA, quality 12)

### Safety

The ESP32 firmware applies motor commands directly from UDP with no on-board obstacle detection. All safety logic (obstacle avoidance, speed clamping, emergency stop) is handled at the software level on the laptop by the ROS2 `safety_monitor_node`, which processes the camera feed and any future sensor inputs to gate motor commands before they are sent over UDP.
