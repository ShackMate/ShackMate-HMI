#!/bin/bash

# Emergency Boot Recovery Script
# Use this if the enhanced silent boot caused boot issues
# This restores safer boot parameters

set -e

echo "🚨 Emergency Boot Recovery"
echo "========================="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)"
   exit 1
fi

# Create backup
BACKUP_DIR="/boot/firmware/backup-recovery-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "📦 Creating backup before recovery..."
if [ -f /boot/firmware/cmdline.txt ]; then
    cp /boot/firmware/cmdline.txt "$BACKUP_DIR/"
    echo "✅ Backed up current cmdline.txt"
fi

if [ -f /boot/firmware/config.txt ]; then
    cp /boot/firmware/config.txt "$BACKUP_DIR/"
    echo "✅ Backed up current config.txt"
fi

echo ""

# Restore safer cmdline.txt
echo "🔧 Restoring safer boot parameters..."
if [ -f /boot/firmware/cmdline.txt ]; then
    # Read the current cmdline
    CMDLINE=$(cat /boot/firmware/cmdline.txt)
    
    # Remove problematic silent boot parameters
    CMDLINE=$(echo "$CMDLINE" | sed 's/loglevel=0/loglevel=3/' | sed 's/console=tty3//' | sed 's/rd\.systemd\.show_status=false//' | sed 's/rd\.udev\.log_priority=3//' | sed 's/plymouth\.ignore-serial-consoles//')
    
    # Clean up extra spaces
    CMDLINE=$(echo "$CMDLINE" | sed 's/  */ /g' | sed 's/^ *//' | sed 's/ *$//')
    
    # Ensure we have basic quiet boot but not completely silent
    if ! echo "$CMDLINE" | grep -q "quiet"; then
        CMDLINE="$CMDLINE quiet"
    fi
    
    if ! echo "$CMDLINE" | grep -q "loglevel="; then
        CMDLINE="$CMDLINE loglevel=3"
    fi
    
    # Write the safer cmdline
    echo "$CMDLINE" > /boot/firmware/cmdline.txt
    echo "✅ Restored safer cmdline.txt parameters"
else
    echo "❌ Error: /boot/firmware/cmdline.txt not found"
    exit 1
fi

# Re-enable getty services that might have been disabled
echo "🔄 Re-enabling essential services..."

if systemctl list-unit-files | grep -q "getty@tty1.service"; then
    systemctl enable getty@tty1.service
    echo "✅ Re-enabled getty@tty1.service"
fi

# Unmask services that might have been masked
if systemctl is-masked console-setup.service >/dev/null 2>&1; then
    systemctl unmask console-setup.service
    echo "✅ Unmasked console-setup.service"
fi

# Update initramfs
echo "🔄 Updating initramfs..."
update-initramfs -u

echo ""
echo "✅ Emergency boot recovery completed!"
echo ""
echo "📁 Current settings backed up to: $BACKUP_DIR"
echo ""
echo "🔄 Changes made:"
echo "   • Restored loglevel=3 (minimal but functional logging)"
echo "   • Removed console redirection"
echo "   • Re-enabled getty@tty1"
echo "   • Unmasked essential services"
echo "   • Updated initramfs"
echo ""
echo "⚠️  Reboot now to test recovery:"
echo "   sudo reboot"
echo ""
echo "📝 Current cmdline.txt:"
cat /boot/firmware/cmdline.txt
echo ""
