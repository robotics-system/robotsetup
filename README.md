# TurtleBot3 Robot Setup — DVA272

Installationsskript för TurtleBot3 Burger med ROS 2 Jazzy på Ubuntu Server 24.04 (Raspberry Pi).

---

## Förutsättningar

- SD-kort flashat med **Ubuntu Server 24.04.2 LTS (64-bit)**
- WiFi, hostname och SSH konfigurerat via Raspberry Pi Imager
- Robot och laptop på samma nätverk

---

## Installera roboten

SSH in på roboten och kör:

```bash
git clone https://github.com/robotics-system/robotsetup.git
cd robotsetup
bash install_robot.sh
```

*Tar ~20 minuter (colcon build på RPi).*

Flasha sedan OpenCR-kortet (motorstyrkortet):

```bash
bash flash_opencr.sh
```

---

## Starta demon (F8 — SLAM + Teleop + RViz)

### På roboten

```bash
source ~/.bashrc
ros2 launch turtlebot3_bringup robot.launch.py
```

### På laptopen

```bash
cd ~/teaching/DVA272/VT26/demo_slam
./build_and_run.sh
```

Öppnar automatiskt:
- **RViz** med karta, laser och robotmodell
- **Teleop** i eget terminalfönster (piltangenter/WASD)

### Spara kartan

```bash
source /opt/ros/jazzy/setup.bash && export ROS_DOMAIN_ID=100
cd ~/teaching/DVA272/VT26/demo_slam && source install/setup.bash
ros2 launch dva272_slam_demo save_map.launch.py
```

Kartan sparas som `~/map_demo.pgm` + `~/map_demo.yaml`.

---

## Inställningar

| Parameter | Värde |
|-----------|-------|
| ROS_DOMAIN_ID | 100 |
| TURTLEBOT3_MODEL | burger |
| LDS_MODEL | LDS-02 |

---

## Studentlabb

Använd `install_student_robot.sh` (ROS_DOMAIN_ID=101, LDS-02).  
Studenterna kör sedan enligt officiell guide:  
https://emanual.robotis.com/docs/en/platform/turtlebot3/bringup/
