#/bin/bash

sudo apt update
sudo apt install setxkbmap

sudo groupadd -f uinput
sudo usermod -aG input,uinput $USER
echo 'KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"' | sudo tee /etc/udev/rules.d/99-kmonad.rules
sudo modprobe uinput

# Enable kmonad as a service on startup
mkdir -p ~/.config/systemd/user
cat ./kmonad.service | envsubst > ~/.config/systemd/user/kmonad.service
systemctl --user daemon-reload
systemctl --user enable kmonad.service
systemctl --user start kmonad.service
