#!/bin/bash

# Raspberry Pi Custom Boot Logo Script
# This script replaces the Raspberry Pi boot logo with a custom ShackMate logo
# Uses framebuffer and kernel logo replacement

set -e

echo "🎨 ShackMate Custom Boot Logo Installer"
echo "======================================="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)"
   exit 1
fi

# Download ShackMate logo
LOGO_URL="https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/ShackMateLogo.png"
TEMP_LOGO="/tmp/ShackMateLogo.png"
FINAL_LOGO="/usr/share/pixmaps/ShackMateLogo.png"

echo "📥 Downloading ShackMate logo..."
if command -v curl >/dev/null 2>&1; then
    curl -sSL "$LOGO_URL" -o "$TEMP_LOGO"
elif command -v wget >/dev/null 2>&1; then
    wget -q "$LOGO_URL" -O "$TEMP_LOGO"
else
    echo "❌ Error: Neither curl nor wget found"
    exit 1
fi

if [ ! -f "$TEMP_LOGO" ]; then
    echo "❌ Error: Failed to download logo"
    exit 1
fi

# Create directory and copy logo
mkdir -p /usr/share/pixmaps
cp "$TEMP_LOGO" "$FINAL_LOGO"
echo "✅ Logo installed to $FINAL_LOGO"

# Install packages needed for custom splash
echo "📦 Installing required packages..."
apt-get update -qq
apt-get install -y fbi imagemagick

# Convert logo to optimal size for boot (if needed)
BOOT_LOGO="/boot/firmware/splash.png"
echo "🖼️  Preparing boot splash image..."

# Get screen resolution (default to common Pi resolution if unknown)
SCREEN_WIDTH=1920
SCREEN_HEIGHT=1080

# Resize and center the logo for boot splash
convert "$FINAL_LOGO" -resize 400x400 -background black -gravity center -extent ${SCREEN_WIDTH}x${SCREEN_HEIGHT} "$BOOT_LOGO"
echo "✅ Boot splash image created at $BOOT_LOGO"

# Create boot splash service
echo "🔧 Creating boot splash service..."
cat > /etc/systemd/system/shackmate-splash.service << EOF
[Unit]
Description=ShackMate Boot Splash
DefaultDependencies=false
After=local-fs.target
Before=basic.target

[Service]
Type=oneshot
ExecStart=/usr/bin/fbi -d /dev/fb0 -T 1 -noverbose -a $BOOT_LOGO
ExecStartPost=/bin/sleep 3
ExecStop=/usr/bin/killall fbi
RemainAfterExit=yes
StandardOutput=null
StandardError=null

[Install]
WantedBy=basic.target
EOF

# Enable the splash service
systemctl daemon-reload
systemctl enable shackmate-splash.service
echo "✅ Boot splash service created and enabled"

# Update config.txt to disable rainbow splash but keep framebuffer
CONFIG_FILE="/boot/firmware/config.txt"
echo "⚙️  Updating boot configuration..."

if [ -f "$CONFIG_FILE" ]; then
    # Backup config
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak.$(date +%Y%m%d-%H%M%S)"
    
    # Check if [all] section exists
    if ! grep -q "^\[all\]" "$CONFIG_FILE"; then
        echo "" >> "$CONFIG_FILE"
        echo "[all]" >> "$CONFIG_FILE"
    fi
    
    # Disable rainbow splash
    if grep -q "^disable_splash=" "$CONFIG_FILE"; then
        sed -i 's/^disable_splash=.*/disable_splash=1/' "$CONFIG_FILE"
    else
        sed -i '/^\[all\]/a disable_splash=1' "$CONFIG_FILE"
    fi
    
    # Ensure framebuffer is enabled for our custom splash
    if grep -q "^framebuffer_width=" "$CONFIG_FILE"; then
        sed -i "s/^framebuffer_width=.*/framebuffer_width=$SCREEN_WIDTH/" "$CONFIG_FILE"
    else
        sed -i "/^\[all\]/a framebuffer_width=$SCREEN_WIDTH" "$CONFIG_FILE"
    fi
    
    if grep -q "^framebuffer_height=" "$CONFIG_FILE"; then
        sed -i "s/^framebuffer_height=.*/framebuffer_height=$SCREEN_HEIGHT/" "$CONFIG_FILE"
    else
        sed -i "/^\[all\]/a framebuffer_height=$SCREEN_HEIGHT" "$CONFIG_FILE"
    fi
    
    echo "✅ Updated $CONFIG_FILE"
else
    echo "❌ Error: $CONFIG_FILE not found"
    exit 1
fi

# Clean up
rm -f "$TEMP_LOGO"

echo ""
echo "✨ ShackMate custom boot logo installation completed!"
echo ""
echo "📋 What was installed:"
echo "   • ShackMate logo: $FINAL_LOGO"
echo "   • Boot splash image: $BOOT_LOGO"
echo "   • Boot splash service: shackmate-splash.service"
echo "   • Updated boot configuration"
echo ""
echo "🔄 To see the custom logo, reboot your Raspberry Pi:"
echo "   sudo reboot"
echo ""
echo "🔙 To remove custom logo:"
echo "   sudo systemctl disable shackmate-splash.service"
echo "   sudo rm $BOOT_LOGO"
echo "   sudo rm /etc/systemd/system/shackmate-splash.service"
echo ""
