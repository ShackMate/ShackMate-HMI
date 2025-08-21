#!/bin/bash

# Quick Pi Deploy Script - for when code is already on Pi
# Run this in the docker directory on the Pi

set -e

echo "🥧 Quick Pi Deploy - Building from existing code..."
echo ""

# Check if we're in the right directory
if [ ! -f "Dockerfile" ]; then
    echo "❌ Dockerfile not found. Please run this script from the docker directory"
    echo "   Expected location: /path/to/ShackMate-HMI/docker/"
    exit 1
fi

# Configuration
DOCKER_HUB_USER="${DOCKER_HUB_USER:-n4ldr}"
IMAGE_NAME="shackmate-kiosk"
IMAGE_TAG="${IMAGE_TAG:-latest}"

echo "📋 Building: ${DOCKER_HUB_USER}/${IMAGE_NAME}:${IMAGE_TAG}"
echo "📁 Working directory: $(pwd)"
echo ""

# Show what files we have
echo "🔍 Docker files in current directory:"
ls -la Dockerfile supervisord.conf entrypoint.sh *.py *.sh 2>/dev/null || true
echo ""

# Build the image
echo "🔨 Building Docker image..."
sudo docker build -t ${DOCKER_HUB_USER}/${IMAGE_NAME}:${IMAGE_TAG} .

if [ $? -ne 0 ]; then
    echo "❌ Docker build failed"
    exit 1
fi

echo "✅ Build successful!"
echo ""

# Stop existing container
echo "🛑 Stopping existing container..."
sudo docker stop shackmate-kiosk 2>/dev/null || true
sudo docker rm shackmate-kiosk 2>/dev/null || true

# Set up X11
echo "🖥️ Setting up display access..."
export DISPLAY=:0
xhost +local: 2>/dev/null || echo "⚠️ X11 will be configured at runtime"

# Run the container
echo "🚀 Starting new container..."
sudo docker run -d \
    --name shackmate-kiosk \
    --privileged \
    --restart unless-stopped \
    -p 8080:8080 \
    -p 80:80 \
    -e DISPLAY=:0 \
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
    -v /dev:/dev \
    -v /sys:/sys \
    -v /proc:/proc \
    --device-cgroup-rule='c *:* rmw' \
    --cap-add=SYS_ADMIN \
    --cap-add=NET_ADMIN \
    --cap-add=SYS_TTY_CONFIG \
    --cap-add=MKNOD \
    --cap-add=DAC_OVERRIDE \
    ${DOCKER_HUB_USER}/${IMAGE_NAME}:${IMAGE_TAG} \
    /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf

echo ""
echo "✅ Container started!"
echo ""

# Show status
echo "📊 Container status:"
sudo docker ps | grep shackmate-kiosk

echo ""
echo "📝 Useful commands:"
echo "  • View logs: sudo docker logs -f shackmate-kiosk"
echo "  • Container shell: sudo docker exec -it shackmate-kiosk bash"
echo "  • Restart: sudo docker restart shackmate-kiosk"
echo "  • Stop: sudo docker stop shackmate-kiosk"
echo ""
echo "🌐 Access ShackMate at:"
echo "  • http://localhost"
echo "  • http://$(hostname -I | awk '{print $1}' 2>/dev/null || echo 'PI_IP')"
echo ""
echo "🔍 Check if services are running:"
echo "sudo docker exec shackmate-kiosk supervisorctl status"
