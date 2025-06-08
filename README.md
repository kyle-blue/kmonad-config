# KMonad Configuration

## QWERTY Enhanced

This configuration modifies the qwerty keyboard to make it more suitable for programming, and to minimise reaching for keys which displace the hands from regular typing positions

## Pre-requisites and how to use

- Clone this repo into ~/.config/kmonad
- Before installing, look for your correct keyboard device path in either `/dev/input/by-id` (for connected keyboards) or `/dev/input/by-path` (for in-built keyboards). Place the correct path under the `DEVICE_FILE_PATH` variable in ./.env.
  - Current laptop value: `/dev/input/by-path/pci-0000:06:00.4-usb-0:3:1.0-event-kbd`
  - Current desktop value: `/dev/input/by-id/usb-Keychron_Keychron_K3-event-kbd`
- Install KMonad (linux binary available in [kmonad releases](https://github.com/kmonad/kmonad/releases))
  - Cmod +x and put the binary in /usr/local/bin
  - Run `./install.sh`
- LOG OUT AND LOG BACK IN (OR RESTART)

Bravo. Kmonad will now run on startup with the configuration defined in ./config.kbd

## Layers

### Base Layer

![](./layout_images/base_layer.jpg)

### CAPS layer (symbol layer)

![](./layout_images/caps_layer.jpg)

### TAB layer (number layer)

![](./layout_images/tab_layer.jpg)

### CAPS & TAB layer (movement layer)

![](./layout_images/caps_and_tab_layer.jpg)

## Note

If you need to edit the layer images in the future, JSON representation for https://keyboard-layout-editor.com/ is stored in `./layout_images/json/`
