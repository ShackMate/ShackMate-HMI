#!/bin/bash

# ShackMate Touchscreen Fix Script
# This script fixes touchscreen issues that may occur after boot configuration changes

echo "🖱️ ShackMate Touchscreen Fix Script"
echo "==================================="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)"
   exit 1
fi

# Backup current config
CONFIG_FILE="/boot/firmware/config.txt"
BACKUP_FILE="${CONFIG_FILE}.touchscreen-backup-$(date +%Y%m%d-%H%M%S)"

if [ -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_FILE" "$BACKUP_FILE"
    echo "✅ Created backup: $BACKUP_FILE"
else
    echo "❌ Error: $CONFIG_FILE not found"
    exit 1
fi

echo "🔧 Fixing touchscreen configuration..."

# Remove potentially problematic framebuffer settings
sed -i '/^framebuffer_width=/d' "$CONFIG_FILE"
sed -i '/^framebuffer_height=/d' "$CONFIG_FILE"

# Add touchscreen-friendly settings
if ! grep -q "^\[all\]" "$CONFIG_FILE"; then
    echo "" >> "$CONFIG_FILE"
    echo "[all]" >> "$CONFIG_FILE"
fi

# Add proper display settings for touchscreen
if ! grep -q "^hdmi_group=" "$CONFIG_FILE"; then
    sed -i '/^\[all\]/a hdmi_group=2' "$CONFIG_FILE"
fi

if ! grep -q "^hdmi_mode=" "$CONFIG_FILE"; then
    sed -i '/^\[all\]/a hdmi_mode=87' "$CONFIG_FILE"
fi

if ! grep -q "^hdmi_cvt=" "$CONFIG_FILE"; then
    sed -i '/^\[all\]/a hdmi_cvt=1024 600 60 6 0 0 0' "$CONFIG_FILE"
fi

if ! grep -q "^hdmi_drive=" "$CONFIG_FILE"; then
    sed -i '/^\[all\]/a hdmi_drive=1' "$CONFIG_FILE"
fi

# Ensure display is forced on
if ! grep -q "^hdmi_force_hotplug=" "$CONFIG_FILE"; then
    sed -i '/^\[all\]/a hdmi_force_hotplug=1' "$CONFIG_FILE"
fi

# Add touchscreen calibration settings if needed
if ! grep -q "^display_rotate=" "$CONFIG_FILE"; then
    sed -i '/^\[all\]/a display_rotate=0' "$CONFIG_FILE"
fi

echo "✅ Updated display configuration for touchscreen compatibility"

# Check if touchscreen overlay is needed
if ! grep -q "^dtoverlay=.*touch" "$CONFIG_FILE"; then
    echo "ℹ️  Adding common touchscreen overlays..."
    echo "# Touchscreen overlays" >> "$CONFIG_FILE"
    echo "dtoverlay=vc4-fkms-v3d" >> "$CONFIG_FILE"
    echo "# Uncomment the appropriate line for your touchscreen:" >> "$CONFIG_FILE"
    echo "# dtoverlay=rpi-ft5406" >> "$CONFIG_FILE"
    echo "# dtoverlay=waveshare35a" >> "$CONFIG_FILE"
    echo "# dtoverlay=waveshare35b-v2" >> "$CONFIG_FILE"
fi

echo ""
echo "✨ Touchscreen fix completed!"
echo ""
echo "📋 Changes made:"
echo "   • Removed potentially problematic framebuffer settings"
echo "   • Added proper HDMI configuration for 1024x600 display"
echo "   • Added touchscreen-friendly display settings"
echo "   • Enabled display force hotplug"
echo ""
echo "🔄 Please reboot to apply changes:"
echo "   sudo reboot"
echo ""
echo "🔙 To restore original settings:"
echo "   sudo cp $BACKUP_FILE $CONFIG_FILE"
echo "   sudo reboot"
echo ""
