#!/bin/bash

# Mstack 8-Encoder Unit Setup Script
# Installs dependencies and configures I2C for encoder reading

set -e

echo "🎛️ Setting up Mstack 8-Encoder Unit"
echo "=================================="

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)"
   exit 1
fi

echo "📦 Installing Python dependencies..."

# Update package list
apt-get update

# Install required system packages
apt-get install -y python3-pip python3-dev i2c-tools

# Install Python packages
pip3 install smbus2 websockets asyncio

echo "⚙️ Configuring I2C..."

# Enable I2C in config.txt if not already enabled
if ! grep -q "dtparam=i2c_arm=on" /boot/firmware/config.txt 2>/dev/null && ! grep -q "dtparam=i2c_arm=on" /boot/config.txt 2>/dev/null; then
    # Determine correct config file location
    if [ -f "/boot/firmware/config.txt" ]; then
        CONFIG_FILE="/boot/firmware/config.txt"
    else
        CONFIG_FILE="/boot/config.txt"
    fi
    
    echo "🔧 Enabling I2C in $CONFIG_FILE..."
    echo "" >> "$CONFIG_FILE"
    echo "# Enable I2C for Mstack 8-Encoder Unit" >> "$CONFIG_FILE"
    echo "dtparam=i2c_arm=on" >> "$CONFIG_FILE"
    echo "dtparam=i2c1=on" >> "$CONFIG_FILE"
else
    echo "✅ I2C already enabled"
fi

# Add user to i2c group
echo "👥 Adding users to i2c group..."
usermod -a -G i2c pi 2>/dev/null || true
usermod -a -G i2c $SUDO_USER 2>/dev/null || true

# Load I2C module
echo "🔌 Loading I2C kernel module..."
modprobe i2c-dev || true

# Add to modules file for permanent loading
if ! grep -q "i2c-dev" /etc/modules; then
    echo "i2c-dev" >> /etc/modules
fi

echo "🔍 I2C Configuration:"
echo "  • Bus: /dev/i2c-1 (I2C1)"
echo "  • GPIO Pins: GPIO 2 (SDA), GPIO 3 (SCL)"
echo "  • Default Address: 0x41"
echo "  • WebSocket Port: 4008"

echo ""
echo "📋 Pin Connections Required:"
echo "  • Pin 2 (5V)    → Encoder VCC"
echo "  • Pin 3 (GPIO 2/SDA) → Encoder SDA"
echo "  • Pin 5 (GPIO 3/SCL) → Encoder SCL"
echo "  • Pin 6 (GND)   → Encoder GND"

echo ""
echo "✅ Setup complete!"
echo ""
echo "🔧 Next steps:"
echo "1. Connect the 8-Encoder Unit to the Raspberry Pi"
echo "2. Reboot the Pi: sudo reboot"
echo "3. Test I2C connection: i2cdetect -y 1"
echo "4. Run the encoder reader: python3 encoder_reader.py"
echo ""
echo "🌐 WebSocket will be available at: ws://your-pi-ip:4008"
