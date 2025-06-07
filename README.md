# KMonad Configuration

## QWERTY Enhanced

This configuration modifies the qwerty keyboard to make it more suitable for programming, and to minimise reaching for keys which displace the hands from regular typing positions

## Pre-requisites

- Clone this repo into ~/.config/kmonad-config
- Install KMonad (linux binary available in releases)
  - Cmod +x and put the binary in /usr/local/bin
  - Run the install script in this repo
- Install setxkbmap: `sudo apt update && sudo apt install setxkbmap`

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
