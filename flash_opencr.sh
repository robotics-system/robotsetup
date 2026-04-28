#!/bin/bash
# Flashar OpenCR-kortet (motorstyrkortet) med TurtleBot3 Burger-firmware.
# Kör på roboten med OpenCR ansluten via USB (/dev/ttyACM0).
set -e

OPENCR_PORT=/dev/ttyACM0
OPENCR_MODEL=burger

echo "--- Flashar OpenCR för TurtleBot3 $OPENCR_MODEL ---"
echo "Port: $OPENCR_PORT"

if [ ! -c "$OPENCR_PORT" ]; then
    echo "FEL: $OPENCR_PORT finns inte. Kontrollera att OpenCR är ansluten via USB."
    exit 1
fi

cd /tmp
rm -rf opencr_update.tar.bz2 opencr_update
wget https://github.com/ROBOTIS-GIT/OpenCR-Binaries/raw/master/turtlebot3/ROS2/latest/opencr_update.tar.bz2
tar xvf opencr_update.tar.bz2
cd opencr_update

# RPi 4 kör aarch64 men opencr-binären är 32-bit ARM.
# Lägg till armhf-arkitektur så kärnan kan köra den nativt.
sudo dpkg --add-architecture armhf
sudo apt-get update -q
sudo apt-get install -y -q libc6:armhf
./update.sh $OPENCR_PORT $OPENCR_MODEL.opencr

echo ""
echo "--- OpenCR flashad! Starta om roboten och kör bringup. ---"
