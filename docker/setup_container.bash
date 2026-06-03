#!/bin/bash
# ==============================================================
# setup_container.bash  —  BUILD TIME ONLY
# Runs once during `docker build`. Must not touch users, home
# directories, or .bashrc — those are runtime concerns handled
# by entrypoint.sh.
# ==============================================================
set -e
echo "===== ROS2 workspace build-time setup ====="

source /opt/ros/jazzy/setup.bash

# ==========================================
# Python tools
# ==========================================
pip install --break-system-packages --no-cache-dir black urdf-parser-py

# ==========================================
# CycloneDDS config
# ==========================================
cat <<EOF > /etc/cyclone_config.xml
<?xml version="1.0" encoding="UTF-8" ?>
<CycloneDDS>
  <Domain>
    <General>
      <Interfaces>
        <NetworkInterface name="lo" priority="default" multicast="true"/>
      </Interfaces>
      <AllowMulticast>true</AllowMulticast>
      <MaxMessageSize>65500B</MaxMessageSize>
    </General>
  </Domain>
</CycloneDDS>
EOF

# ==========================================
# ros_ws skeleton
# ==========================================
mkdir -p /home/ubuntu/ros_ws/src

# ==========================================
# TurtleBot3 from source — simulation only
# Packages selected to cover full Rico book curriculum:
#   - turtlebot3_description: URDF/meshes
#   - turtlebot3_fake_node: required by turtlebot3_simulations
#   - turtlebot3_gazebo: Gazebo world and launch files
#   - turtlebot3_simulations: top-level simulation package
#   - turtlebot3_teleop: keyboard teleoperation (Ch.3+)
#   - turtlebot3_navigation2: Nav2 TB3 launch files (Ch.6)
# ==========================================
echo "===== Cloning TurtleBot3 from source ====="
mkdir -p /opt/tb3_ws/src
cd /opt/tb3_ws/src
git clone -b jazzy https://github.com/ROBOTIS-GIT/turtlebot3_simulations.git
git clone -b jazzy https://github.com/ROBOTIS-GIT/turtlebot3.git

# ------------------------------------------
# Fix 1: Camera resolution 640x480
# ------------------------------------------
sed -i 's/<width>1920<\/width>/<width>640<\/width>/' \
    /opt/tb3_ws/src/turtlebot3_simulations/turtlebot3_gazebo/models/turtlebot3_waffle/model.sdf
sed -i 's/<height>1080<\/height>/<height>480<\/height>/' \
    /opt/tb3_ws/src/turtlebot3_simulations/turtlebot3_gazebo/models/turtlebot3_waffle/model.sdf

# ------------------------------------------
# Fix 2: Camera update rate 15Hz
# ------------------------------------------
sed -i '377s/<update_rate>30<\/update_rate>/<update_rate>15<\/update_rate>/' \
    /opt/tb3_ws/src/turtlebot3_simulations/turtlebot3_gazebo/models/turtlebot3_waffle/model.sdf

# ------------------------------------------
# Fix 3: Physics rate 500Hz
# ------------------------------------------
sed -i 's/<real_time_update_rate>1000.0<\/real_time_update_rate>/<real_time_update_rate>500.0<\/real_time_update_rate>/' \
    /opt/tb3_ws/src/turtlebot3_simulations/turtlebot3_gazebo/worlds/turtlebot3_world.world
sed -i 's/<max_step_size>0.001<\/max_step_size>/<max_step_size>0.002<\/max_step_size>/' \
    /opt/tb3_ws/src/turtlebot3_simulations/turtlebot3_gazebo/worlds/turtlebot3_world.world

# ------------------------------------------
# Fix 4: Bridge yaml with camera/image_raw
# ------------------------------------------
cat > /opt/tb3_ws/src/turtlebot3_simulations/turtlebot3_gazebo/params/turtlebot3_waffle_bridge.yaml << 'EOF'
- ros_topic_name: "clock"
  gz_topic_name: "clock"
  ros_type_name: "rosgraph_msgs/msg/Clock"
  gz_type_name: "gz.msgs.Clock"
  direction: GZ_TO_ROS
- ros_topic_name: "joint_states"
  gz_topic_name: "joint_states"
  ros_type_name: "sensor_msgs/msg/JointState"
  gz_type_name: "gz.msgs.Model"
  direction: GZ_TO_ROS
