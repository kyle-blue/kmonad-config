#!/bin/bash
# install-macos.sh - Install Kanata on macOS with auto-start via launchd
#
# Requirements:
#   - kanata (brew install kanata)
#   - Karabiner-DriverKit-VirtualHIDDevice v5.0.0+ (v6.x recommended)
#     Download: https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/releases
#
# kanata v1.8.0+ requires Karabiner-DriverKit-VirtualHIDDevice v5.0.0 or later.
# Older versions (v1.x-v4.x) use an incompatible IPC mechanism and will cause
# "connect_failed asio.system:2" errors.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$HOME/.config/kanata"
CONFIG_FILE="$CONFIG_DIR/kanata.kbd"
KANATA_BIN="$(which kanata 2>/dev/null || true)"
KANATA_PLIST_NAME="com.kanata.keyboard"
KANATA_PLIST_PATH="/Library/LaunchDaemons/$KANATA_PLIST_NAME.plist"
KARABINER_DAEMON_PLIST_NAME="com.kanata.karabiner-daemon"
KARABINER_DAEMON_PLIST_PATH="/Library/LaunchDaemons/$KARABINER_DAEMON_PLIST_NAME.plist"
KARABINER_DRIVER="/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice"
KARABINER_DAEMON_BIN="$KARABINER_DRIVER/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon"
KARABINER_MIN_VERSION="5.0.0"

echo "Kanata macOS Installer"
echo "======================"
echo ""

# ---------------------------------------------------------------------------
# Step 1: Check kanata is installed
# ---------------------------------------------------------------------------
if [ -z "$KANATA_BIN" ]; then
    echo "Error: kanata not found in PATH."
    echo "Install with: brew install kanata"
    exit 1
fi

# Resolve symlinks to get the real binary path (needed for Input Monitoring)
KANATA_REAL_BIN="$(realpath "$KANATA_BIN" 2>/dev/null || readlink -f "$KANATA_BIN" 2>/dev/null || echo "$KANATA_BIN")"
echo "Found kanata at: $KANATA_BIN"
if [ "$KANATA_REAL_BIN" != "$KANATA_BIN" ]; then
    echo "  Real path:   $KANATA_REAL_BIN"
fi

# ---------------------------------------------------------------------------
# Step 2: Check Karabiner VirtualHIDDevice driver (v5.0.0+ required)
# ---------------------------------------------------------------------------
echo ""
if [ ! -d "$KARABINER_DRIVER" ]; then
    echo "Error: Karabiner-DriverKit-VirtualHIDDevice is not installed."
    echo ""
    echo "kanata on macOS requires this driver (v5.0.0 or later) for keyboard"
    echo "interception. Download the latest .pkg from:"
    echo ""
    echo "  https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/releases"
    echo ""
    echo "After installing, re-run this script."
    exit 1
fi

# Check the installed version via the Manager app bundle
KARABINER_VERSION=""
MANAGER_APP="/Applications/.Karabiner-VirtualHIDDevice-Manager.app"
if [ -d "$MANAGER_APP" ]; then
    KARABINER_VERSION="$(defaults read "$MANAGER_APP/Contents/Info.plist" CFBundleVersion 2>/dev/null || true)"
fi
# Fallback: check systemextensionsctl output
if [ -z "$KARABINER_VERSION" ]; then
    KARABINER_VERSION="$(systemextensionsctl list 2>&1 | grep -o 'org.pqrs.Karabiner-DriverKit-VirtualHIDDevice ([^)]*' | grep -o '[0-9][0-9.]*' | head -1 || true)"
fi

echo "Found Karabiner VirtualHIDDevice driver."
if [ -n "$KARABINER_VERSION" ]; then
    echo "  Installed version: $KARABINER_VERSION"

    # Compare major version - must be >= 5
    MAJOR_VERSION="$(echo "$KARABINER_VERSION" | cut -d. -f1)"
    if [ "$MAJOR_VERSION" -lt 5 ] 2>/dev/null; then
        echo ""
        echo "============================================="
        echo "  ERROR: Karabiner driver version too old"
        echo "============================================="
        echo ""
        echo "  Installed: v$KARABINER_VERSION"
        echo "  Required:  v$KARABINER_MIN_VERSION or later"
        echo ""
        echo "  kanata v1.8.0+ requires Karabiner-DriverKit-VirtualHIDDevice v5.0.0+"
        echo "  Older versions use an incompatible IPC mechanism and will cause"
        echo "  'connect_failed asio.system:2' errors."
        echo ""
        echo "  To fix:"
        echo "  1. Uninstall the old version:"
        echo "     sudo '$KARABINER_DRIVER/scripts/uninstall/deactivate_driver.sh'"
        echo ""
        echo "  2. Download and install the latest version from:"
        echo "     https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/releases"
        echo ""
        echo "  3. Re-run this script."
        exit 1
    fi
