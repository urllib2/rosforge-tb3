# RosForge — ROS2 TurtleBot3 Environment

Your local development environment for the RosForge ROS2 course.

---

## Prerequisites

Install these tools before starting:

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) — runs the container
- [Visual Studio Code](https://code.visualstudio.com/) — your code editor
- [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) — connects VS Code to the container

---

## First-Time Setup

### Step 1 — Download the environment

Download and unzip the course folder anywhere on your machine. Recommended:

```
C:\Users\YourName\Documents\rosforge-tb3\
```

### Step 2 — Open in VS Code

1. Open VS Code
2. **File → Open Folder** → select `rosforge-tb3/`
3. Press **Ctrl+Shift+P** → type `Dev Containers: Reopen in Container`
4. Wait for the container to build and start (~5 minutes the first time)

VS Code will reopen inside the container. You are ready.

### Step 3 — Build the workspace (once)

Open a terminal in VS Code (**Ctrl+`**) and run:

```bash
cd ~/ros_ws
colcon build --symlink-install
source install/setup.bash
```

> ⚠️ You only need to do this **once**. The build output is saved on your machine.

---

## Daily Usage

Every time you open VS Code:

1. **Ctrl+Shift+P** → `Dev Containers: Reopen in Container`
2. Your workspace is ready — no need to rebuild

---

## Access the Desktop (Gazebo + RViz)

The container includes a full Linux desktop accessible from your browser.

Open: [http://localhost:6080](http://localhost:6080)

Password: `ubuntu`

Use this desktop to run Gazebo simulations and RViz.

---

## Where to Write Your Code

All your code goes in:

```
rosforge-tb3/
└── ros_ws/
    └── src/         ← your ROS2 packages go here
```

This folder is synchronized between your Windows machine and the container. Your code is always saved on your machine — even if the container is deleted.

---

## Course Commands Reference

### Start Gazebo simulation

```bash
ros2 launch turtlebot3_gazebo turtlebot3_world.launch.py
```

### Start SLAM mapping

```bash
ros2 launch slam_toolbox online_async_launch.py \
  use_sim_time:=True \
  slam_params_file:=$(ros2 pkg prefix slam_toolbox)/share/slam_toolbox/config/mapper_params_online_async.yaml
```

### Open RViz

```bash
rviz2
```

### Teleoperate the robot

```bash
ros2 run turtlebot3_teleop teleop_keyboard
```

### Save the map

```bash
ros2 run nav2_map_server map_saver_cli -f ~/my_map
```

### Start autonomous navigation

```bash
ros2 launch nav2_bringup bringup_launch.py \
  use_sim_time:=True \
  map:=$HOME/my_map.yaml
```

---

## Troubleshooting

**Container not starting**
Make sure Docker Desktop is running before opening VS Code.

**Gazebo is slow**
This is normal on machines without a dedicated GPU. The container uses software rendering.

**`colcon build` fails**
Make sure you are in `~/ros_ws` before running the build command.

**Desktop is blank at localhost:6080**
Wait 10–15 seconds after the container starts, then refresh the page.

---

## Support

Having issues? Contact your mentor on WhatsApp or visit [rosforge.com](https://rosforge.com)