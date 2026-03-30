FROM osrf/ros:jazzy-desktop-full
ARG TARGETPLATFORM
ARG TARGETARCH
ARG QEMU_CPU
LABEL maintainer="you"
SHELL ["/bin/bash", "-c"]

# ==========================================
# osrf/ros:jazzy-desktop-full already includes:
#   - Ubuntu Noble
#   - ROS2 Jazzy desktop-full (rviz2, rqt, etc.)
#   - python3-colcon, rosdep, vcstool
# ==========================================

ENV ROS_DISTRO=jazzy

# ==========================================
# Desktop + VNC + noVNC
# ==========================================
RUN apt-get update -q && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    xfce4 xfce4-terminal xfwm4 \
    dbus-x11 \
    tigervnc-standalone-server tigervnc-common \
    supervisor wget curl gosu git sudo \
    python3-full python3-pip tini \
    build-essential vim lsb-release locales \
    bash-completion tzdata \
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
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ==========================================
# Python tools
# ==========================================
RUN pip install --break-system-packages --no-cache-dir black urdf-parser-py

# ==========================================
# Setup + entrypoint
# ==========================================
COPY ./setup_container.bash /
RUN chmod +x /setup_container.bash && bash /setup_container.bash

COPY ./entrypoint.sh /
RUN chmod +x /entrypoint.sh

ENV USER=ubuntu
ENV PASSWD=ubuntu
ENV TURTLEBOT3_MODEL=burger

CMD ["/bin/bash", "-c", "/entrypoint.sh"]