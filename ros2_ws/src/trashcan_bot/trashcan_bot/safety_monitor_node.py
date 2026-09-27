"""Safety monitor node: passes /cmd_vel through to /cmd_vel_safe with logging.

Actual safety enforcement (obstacle cutoff) is on the ESP32.
This node provides a software-side logging layer and a clean separation
between user intent (/cmd_vel) and commanded output (/cmd_vel_safe).
"""

import math

import rclpy
from rclpy.node import Node
from geometry_msgs.msg import Twist


class SafetyMonitorNode(Node):

    def __init__(self):
        super().__init__('safety_monitor_node')

        self.declare_parameter('max_linear_speed', 0.34)   # m/s (hardware max)
        self.declare_parameter('max_angular_speed', 3.78)   # rad/s (hardware max)

        self.max_linear = self.get_parameter('max_linear_speed').value
        self.max_angular = self.get_parameter('max_angular_speed').value

        self.sub = self.create_subscription(
            Twist, '/cmd_vel', self._cmd_vel_cb, 10
        )
        self.pub = self.create_publisher(Twist, '/cmd_vel_safe', 10)

        self.get_logger().info(
            f'Safety monitor active. Limits: linear={self.max_linear:.2f} m/s, '
            f'angular={self.max_angular:.2f} rad/s. '
            f'Hardware safety cutoff is on ESP32 (ToF < 150mm).'
        )

    def _cmd_vel_cb(self, msg: Twist):
        safe = Twist()

        # Clamp to max speeds
        safe.linear.x = self._clamp(msg.linear.x, -self.max_linear, self.max_linear)
        safe.angular.z = self._clamp(msg.angular.z, -self.max_angular, self.max_angular)

        # Warn if input was clamped
        if abs(msg.linear.x) > self.max_linear:
            self.get_logger().warn(
                f'Linear speed clamped: {msg.linear.x:.2f} -> {safe.linear.x:.2f} m/s'
            )
        if abs(msg.angular.z) > self.max_angular:
            self.get_logger().warn(
                f'Angular speed clamped: {msg.angular.z:.2f} -> {safe.angular.z:.2f} rad/s'
            )

        self.pub.publish(safe)

    @staticmethod
    def _clamp(value: float, min_val: float, max_val: float) -> float:
        return max(min_val, min(max_val, value))


def main(args=None):
    rclpy.init(args=args)
    node = SafetyMonitorNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
