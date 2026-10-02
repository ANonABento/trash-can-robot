"""Safety monitor node: gates /cmd_vel -> /cmd_vel_safe and watches the ESP32.

- Clamps speeds to hardware limits.
- Republishes the last command at a fixed rate so the motor node keeps feeding
  the ESP32 failsafe (which stops the motors if UDP commands go quiet).
- Publishes zero velocity if /cmd_vel goes stale (teleop dead-man) or if the
  ESP32 heartbeat (UDP broadcast on port 4211) disappears.
- Publishes /esp32/alive (Bool) and /diagnostics for Foxglove.

There is no on-board obstacle sensing; the only ESP32-side protection is the
command-timeout failsafe in firmware.
"""

import json
import socket
import threading
import time

import rclpy
from rclpy.node import Node
from geometry_msgs.msg import Twist
from std_msgs.msg import Bool
from diagnostic_msgs.msg import DiagnosticArray, DiagnosticStatus, KeyValue


class SafetyMonitorNode(Node):

    def __init__(self):
        super().__init__('safety_monitor_node')

        self.declare_parameter('max_linear_speed', 0.34)   # m/s (hardware max)
        self.declare_parameter('max_angular_speed', 3.78)   # rad/s (hardware max)
        self.declare_parameter('heartbeat_port', 4211)
        self.declare_parameter('heartbeat_timeout', 3.0)    # s without heartbeat -> stop
        self.declare_parameter('cmd_timeout', 0.5)          # s without /cmd_vel -> stop
        self.declare_parameter('publish_rate', 10.0)        # Hz
        self.declare_parameter('require_heartbeat', True)   # False for bench testing

        self.max_linear = self.get_parameter('max_linear_speed').value
        self.max_angular = self.get_parameter('max_angular_speed').value
        self.hb_timeout = self.get_parameter('heartbeat_timeout').value
        self.cmd_timeout = self.get_parameter('cmd_timeout').value
        self.require_hb = self.get_parameter('require_heartbeat').value
        rate = self.get_parameter('publish_rate').value

        self._lock = threading.Lock()
        self._last_cmd = Twist()
        self._last_cmd_t = 0.0
        self._last_hb_t = 0.0
        self._last_hb = {}
        self._was_alive = None

        self.sub = self.create_subscription(Twist, '/cmd_vel', self._cmd_vel_cb, 10)
        self.pub = self.create_publisher(Twist, '/cmd_vel_safe', 10)
        self.alive_pub = self.create_publisher(Bool, '/esp32/alive', 10)
        self.diag_pub = self.create_publisher(DiagnosticArray, '/diagnostics', 10)

        self._sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self._sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self._sock.settimeout(0.5)
        self._sock.bind(('', self.get_parameter('heartbeat_port').value))
        self._running = True
        self._thread = threading.Thread(target=self._hb_loop, daemon=True)
        self._thread.start()

        self.timer = self.create_timer(1.0 / rate, self._tick)

        self.get_logger().info(
            f'Safety monitor active. Limits: linear={self.max_linear:.2f} m/s, '
            f'angular={self.max_angular:.2f} rad/s. '
            f'Heartbeat timeout {self.hb_timeout:.1f}s, cmd timeout {self.cmd_timeout:.1f}s.'
        )

    # -- inputs -----------------------------------------------------------
    def _hb_loop(self):
        while self._running:
            try:
                data, _ = self._sock.recvfrom(512)
                info = json.loads(data.decode('utf-8'))
            except socket.timeout:
                continue
            except (ValueError, OSError):
                continue
            with self._lock:
                self._last_hb = info
                self._last_hb_t = time.monotonic()

    def _cmd_vel_cb(self, msg: Twist):
        safe = Twist()
        safe.linear.x = self._clamp(msg.linear.x, -self.max_linear, self.max_linear)
        safe.angular.z = self._clamp(msg.angular.z, -self.max_angular, self.max_angular)

        if abs(msg.linear.x) > self.max_linear:
            self.get_logger().warn(
                f'Linear speed clamped: {msg.linear.x:.2f} -> {safe.linear.x:.2f} m/s')
        if abs(msg.angular.z) > self.max_angular:
            self.get_logger().warn(
                f'Angular speed clamped: {msg.angular.z:.2f} -> {safe.angular.z:.2f} rad/s')

        with self._lock:
            self._last_cmd = safe
            self._last_cmd_t = time.monotonic()

    # -- periodic gate ----------------------------------------------------
    def _tick(self):
        now = time.monotonic()
        with self._lock:
            hb_age = now - self._last_hb_t if self._last_hb_t else float('inf')
            cmd_age = now - self._last_cmd_t if self._last_cmd_t else float('inf')
            cmd = self._last_cmd
            hb = dict(self._last_hb)

        alive = hb_age < self.hb_timeout
        if alive != self._was_alive:
            if alive:
                self.get_logger().info('ESP32 heartbeat OK')
            else:
                self.get_logger().error(
                    f'ESP32 heartbeat lost (>{self.hb_timeout:.1f}s). Stopping motors.')
            self._was_alive = alive

        out = Twist()
        if cmd_age < self.cmd_timeout and (alive or not self.require_hb):
            out = cmd
        self.pub.publish(out)

        self.alive_pub.publish(Bool(data=alive))
        self._publish_diag(alive, hb_age, hb)

    def _publish_diag(self, alive, hb_age, hb):
        status = DiagnosticStatus()
        status.name = 'esp32_camera'
        status.hardware_id = hb.get('ip', 'unknown')
        if not alive:
            status.level = DiagnosticStatus.ERROR
            status.message = 'No heartbeat'
        elif hb.get('rssi', 0) < -80 or hb.get('cam_failures', 0) > 0:
            status.level = DiagnosticStatus.WARN
            status.message = 'Degraded (weak WiFi or camera failures)'
        else:
            status.level = DiagnosticStatus.OK
            status.message = 'OK'
        status.values = [KeyValue(key='heartbeat_age_s', value=f'{hb_age:.1f}')]
        status.values += [KeyValue(key=k, value=str(v)) for k, v in hb.items()]

        arr = DiagnosticArray()
        arr.header.stamp = self.get_clock().now().to_msg()
        arr.status = [status]
        self.diag_pub.publish(arr)

    @staticmethod
    def _clamp(value: float, min_val: float, max_val: float) -> float:
        return max(min_val, min(max_val, value))

    def destroy_node(self):
        self._running = False
        self._sock.close()
        super().destroy_node()


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
