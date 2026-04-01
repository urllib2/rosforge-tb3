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
# Fix /tmp/.X11-unix (must be done as root)
# ==========================================
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix

# ==========================================
# Start dbus system daemon
# ==========================================
mkdir -p /run/dbus
dbus-daemon --system --fork || true

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
# XFCE startup script (runs as ubuntu user)
# ==========================================
cat <<EOF > /usr/local/bin/start-xfce.sh
#!/bin/bash
# Wait for Xvnc to be ready
for i in \$(seq 1 20); do
    if DISPLAY=:1 xdpyinfo >/dev/null 2>&1; then
        break
    fi
    echo "Waiting for Xvnc... \$i"
    sleep 1
done

export DISPLAY=:1
export HOME=$HOME_DIR
export USER=$USER

# Mark desktop files as trusted before XFCE starts
mkdir -p $HOME_DIR/Desktop
chmod +x $HOME_DIR/Desktop/*.desktop 2>/dev/null || true
chown -R $USER:$USER $HOME_DIR/Desktop 2>/dev/null || true

# Start dbus session and XFCE
eval \$(dbus-launch --sh-syntax)
export DBUS_SESSION_BUS_ADDRESS
exec startxfce4
EOF
chmod +x /usr/local/bin/start-xfce.sh

# ==========================================
# Supervisor config
# ==========================================
cat <<EOF > /etc/supervisor/conf.d/supervisord.conf
[supervisord]
nodaemon=true

[program:xvnc]
command=Xvnc :1 -geometry 1280x720 -depth 24 -rfbauth $HOME_DIR/.vnc/passwd -rfbport 5901 -localhost no
autorestart=true
priority=10
startsecs=1
stdout_logfile=/var/log/xvnc.log
stderr_logfile=/var/log/xvnc.log

[program:xfce]
command=gosu $USER /usr/local/bin/start-xfce.sh
autorestart=true
priority=20
startsecs=5
stdout_logfile=/var/log/xfce.log
stderr_logfile=/var/log/xfce.log

[program:novnc]
command=websockify --web=/usr/lib/novnc 80 localhost:5901
autorestart=true
priority=30
startsecs=3
stdout_logfile=/var/log/novnc.log
stderr_logfile=/var/log/novnc.log
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
# Desktop shortcut — Terminator
# ==========================================
mkdir -p "$HOME_DIR/Desktop"
rm -f "$HOME_DIR/Desktop/terminal.desktop"
cat <<EOF > "$HOME_DIR/Desktop/terminator.desktop"
[Desktop Entry]
Name=Terminator
Exec=terminator
Icon=utilities-terminal
Type=Application
Categories=Utility;TerminalEmulator;
EOF
chmod +x "$HOME_DIR/Desktop/terminator.desktop"
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
