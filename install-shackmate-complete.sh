#!/bin/bash

# ShackMate Complete Installation Script
# This script:
# 1. Disables Raspberry Pi boot splash and text
# 2. Installs and starts the UDP listener service
# 3. Sets up everything needed for ShackMate operation

set -e  # Exit on any error

echo "🏠 ShackMate Complete Installation Script"
echo "========================================="
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

echo "📦 Step 1: Boot Configuration and Custom Logo"
echo "============================================="

# Check if boot configuration is already done
if grep -q "quiet splash" /boot/firmware/cmdline.txt 2>/dev/null; then
    echo "ℹ️  Boot splash configuration already appears to be modified"
    echo "   Skipping boot configuration step..."
else
    echo "📥 Downloading and running boot splash disable script..."
    
    # Download and run boot splash disable script
    BOOT_SCRIPT_URL="https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/disable-boot-splash.sh"
    TEMP_BOOT_SCRIPT="/tmp/disable-boot-splash.sh"

    if command -v curl >/dev/null 2>&1; then
        curl -sSL "$BOOT_SCRIPT_URL" -o "$TEMP_BOOT_SCRIPT"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$BOOT_SCRIPT_URL" -O "$TEMP_BOOT_SCRIPT"
    else
        echo "❌ Error: Neither curl nor wget found. Please install one of them."
        exit 1
    fi

    # Run boot splash disable script
    chmod +x "$TEMP_BOOT_SCRIPT"
    "$TEMP_BOOT_SCRIPT"
    rm -f "$TEMP_BOOT_SCRIPT"
    echo "✅ Boot configuration completed"
fi

echo ""
echo "🎨 Custom ShackMate Logo Check"
echo "=============================="

# Check if custom logo is already installed
if systemctl is-enabled shackmate-splash.service >/dev/null 2>&1; then
    echo "ℹ️  Custom ShackMate logo service already installed and enabled"
    echo "   Skipping logo installation..."
else
    echo "📥 Installing custom ShackMate logo..."
    
    # Download and run custom logo script
    LOGO_SCRIPT_URL="https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/install-custom-logo.sh"
    TEMP_LOGO_SCRIPT="/tmp/install-custom-logo.sh"

    if command -v curl >/dev/null 2>&1; then
        curl -sSL "$LOGO_SCRIPT_URL" -o "$TEMP_LOGO_SCRIPT"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$LOGO_SCRIPT_URL" -O "$TEMP_LOGO_SCRIPT"
    else
        echo "❌ Error: curl/wget not found"
        exit 1
    fi

    # Run custom logo installer
    chmod +x "$TEMP_LOGO_SCRIPT"
    "$TEMP_LOGO_SCRIPT"
    rm -f "$TEMP_LOGO_SCRIPT"
    echo "✅ Custom logo installation completed"
fi

echo ""
echo "🌐 Step 2: Installing ShackMate UDP Listener Service"
echo "===================================================="

echo ""
echo "🌐 Step 2: ShackMate UDP Listener Service"
echo "========================================="

# Check if UDP listener service is already installed and running
if systemctl is-enabled shackmate-udp-listener.service >/dev/null 2>&1; then
    if systemctl is-active shackmate-udp-listener.service >/dev/null 2>&1; then
        echo "ℹ️  ShackMate UDP Listener service already installed and running"
        echo "   Current status: $(systemctl is-active shackmate-udp-listener.service)"
        echo "   Skipping UDP listener installation..."
    else
        echo "ℹ️  ShackMate UDP Listener service installed but not running"
        echo "   Starting service..."
        systemctl start shackmate-udp-listener.service
        echo "✅ Service started"
    fi
