#!/bin/bash

# ShackMate Pi Installation Script
# This script installs ShackMate Docker kiosk on Raspberry Pi

set -e

echo "🥧 ShackMate Raspberry Pi Installation..."
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root (use sudo)"
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "🐳 Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    usermod -aG docker pi 2>/dev/null || usermod -aG docker $SUDO_USER 2>/dev/null || true
    systemctl enable docker
    systemctl start docker
    echo "✅ Docker installed!"
else
    echo "✅ Docker already installed"
fi

# Pull the latest image
echo "📥 Pulling ShackMate image from DockerHub..."
docker pull shackmate/shackmate-kiosk:latest

# Enable X11 access
echo "🖥️ Setting up X11 access..."
xhost +local: 2>/dev/null || echo "⚠️ X11 setup will be handled at runtime"

# Create systemd service
echo "📋 Setting up systemd service..."
cat > /etc/systemd/system/shackmate-docker.service << 'EOF'
[Unit]
Description=ShackMate Docker Kiosk Container
Requires=docker.service
After=docker.service graphical.target
Wants=graphical.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=/usr/bin/docker pull shackmate/shackmate-kiosk:latest
ExecStartPre=-/usr/bin/docker stop shackmate-kiosk
ExecStartPre=-/usr/bin/docker rm shackmate-kiosk
ExecStart=/usr/bin/docker run -d --name shackmate-kiosk --privileged --restart unless-stopped -p 8080:8080 -p 80:80 -e DISPLAY=:0 -v /tmp/.X11-unix:/tmp/.X11-unix:rw -v /dev:/dev -v /sys:/sys -v /proc:/proc --device-cgroup-rule='c *:* rmw' --cap-add=SYS_ADMIN --cap-add=NET_ADMIN --cap-add=SYS_TTY_CONFIG --cap-add=MKNOD --cap-add=DAC_OVERRIDE shackmate/shackmate-kiosk:latest /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
ExecStop=/usr/bin/docker stop shackmate-kiosk
ExecStopPost=/usr/bin/docker rm shackmate-kiosk
TimeoutStartSec=300
Restart=on-failure
User=root

[Install]
WantedBy=graphical.target
EOF

# Reload systemd and enable service
systemctl daemon-reload
systemctl enable shackmate-docker.service

echo "✅ Installation complete!"
echo ""
echo "🚀 To start ShackMate now:"
echo "sudo systemctl start shackmate-docker"
echo ""
echo "📊 To check status:"
echo "sudo systemctl status shackmate-docker"
echo ""
echo "📝 To view logs:"
echo "sudo docker logs -f shackmate-kiosk"
echo ""
echo "🔄 ShackMate will automatically start on boot"
echo "🌐 Access at: http://localhost or http://shackmate.router"
