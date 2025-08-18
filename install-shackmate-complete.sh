#!/bin/bash

# ShackMate Complete Installation Script
# This script:
# 1. Disables Raspberry Pi boot splash and text
# 2. Installs and starts the UDP listener service
# 3. Sets up everything needed for ShackMate operation

set -e  # Exit on any error

echo "🏠 ShackMate Complete Installation Script"
echo "========================================="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)"
   exit 1
fi

# Check if running on Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
    echo "⚠️  Warning: This doesn't appear to be a Raspberry Pi"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "📦 Step 1: Installing Boot Splash Disable Script"
echo "================================================"

# Download and run boot splash disable script
BOOT_SCRIPT_URL="https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/disable-boot-splash.sh"
TEMP_BOOT_SCRIPT="/tmp/disable-boot-splash.sh"

echo "📥 Downloading boot splash disable script..."
if command -v curl >/dev/null 2>&1; then
    curl -sSL "$BOOT_SCRIPT_URL" -o "$TEMP_BOOT_SCRIPT"
elif command -v wget >/dev/null 2>&1; then
    wget -q "$BOOT_SCRIPT_URL" -O "$TEMP_BOOT_SCRIPT"
else
    echo "❌ Error: Neither curl nor wget found. Please install one of them."
    exit 1
fi

# Run boot splash disable script
chmod +x "$TEMP_BOOT_SCRIPT"
"$TEMP_BOOT_SCRIPT"
rm -f "$TEMP_BOOT_SCRIPT"

echo ""
echo "🎨 Step 1.5: Installing Custom ShackMate Logo"
echo "============================================="

# Download and run custom logo script
LOGO_SCRIPT_URL="https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/install-custom-logo.sh"
TEMP_LOGO_SCRIPT="/tmp/install-custom-logo.sh"

echo "📥 Downloading custom logo installer..."
if command -v curl >/dev/null 2>&1; then
    curl -sSL "$LOGO_SCRIPT_URL" -o "$TEMP_LOGO_SCRIPT"
elif command -v wget >/dev/null 2>&1; then
    wget -q "$LOGO_SCRIPT_URL" -O "$TEMP_LOGO_SCRIPT"
else
    echo "❌ Error: curl/wget not found"
    exit 1
fi

# Run custom logo installer
chmod +x "$TEMP_LOGO_SCRIPT"
"$TEMP_LOGO_SCRIPT"
rm -f "$TEMP_LOGO_SCRIPT"

echo ""
echo "🌐 Step 2: Installing ShackMate UDP Listener Service"
echo "===================================================="

# Create installation directory
INSTALL_DIR="/opt/shackmate"
mkdir -p "$INSTALL_DIR"

# Download UDP listener script
UDP_SCRIPT_URL="https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/udp_listener.py"
UDP_SCRIPT_PATH="$INSTALL_DIR/udp_listener.py"

echo "📥 Downloading UDP listener script..."
if command -v curl >/dev/null 2>&1; then
    curl -sSL "$UDP_SCRIPT_URL" -o "$UDP_SCRIPT_PATH"
elif command -v wget >/dev/null 2>&1; then
    wget -q "$UDP_SCRIPT_URL" -O "$UDP_SCRIPT_PATH"
else
    echo "❌ Error: curl/wget not found"
    exit 1
fi

# Make executable
chmod +x "$UDP_SCRIPT_PATH"
echo "✅ UDP listener script installed to $UDP_SCRIPT_PATH"

# Download systemd service file
SERVICE_URL="https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/shackmate-udp-listener.service"
SERVICE_PATH="/etc/systemd/system/shackmate-udp-listener.service"

echo "📥 Downloading systemd service file..."
if command -v curl >/dev/null 2>&1; then
    curl -sSL "$SERVICE_URL" -o "$SERVICE_PATH"
elif command -v wget >/dev/null 2>&1; then
    wget -q "$SERVICE_URL" -O "$SERVICE_PATH"
else
    echo "❌ Error: curl/wget not found"
    exit 1
fi

echo "✅ Service file installed to $SERVICE_PATH"

# Ensure proper permissions
chown root:root "$UDP_SCRIPT_PATH"
chown root:root "$SERVICE_PATH"

echo ""
echo "🔄 Step 3: Configuring and Starting Service"
echo "==========================================="

# Reload systemd to recognize new service
systemctl daemon-reload
echo "✅ Systemd daemon reloaded"

# Enable service to start on boot
systemctl enable shackmate-udp-listener.service
echo "✅ ShackMate UDP Listener service enabled for auto-start"

# Start the service
systemctl start shackmate-udp-listener.service
echo "✅ ShackMate UDP Listener service started"

# Check service status
echo ""
echo "📊 Service Status:"
systemctl --no-pager status shackmate-udp-listener.service

echo ""
echo "🔍 Step 4: Verification"
echo "======================"

# Verify Python script can run
echo "🐍 Checking Python script syntax..."
python3 -m py_compile "$UDP_SCRIPT_PATH"
echo "✅ Python script syntax is valid"

# Check if service is running
if systemctl is-active --quiet shackmate-udp-listener.service; then
    echo "✅ ShackMate UDP Listener service is running"
else
    echo "⚠️  Service may not be running properly"
fi

# Check if port is being listened on
echo "🔌 Checking if UDP port 4210 is being listened on..."
if ss -ulnp | grep -q ":4210"; then
    echo "✅ UDP port 4210 is being listened on"
else
    echo "⚠️  UDP port 4210 may not be available"
fi

echo ""
echo "✨ Installation completed successfully!"
echo ""
echo "📋 Summary of changes:"
echo "   • Boot splash and verbose text disabled"
echo "   • Custom ShackMate logo installed as boot splash"
echo "   • ShackMate UDP Listener installed to $INSTALL_DIR"
echo "   • Systemd service created and started"
echo "   • Service enabled for auto-start on boot"
echo "   • Listening on UDP port 4210 for router updates"
echo "   • Updates /etc/hosts with discovered router IP"
echo ""
echo "🔄 Next steps:"
echo "   1. Reboot to apply boot splash changes: sudo reboot"
echo "   2. Check service logs: sudo journalctl -u shackmate-udp-listener.service -f"
echo "   3. Test by sending UDP packets to port 4210"
echo ""
echo "🛠️  Useful commands:"
echo "   • Check service status: sudo systemctl status shackmate-udp-listener"
echo "   • View logs: sudo journalctl -u shackmate-udp-listener -f"
echo "   • Restart service: sudo systemctl restart shackmate-udp-listener"
echo "   • Stop service: sudo systemctl stop shackmate-udp-listener"
echo "   • Disable auto-start: sudo systemctl disable shackmate-udp-listener"
echo ""