- ros_topic_name: "odom"
  gz_topic_name: "odom"
  ros_type_name: "nav_msgs/msg/Odometry"
  gz_type_name: "gz.msgs.Odometry"
  direction: GZ_TO_ROS
- ros_topic_name: "tf"
  gz_topic_name: "tf"
  ros_type_name: "tf2_msgs/msg/TFMessage"
  gz_type_name: "gz.msgs.Pose_V"
  direction: GZ_TO_ROS
- ros_topic_name: "cmd_vel"
  gz_topic_name: "cmd_vel"
  ros_type_name: "geometry_msgs/msg/TwistStamped"
  gz_type_name: "gz.msgs.Twist"
  direction: ROS_TO_GZ
- ros_topic_name: "imu"
  gz_topic_name: "imu"
  ros_type_name: "sensor_msgs/msg/Imu"
  gz_type_name: "gz.msgs.IMU"
  direction: GZ_TO_ROS
- ros_topic_name: "scan"
  gz_topic_name: "scan"
  ros_type_name: "sensor_msgs/msg/LaserScan"
  gz_type_name: "gz.msgs.LaserScan"
  direction: GZ_TO_ROS
- ros_topic_name: "camera/camera_info"
  gz_topic_name: "camera/camera_info"
  ros_type_name: "sensor_msgs/msg/CameraInfo"
  gz_type_name: "gz.msgs.CameraInfo"
  direction: GZ_TO_ROS
- ros_topic_name: "camera/image_raw"
  gz_topic_name: "camera/image_raw"
  ros_type_name: "sensor_msgs/msg/Image"
  gz_type_name: "gz.msgs.Image"
  direction: GZ_TO_ROS
EOF

# ------------------------------------------
# Fix 5: Remove image_bridge from spawn launch
# ------------------------------------------
cat > /opt/tb3_ws/src/turtlebot3_simulations/turtlebot3_gazebo/launch/spawn_turtlebot3.launch.py << 'EOF'
import os
from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node

def generate_launch_description():
    TURTLEBOT3_MODEL = os.environ['TURTLEBOT3_MODEL']
    model_folder = 'turtlebot3_' + TURTLEBOT3_MODEL
    urdf_path = os.path.join(
        get_package_share_directory('turtlebot3_gazebo'),
        'models', model_folder, 'model.sdf'
    )
    x_pose = LaunchConfiguration('x_pose', default='0.0')
    y_pose = LaunchConfiguration('y_pose', default='0.0')
    declare_x_position_cmd = DeclareLaunchArgument(
        'x_pose', default_value='0.0',
        description='Specify namespace of the robot')
    declare_y_position_cmd = DeclareLaunchArgument(
        'y_pose', default_value='0.0',
        description='Specify namespace of the robot')
    start_gazebo_ros_spawner_cmd = Node(
        package='ros_gz_sim', executable='create',
        arguments=[
            '-name', TURTLEBOT3_MODEL,
            '-file', urdf_path,
            '-x', x_pose,
            '-y', y_pose,
            '-z', '0.01'
        ],
        output='screen',
    )
    bridge_params = os.path.join(
        get_package_share_directory('turtlebot3_gazebo'),
        'params', model_folder + '_bridge.yaml'
    )
    start_gazebo_ros_bridge_cmd = Node(
        package='ros_gz_bridge', executable='parameter_bridge',
        arguments=['--ros-args', '-p', f'config_file:={bridge_params}'],
        output='screen',
    )
    ld = LaunchDescription()
    ld.add_action(declare_x_position_cmd)
    ld.add_action(declare_y_position_cmd)
    ld.add_action(start_gazebo_ros_spawner_cmd)
    ld.add_action(start_gazebo_ros_bridge_cmd)
    # image_bridge removed — camera/image_raw handled by parameter_bridge
    return ld
EOF

# ------------------------------------------
# Build simulation + teleop + navigation packages
# ------------------------------------------
echo "===== Building TurtleBot3 packages ====="
cd /opt/tb3_ws
colcon build --symlink-install --packages-select \
  turtlebot3_description \
  turtlebot3_fake_node \
  turtlebot3_gazebo \
  turtlebot3_simulations \
  turtlebot3_teleop \
  turtlebot3_navigation2

# Make available to all users
echo "source /opt/tb3_ws/install/setup.bash" >> /etc/bash.bashrc

echo "===== Build-time setup complete ====="
