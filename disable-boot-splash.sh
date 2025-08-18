#!/bin/bash

# Raspberry Pi 5 Boot Splash and Text Disable Script with Custom Logo
# This script disables boot messages, replaces splash with custom ShackMate logo
# Compatible with Raspberry Pi OS Bookworm and later

set -e  # Exit on any error

echo "🍓 Raspberry Pi 5 Boot Splash Disable Script with Custom Logo"
echo "============================================================="
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

# Backup original files
echo "📦 Creating backups..."
BACKUP_DIR="/boot/firmware/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

if [ -f /boot/firmware/cmdline.txt ]; then
    cp /boot/firmware/cmdline.txt "$BACKUP_DIR/"
    echo "✅ Backed up cmdline.txt to $BACKUP_DIR"
fi

if [ -f /boot/firmware/config.txt ]; then
    cp /boot/firmware/config.txt "$BACKUP_DIR/"
    echo "✅ Backed up config.txt to $BACKUP_DIR"
fi

echo ""

# Modify cmdline.txt
echo "🔧 Modifying boot command line parameters..."
if [ -f /boot/firmware/cmdline.txt ]; then
    # Read the current cmdline
    CMDLINE=$(cat /boot/firmware/cmdline.txt)
    
    # Remove any existing quiet/splash parameters to avoid duplicates
    CMDLINE=$(echo "$CMDLINE" | sed 's/quiet//g' | sed 's/splash//g' | sed 's/loglevel=[0-9]//g' | sed 's/logo\.nologo//g' | sed 's/vt\.global_cursor_default=[0-9]//g')
    
    # Clean up extra spaces
    CMDLINE=$(echo "$CMDLINE" | sed 's/  */ /g' | sed 's/^ *//' | sed 's/ *$//')
    
    # Add our parameters
    NEW_CMDLINE="$CMDLINE quiet splash loglevel=1 logo.nologo vt.global_cursor_default=0"
    
    # Write the new cmdline
    echo "$NEW_CMDLINE" > /boot/firmware/cmdline.txt
    echo "✅ Updated cmdline.txt with quiet boot parameters"
else
    echo "❌ Error: /boot/firmware/cmdline.txt not found"
    exit 1
fi

# Install custom ShackMate logo
echo "🎨 Installing custom ShackMate logo..."
CONFIG_FILE="/boot/firmware/config.txt"
LOGO_URL="https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/ShackMateLogo.png"
LOGO_PATH="/boot/firmware/ShackMateLogo.png"

# Download ShackMate logo
echo "📥 Downloading ShackMate logo..."
if command -v curl >/dev/null 2>&1; then
    curl -sSL "$LOGO_URL" -o "$LOGO_PATH"
elif command -v wget >/dev/null 2>&1; then
    wget -q "$LOGO_URL" -O "$LOGO_PATH"
else
    echo "⚠️  Warning: Could not download logo (curl/wget not found)"
    echo "   You can manually copy ShackMateLogo.png to /boot/firmware/"
fi

if [ -f "$LOGO_PATH" ]; then
    echo "✅ ShackMate logo downloaded to $LOGO_PATH"
else
    echo "⚠️  Warning: Could not install custom logo"
fi

if [ -f "$CONFIG_FILE" ]; then
    # Check if [all] section exists, if not add it
    if ! grep -q "^\[all\]" "$CONFIG_FILE"; then
        echo "" >> "$CONFIG_FILE"
        echo "[all]" >> "$CONFIG_FILE"
    fi
    
    # Configure custom logo instead of disabling splash
    if [ -f "$LOGO_PATH" ]; then
        # Use custom logo
        if grep -q "^splash=" "$CONFIG_FILE"; then
            sed -i "s|^splash=.*|splash=$LOGO_PATH|" "$CONFIG_FILE"
        else
            sed -i "/^\[all\]/a splash=$LOGO_PATH" "$CONFIG_FILE"
        fi
        echo "✅ Configured custom ShackMate logo as boot splash"
    else
        # Fallback to disabling splash if logo not available
        if grep -q "^disable_splash=" "$CONFIG_FILE"; then
            sed -i 's/^disable_splash=.*/disable_splash=1/' "$CONFIG_FILE"
        else
            sed -i '/^\[all\]/a disable_splash=1' "$CONFIG_FILE"
        fi
        echo "✅ Disabled default splash screen (logo not available)"
    fi
    
    # Keep rainbow splash disabled
    if grep -q "^disable_splash=" "$CONFIG_FILE"; then
        sed -i 's/^disable_splash=.*/disable_splash=1/' "$CONFIG_FILE"
    else
        sed -i '/^\[all\]/a disable_splash=1' "$CONFIG_FILE"
    fi
    
    # Add or update boot_delay setting (reduces delay)
    if grep -q "^boot_delay=" "$CONFIG_FILE"; then
        sed -i 's/^boot_delay=.*/boot_delay=0/' "$CONFIG_FILE"
    else
        sed -i '/^\[all\]/a boot_delay=0' "$CONFIG_FILE"
    fi
    
    echo "✅ Updated config.txt with custom logo configuration"
else
    echo "❌ Error: $CONFIG_FILE not found"
    exit 1
fi

# Disable Plymouth boot splash (if installed)
echo "🚫 Disabling Plymouth boot splash service..."
if systemctl is-enabled plymouth-start.service >/dev/null 2>&1; then
    systemctl disable plymouth-start.service
    echo "✅ Disabled Plymouth start service"
fi

if systemctl is-enabled plymouth-read-write.service >/dev/null 2>&1; then
    systemctl disable plymouth-read-write.service
    echo "✅ Disabled Plymouth read-write service"
fi

if systemctl is-enabled plymouth-quit-wait.service >/dev/null 2>&1; then
    systemctl disable plymouth-quit-wait.service
    echo "✅ Disabled Plymouth quit-wait service"
fi

if systemctl is-enabled plymouth-quit.service >/dev/null 2>&1; then
    systemctl disable plymouth-quit.service
    echo "✅ Disabled Plymouth quit service"
fi

# Update initramfs if it exists
if command -v update-initramfs >/dev/null 2>&1; then
    echo "🔄 Updating initramfs..."
    update-initramfs -u
    echo "✅ Updated initramfs"
fi

echo ""
echo "✨ Configuration completed successfully!"
echo ""
echo "📁 Backup files stored in: $BACKUP_DIR"
echo ""
echo "🔄 Changes made:"
echo "   • Added quiet boot parameters to cmdline.txt"
echo "   • Installed custom ShackMate logo as boot splash"
echo "   • Disabled rainbow splash screen in config.txt"
echo "   • Reduced boot delay to 0"
echo "   • Disabled Plymouth splash services"
echo ""
echo "⚠️  To apply changes, you need to reboot your Raspberry Pi:"
echo "   sudo reboot"
echo ""
echo "🔙 To restore original settings:"
echo "   sudo cp $BACKUP_DIR/cmdline.txt /boot/firmware/"
echo "   sudo cp $BACKUP_DIR/config.txt /boot/firmware/"
echo "   sudo reboot"
echo ""
