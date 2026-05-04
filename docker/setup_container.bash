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
# CycloneDDS config (static file, goes to /etc so it's
# available before the home directory exists at runtime)
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
# ros_ws skeleton (bind-mounted at runtime, but colcon
# expects the directory to pre-exist inside the container)
# ==========================================
mkdir -p /home/ubuntu/ros_ws/src

echo "===== Build-time setup complete ====="