#!/bin/bash

# Configure Console Auto-Login Script
# This script configures Raspberry Pi to boot to console with automatic login
# instead of desktop environment

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

# Get the actual user (in case script is run with sudo)
REAL_USER=${SUDO_USER:-$(whoami)}
if [ "$REAL_USER" = "root" ]; then
    REAL_USER="pi"  # Default to pi user
fi

print_status "Configuring console auto-login for user: $REAL_USER"

echo "Starting Console Auto-Login Configuration..."
echo "=================================================="

# Step 1: Set boot target to console (multi-user.target)
print_status "Setting boot target to console mode..."
systemctl set-default multi-user.target
if [ $? -eq 0 ]; then
    print_success "Boot target set to console mode"
else
    print_error "Failed to set boot target"
    exit 1
fi

# Step 2: Create auto-login configuration directory
print_status "Creating auto-login configuration..."
AUTO_LOGIN_DIR="/etc/systemd/system/getty@tty1.service.d"
mkdir -p "$AUTO_LOGIN_DIR"

# Step 3: Create auto-login configuration file
AUTO_LOGIN_CONF="$AUTO_LOGIN_DIR/autologin.conf"
print_status "Writing auto-login configuration to $AUTO_LOGIN_CONF..."

cat > "$AUTO_LOGIN_CONF" << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $REAL_USER --noclear %I \$TERM
EOF

if [ -f "$AUTO_LOGIN_CONF" ]; then
    print_success "Auto-login configuration created"
else
    print_error "Failed to create auto-login configuration"
    exit 1
fi

# Step 4: Reload systemd daemon
print_status "Reloading systemd daemon..."
systemctl daemon-reload
if [ $? -eq 0 ]; then
    print_success "Systemd daemon reloaded"
else
    print_error "Failed to reload systemd daemon"
    exit 1
fi

# Step 5: Enable getty service
print_status "Enabling getty service..."
systemctl enable getty@tty1.service
if [ $? -eq 0 ]; then
    print_success "Getty service enabled"
else
    print_warning "Getty service may already be enabled"
fi

# Step 6: Disable desktop auto-login (if it exists)
print_status "Disabling desktop auto-login..."
LIGHTDM_CONF="/etc/lightdm/lightdm.conf"
if [ -f "$LIGHTDM_CONF" ]; then
    # Comment out any existing autologin-user lines
    sed -i 's/^autologin-user=/#autologin-user=/' "$LIGHTDM_CONF"
    print_success "Desktop auto-login disabled"
else
    print_status "No desktop auto-login configuration found"
fi

# Step 7: Create a backup script for reverting changes
REVERT_SCRIPT="/home/$REAL_USER/revert-to-desktop.sh"
print_status "Creating revert script at $REVERT_SCRIPT..."

cat > "$REVERT_SCRIPT" << 'EOF'
#!/bin/bash
# Script to revert back to desktop auto-login

echo "🔄 Reverting to desktop auto-login..."

# Set boot target back to desktop
sudo systemctl set-default graphical.target

# Remove console auto-login configuration
sudo rm -f /etc/systemd/system/getty@tty1.service.d/autologin.conf

# Enable desktop auto-login
if [ -f /etc/lightdm/lightdm.conf ]; then
    sudo sed -i 's/^#autologin-user=pi/autologin-user=pi/' /etc/lightdm/lightdm.conf
    # If the line doesn't exist, add it
    if ! grep -q "^autologin-user=" /etc/lightdm/lightdm.conf; then
        sudo sed -i '/^\[Seat:\*\]/a autologin-user=pi' /etc/lightdm/lightdm.conf
    fi
fi

# Reload systemd
sudo systemctl daemon-reload

echo "✅ Reverted to desktop auto-login. Reboot to take effect."
echo "   Run: sudo reboot"
EOF

chmod +x "$REVERT_SCRIPT"
chown "$REAL_USER:$REAL_USER" "$REVERT_SCRIPT"
print_success "Revert script created at $REVERT_SCRIPT"

# Step 8: Show current configuration
echo ""
echo "Configuration Summary:"
echo "========================"
echo "• Boot Target: $(systemctl get-default)"
echo "• Auto-login User: $REAL_USER"
echo "• Auto-login Config: $AUTO_LOGIN_CONF"
echo "• Revert Script: $REVERT_SCRIPT"

echo ""
print_success "Console auto-login configuration completed!"
echo ""
echo "Next Steps:"
echo "  1. Reboot your Raspberry Pi: sudo reboot"
echo "  2. The system will boot to console and automatically log in as '$REAL_USER'"
echo "  3. To revert to desktop auto-login, run: $REVERT_SCRIPT"
echo ""
print_warning "Note: After reboot, you'll be at the command line instead of desktop"
echo "      Your Docker containers and services will still work normally"

# Ask if user wants to reboot now
echo ""
read -p "Would you like to reboot now to apply changes? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Rebooting in 5 seconds... (Ctrl+C to cancel)"
    sleep 5
    reboot
else
    echo "Remember to reboot later to apply the changes: sudo reboot"
fi