else
    echo "📥 Installing ShackMate UDP Listener service..."
    
    # Create installation directory
    INSTALL_DIR="/opt/shackmate"
    mkdir -p "$INSTALL_DIR"

    # Download UDP listener script
    UDP_SCRIPT_URL="https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/udp_listener.py"
    UDP_SCRIPT_PATH="$INSTALL_DIR/udp_listener.py"

    if command -v curl >/dev/null 2>&1; then
        curl -sSL "$UDP_SCRIPT_URL" -o "$UDP_SCRIPT_PATH"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$UDP_SCRIPT_URL" -O "$UDP_SCRIPT_PATH"
    else
        echo "❌ Error: curl/wget not found"
        exit 1
    fi

    # Make executable
    chmod +x "$UDP_SCRIPT_PATH"
    echo "✅ UDP listener script installed to $UDP_SCRIPT_PATH"

    # Download systemd service file
    SERVICE_URL="https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/shackmate-udp-listener.service"
    SERVICE_PATH="/etc/systemd/system/shackmate-udp-listener.service"

    if command -v curl >/dev/null 2>&1; then
        curl -sSL "$SERVICE_URL" -o "$SERVICE_PATH"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$SERVICE_URL" -O "$SERVICE_PATH"
    else
        echo "❌ Error: curl/wget not found"
        exit 1
    fi

    echo "✅ Service file installed to $SERVICE_PATH"

    # Ensure proper permissions
    chown root:root "$UDP_SCRIPT_PATH"
    chown root:root "$SERVICE_PATH"

    # Reload systemd to recognize new service
    systemctl daemon-reload
    echo "✅ Systemd daemon reloaded"

    # Enable service to start on boot
    systemctl enable shackmate-udp-listener.service
    echo "✅ ShackMate UDP Listener service enabled for auto-start"

    # Start the service
    systemctl start shackmate-udp-listener.service
    echo "✅ ShackMate UDP Listener service started"
fi

echo ""
echo "📊 UDP Listener Service Status:"
echo "==============================="
systemctl --no-pager status shackmate-udp-listener.service || echo "Service status check completed"
echo ""
echo "📊 Service Status:"
systemctl --no-pager status shackmate-udp-listener.service

echo ""
echo "🔍 Step 4: Verification"
echo "======================"

# Verify Python script can run
echo "🐍 Checking Python script syntax..."
python3 -m py_compile "$UDP_SCRIPT_PATH"
echo "✅ Python script syntax is valid"

# Check if service is running
if systemctl is-active --quiet shackmate-udp-listener.service; then
    echo "✅ ShackMate UDP Listener service is running"
else
    echo "⚠️  Service may not be running properly"
fi

# Check if port is being listened on
echo "🔌 Checking if UDP port 4210 is being listened on..."
if ss -ulnp | grep -q ":4210"; then
    echo "✅ UDP port 4210 is being listened on"
else
    echo "⚠️  UDP port 4210 may not be available"
fi

echo ""
echo "🐳 Step 3: Docker Installation and Configuration"
echo "==============================================="

# Check if Docker is already installed
if command -v docker >/dev/null 2>&1; then
    DOCKER_VERSION=$(docker --version 2>/dev/null | cut -d' ' -f3 | cut -d',' -f1)
    echo "ℹ️  Docker already installed: $DOCKER_VERSION"
    
    # Check if docker-compose is available
    if docker compose version >/dev/null 2>&1; then
        echo "ℹ️  Docker Compose already available"
        echo "   Checking Docker configuration..."
    else
        echo "⚠️  Docker Compose not available, will install..."
    fi
    
    # Check if user is in docker group
    REAL_USER=${SUDO_USER:-$(whoami)}
    if groups "$REAL_USER" | grep -q "docker"; then
        echo "ℹ️  User $REAL_USER already in docker group"
        DOCKER_ALREADY_CONFIGURED=true
    else
        echo "ℹ️  Adding user $REAL_USER to docker group..."
        usermod -aG docker "$REAL_USER"
        echo "✅ User added to docker group"
        DOCKER_ALREADY_CONFIGURED=false
    fi
else
    echo "📥 Installing Docker and Docker Compose..."
    DOCKER_ALREADY_CONFIGURED=false
fi

