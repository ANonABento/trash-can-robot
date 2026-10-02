"""Camera node: connects to ESP32 MJPEG stream and publishes ROS2 Image topics."""

import rclpy
from rclpy.node import Node
from sensor_msgs.msg import Image, CompressedImage
import cv2
import numpy as np
import requests
import threading


class CameraNode(Node):

    def __init__(self):
        super().__init__('camera_node')

        self.declare_parameter('esp32_ip', 'trashcam.local')
        self.declare_parameter('stream_port', 80)

        self.esp32_ip = self.get_parameter('esp32_ip').value
        self.stream_port = self.get_parameter('stream_port').value
        self.stream_url = f'http://{self.esp32_ip}:{self.stream_port}/stream'

        self.pub_raw = self.create_publisher(Image, '/camera/image_raw', 10)
        self.pub_compressed = self.create_publisher(
            CompressedImage, '/camera/image_compressed', 10
        )

        self.get_logger().info(f'Connecting to MJPEG stream at {self.stream_url}')

        self._running = True
        self._thread = threading.Thread(target=self._stream_loop, daemon=True)
        self._thread.start()

    def _stream_loop(self):
        while self._running:
            try:
                response = requests.get(self.stream_url, stream=True, timeout=5)
                byte_buf = b''

                for chunk in response.iter_content(chunk_size=4096):
                    if not self._running:
                        break
                    byte_buf += chunk

                    # Find JPEG start and end markers
                    start = byte_buf.find(b'\xff\xd8')
                    end = byte_buf.find(b'\xff\xd9')

                    if start != -1 and end != -1 and end > start:
                        jpg_bytes = byte_buf[start:end + 2]
                        byte_buf = byte_buf[end + 2:]

                        self._publish_frame(jpg_bytes)

            except requests.exceptions.RequestException as e:
                self.get_logger().warn(f'Stream connection error: {e}. Retrying...')
                import time
                time.sleep(1.0)

    def _publish_frame(self, jpg_bytes: bytes):
        now = self.get_clock().now().to_msg()

        # Publish compressed image
        comp_msg = CompressedImage()
        comp_msg.header.stamp = now
        comp_msg.header.frame_id = 'camera'
        comp_msg.format = 'jpeg'
        comp_msg.data = list(jpg_bytes)
        self.pub_compressed.publish(comp_msg)

        # Decode and publish raw image
        np_arr = np.frombuffer(jpg_bytes, dtype=np.uint8)
        frame = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
        if frame is None:
            return

        img_msg = Image()
        img_msg.header.stamp = now
        img_msg.header.frame_id = 'camera'
        img_msg.height = frame.shape[0]
        img_msg.width = frame.shape[1]
        img_msg.encoding = 'bgr8'
        img_msg.is_bigendian = False
        img_msg.step = frame.shape[1] * 3
        img_msg.data = frame.tobytes()
        self.pub_raw.publish(img_msg)

    def destroy_node(self):
        self._running = False
        self._thread.join(timeout=2.0)
        super().destroy_node()


def main(args=None):
    rclpy.init(args=args)
    node = CameraNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
