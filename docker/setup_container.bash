#!/bin/bash
set -e

echo "===== ROS2 Workspace Setup ====="

source /opt/ros/jazzy/setup.bash

USER=ubuntu
HOME_DIR=/home/$USER
WS=$HOME_DIR/ros_ws

# ==========================================
# Create user if not exists
# ==========================================
id -u $USER &>/dev/null || adduser --disabled-password --gecos "" $USER
echo "$USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USER
chmod 0440 /etc/sudoers.d/$USER

mkdir -p $WS/src
chown -R $USER:$USER $HOME_DIR

# ==========================================
# Python tools
# ==========================================
pip install --break-system-packages black urdf-parser-py

# ==========================================
# CycloneDDS config
# ==========================================
cat <<EOF > $HOME_DIR/cyclone_config.xml
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
# Environment
# ==========================================
BASHRC="$HOME_DIR/.bashrc"

echo "source /opt/ros/jazzy/setup.bash" >> $BASHRC
echo "[ -f $WS/install/setup.bash ] && source $WS/install/setup.bash" >> $BASHRC
echo "export TURTLEBOT3_MODEL=burger" >> $BASHRC
echo "export GZ_SIM_RESOURCE_PATH=/opt/ros/jazzy/share/turtlebot3_gazebo/models" >> $BASHRC
echo "export SDF_PATH=/opt/ros/jazzy/share/turtlebot3_gazebo/models" >> $BASHRC
echo "export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp" >> $BASHRC
echo "export CYCLONEDDS_URI=file:///home/ubuntu/cyclone_config.xml" >> $BASHRC
echo "export PYTHONWARNINGS=\"ignore:setup.py install is deprecated\"" >> $BASHRC
echo "export LIBGL_ALWAYS_SOFTWARE=1" >> $BASHRC
echo "export MESA_GL_VERSION_OVERRIDE=3.3" >> $BASHRC
echo "export GZ_VERBOSE=0" >> $BASHRC

chown $USER:$USER $BASHRC

echo "===== Setup complete ====="
