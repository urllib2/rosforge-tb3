FROM osrf/ros:jazzy-desktop-full
ARG TARGETPLATFORM
ARG TARGETARCH
ARG QEMU_CPU
LABEL maintainer="Sami Turki - RosForge.com"
SHELL ["/bin/bash", "-c"]

# ==========================================
# osrf/ros:jazzy-desktop-full already includes:
#   - Ubuntu Noble
#   - ROS2 Jazzy desktop-full (rviz2, rqt, etc.)
#   - python3-colcon, rosdep, vcstool
# ==========================================

ENV ROS_DISTRO=jazzy

# ==========================================
# OpenGL / Gazebo — set as ENV so these apply to ALL
# processes (not just login shells that source .bashrc)
# ==========================================
ENV LIBGL_ALWAYS_SOFTWARE=1
ENV MESA_GL_VERSION_OVERRIDE=3.3
ENV GZ_VERBOSE=0
ENV TURTLEBOT3_MODEL=burger
ENV RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ENV CYCLONEDDS_URI=file:///home/ubuntu/cyclone_config.xml

# ==========================================
# Desktop + VNC + noVNC
# ==========================================
RUN apt-get update -q && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    xfce4 xfce4-terminal xfwm4 \
    dbus-x11 \
    x11-utils \
    tigervnc-standalone-server tigervnc-common \
    supervisor wget curl gosu git sudo \
    python3-full python3-pip tini \
    build-essential vim lsb-release locales \
    bash-completion tzdata \
    terminator \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ==========================================
# noVNC
# ==========================================
RUN git clone https://github.com/AtsushiSaito/noVNC.git -b add_clipboard_support /usr/lib/novnc && \
    pip install --no-cache-dir --break-system-packages git+https://github.com/novnc/websockify.git@v0.10.0 && \
    ln -s /usr/lib/novnc/vnc.html /usr/lib/novnc/index.html && \
    sed -i "s/UI.initSetting('resize', 'off');/UI.initSetting('resize', 'remote');/g" /usr/lib/novnc/app/ui.js

# ==========================================
# TB3 + Nav2 + SLAM + DDS
# ==========================================
RUN apt-get update -q && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        ros-${ROS_DISTRO}-rmw-cyclonedds-cpp \
        ros-${ROS_DISTRO}-navigation2 \
        ros-${ROS_DISTRO}-nav2-bringup \
        ros-${ROS_DISTRO}-slam-toolbox \
        ros-${ROS_DISTRO}-ros-gz \
        ros-${ROS_DISTRO}-ros-gz-sim \
        ros-${ROS_DISTRO}-turtlebot3 \
        ros-${ROS_DISTRO}-turtlebot3-simulations \
        ros-${ROS_DISTRO}-teleop-twist-keyboard \
        ros-${ROS_DISTRO}-rclpy \
        ros-${ROS_DISTRO}-geometry-msgs \
        ros-${ROS_DISTRO}-sensor-msgs \
        ros-${ROS_DISTRO}-std-srvs \
        ros-${ROS_DISTRO}-urdf-tutorial \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ==========================================
# Build-time setup (Python tools, static config files)
# Does NOT touch users or .bashrc — that's entrypoint.sh's job
# ==========================================
COPY ./setup_container.bash /
RUN chmod +x /setup_container.bash && bash /setup_container.bash

# ==========================================
# Runtime entrypoint
# ==========================================
COPY ./entrypoint.sh /
RUN chmod +x /entrypoint.sh

ENV USER=ubuntu
ENV PASSWD=ubuntu

HEALTHCHECK --interval=15s --timeout=5s --start-period=20s --retries=3 \
    CMD curl -f http://localhost:80 || exit 1

CMD ["/entrypoint.sh"]