#/bin/bash

SCRIPT=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT")

sudo apt update
sudo apt install setxkbmap

sudo groupadd -f uinput
sudo usermod -aG input,uinput $USER
echo 'KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"' | sudo tee /etc/udev/rules.d/99-kmonad.rules
sudo modprobe uinput

# Enable kmonad as a service on startup

set -a
. ./.env
set +a

RAND_STRING=$(head -c 4 /dev/urandom | xxd -p)
export SERVICE_NAME="kmonad-$RAND_STRING"
export CONFIG_NAME=".config-$RAND_STRING.kbd"

mkdir -p ~/.config/systemd/user

cat ./kmonad.service | envsubst > ~/.config/systemd/user/$SERVICE_NAME.service
cat ./config.kbd | envsubst > ~/.config/kmonad/$CONFIG_NAME
systemctl --user daemon-reload
systemctl --user enable $SERVICE_NAME.service
systemctl --user start $SERVICE_NAME.service
