#!/bin/bash

# ShackMate Pi Docker Build and Deploy Script
# Run this script directly on the Raspberry Pi

set -e

echo "🥧 ShackMate Pi Docker Build and Deploy..."
echo "🏗️ Building on ARM64 architecture for Raspberry Pi"
echo ""

# Check if we're on the Pi
if ! uname -a | grep -q "aarch64\|arm"; then
    echo "⚠️ Warning: This doesn't appear to be an ARM system"
    echo "   Current architecture: $(uname -m)"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Configuration
DOCKER_HUB_USER="${DOCKER_HUB_USER:-shackmate}"
IMAGE_NAME="shackmate-kiosk"
IMAGE_TAG="${IMAGE_TAG:-latest}"
REPO_URL="https://github.com/ShackMate/ShackMate-HMI.git"
WORK_DIR="/tmp/shackmate-build"

echo "📋 Configuration:"
echo "  • Docker Hub: ${DOCKER_HUB_USER}/${IMAGE_NAME}:${IMAGE_TAG}"
echo "  • Build directory: ${WORK_DIR}"
echo ""

# Clean up any previous build
if [ -d "$WORK_DIR" ]; then
    echo "🧹 Cleaning up previous build..."
    rm -rf "$WORK_DIR"
fi

# Clone the repository
echo "📥 Cloning ShackMate repository..."
git clone "$REPO_URL" "$WORK_DIR"
cd "$WORK_DIR/docker"

echo "✅ Repository cloned successfully"
echo ""

# Verify we have the Docker files
if [ ! -f "Dockerfile" ]; then
    echo "❌ Dockerfile not found in $(pwd)"
    exit 1
fi

echo "🔍 Docker files found:"
ls -la Dockerfile supervisord.conf entrypoint.sh *.py 2>/dev/null || true
echo ""

# Build the Docker image
echo "🔨 Building Docker image for ARM64..."
sudo docker build -t ${DOCKER_HUB_USER}/${IMAGE_NAME}:${IMAGE_TAG} .

if [ $? -eq 0 ]; then
    echo "✅ Docker image built successfully!"
else
    echo "❌ Docker build failed"
    exit 1
fi

echo ""

# Ask if user wants to push to DockerHub
read -p "🐳 Push to DockerHub? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "📤 Pushing to DockerHub..."
    
    # Check if logged in to Docker Hub
    if ! sudo docker info | grep -q "Username:"; then
        echo "🔐 Please log in to Docker Hub:"
        sudo docker login
    fi
    
    sudo docker push ${DOCKER_HUB_USER}/${IMAGE_NAME}:${IMAGE_TAG}
    echo "✅ Image pushed to DockerHub!"
else
    echo "⏭️ Skipping DockerHub push."
fi

echo ""

# Ask if user wants to run locally
read -p "🏃 Run container locally on this Pi? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🛑 Stopping any existing container..."
    sudo docker stop shackmate-kiosk 2>/dev/null || true
    sudo docker rm shackmate-kiosk 2>/dev/null || true
    
    echo "🖥️ Setting up X11 access..."
    xhost +local: 2>/dev/null || echo "⚠️ X11 setup will be handled at runtime"
    
    echo "🚀 Starting ShackMate container..."
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
    
    echo "✅ Container started!"
    echo ""
    echo "📊 Container status:"
    sudo docker ps | grep shackmate-kiosk
    
    echo ""
    echo "📝 To view logs:"
    echo "sudo docker logs -f shackmate-kiosk"
else
    echo "⏭️ Skipping local run."
fi

echo ""

# Ask if user wants to install systemd service
read -p "⚙️ Install systemd service for auto-start? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "📋 Installing systemd service..."
    
    # Copy the service file
    sudo cp shackmate-docker.service /etc/systemd/system/
    
    # Reload and enable
    sudo systemctl daemon-reload
    sudo systemctl enable shackmate-docker.service
    
    echo "✅ Systemd service installed and enabled!"
    echo ""
    echo "🔧 Service management:"
    echo "  • Start: sudo systemctl start shackmate-docker"
    echo "  • Status: sudo systemctl status shackmate-docker"
    echo "  • Logs: sudo docker logs -f shackmate-kiosk"
else
    echo "⏭️ Skipping systemd service installation."
fi

# Clean up build directory
echo ""
echo "🧹 Cleaning up build directory..."
cd /
rm -rf "$WORK_DIR"

echo ""
echo "🎉 Pi build and deploy complete!"
echo ""
echo "📋 Summary:"
echo "  • Built for: $(uname -m) architecture"
echo "  • Image: ${DOCKER_HUB_USER}/${IMAGE_NAME}:${IMAGE_TAG}"
echo "  • Location: Built and deployed on Pi"
echo ""
echo "🌐 Access ShackMate at:"
echo "  • http://localhost"
echo "  • http://$(hostname -I | awk '{print $1}')"
echo "  • http://shackmate.router (after UDP updates)"
