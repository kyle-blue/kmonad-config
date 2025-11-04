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

# Prompt for a user-defined suffix for the service name
while true; do
    read -rp "Enter a name suffix for the service (letters, digits, '-' and '_'). Leave empty to use 'default': " NAME
    NAME=${NAME:-default}
    # sanitize: keep only allowed chars
    SAFE_NAME=$(echo "$NAME" | tr -cd '[:alnum:]-_')
    if [ -n "$SAFE_NAME" ]; then
        break
    fi
    echo "Name contains no valid characters, please try again."
done

export SERVICE_NAME="kmonad-$SAFE_NAME"
export CONFIG_NAME=".config-$SAFE_NAME.kbd"

mkdir -p ~/.config/systemd/user

cat ./kmonad.service | envsubst > ~/.config/systemd/user/$SERVICE_NAME.service
cat ./config.kbd | envsubst > ~/.config/kmonad/$CONFIG_NAME
systemctl --user daemon-reload
systemctl --user enable $SERVICE_NAME.service
systemctl --user start $SERVICE_NAME.service
