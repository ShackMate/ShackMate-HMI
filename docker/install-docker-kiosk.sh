#!/bin/bash

echo "🔧 Installing ShackMate Docker Kiosk System..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root (use sudo)"
    exit 1
fi

# Ensure Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

echo "📋 Setting up systemd service..."

# Copy systemd service file
cp /opt/shackmate/ShackMate/ShackMate-HMI/docker/shackmate-docker.service /etc/systemd/system/

# Reload systemd and enable the service
systemctl daemon-reload
systemctl enable shackmate-docker.service

echo "🐳 Building Docker image..."
cd /opt/shackmate/ShackMate/ShackMate-HMI/docker
docker build -t shackmate-kiosk .

echo "✅ Installation complete!"
echo ""
echo "🚀 To start the service now:"
echo "sudo systemctl start shackmate-docker"
echo ""
echo "📊 To check service status:"
echo "sudo systemctl status shackmate-docker"
echo ""
echo "📝 To view container logs:"
echo "docker logs -f shackmate-kiosk"
echo ""
echo "🔄 The service will automatically start on boot."
echo "🌐 Access ShackMate at: http://localhost or http://shackmate.router"
