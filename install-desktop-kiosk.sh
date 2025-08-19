#!/bin/bash

# Install Desktop Environment for Touchscreen Kiosk
echo "🖥️ Installing Desktop Environment for Touchscreen Kiosk..."

ssh sm@10.146.1.254 << 'EOF'
    echo "📦 Installing minimal desktop environment..."
    
    # Install a lightweight desktop environment
    sudo apt-get install -y --no-install-recommends \
        task-lxde-desktop \
        lightdm \
        lightdm-gtk-greeter \
        xserver-xorg-input-libinput
    
    echo "🔧 Configuring automatic login to desktop..."
    
    # Configure LightDM for auto-login
    sudo mkdir -p /etc/lightdm/lightdm.conf.d
    sudo tee /etc/lightdm/lightdm.conf.d/01-autologin.conf > /dev/null << 'LIGHTDM'
[Seat:*]
autologin-user=sm
autologin-user-timeout=0
user-session=LXDE
LIGHTDM
    
    # Set system to boot to graphical target
    sudo systemctl set-default graphical.target
    
    echo "🎯 Creating desktop autostart for kiosk mode..."
    
    # Create autostart directory
    mkdir -p ~/.config/autostart
    
    # Create autostart entry for kiosk mode
    cat > ~/.config/autostart/shackmate-kiosk.desktop << 'DESKTOP'
[Desktop Entry]
Type=Application
Name=ShackMate Kiosk
Exec=/home/sm/start-kiosk-simple.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
DESKTOP
    
    # Also create a desktop shortcut for manual control
    cat > ~/Desktop/ShackMate-Control.desktop << 'CONTROL'
[Desktop Entry]
Version=1.0
Type=Application
Name=ShackMate Control
Comment=Start/Stop ShackMate Kiosk
Exec=lxterminal -e "bash -c 'echo Choose an option:; echo 1. Start Kiosk; echo 2. Stop Kiosk; echo 3. Status; read -p \"Enter choice (1-3): \" choice; case \$choice in 1) ~/start-kiosk-simple.sh;; 2) ~/stop-kiosk.sh;; 3) ~/kiosk-status.sh;; *) echo Invalid choice;; esac; read -p \"Press Enter to close...\"'"
Icon=applications-internet
Terminal=false
Categories=Network;
CONTROL
    
    chmod +x ~/Desktop/ShackMate-Control.desktop
    
    echo ""
    echo "✅ Desktop environment setup complete!"
    echo ""
    echo "📋 Configuration Summary:"
    echo "   ✅ LXDE desktop environment installed"
    echo "   ✅ Auto-login to desktop configured"
    echo "   ✅ Graphical boot target set"
    echo "   ✅ Kiosk auto-start configured"
    echo "   ✅ Desktop control shortcut created"
    echo ""
    echo "🔄 Reboot required to activate desktop mode:"
    echo "   sudo reboot"
    echo ""
    echo "🎯 After reboot:"
    echo "   - Pi will boot to desktop automatically"
    echo "   - ShackMate kiosk will auto-start in full screen"
    echo "   - Touchscreen will show the web interface"
    echo "   - Use desktop shortcut for manual control"

EOF

echo ""
echo "🎉 Desktop environment installation complete!"
echo ""
echo "📋 Final Steps:"
echo "   1. Reboot the Pi: ssh sm@10.146.1.254 'sudo reboot'"
echo "   2. Wait 2-3 minutes for desktop to load"
echo "   3. Touchscreen should show ShackMate interface in full screen"
echo "   4. If needed, use the desktop control icon for manual start/stop"
echo ""
echo "💡 The Pi will now:"
echo "   ✅ Boot to desktop automatically"
echo "   ✅ Auto-login as user 'sm'"
echo "   ✅ Launch kiosk mode on startup"
echo "   ✅ Display on the physical touchscreen"
