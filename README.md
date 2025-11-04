# KMonad Configuration

## QWERTY Enhanced

This configuration modifies the qwerty keyboard to make it more suitable for programming, and to minimise reaching for keys which displace the hands from regular typing positions

## Pre-requisites and Installation

### Linux Installation

- Clone this repo into ~/.config/kmonad
- Before installing, look for your correct keyboard device path in either `/dev/input/by-id` (for connected keyboards) or `/dev/input/by-path` (for in-built keyboards). Place the correct path under the `DEVICE_FILE_PATH` variable in ./.env.
  - Current laptop value: `/dev/input/by-path/pci-0000:06:00.4-usb-0:3:1.0-event-kbd`
  - Current desktop value: `/dev/input/by-id/usb-Keychron_Keychron_K3-event-kbd`
- Install KMonad (linux binary available in [kmonad releases](https://github.com/kmonad/kmonad/releases))
  - Chmod +x and put the binary in /usr/local/bin
  - Run `./install.sh`
- LOG OUT AND LOG BACK IN (OR RESTART)

### Windows Installation

- Download this repository to any location (e.g., `C:\kmonad-config`)
- Download KMonad for Windows from [kmonad releases](https://github.com/kmonad/kmonad/releases)
  - Place `kmonad.exe` in `C:\Program Files\kmonad\` (or another location)
- Open PowerShell as Administrator
- Navigate to the repository directory
- Run `.\install.ps1`
  - The script will guide you through the installation process
  - It will first try to create a Windows service, and fall back to a scheduled task if needed
- RESTART your computer for changes to take effect

**Windows Service Management:**
- Start: `Start-Service -Name "KMonad-<suffix>"` or `Start-ScheduledTask -TaskName "KMonad-<suffix>"`
- Stop: `Stop-Service -Name "KMonad-<suffix>"` or `Stop-ScheduledTask -TaskName "KMonad-<suffix>"`
- Status: `Get-Service -Name "KMonad-<suffix>"` or `Get-ScheduledTask -TaskName "KMonad-<suffix>"`
- Uninstall: Run `.\uninstall.ps1` as Administrator

**Windows Troubleshooting:**
- If you get service startup errors, run `.\test-kmonad.ps1` to diagnose issues
- KMonad may be blocked by antivirus software - add it to exclusions if needed
- Some systems work better with scheduled tasks than services
- Ensure you're using the Windows version of KMonad, not the Linux version

Bravo. Kmonad will now run on startup with the configuration defined in the appropriate config file

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
