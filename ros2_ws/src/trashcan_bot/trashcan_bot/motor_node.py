"""Motor node: converts /cmd_vel Twist to differential drive PWM and sends UDP to ESP32.

The ESP32 stops the motors if it hears nothing for 300 ms, so this node
re-sends the latest command at 20 Hz. It sends zeros once /cmd_vel_safe has
been quiet for cmd_timeout_s (longer than a keyboard's key-repeat delay).
"""

import json
import socket
import math

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

        self.declare_parameter('esp32_ip', '192.168.1.100')
        self.declare_parameter('udp_port', 4210)
        self.declare_parameter('send_rate_hz', 20.0)
        self.declare_parameter('cmd_timeout_s', 0.6)

        self.esp32_ip = self.get_parameter('esp32_ip').value
        self.udp_port = self.get_parameter('udp_port').value
        self.cmd_timeout_s = self.get_parameter('cmd_timeout_s').value

        self._pwm = (0, 0)
        self._last_cmd_time = None

        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

        self.sub = self.create_subscription(
            Twist, '/cmd_vel_safe', self._cmd_vel_cb, 10
        )
        self.create_timer(1.0 / self.get_parameter('send_rate_hz').value, self._send_tick)

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

        self._pwm = (pwm_left, pwm_right)
        self._last_cmd_time = self.get_clock().now()
        self._send(*self._pwm)

    def _send_tick(self):
        if self._last_cmd_time is None:
            return
        age = (self.get_clock().now() - self._last_cmd_time).nanoseconds / 1e9
        if age > self.cmd_timeout_s:
            self._pwm = (0, 0)
        self._send(*self._pwm)

    def _send(self, pwm_left: int, pwm_right: int):
        # UDP JSON matching firmware format: {"l": <int>, "r": <int>}
        payload = json.dumps({"l": pwm_left, "r": pwm_right}).encode('utf-8')
        try:
            self.sock.sendto(payload, (self.esp32_ip, self.udp_port))
        except OSError as e:
            self.get_logger().warn(f'UDP send failed: {e}', throttle_duration_sec=2.0)

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
