## Foxglove Studio Setup

Start the Foxglove bridge alongside your ROS2 nodes: `ros2 launch foxglove_bridge foxglove_bridge.launch.xml`. Then open Foxglove Studio (desktop app or web at studio.foxglove.dev), connect to `ws://localhost:8765`, and import `trashcan_layout.json` via the layout menu. The layout provides a camera view, a velocity plot, and a 3D panel stub.
