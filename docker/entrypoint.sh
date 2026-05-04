#!/bin/bash
# ==============================================================
# entrypoint.sh  —  RUNTIME ONLY
# Runs every time the container starts. Idempotent: safe to
# restart the container without side effects.
# ==============================================================
set -e

# ==========================================
# Resolve user / home
# ==========================================
TARGET_USER=${USER:-root}
HOME_DIR=/root

if [ "$TARGET_USER" != "root" ]; then
    echo "* Ensuring user: $TARGET_USER"

    # Create user only if it doesn't exist yet
    if ! id -u "$TARGET_USER" &>/dev/null; then
        useradd --create-home --shell /bin/bash \
                --user-group --groups adm,sudo "$TARGET_USER"
    fi

    # Passwordless sudo (write to a dedicated drop-in, not /etc/sudoers)
    echo "$TARGET_USER ALL=(ALL) NOPASSWD:ALL" \
        > /etc/sudoers.d/90-${TARGET_USER}-nopasswd
    chmod 0440 /etc/sudoers.d/90-${TARGET_USER}-nopasswd

    # Set login password from env (default: ubuntu)
    PASSWORD=${PASSWD:-ubuntu}
    echo "$TARGET_USER:$PASSWORD" | chpasswd

    HOME_DIR="/home/$TARGET_USER"
    cp -r /root/.asoundrc "$HOME_DIR/" 2>/dev/null || true
    chown -R "$TARGET_USER:$TARGET_USER" "$HOME_DIR"
    [ -d "/dev/snd" ] && chgrp -R adm /dev/snd
fi

# ==========================================
# Fix /tmp/.X11-unix  (must run as root)
# ==========================================
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix

# ==========================================
# dbus system daemon
# ==========================================
mkdir -p /run/dbus
dbus-daemon --system --fork || true

# ==========================================
# VNC password
# ==========================================
VNC_PASSWORD=${PASSWD:-ubuntu}
mkdir -p "$HOME_DIR/.vnc"
echo "$VNC_PASSWORD" | vncpasswd -f > "$HOME_DIR/.vnc/passwd"
chmod 600 "$HOME_DIR/.vnc/passwd"
chown -R "$TARGET_USER:$TARGET_USER" "$HOME_DIR/.vnc"
sed -i "s/password = WebUtil.getConfigVar('password');/password = '$VNC_PASSWORD'/" \
    /usr/lib/novnc/app/ui.js

# ==========================================
# CycloneDDS config — copy from /etc to home
# (home may be a bind-mount that didn't exist at build time)
# ==========================================
if [ ! -f "$HOME_DIR/cyclone_config.xml" ]; then
    cp /etc/cyclone_config.xml "$HOME_DIR/cyclone_config.xml"
    chown "$TARGET_USER:$TARGET_USER" "$HOME_DIR/cyclone_config.xml"
fi

# ==========================================
# .bashrc — write once, guarded by grep
# All env vars that affect interactive terminals go here.
# Process-level vars (Gazebo, OpenGL) are set in Dockerfile ENV.
# ==========================================
BASHRC="$HOME_DIR/.bashrc"

_append_if_missing() {
    local marker="$1"
    local line="$2"
    grep -qF "$marker" "$BASHRC" 2>/dev/null || echo "$line" >> "$BASHRC"
}

_append_if_missing "source /opt/ros/$ROS_DISTRO/setup.bash" \
    "source /opt/ros/$ROS_DISTRO/setup.bash"

_append_if_missing "ros_ws/install/setup.bash" \
    "[ -f $HOME_DIR/ros_ws/install/setup.bash ] && source $HOME_DIR/ros_ws/install/setup.bash"

_append_if_missing "TURTLEBOT3_MODEL" \
    "export TURTLEBOT3_MODEL=burger"

_append_if_missing "GZ_SIM_RESOURCE_PATH" \
    "export GZ_SIM_RESOURCE_PATH=\$GZ_SIM_RESOURCE_PATH:/opt/ros/jazzy/share/turtlebot3_gazebo/models"

_append_if_missing "SDF_PATH" \
    "export SDF_PATH=\$SDF_PATH:/opt/ros/jazzy/share/turtlebot3_gazebo/models"

_append_if_missing "RMW_IMPLEMENTATION" \
    "export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp"

_append_if_missing "CYCLONEDDS_URI" \
    "export CYCLONEDDS_URI=file://$HOME_DIR/cyclone_config.xml"

_append_if_missing "PYTHONWARNINGS" \
    "export PYTHONWARNINGS=\"ignore:setup.py install is deprecated\""

_append_if_missing "GZ_VERBOSE" \
    "export GZ_VERBOSE=0"

chown "$TARGET_USER:$TARGET_USER" "$BASHRC"

# ==========================================
# XFCE startup script
# ==========================================
cat <<EOF > /usr/local/bin/start-xfce.sh
#!/bin/bash
for i in \$(seq 1 20); do
    DISPLAY=:1 xdpyinfo >/dev/null 2>&1 && break
    echo "Waiting for Xvnc... \$i"
    sleep 1
done

export DISPLAY=:1
export HOME=$HOME_DIR
export USER=$TARGET_USER

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
command=gosu $TARGET_USER /usr/local/bin/start-xfce.sh
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
# Desktop shortcut — Terminator
# ==========================================
mkdir -p "$HOME_DIR/Desktop"
cat <<EOF > "$HOME_DIR/Desktop/terminator.desktop"
[Desktop Entry]
Name=Terminator
Exec=terminator
Icon=utilities-terminal
Type=Application
Categories=Utility;TerminalEmulator;
EOF
chmod +x "$HOME_DIR/Desktop/terminator.desktop"
# Mark as trusted so XFCE doesn't show the "untrusted app" dialog
gio set "$HOME_DIR/Desktop/terminator.desktop" \
    metadata::trusted true 2>/dev/null || true
chown -R "$TARGET_USER:$TARGET_USER" "$HOME_DIR/Desktop"

# ==========================================
# ROS home dir permissions
# ==========================================
mkdir -p "$HOME_DIR/.ros"
chown -R "$TARGET_USER:$TARGET_USER" "$HOME_DIR/.ros"

# ==========================================
# Start services
# ==========================================
exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf