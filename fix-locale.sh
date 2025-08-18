#!/bin/bash

# Fix Locale Settings Script
# This script fixes common locale warnings on Raspberry Pi

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

echo "Fixing Locale Settings"
echo "======================"

# Step 1: Generate the en_GB.UTF-8 locale
print_status "Generating en_GB.UTF-8 locale..."
locale-gen en_GB.UTF-8

# Step 2: Generate the en_US.UTF-8 locale as a fallback
print_status "Generating en_US.UTF-8 locale as fallback..."
locale-gen en_US.UTF-8

# Step 3: Update locale configuration
print_status "Updating locale configuration..."
update-locale LANG=en_GB.UTF-8
update-locale LC_ALL=en_GB.UTF-8

# Step 4: Set locale in /etc/locale.gen
print_status "Configuring /etc/locale.gen..."
if [ -f /etc/locale.gen ]; then
    # Uncomment en_GB.UTF-8 and en_US.UTF-8 if they're commented out
    sed -i '/^# en_GB.UTF-8 UTF-8/s/^# //' /etc/locale.gen
    sed -i '/^# en_US.UTF-8 UTF-8/s/^# //' /etc/locale.gen
    
    # Add them if they don't exist
    if ! grep -q "^en_GB.UTF-8 UTF-8" /etc/locale.gen; then
        echo "en_GB.UTF-8 UTF-8" >> /etc/locale.gen
    fi
    if ! grep -q "^en_US.UTF-8 UTF-8" /etc/locale.gen; then
        echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    fi
    
    print_success "Updated /etc/locale.gen"
else
    print_warning "/etc/locale.gen not found, creating it..."
    cat > /etc/locale.gen << EOF
en_GB.UTF-8 UTF-8
en_US.UTF-8 UTF-8
EOF
fi

# Step 5: Regenerate locales
print_status "Regenerating all locales..."
locale-gen

# Step 6: Set default locale in /etc/default/locale
print_status "Setting default locale in /etc/default/locale..."
cat > /etc/default/locale << EOF
LANG=en_GB.UTF-8
LC_ALL=en_GB.UTF-8
LANGUAGE=en_GB:en
EOF

# Step 7: Update dpkg locale configuration
print_status "Configuring dpkg locale settings..."
if command -v dpkg-reconfigure >/dev/null 2>&1; then
    echo 'locales locales/locales_to_be_generated multiselect en_GB.UTF-8 UTF-8, en_US.UTF-8 UTF-8' | debconf-set-selections
    echo 'locales locales/default_environment_locale select en_GB.UTF-8' | debconf-set-selections
    dpkg-reconfigure -f noninteractive locales
    print_success "Reconfigured locales via dpkg"
fi

# Step 8: Export locale variables for current session
print_status "Setting locale variables for current session..."
export LANG=en_GB.UTF-8
export LC_ALL=en_GB.UTF-8
export LANGUAGE=en_GB:en

# Step 9: Add locale settings to profile
print_status "Adding locale settings to /etc/profile..."
if ! grep -q "export LANG=en_GB.UTF-8" /etc/profile; then
    cat >> /etc/profile << EOF

# Locale settings
export LANG=en_GB.UTF-8
export LC_ALL=en_GB.UTF-8
export LANGUAGE=en_GB:en
EOF
    print_success "Added locale settings to /etc/profile"
fi

# Step 10: Show current locale status
echo ""
print_success "Locale configuration completed!"
echo ""
echo "Current locale settings:"
echo "========================"
locale
echo ""
echo "Available locales:"
echo "=================="
locale -a | grep -E "(en_GB|en_US)" || echo "Locales are being generated..."

echo ""
print_success "Locale fix completed!"
echo ""
echo "Next steps:"
echo "  1. Logout and login again for changes to take effect"
echo "  2. Or run: source /etc/profile"
echo "  3. Or reboot: sudo reboot"
echo ""
print_warning "Note: Some processes may still show locale warnings until you logout/login or reboot"