fi

# Check driver activation status
check_driver_status() {
    systemextensionsctl list 2>&1 | grep -i "org.pqrs.Karabiner-DriverKit-VirtualHIDDevice" || true
}

DRIVER_STATUS="$(check_driver_status)"

if echo "$DRIVER_STATUS" | grep -q "activated waiting for user"; then
    echo ""
    echo "============================================="
    echo "  ACTION REQUIRED: Approve Karabiner Driver"
    echo "============================================="
    echo ""
    echo "The Karabiner VirtualHIDDevice driver needs your approval."
    echo ""
    echo "  1. Open System Settings > General > Login Items & Extensions"
    echo "  2. Find 'Karabiner-DriverKit-VirtualHIDDevice' or 'org.pqrs'"
    echo "  3. Click 'Allow' to approve the system extension"
    echo "  4. You may need to authenticate with your password or Touch ID"
    echo ""
    echo "After approving, press Enter to continue..."
    read -r

    DRIVER_STATUS="$(check_driver_status)"
    if echo "$DRIVER_STATUS" | grep -q "activated waiting for user"; then
        echo "Warning: Driver still waiting for approval. You may need to restart."
        read -rp "Continue anyway? (y/N): " CONTINUE
        if [[ ! "$CONTINUE" =~ ^[yY]$ ]]; then
            exit 1
        fi
    fi
fi

if echo "$DRIVER_STATUS" | grep -q "activated enabled"; then
    echo "Karabiner driver is activated and enabled."
elif [ -z "$DRIVER_STATUS" ]; then
    echo "Activating Karabiner VirtualHIDDevice driver..."
    if [ -d "/Applications/.Karabiner-VirtualHIDDevice-Manager.app" ]; then
        "/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager" activate 2>&1 || true
        sleep 2
    fi
    DRIVER_STATUS="$(check_driver_status)"
    if echo "$DRIVER_STATUS" | grep -q "activated waiting for user"; then
        echo ""
        echo "  System extension approval required."
        echo "  Go to System Settings > General > Login Items & Extensions"
        echo "  and approve the Karabiner extension, then press Enter..."
        read -r
    fi
fi

# ---------------------------------------------------------------------------
# Step 3: Check Input Monitoring permission
# ---------------------------------------------------------------------------
echo ""
echo "============================================="
echo "  IMPORTANT: Input Monitoring Permission"
echo "============================================="
echo ""
echo "kanata requires Input Monitoring permission to intercept keyboard events."
echo ""
echo "  1. Open System Settings > Privacy & Security > Input Monitoring"
echo "  2. Click '+' to add the kanata binary:"
echo "     $KANATA_REAL_BIN"
echo "  3. Enable the toggle for kanata"
echo ""
echo "  Tip: In Finder, press Cmd+Shift+G and paste the path above."
echo ""
read -rp "Have you added kanata to Input Monitoring? (y/N): " IM_DONE
if [[ ! "$IM_DONE" =~ ^[yY]$ ]]; then
    echo ""
    echo "Warning: kanata will fail with 'IOHIDDeviceOpen error: not permitted'"
    echo "if Input Monitoring is not granted. You can add it later and restart."
fi

# ---------------------------------------------------------------------------
# Step 4: Copy and validate config
# ---------------------------------------------------------------------------
mkdir -p "$CONFIG_DIR"
echo ""
echo "Config directory: $CONFIG_DIR"

if [ -f "$CONFIG_FILE" ]; then
    echo "Config file already exists at: $CONFIG_FILE"
    read -rp "Overwrite? (y/N): " OVERWRITE
    if [[ ! "$OVERWRITE" =~ ^[yY]$ ]]; then
        echo "Keeping existing config."
    else
        cp "$SCRIPT_DIR/config-macos.kbd" "$CONFIG_FILE"
        echo "Config updated."
    fi
else
    cp "$SCRIPT_DIR/config-macos.kbd" "$CONFIG_FILE"
    echo "Config copied to: $CONFIG_FILE"
fi

echo ""
echo "Validating kanata config..."
if "$KANATA_BIN" --check -c "$CONFIG_FILE"; then
    echo "Config validation passed."
else
    echo "Error: Config validation failed. Please check the config file."
    exit 1
fi

# ---------------------------------------------------------------------------
# Step 5: Create launchd daemons (Karabiner daemon + kanata)
# ---------------------------------------------------------------------------

# Stop existing services
if sudo launchctl list 2>/dev/null | grep -q "$KANATA_PLIST_NAME"; then
    echo ""
    echo "Stopping existing kanata service..."
    sudo launchctl unload "$KANATA_PLIST_PATH" 2>/dev/null || true
