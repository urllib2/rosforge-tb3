#!/bin/bash
set -e

# ==========================================
# Create User
# ==========================================
USER=${USER:-root}
HOME_DIR=/root

if [ "$USER" != "root" ]; then
    echo "* Creating user: $USER"
    id -u "$USER" &>/dev/null || \
        useradd --create-home --shell /bin/bash --user-group --groups adm,sudo "$USER"
    echo "$USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
    PASSWORD=${PASSWD:-ubuntu}
    echo "$USER:$PASSWORD" | chpasswd
    HOME_DIR="/home/$USER"
    cp -r /root/.asoundrc "$HOME_DIR/" 2>/dev/null || true
    chown -R "$USER:$USER" "$HOME_DIR"
    [ -d "/dev/snd" ] && chgrp -R adm /dev/snd
fi

# ==========================================
# VNC Password
# ==========================================
VNC_PASSWORD=${PASSWD:-ubuntu}
mkdir -p "$HOME_DIR/.vnc"
echo "$VNC_PASSWORD" | vncpasswd -f > "$HOME_DIR/.vnc/passwd"
chmod 600 "$HOME_DIR/.vnc/passwd"
chown -R "$USER:$USER" "$HOME_DIR/.vnc"
sed -i "s/password = WebUtil.getConfigVar('password');/password = '$VNC_PASSWORD'/" /usr/lib/novnc/app/ui.js

# ==========================================
# VNC xstartup (XFCE)
# ==========================================
cat <<EOF > "$HOME_DIR/.vnc/xstartup"
#!/bin/sh
unset DBUS_SESSION_BUS_ADDRESS
startxfce4 &
EOF
chmod +x "$HOME_DIR/.vnc/xstartup"
chown "$USER:$USER" "$HOME_DIR/.vnc/xstartup"

# ==========================================
# VNC run script
# ==========================================
cat <<EOF > "$HOME_DIR/.vnc/vnc_run.sh"
#!/bin/bash
rm -rf /tmp/.X1-lock /tmp/.X11-unix/X1
vncserver :1 -geometry 1280x720 -depth 24 -fg
EOF
chmod +x "$HOME_DIR/.vnc/vnc_run.sh"
chown "$USER:$USER" "$HOME_DIR/.vnc/vnc_run.sh"

# ==========================================
# Supervisor config
# ==========================================
cat <<EOF > /etc/supervisor/conf.d/supervisord.conf
[supervisord]
nodaemon=true

[program:vnc]
command=gosu $USER bash $HOME_DIR/.vnc/vnc_run.sh

[program:novnc]
command=gosu $USER bash -c "websockify --web=/usr/lib/novnc 80 localhost:5901"
EOF

# ==========================================
# ROS Environment
# ==========================================
BASHRC="$HOME_DIR/.bashrc"

grep -q "source /opt/ros/$ROS_DISTRO/setup.bash" "$BASHRC" || \
    echo "source /opt/ros/$ROS_DISTRO/setup.bash" >> "$BASHRC"

grep -q "ros_ws/install/setup.bash" "$BASHRC" || \
    echo "[ -f /home/ubuntu/ros_ws/install/setup.bash ] && source /home/ubuntu/ros_ws/install/setup.bash" >> "$BASHRC"

grep -q "TURTLEBOT3_MODEL" "$BASHRC" || \
    echo "export TURTLEBOT3_MODEL=burger" >> "$BASHRC"

grep -q "GZ_SIM_RESOURCE_PATH" "$BASHRC" || \
    echo "export GZ_SIM_RESOURCE_PATH=\$GZ_SIM_RESOURCE_PATH:/opt/ros/jazzy/share/turtlebot3_gazebo/models" >> "$BASHRC"

grep -q "SDF_PATH" "$BASHRC" || \
    echo "export SDF_PATH=\$SDF_PATH:/opt/ros/jazzy/share/turtlebot3_gazebo/models" >> "$BASHRC"

grep -q "RMW_IMPLEMENTATION" "$BASHRC" || \
    echo "export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp" >> "$BASHRC"

grep -q "CYCLONEDDS_URI" "$BASHRC" || \
    echo "export CYCLONEDDS_URI=file:///home/ubuntu/cyclone_config.xml" >> "$BASHRC"

chown "$USER:$USER" "$BASHRC"

# ==========================================
# Desktop shortcut — xfce4-terminal
# ==========================================
mkdir -p "$HOME_DIR/Desktop"
cat <<EOF > "$HOME_DIR/Desktop/terminal.desktop"
[Desktop Entry]
Name=Terminal
Exec=xfce4-terminal
Icon=utilities-terminal
Type=Application
Categories=Utility;TerminalEmulator;
EOF
chmod +x "$HOME_DIR/Desktop/terminal.desktop"
chown -R "$USER:$USER" "$HOME_DIR/Desktop"

# ==========================================
# ROS home permissions
# ==========================================
mkdir -p "$HOME_DIR/.ros"
chown -R "$USER:$USER" "$HOME_DIR/.ros"

# ==========================================
# Start services
# ==========================================
exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf