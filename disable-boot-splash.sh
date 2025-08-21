#!/bin/bash

# ShackMate Boot Splash Disable Script
# This script disables boot text, console, and sets up custom ShackMate logo

set -e

echo "🖼️ ShackMate Boot Configuration Setup"
echo "====================================="

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)"
   exit 1
fi

# Backup original files
echo "📋 Creating backups..."
cp /boot/firmware/cmdline.txt /boot/firmware/cmdline.txt.backup 2>/dev/null || cp /boot/cmdline.txt /boot/cmdline.txt.backup 2>/dev/null || true
cp /boot/firmware/config.txt /boot/firmware/config.txt.backup 2>/dev/null || cp /boot/config.txt /boot/config.txt.backup 2>/dev/null || true

# Determine correct boot directory
if [ -d "/boot/firmware" ]; then
    BOOT_DIR="/boot/firmware"
elif [ -d "/boot" ]; then
    BOOT_DIR="/boot"
else
    echo "❌ Cannot find boot directory"
    exit 1
fi

echo "📁 Using boot directory: $BOOT_DIR"

# Update cmdline.txt to disable boot text and console
echo "🔧 Configuring cmdline.txt..."
CMDLINE_FILE="$BOOT_DIR/cmdline.txt"

# Read current cmdline
CURRENT_CMDLINE=$(cat "$CMDLINE_FILE")

# Remove existing splash and console parameters
CMDLINE_CLEAN=$(echo "$CURRENT_CMDLINE" | sed -e 's/console=[^ ]*//g' -e 's/splash//g' -e 's/plymouth.enable=[^ ]*//g' -e 's/  */ /g' -e 's/^ *//' -e 's/ *$//')

# Add our parameters
NEW_CMDLINE="$CMDLINE_CLEAN console=tty3 splash quiet plymouth.enable=0 vt.global_cursor_default=0 logo.nologo loglevel=0"

echo "Original: $CURRENT_CMDLINE"
echo "New:      $NEW_CMDLINE"

# Write new cmdline
echo "$NEW_CMDLINE" > "$CMDLINE_FILE"

# Update config.txt for display and logo
echo "🔧 Configuring config.txt..."
CONFIG_FILE="$BOOT_DIR/config.txt"

# Add/update display and boot configurations
cat >> "$CONFIG_FILE" << 'EOF'

# ShackMate Boot Configuration
# Disable boot rainbow splash
disable_splash=1

# Force HDMI mode
hdmi_force_hotplug=1

# GPU memory split (increase for graphics)
gpu_mem=128

# Disable camera LED
disable_camera_led=1

# Disable boot sound
disable_audio_dither=1

# Console settings
enable_uart=0
EOF

# Download ShackMate logo if not present
echo "🖼️ Setting up ShackMate logo..."
LOGO_DIR="/usr/share/plymouth/themes/shackmate"
mkdir -p "$LOGO_DIR"

# Download logo from repository
LOGO_URL="https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/ShackMateLogo.png"
wget -q "$LOGO_URL" -O "$LOGO_DIR/logo.png" || {
    echo "⚠️ Could not download logo, creating placeholder"
    # Create a simple placeholder if download fails
    convert -size 640x480 xc:black -fill white -pointsize 48 -gravity center -annotate 0 "ShackMate" "$LOGO_DIR/logo.png" 2>/dev/null || true
}

# Create Plymouth theme for boot logo
echo "🎨 Creating Plymouth boot theme..."
cat > "$LOGO_DIR/shackmate.plymouth" << 'EOF'
[Plymouth Theme]
Name=ShackMate
Description=ShackMate Boot Theme
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/shackmate
ScriptFile=/usr/share/plymouth/themes/shackmate/shackmate.script
EOF

# Create Plymouth script
cat > "$LOGO_DIR/shackmate.script" << 'EOF'
# ShackMate Plymouth Boot Script

# Set background to black
Window.SetBackgroundTopColor(0, 0, 0);
Window.SetBackgroundBottomColor(0, 0, 0);

# Load and display logo
logo.image = Image("logo.png");
logo.sprite = Sprite(logo.image);
logo.sprite.SetPosition(Window.GetWidth() / 2 - logo.image.GetWidth() / 2, 
                       Window.GetHeight() / 2 - logo.image.GetHeight() / 2, 10000);

# Progress function (optional)
fun progress_callback(duration, progress) {
    # Simple progress indicator
    if (progress > 0.5) {
        # Could add loading text or progress bar here
    }
}
Plymouth.SetUpdateFunction(progress_callback);
EOF

# Install Plymouth theme (if Plymouth is available)
if command -v plymouth-set-default-theme &> /dev/null; then
    echo "🔧 Installing Plymouth theme..."
    update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth "$LOGO_DIR/shackmate.plymouth" 100
    plymouth-set-default-theme shackmate 2>/dev/null || true
    update-initramfs -u 2>/dev/null || true
else
    echo "⚠️ Plymouth not available, skipping theme installation"
fi

# Disable getty on tty1 to hide console
echo "🔒 Disabling console on tty1..."
systemctl mask getty@tty1.service 2>/dev/null || true

# Create directory for getty service override
mkdir -p /etc/systemd/system/getty@tty3.service.d/ 2>/dev/null || true

# Create custom getty service for tty3 (hidden)
cat > /etc/systemd/system/getty@tty3.service.d/override.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin pi --noclear %I $TERM
StandardInput=tty
StandardOutput=tty
EOF

# Set framebuffer to reduce console output
echo "📺 Configuring framebuffer console..."
echo 'FRAMEBUFFER=y' >> /etc/initramfs-tools/conf.d/splash 2>/dev/null || true

# Create a service to clear console on boot
cat > /etc/systemd/system/clear-console.service << 'EOF'
[Unit]
Description=Clear Console
After=getty.target
DefaultDependencies=false

[Service]
Type=oneshot
ExecStart=/bin/clear
ExecStart=/usr/bin/setterm -cursor off
StandardOutput=tty
TTYPath=/dev/tty1
RemainAfterExit=yes

[Install]
WantedBy=graphical.target
EOF

systemctl enable clear-console.service 2>/dev/null || true

echo "✅ Boot configuration complete!"
echo ""
echo "📋 Changes made:"
echo "  • Disabled boot text and console output"
echo "  • Set console to tty3 (hidden)"
echo "  • Added ShackMate boot logo"
echo "  • Configured quiet boot process"
echo "  • Disabled rainbow splash"
echo ""
echo "🔄 Reboot required for changes to take effect"
