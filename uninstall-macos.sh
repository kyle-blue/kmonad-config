#!/bin/bash
# uninstall-macos.sh - Uninstall Kanata from macOS

set -e

KANATA_PLIST_NAME="com.kanata.keyboard"
KANATA_PLIST_PATH="/Library/LaunchDaemons/$KANATA_PLIST_NAME.plist"
KARABINER_DAEMON_PLIST_NAME="com.kanata.karabiner-daemon"
KARABINER_DAEMON_PLIST_PATH="/Library/LaunchDaemons/$KARABINER_DAEMON_PLIST_NAME.plist"
CONFIG_DIR="$HOME/.config/kanata"

echo "Kanata macOS Uninstaller"
echo "========================"
echo ""

# Stop and remove kanata service
if [ -f "$KANATA_PLIST_PATH" ]; then
    echo "Stopping kanata service..."
    sudo launchctl unload "$KANATA_PLIST_PATH" 2>/dev/null || true
    sudo rm "$KANATA_PLIST_PATH"
    echo "Removed kanata launchd daemon."
else
    echo "No kanata launchd daemon found."
fi

# Stop and remove Karabiner daemon service
if [ -f "$KARABINER_DAEMON_PLIST_PATH" ]; then
    echo "Stopping Karabiner daemon service..."
    sudo launchctl unload "$KARABINER_DAEMON_PLIST_PATH" 2>/dev/null || true
    sudo rm "$KARABINER_DAEMON_PLIST_PATH"
    echo "Removed Karabiner daemon launchd service."
else
    echo "No Karabiner daemon launchd service found."
fi

# Ask about config
if [ -d "$CONFIG_DIR" ]; then
    echo ""
    read -rp "Remove config directory ($CONFIG_DIR)? (y/N): " REMOVE_CONFIG
    if [[ "$REMOVE_CONFIG" =~ ^[yY]$ ]]; then
        rm -rf "$CONFIG_DIR"
        echo "Removed config directory."
    else
        echo "Config directory kept."
    fi
fi

echo ""
echo "Kanata services have been removed."
echo "To also uninstall the kanata binary: brew uninstall kanata"
