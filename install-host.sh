#!/bin/bash
# ShackMate HMI Host Installation Script
# Run with: bash install-host.sh

set -e

echo "🚀 ShackMate HMI Host Installation Starting..."
echo "================================================="

# Update system
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install required packages
echo "📦 Installing required packages..."
sudo apt install -y apache2 php libapache2-mod-php chromium xinit xterm python3 curl unzip

# Configure Apache
echo "⚙️ Configuring Apache..."
sudo a2enmod rewrite
echo "ServerName localhost" | sudo tee -a /etc/apache2/apache2.conf
echo "DirectoryIndex index.php index.html" | sudo tee -a /etc/apache2/apache2.conf

# Download and install web files
echo "📥 Installing ShackMate web interface..."
cd /tmp
curl -L https://github.com/ShackMate/ShackMate-HMI/archive/main.zip -o shackmate.zip
unzip -q shackmate.zip
sudo rm -f /var/www/html/index.html  # Remove default Apache page
sudo cp -r ShackMate-HMI-main/docker/web/* /var/www/html/
sudo chown -R www-data:www-data /var/www/html

# Install UDP listener
echo "📡 Installing UDP listener..."
sudo cp ShackMate-HMI-main/docker/udp_listener.py /usr/local/bin/
sudo chmod +x /usr/local/bin/udp_listener.py
sudo mkdir -p /var/log/shackmate
sudo chown root:root /var/log/shackmate

# Create systemd services
echo "🔧 Creating systemd services..."

# UDP Listener Service
sudo tee /etc/systemd/system/shackmate-udp.service > /dev/null << 'EOF'
[Unit]
Description=ShackMate UDP Listener
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/usr/local/bin
ExecStart=/usr/bin/python3 /usr/local/bin/udp_listener.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Browser Kiosk Service
sudo tee /etc/systemd/system/shackmate-kiosk.service > /dev/null << 'EOF'
[Unit]
Description=ShackMate Kiosk Browser
After=apache2.service
Wants=apache2.service

[Service]
Type=simple
User=pi
Environment=DISPLAY=:0
ExecStart=/usr/bin/startx /usr/bin/chromium-browser --kiosk --noerrdialogs --disable-infobars --no-first-run --disable-translate http://localhost -- :0 vt1
Restart=always
RestartSec=5

[Install]
WantedBy=graphical.target
EOF

# Set system to graphical target
echo "🖥️ Configuring system for auto-start..."
sudo systemctl set-default graphical.target

# Enable and start services
echo "🚀 Enabling services..."
sudo systemctl daemon-reload
sudo systemctl enable apache2
sudo systemctl enable shackmate-udp
sudo systemctl enable shackmate-kiosk

sudo systemctl start apache2
sudo systemctl start shackmate-udp

echo ""
echo "✅ ShackMate HMI Installation Complete!"
echo "================================================="
echo "🌐 Web interface: http://localhost"
echo "📡 UDP listener: Running on port 8080"
echo "🖥️ Browser kiosk: Will start on next reboot"
echo ""
echo "🔄 Reboot now to start kiosk: sudo reboot"
echo ""
echo "🔧 Manage services:"
echo "  sudo systemctl restart shackmate-kiosk"
echo "  sudo systemctl restart shackmate-udp"
echo "  sudo systemctl restart apache2"
