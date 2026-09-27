"""Launch file for keyboard teleop only."""

from launch import LaunchDescription
from launch_ros.actions import Node


def generate_launch_description():
    teleop_node = Node(
        package='trashcan_bot',
        executable='teleop_key_node',
        name='teleop_key_node',
        output='screen',
        prefix='xterm -e',  # needs a terminal for keyboard input
    )

    return LaunchDescription([
        teleop_node,
    ])
