#!/bin/bash

# Fix Chromium Launch Issues Script
# Addresses potential issues caused by boot customization scripts

set -e

echo "🌐 Chromium Launch Fix Script"
echo "============================"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)"
   exit 1
fi

# Create backup
BACKUP_DIR="/boot/firmware/backup-chromium-fix-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "📦 Creating backup..."
if [ -f /boot/firmware/cmdline.txt ]; then
    cp /boot/firmware/cmdline.txt "$BACKUP_DIR/"
    echo "✅ Backed up cmdline.txt"
fi

echo ""

# Fix console redirection that might interfere with display
echo "🔧 Fixing console and display issues..."
if [ -f /boot/firmware/cmdline.txt ]; then
    # Remove console redirection that can interfere with desktop
    sed -i 's/console=tty3//g' /boot/firmware/cmdline.txt
    sed -i 's/console=ttyS0//g' /boot/firmware/cmdline.txt
    
    # Clean up extra spaces
    sed -i 's/  */ /g' /boot/firmware/cmdline.txt
    sed -i 's/^ *//' /boot/firmware/cmdline.txt
    sed -i 's/ *$//' /boot/firmware/cmdline.txt
    
    echo "✅ Removed console redirection from cmdline.txt"
else
    echo "❌ Error: /boot/firmware/cmdline.txt not found"
    exit 1
fi

# Re-enable essential services for desktop environment
echo "🔄 Re-enabling essential services..."

# Re-enable getty@tty1 (needed for proper console/desktop interaction)
if systemctl list-unit-files | grep -q "getty@tty1.service"; then
    systemctl enable getty@tty1.service
    echo "✅ Re-enabled getty@tty1.service"
fi

# Unmask console-setup (needed for proper keyboard/console setup)
if systemctl is-masked console-setup.service >/dev/null 2>&1; then
    systemctl unmask console-setup.service
    echo "✅ Unmasked console-setup.service"
fi

# Ensure display manager services are enabled (common ones)
display_managers=("lightdm.service" "gdm.service" "sddm.service" "lxdm.service")
for dm in "${display_managers[@]}"; do
    if systemctl list-unit-files | grep -q "^$dm"; then
        if ! systemctl is-enabled "$dm" >/dev/null 2>&1; then
            systemctl enable "$dm" 2>/dev/null && echo "✅ Enabled $dm" || true
        fi
    fi
done

# Check and fix GPU memory allocation in config.txt
echo "🎮 Checking GPU configuration..."
CONFIG_FILE="/boot/firmware/config.txt"

if [ -f "$CONFIG_FILE" ]; then
    # Ensure adequate GPU memory for Chromium
    if ! grep -q "^gpu_mem=" "$CONFIG_FILE"; then
        if ! grep -q "^\[all\]" "$CONFIG_FILE"; then
            echo "" >> "$CONFIG_FILE"
            echo "[all]" >> "$CONFIG_FILE"
        fi
        sed -i '/^\[all\]/a gpu_mem=128' "$CONFIG_FILE"
        echo "✅ Set GPU memory to 128MB"
    else
        # Update existing gpu_mem if it's too low
        current_gpu_mem=$(grep "^gpu_mem=" "$CONFIG_FILE" | cut -d'=' -f2)
        if [ "$current_gpu_mem" -lt 64 ]; then
            sed -i 's/^gpu_mem=.*/gpu_mem=128/' "$CONFIG_FILE"
            echo "✅ Updated GPU memory to 128MB"
        fi
    fi
    
    # Ensure KMS (kernel mode setting) is enabled
    if ! grep -q "^dtoverlay=vc4-kms-v3d" "$CONFIG_FILE"; then
        if ! grep -q "^\[all\]" "$CONFIG_FILE"; then
            echo "" >> "$CONFIG_FILE"
            echo "[all]" >> "$CONFIG_FILE"
        fi
        sed -i '/^\[all\]/a dtoverlay=vc4-kms-v3d' "$CONFIG_FILE"
        echo "✅ Enabled VC4 KMS graphics driver"
    fi
fi

# Update initramfs
echo "🔄 Updating initramfs..."
update-initramfs -u

echo ""
echo "✅ Chromium launch fix completed!"
echo ""
echo "📁 Backup stored in: $BACKUP_DIR"
echo ""
echo "🔄 Changes made:"
echo "   • Removed console redirection from boot parameters"
echo "   • Re-enabled getty@tty1.service"
echo "   • Unmasked console-setup.service"
echo "   • Ensured adequate GPU memory allocation"
echo "   • Enabled KMS graphics driver"
echo "   • Updated initramfs"
echo ""
echo "⚠️  Reboot required to apply all changes:"
echo "   sudo reboot"
echo ""
echo "🚀 After reboot, try launching Chromium:"
echo "   chromium-browser --no-sandbox"
echo ""
echo "🔍 To diagnose further issues:"
echo "   curl -sSL https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/chromium-diagnostics.sh | bash"
echo ""
