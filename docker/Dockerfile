FROM ubuntu:noble-20240605

ARG TARGETPLATFORM
ARG TARGETARCH
ARG QEMU_CPU

LABEL maintainer="you"

SHELL ["/bin/bash", "-c"]

# ==========================================
# System update
# ==========================================
RUN apt-get update -q && \
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ==========================================
# System + desktop packages
# ==========================================
RUN apt-get update -q && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    xfce4 xfce4-terminal xfwm4 \
    tigervnc-standalone-server tigervnc-common \
    supervisor wget curl gosu git sudo \
    python3-full python3-pip tini \
    build-essential vim lsb-release locales \
    bash-completion tzdata \
    curl gnupg2 \
    dbus-x11 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*


# ==========================================
# noVNC
# ==========================================
RUN git clone https://github.com/AtsushiSaito/noVNC.git -b add_clipboard_support /usr/lib/novnc && \
    pip install --no-cache-dir --break-system-packages git+https://github.com/novnc/websockify.git@v0.10.0 && \
    ln -s /usr/lib/novnc/vnc.html /usr/lib/novnc/index.html

RUN sed -i "s/UI.initSetting('resize', 'off');/UI.initSetting('resize', 'remote');/g" /usr/lib/novnc/app/ui.js

# ==========================================
# ROS2 Jazzy + Nav2 + SLAM Toolbox + TB3
# ==========================================
ENV ROS_DISTRO=jazzy

RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
        -o /usr/share/keyrings/ros-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
        http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" \
        > /etc/apt/sources.list.d/ros2.list && \
    apt-get update -q && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        # ROS2 core
        ros-${ROS_DISTRO}-desktop \
        python3-argcomplete \
        python3-colcon-common-extensions \
        python3-rosdep \
        python3-vcstool \
        # DDS
        ros-${ROS_DISTRO}-rmw-cyclonedds-cpp \
        # Navigation
        ros-${ROS_DISTRO}-navigation2 \
        ros-${ROS_DISTRO}-nav2-bringup \
        # SLAM
        ros-${ROS_DISTRO}-slam-toolbox \
        # Simulation
        ros-${ROS_DISTRO}-ros-gz \
        ros-${ROS_DISTRO}-ros-gz-sim \
        # TurtleBot3
        ros-${ROS_DISTRO}-turtlebot3 \
        ros-${ROS_DISTRO}-turtlebot3-simulations \
        # Tools
        ros-${ROS_DISTRO}-rviz2 \
        ros-${ROS_DISTRO}-teleop-twist-keyboard \
        # Core libs
        ros-${ROS_DISTRO}-rclpy \
        ros-${ROS_DISTRO}-geometry-msgs \
        ros-${ROS_DISTRO}-sensor-msgs \
        ros-${ROS_DISTRO}-std-srvs \
    && rosdep init \
    && rosdep update \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ==========================================
# Setup + entrypoint
# ==========================================
COPY ./setup_container.bash /
RUN bash /setup_container.bash

COPY ./entrypoint.sh /

COPY ./entrypoint.sh /
RUN chmod +x /entrypoint.sh

ENV USER=ubuntu
ENV PASSWD=ubuntu
ENV TURTLEBOT3_MODEL=burger

CMD ["/bin/bash", "-c", "/entrypoint.sh"]