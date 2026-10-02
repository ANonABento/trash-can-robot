"""Launch file for the trash can robot: camera, motor, and safety monitor nodes."""

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def generate_launch_description():
    esp32_ip_arg = DeclareLaunchArgument(
        'esp32_ip',
        default_value='trashcam.local',
        description='IP or mDNS hostname of the ESP32 camera board'
    )

    esp32_ip = LaunchConfiguration('esp32_ip')

    camera_node = Node(
        package='trashcan_bot',
        executable='camera_node',
        name='camera_node',
        parameters=[{'esp32_ip': esp32_ip}],
        output='screen',
    )

    motor_node = Node(
        package='trashcan_bot',
        executable='motor_node',
        name='motor_node',
        parameters=[{'esp32_ip': esp32_ip}],
        output='screen',
    )

    safety_monitor_node = Node(
        package='trashcan_bot',
        executable='safety_monitor_node',
        name='safety_monitor_node',
        output='screen',
    )

    return LaunchDescription([
        esp32_ip_arg,
        camera_node,
        motor_node,
        safety_monitor_node,
    ])