# Run Docker installation if needed
if [ "$DOCKER_ALREADY_CONFIGURED" != "true" ] || ! command -v docker >/dev/null 2>&1; then
    # Download and run Docker installation script
    DOCKER_SCRIPT_URL="https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/install-docker.sh"
    TEMP_DOCKER_SCRIPT="/tmp/install-docker.sh"

    if command -v curl >/dev/null 2>&1; then
        curl -sSL "$DOCKER_SCRIPT_URL" -o "$TEMP_DOCKER_SCRIPT"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$DOCKER_SCRIPT_URL" -O "$TEMP_DOCKER_SCRIPT"
    else
        echo "❌ Error: curl/wget not found"
        exit 1
    fi

    # Run Docker installation script
    chmod +x "$TEMP_DOCKER_SCRIPT"
    "$TEMP_DOCKER_SCRIPT"
    rm -f "$TEMP_DOCKER_SCRIPT"
    echo "✅ Docker installation completed"
else
    echo "✅ Docker configuration is up to date"
fi

echo ""
echo "🖥️  Step 4: Console Auto-Login Configuration (Optional)"
echo "======================================================"

echo ""
echo "🖥️  Step 4: Console Auto-Login Configuration (Optional)"
echo "======================================================"

# Check if console auto-login is already configured
if systemctl get-default | grep -q "multi-user.target" && [ -f "/etc/systemd/system/getty@tty1.service.d/autologin.conf" ]; then
    echo "ℹ️  Console auto-login already configured"
    echo "   Current boot target: $(systemctl get-default)"
    echo "   Skipping console auto-login configuration..."
    CONSOLE_CONFIGURED=true
else
    read -p "Would you like to configure console auto-login instead of desktop? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "📥 Downloading console auto-login script..."
        
        # Download and run console auto-login script
        CONSOLE_SCRIPT_URL="https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/configure-console-autologin.sh"
        TEMP_CONSOLE_SCRIPT="/tmp/configure-console-autologin.sh"
        
        if command -v curl >/dev/null 2>&1; then
            curl -sSL "$CONSOLE_SCRIPT_URL" -o "$TEMP_CONSOLE_SCRIPT"
        elif command -v wget >/dev/null 2>&1; then
            wget -q "$CONSOLE_SCRIPT_URL" -O "$TEMP_CONSOLE_SCRIPT"
        else
            echo "❌ Error: curl/wget not found"
            exit 1
        fi
        
        # Run console auto-login script (but don't auto-reboot)
        chmod +x "$TEMP_CONSOLE_SCRIPT"
        
        # Modify the script to not auto-reboot (we'll handle that at the end)
        sed -i '/read -p.*reboot now/,/fi$/d' "$TEMP_CONSOLE_SCRIPT"
        sed -i '/reboot$/d' "$TEMP_CONSOLE_SCRIPT"
        
        "$TEMP_CONSOLE_SCRIPT"
        rm -f "$TEMP_CONSOLE_SCRIPT"
        
        CONSOLE_CONFIGURED=true
        echo "✅ Console auto-login configuration completed"
    else
        echo "Skipping console auto-login configuration"
        CONSOLE_CONFIGURED=false
    fi
fi

echo ""
echo "✨ Installation completed successfully!"
echo ""
echo "📋 Summary of changes:"
echo "   • Boot splash and verbose text disabled"
echo "   • Custom ShackMate logo installed as boot splash"
echo "   • ShackMate UDP Listener installed to $INSTALL_DIR"
echo "   • Systemd service created and started"
echo "   • Service enabled for auto-start on boot"
echo "   • Listening on UDP port 4210 for router updates"
echo "   • Updates /etc/hosts with discovered router IP"
echo "   • Docker and Docker Compose installed"
echo "   • Docker configuration restored from GitHub"
if [ "$CONSOLE_CONFIGURED" = "true" ]; then
    echo "   • Console auto-login configured (boots to command line)"
fi
echo ""
echo "🔄 Next steps:"
echo "   1. Reboot to apply all changes: sudo reboot"
echo "   2. Check UDP service: sudo systemctl status shackmate-udp-listener"
echo "   3. Test Docker: docker run hello-world"
echo "   4. Start Docker services: cd ~/docker && docker-compose up -d"
echo ""
echo "🛠️  Useful commands:"
echo "   • Check UDP service: sudo systemctl status shackmate-udp-listener"
echo "   • View UDP logs: sudo journalctl -u shackmate-udp-listener -f"
echo "   • Docker status: docker ps"
echo "   • Docker logs: docker-compose logs -f"
echo "   • Stop Docker services: docker-compose down"
echo ""
