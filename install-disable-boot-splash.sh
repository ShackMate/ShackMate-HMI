#!/bin/bash

# Quick installer for Raspberry Pi Boot Splash Disable Script
# Usage: curl -sSL https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/install-disable-boot-splash.sh | sudo bash

set -e

echo "🍓 Raspberry Pi Boot Splash Disable - Quick Installer"
echo "===================================================="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)"
   exit 1
fi

# Download and run the main script
SCRIPT_URL="https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/disable-boot-splash.sh"
TEMP_SCRIPT="/tmp/disable-boot-splash.sh"

echo "📥 Downloading script from GitHub..."
if command -v curl >/dev/null 2>&1; then
    curl -sSL "$SCRIPT_URL" -o "$TEMP_SCRIPT"
elif command -v wget >/dev/null 2>&1; then
    wget -q "$SCRIPT_URL" -O "$TEMP_SCRIPT"
else
    echo "❌ Error: Neither curl nor wget found. Please install one of them."
    exit 1
fi

echo "✅ Script downloaded successfully"
echo ""

# Make executable and run
chmod +x "$TEMP_SCRIPT"
"$TEMP_SCRIPT"

# Clean up
rm -f "$TEMP_SCRIPT"

echo "🧹 Temporary files cleaned up"
