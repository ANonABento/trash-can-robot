"""Keyboard teleop node: WASD control publishing to /cmd_vel."""

import sys
import termios
import tty

import rclpy
from rclpy.node import Node
from geometry_msgs.msg import Twist

USAGE = """
Keyboard Teleop for Trash Can Robot
------------------------------------
   W
 A S D

W/S : forward/backward
A/D : turn left/right
Q   : quit

Speed is adjustable via 'max_linear_speed' and 'max_angular_speed' params.
"""


class TeleopKeyNode(Node):

    def __init__(self):
        super().__init__('teleop_key_node')

        self.declare_parameter('max_linear_speed', 0.2)   # m/s
        self.declare_parameter('max_angular_speed', 1.0)   # rad/s

        self.max_linear = self.get_parameter('max_linear_speed').value
        self.max_angular = self.get_parameter('max_angular_speed').value

        self.pub = self.create_publisher(Twist, '/cmd_vel', 10)

        self.get_logger().info(USAGE)

    def run(self):
        old_settings = termios.tcgetattr(sys.stdin)
        try:
            tty.setcbreak(sys.stdin.fileno())
            while True:
                key = sys.stdin.read(1).lower()

                twist = Twist()

                if key == 'w':
                    twist.linear.x = self.max_linear
                elif key == 's':
                    twist.linear.x = -self.max_linear
                elif key == 'a':
                    twist.angular.z = self.max_angular
                elif key == 'd':
                    twist.angular.z = -self.max_angular
                elif key == 'q':
                    # Send zero velocity before quitting
                    self.pub.publish(Twist())
                    break
                # Any other key sends zero velocity (stop)

                self.pub.publish(twist)

        finally:
            termios.tcsetattr(sys.stdin, termios.TCSADRAIN, old_settings)


def main(args=None):
    rclpy.init(args=args)
    node = TeleopKeyNode()
    try:
        node.run()
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
