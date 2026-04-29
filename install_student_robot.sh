#!/bin/bash
# =============================================================================
# TurtleBot3 Burger – Student Robot Setup (ROS 2 Jazzy, Ubuntu Server 24.04)
# Baserat på: https://emanual.robotis.com/docs/en/platform/turtlebot3/sbc_setup/
#
# Installerar ROS2 + TurtleBot3 på robotens SD-kort.
# Studenten kör sedan själv bringup, teleop och SLAM på sin laptop.
#
# Användning:
#   git clone https://github.com/robotics-system/robotsetup.git
#   cd robotsetup && bash install_student_robot.sh
#
# Tar ca 20-30 minuter (colcon build på Raspberry Pi).
# Kör flash_opencr.sh separat efteråt.
# =============================================================================
set -eo pipefail

# ── Konfiguration ────────────────────────────────────────────────────────────
ROS_DISTRO=jazzy
DOMAIN_ID=101
LDS_MODEL=LDS-02
TB3_MODEL=burger
WORKSPACE="$HOME/turtlebot3_ws"
# ─────────────────────────────────────────────────────────────────────────────

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

step() { echo -e "\n${BOLD}${GREEN}[$(date +%H:%M:%S)] $*${NC}"; }
warn() { echo -e "${YELLOW}VARNING: $*${NC}"; }
die()  { echo -e "${RED}FEL: $*${NC}" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] && die "Kör INTE som root."

# ── 0. Stäng av unattended-upgrades ─────────────────────────────────────────
step "0/7  Inaktiverar unattended-upgrades"
sudo systemctl stop unattended-upgrades 2>/dev/null || true
sudo systemctl disable unattended-upgrades 2>/dev/null || true
sudo killall unattended-upgr 2>/dev/null || true
while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
    echo "  Väntar på att apt-låset ska släppas..."; sleep 2
done

# ── 1. Swap-fil ──────────────────────────────────────────────────────────────
step "1/7  Skapar swap-fil (2 GB)"
if [ ! -f /swapfile ]; then
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab > /dev/null
    echo "  Swap skapad."
else
    echo "  Swap finns redan, hoppar över."
fi

# ── 2. Locale ────────────────────────────────────────────────────────────────
step "2/7  Konfigurerar locale"
sudo apt-get update -q
sudo apt-get install -y -q locales
sudo locale-gen en_US en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export LANG=en_US.UTF-8

# ── 3. ROS 2 Jazzy ──────────────────────────────────────────────────────────
step "3/7  Installerar ROS 2 Jazzy"
sudo apt-get install -y -q software-properties-common curl

if [ ! -f /usr/share/keyrings/ros-archive-keyring.gpg ]; then
    sudo add-apt-repository universe -y
    sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
        -o /usr/share/keyrings/ros-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo "$UBUNTU_CODENAME") main" \
        | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null
    sudo apt-get update -q
fi

sudo apt-get install -y -q --allow-downgrades \
    liblz4-1=1.9.4-1build1 \
    libzstd1=1.5.5+dfsg2-2build1 \
    zlib1g=1:1.3.dfsg-3.1ubuntu2

sudo apt-get install -y -q \
    ros-${ROS_DISTRO}-ros-base \
    python3-colcon-common-extensions

# ── 4. TurtleBot3-beroenden ──────────────────────────────────────────────────
step "4/7  Installerar TurtleBot3-beroenden"
sudo apt-get install -y -q --allow-downgrades \
    python3-argcomplete \
    libboost-system-dev \
    gcc g++ make cmake \
    libudev-dev \
    git \
    ros-${ROS_DISTRO}-hls-lfcd-lds-driver \
    ros-${ROS_DISTRO}-turtlebot3-msgs \
    ros-${ROS_DISTRO}-dynamixel-sdk \
    ros-${ROS_DISTRO}-xacro

# ── 5. Bygg turtlebot3_ws ────────────────────────────────────────────────────
step "5/7  Klonar och bygger turtlebot3_ws  (~20 min)"
source /opt/ros/${ROS_DISTRO}/setup.bash

mkdir -p "${WORKSPACE}/src"
cd "${WORKSPACE}/src"

if [ ! -d turtlebot3 ]; then
    git clone -b ${ROS_DISTRO} https://github.com/ROBOTIS-GIT/turtlebot3.git
fi
if [ ! -d ld08_driver ]; then
    git clone -b ${ROS_DISTRO} https://github.com/ROBOTIS-GIT/ld08_driver.git
fi
if [ ! -d hls_lfcd_lds_driver ]; then
    git clone -b ${ROS_DISTRO} https://github.com/ROBOTIS-GIT/hls_lfcd_lds_driver.git
fi

cd "${WORKSPACE}/src/turtlebot3"
rm -rf turtlebot3_cartographer turtlebot3_navigation2

cd "${WORKSPACE}"
colcon build --symlink-install --parallel-workers 1

# ── 6. USB-regler för OpenCR ─────────────────────────────────────────────────
step "6/7  Konfigurerar udev-regler för OpenCR"
source "${WORKSPACE}/install/setup.bash"

RULES_SRC="$(ros2 pkg prefix turtlebot3_bringup)/share/turtlebot3_bringup/script/99-turtlebot3-cdc.rules"
if [ -f "$RULES_SRC" ]; then
    sudo cp "$RULES_SRC" /etc/udev/rules.d/
    sudo udevadm control --reload-rules
    sudo udevadm trigger
else
    warn "Kunde inte hitta udev-regler på $RULES_SRC"
fi

# ── 7. Miljövariabler ────────────────────────────────────────────────────────
step "7/7  Skriver miljövariabler till ~/.bashrc"

append_if_missing() {
    grep -qxF "$1" ~/.bashrc || echo "$1" >> ~/.bashrc
}

append_if_missing "source /opt/ros/${ROS_DISTRO}/setup.bash"
append_if_missing "source ${WORKSPACE}/install/setup.bash"
append_if_missing "export ROS_DOMAIN_ID=${DOMAIN_ID}"
append_if_missing "export TURTLEBOT3_MODEL=${TB3_MODEL}"
append_if_missing "export LDS_MODEL=${LDS_MODEL}"

# ── Klart ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║   INSTALLATION KLAR!                                     ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  ROS_DOMAIN_ID = $DOMAIN_ID"
echo "  LDS_MODEL     = $LDS_MODEL"
echo ""
echo "Nästa steg:"
echo "  1. bash flash_opencr.sh"
echo "  2. source ~/.bashrc"
echo "  3. ros2 launch turtlebot3_bringup robot.launch.py"
echo ""
echo "Studentkommandon (på laptop, ROS_DOMAIN_ID=$DOMAIN_ID):"
echo "  Bringup:  ros2 launch turtlebot3_bringup robot.launch.py"
echo "  Teleop:   ros2 run turtlebot3_teleop teleop_keyboard"
echo "  SLAM:     ros2 launch turtlebot3_cartographer cartographer.launch.py"
echo "  Spara:    ros2 run nav2_map_server map_saver_cli -f ~/map"
