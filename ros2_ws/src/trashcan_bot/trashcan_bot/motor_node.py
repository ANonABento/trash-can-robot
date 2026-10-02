"""Motor node: converts /cmd_vel Twist to differential drive PWM and sends UDP to ESP32."""

import json
import socket
import math
import time

import rclpy
from rclpy.node import Node
from geometry_msgs.msg import Twist

# Robot physical parameters
TRACK_WIDTH_M = 0.18       # distance between wheel centers
WHEEL_RADIUS_M = 0.0325    # wheel radius

# Motor specs: 100 RPM at 12V -> max wheel speed
MAX_WHEEL_RAD_S = (100.0 * 2.0 * math.pi) / 60.0  # ~10.47 rad/s
MAX_LINEAR_M_S = MAX_WHEEL_RAD_S * WHEEL_RADIUS_M  # ~0.34 m/s


class MotorNode(Node):

    def __init__(self):
        super().__init__('motor_node')

        self.declare_parameter('esp32_ip', 'trashcam.local')
        self.declare_parameter('udp_port', 4210)

        self.esp32_ip = self.get_parameter('esp32_ip').value
        self.udp_port = self.get_parameter('udp_port').value

        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self._addr = None
        self._addr_t = 0.0

        self.sub = self.create_subscription(
            Twist, '/cmd_vel_safe', self._cmd_vel_cb, 10
        )

        self.get_logger().info(
            f'Motor node ready. Sending UDP to {self.esp32_ip}:{self.udp_port}'
        )

    def _cmd_vel_cb(self, msg: Twist):
        linear_x = msg.linear.x    # m/s forward
        angular_z = msg.angular.z  # rad/s counterclockwise

        # Differential drive kinematics: convert to wheel speeds (rad/s)
        v_left = (linear_x - angular_z * TRACK_WIDTH_M / 2.0) / WHEEL_RADIUS_M
        v_right = (linear_x + angular_z * TRACK_WIDTH_M / 2.0) / WHEEL_RADIUS_M

        # Normalize to PWM range [-255, 255]
        pwm_left = int(self._clamp(v_left / MAX_WHEEL_RAD_S * 255.0, -255, 255))
        pwm_right = int(self._clamp(v_right / MAX_WHEEL_RAD_S * 255.0, -255, 255))

        # Send UDP JSON matching firmware format: {"l": <int>, "r": <int>}
        payload = json.dumps({"l": pwm_left, "r": pwm_right}).encode('utf-8')
        addr = self._resolve()
        if addr:
            self.sock.sendto(payload, (addr, self.udp_port))

    def _resolve(self):
        """Resolve esp32_ip (IP or mDNS name), cached so sends never block on lookups."""
        now = time.monotonic()
        if self._addr is None or now - self._addr_t > 30.0:
            try:
                self._addr = socket.gethostbyname(self.esp32_ip)
            except OSError:
                self.get_logger().warn(f'Cannot resolve {self.esp32_ip}',
                                       throttle_duration_sec=5.0)
            self._addr_t = now if self._addr else now - 25.0  # retry in ~5s on failure
        return self._addr

    @staticmethod
    def _clamp(value: float, min_val: float, max_val: float) -> float:
        return max(min_val, min(max_val, value))

    def destroy_node(self):
        self.sock.close()
        super().destroy_node()


def main(args=None):
    rclpy.init(args=args)
    node = MotorNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
