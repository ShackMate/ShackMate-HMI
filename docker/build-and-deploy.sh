#!/bin/bash

# ShackMate Docker Build and Deploy Script

set -e  # Exit on any error

DOCKER_HUB_USER="${DOCKER_HUB_USER:-shackmate}"
IMAGE_NAME="shackmate-kiosk"
IMAGE_TAG="${IMAGE_TAG:-latest}"
PI_HOST="${PI_HOST:-sm@10.146.1.254}"

echo "🏗️ Building ShackMate Docker Image..."
echo "📋 Image: ${DOCKER_HUB_USER}/${IMAGE_NAME}:${IMAGE_TAG}"
echo ""

# Build the Docker image
echo "🔨 Building Docker image..."
docker build -t ${DOCKER_HUB_USER}/${IMAGE_NAME}:${IMAGE_TAG} .

echo "✅ Docker image built successfully!"
echo ""

# Ask if user wants to push to DockerHub
read -p "🐳 Push to DockerHub? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "📤 Pushing to DockerHub..."
    
    # Check if logged in to Docker Hub
    if ! docker info | grep -q "Username:"; then
        echo "🔐 Please log in to Docker Hub:"
        docker login
    fi
    
    docker push ${DOCKER_HUB_USER}/${IMAGE_NAME}:${IMAGE_TAG}
    echo "✅ Image pushed to DockerHub!"
else
    echo "⏭️ Skipping DockerHub push."
fi

echo ""

# Ask if user wants to deploy to Pi
read -p "🥧 Deploy to Raspberry Pi (${PI_HOST})? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Deploying to Raspberry Pi..."
    
    # Create deployment script for Pi
    cat > deploy-to-pi.sh << 'EOF'
#!/bin/bash

DOCKER_HUB_USER="${1:-shackmate}"
IMAGE_NAME="${2:-shackmate-kiosk}"
IMAGE_TAG="${3:-latest}"

echo "🥧 ShackMate Pi Deployment Starting..."

# Stop any existing container
echo "🛑 Stopping existing container..."
sudo docker stop shackmate-kiosk 2>/dev/null || true
sudo docker rm shackmate-kiosk 2>/dev/null || true

# Pull latest image
echo "📥 Pulling latest image..."
sudo docker pull ${DOCKER_HUB_USER}/${IMAGE_NAME}:${IMAGE_TAG}

# Enable X11 access for docker
echo "🖥️ Setting up X11 access..."
xhost +local: 2>/dev/null || echo "⚠️ X11 not available (headless mode)"

# Run the container
echo "🏃 Starting ShackMate container..."
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

echo "✅ ShackMate container started!"
echo ""
echo "📊 Container status:"
sudo docker ps | grep shackmate-kiosk

echo ""
echo "📝 To view logs:"
echo "sudo docker logs -f shackmate-kiosk"
echo ""
echo "🌐 Access ShackMate at: http://localhost or http://shackmate.router"
EOF

    # Copy deployment script to Pi and run it
    echo "📁 Copying deployment script to Pi..."
    scp deploy-to-pi.sh ${PI_HOST}:~/
    
    echo "🏃 Running deployment on Pi..."
    ssh ${PI_HOST} "chmod +x ~/deploy-to-pi.sh && ~/deploy-to-pi.sh ${DOCKER_HUB_USER} ${IMAGE_NAME} ${IMAGE_TAG}"
    
    # Clean up local deployment script
    rm deploy-to-pi.sh
    
    echo "✅ Deployment complete!"
else
    echo "⏭️ Skipping Pi deployment."
fi

echo ""
echo "🎉 Build and deploy process complete!"
echo ""
echo "📋 Summary:"
echo "  • Image: ${DOCKER_HUB_USER}/${IMAGE_NAME}:${IMAGE_TAG}"
echo "  • Local build: ✅"
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "  • DockerHub push: ✅"
    echo "  • Pi deployment: ✅"
fi
echo ""
echo "🔧 Next steps:"
echo "  • Test the container on Pi"
echo "  • Check logs: docker logs -f shackmate-kiosk"
echo "  • Access web interface: http://shackmate.router"