fi
if sudo launchctl list 2>/dev/null | grep -q "$KARABINER_DAEMON_PLIST_NAME"; then
    echo "Stopping existing Karabiner daemon service..."
    sudo launchctl unload "$KARABINER_DAEMON_PLIST_PATH" 2>/dev/null || true
fi

# Kill any user-level Karabiner daemon (we'll run it as root via launchd instead)
pkill -f "Karabiner-VirtualHIDDevice-Daemon" 2>/dev/null || true
sleep 1

echo ""
echo "Creating Karabiner daemon launchd service (runs as root)..."
sudo tee "$KARABINER_DAEMON_PLIST_PATH" > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$KARABINER_DAEMON_PLIST_NAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>$KARABINER_DAEMON_BIN</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/tmp/karabiner-daemon.err.log</string>
    <key>StandardOutPath</key>
    <string>/tmp/karabiner-daemon.out.log</string>
</dict>
</plist>
EOF
sudo chmod 644 "$KARABINER_DAEMON_PLIST_PATH"
sudo chown root:wheel "$KARABINER_DAEMON_PLIST_PATH"

echo "Creating kanata launchd service (runs as root)..."
sudo tee "$KANATA_PLIST_PATH" > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$KANATA_PLIST_NAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>$KANATA_REAL_BIN</string>
        <string>--nodelay</string>
        <string>-c</string>
        <string>$CONFIG_FILE</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/tmp/kanata.err.log</string>
    <key>StandardOutPath</key>
    <string>/tmp/kanata.out.log</string>
    <key>ThrottleInterval</key>
    <integer>30</integer>
</dict>
</plist>
EOF
sudo chmod 644 "$KANATA_PLIST_PATH"
sudo chown root:wheel "$KANATA_PLIST_PATH"

# ---------------------------------------------------------------------------
# Step 6: Start services (Karabiner daemon first, then kanata)
# ---------------------------------------------------------------------------
echo ""
echo "Starting Karabiner daemon..."
sudo launchctl load "$KARABINER_DAEMON_PLIST_PATH"
sleep 2

echo "Starting kanata..."
sudo launchctl load "$KANATA_PLIST_PATH"
sleep 3

# Check if services are running
echo ""
DAEMON_OK=false
KANATA_OK=false
if sudo launchctl list 2>/dev/null | grep -q "$KARABINER_DAEMON_PLIST_NAME"; then
    echo "Karabiner daemon service is loaded."
    DAEMON_OK=true
fi
if sudo launchctl list 2>/dev/null | grep -q "$KANATA_PLIST_NAME"; then
    echo "Kanata service is loaded."
    KANATA_OK=true
fi

# Quick log check for errors
if [ -f /tmp/kanata.err.log ]; then
    RECENT_ERRORS="$(tail -5 /tmp/kanata.err.log 2>/dev/null)"
    if echo "$RECENT_ERRORS" | grep -q "not permitted"; then
        echo ""
        echo "Warning: kanata reports 'not permitted' - Input Monitoring may not be enabled."
        echo "Add this binary to Input Monitoring: $KANATA_REAL_BIN"
    fi
fi
if [ -f /tmp/kanata.out.log ]; then
    if tail -10 /tmp/kanata.out.log 2>/dev/null | grep -q "connect_failed"; then
        echo ""
        echo "Warning: 'connect_failed' errors detected."
        echo "This usually means the Karabiner driver version is incompatible."
        echo "Ensure Karabiner-DriverKit-VirtualHIDDevice v5.0.0+ is installed."
    fi
fi

echo ""
echo "============================================="
echo "Installation complete!"
echo "============================================="
echo ""
echo "Config file:  $CONFIG_FILE"
echo "Kanata logs:  /tmp/kanata.out.log"
echo "Error logs:   /tmp/kanata.err.log"
echo "Daemon logs:  /tmp/karabiner-daemon.out.log"
echo ""
echo "Useful commands:"
echo "  Check status:   sudo launchctl list | grep -E 'kanata|karabiner'"
echo "  View logs:      tail -f /tmp/kanata.out.log"
echo "  View errors:    tail -f /tmp/kanata.err.log"
echo "  Restart kanata: sudo launchctl unload $KANATA_PLIST_PATH && sudo launchctl load $KANATA_PLIST_PATH"
echo "  Stop kanata:    sudo launchctl unload $KANATA_PLIST_PATH"
echo "  Uninstall:      ./uninstall-macos.sh"
echo ""
echo "If kanata is not working:"
echo "  1. Ensure Karabiner-DriverKit-VirtualHIDDevice v5.0.0+ is installed"
echo "  2. Approve the system extension in System Settings > Login Items & Extensions"
echo "  3. Add kanata to Input Monitoring: $KANATA_REAL_BIN"
