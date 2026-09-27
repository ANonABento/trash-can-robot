from setuptools import setup
import os
from glob import glob

package_name = 'trashcan_bot'

setup(
    name=package_name,
    version='0.1.0',
    packages=[package_name],
    data_files=[
        ('share/ament_index/resource_index/packages', ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
        (os.path.join('share', package_name, 'launch'), glob('launch/*.launch.py')),
    ],
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='user',
    maintainer_email='user@example.com',
    description='ROS2 nodes for the trash can robot',
    license='MIT',
    entry_points={
        'console_scripts': [
            'camera_node = trashcan_bot.camera_node:main',
            'motor_node = trashcan_bot.motor_node:main',
            'teleop_key_node = trashcan_bot.teleop_key_node:main',
            'safety_monitor_node = trashcan_bot.safety_monitor_node:main',
        ],
    },
)
