#!/bin/bash

# Enhanced Silent Boot Script
# This script completely suppresses all console output during boot
# Use this if you're still seeing console text during boot

set -e

echo "🔇 Enhanced Silent Boot Configuration"
echo "===================================="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)"
   exit 1
fi

# Create backup
BACKUP_DIR="/boot/firmware/backup-silent-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "📦 Creating backup..."
if [ -f /boot/firmware/cmdline.txt ]; then
    cp /boot/firmware/cmdline.txt "$BACKUP_DIR/"
    echo "✅ Backed up cmdline.txt to $BACKUP_DIR"
fi

if [ -f /boot/firmware/config.txt ]; then
    cp /boot/firmware/config.txt "$BACKUP_DIR/"
    echo "✅ Backed up config.txt to $BACKUP_DIR"
fi

echo ""

# Modify cmdline.txt for completely silent boot
echo "🔇 Configuring completely silent boot..."
if [ -f /boot/firmware/cmdline.txt ]; then
    # Read the current cmdline
    CMDLINE=$(cat /boot/firmware/cmdline.txt)
    
    # Remove any existing parameters that might show console output
    CMDLINE=$(echo "$CMDLINE" | sed 's/quiet//g' | sed 's/splash//g' | sed 's/loglevel=[0-9]//g' | sed 's/logo\.nologo//g' | sed 's/vt\.global_cursor_default=[0-9]//g' | sed 's/console=[a-zA-Z0-9,]*//g' | sed 's/plymouth\.ignore-serial-consoles//g' | sed 's/rd\.systemd\.show_status=[a-z]*//g' | sed 's/rd\.udev\.log_priority=[0-9]*//g')
    
    # Clean up extra spaces
    CMDLINE=$(echo "$CMDLINE" | sed 's/  */ /g' | sed 's/^ *//' | sed 's/ *$//')
    
    # Add parameters for completely silent boot
    NEW_CMDLINE="$CMDLINE quiet splash loglevel=0 logo.nologo vt.global_cursor_default=0 console=tty3 plymouth.ignore-serial-consoles rd.systemd.show_status=false rd.udev.log_priority=3"
    
    # Write the new cmdline
    echo "$NEW_CMDLINE" > /boot/firmware/cmdline.txt
    echo "✅ Updated cmdline.txt with silent boot parameters"
else
    echo "❌ Error: /boot/firmware/cmdline.txt not found"
    exit 1
fi

# Update config.txt for additional silence
echo "⚙️  Updating config.txt for silent boot..."
CONFIG_FILE="/boot/firmware/config.txt"

if [ -f "$CONFIG_FILE" ]; then
    # Check if [all] section exists
    if ! grep -q "^\[all\]" "$CONFIG_FILE"; then
        echo "" >> "$CONFIG_FILE"
        echo "[all]" >> "$CONFIG_FILE"
    fi
    
    # Disable all splash screens and boot messages
    if grep -q "^disable_splash=" "$CONFIG_FILE"; then
        sed -i 's/^disable_splash=.*/disable_splash=1/' "$CONFIG_FILE"
    else
        sed -i '/^\[all\]/a disable_splash=1' "$CONFIG_FILE"
    fi
    
    # Reduce boot delay
    if grep -q "^boot_delay=" "$CONFIG_FILE"; then
        sed -i 's/^boot_delay=.*/boot_delay=0/' "$CONFIG_FILE"
    else
        sed -i '/^\[all\]/a boot_delay=0' "$CONFIG_FILE"
    fi
    
    # Disable rainbow splash
    if grep -q "^disable_splash=" "$CONFIG_FILE"; then
        # Already handled above
        :
    else
        sed -i '/^\[all\]/a disable_splash=1' "$CONFIG_FILE"
    fi
    
    echo "✅ Updated $CONFIG_FILE for silent boot"
else
    echo "❌ Error: $CONFIG_FILE not found"
    exit 1
fi

# Disable additional services that might show console output
echo "🚫 Disabling additional verbose services..."

# Disable getty on tty1 (where console messages appear)
if systemctl is-enabled getty@tty1.service >/dev/null 2>&1; then
    systemctl disable getty@tty1.service
    echo "✅ Disabled getty@tty1.service"
fi

# Mask console-setup service if it exists (reduces boot messages)
if systemctl list-unit-files | grep -q console-setup; then
    systemctl mask console-setup.service
    echo "✅ Masked console-setup.service"
fi

# Update initramfs
echo "🔄 Updating initramfs..."
update-initramfs -u

echo ""
echo "✨ Enhanced silent boot configuration completed!"
echo ""
echo "📁 Backup files stored in: $BACKUP_DIR"
echo ""
echo "🔄 Changes made:"
echo "   • Set loglevel=0 (completely silent kernel)"
echo "   • Redirected console to tty3 (not visible)"
echo "   • Added systemd silence parameters"
echo "   • Disabled getty on tty1"
echo "   • Masked verbose services"
echo "   • Updated initramfs"
echo ""
echo "⚠️  To apply changes, reboot your Raspberry Pi:"
echo "   sudo reboot"
echo ""
echo "🔙 To restore original settings:"
echo "   sudo cp $BACKUP_DIR/cmdline.txt /boot/firmware/"
echo "   sudo cp $BACKUP_DIR/config.txt /boot/firmware/"
echo "   sudo systemctl enable getty@tty1.service"
echo "   sudo systemctl unmask console-setup.service"
echo "   sudo reboot"
echo ""
