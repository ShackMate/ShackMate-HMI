#!/bin/bash

echo "🐳 Starting ShackMate Docker Container..."

# Stop any existing container
docker stop shackmate-kiosk 2>/dev/null || true
docker rm shackmate-kiosk 2>/dev/null || true

# Build the image if it doesn't exist
if ! docker images | grep -q "shackmate-kiosk"; then
    echo "🔨 Building ShackMate Docker image..."
    cd /opt/shackmate/ShackMate/ShackMate-HMI/docker
    docker build -t shackmate-kiosk .
fi

echo "🚀 Starting container with hardware access..."

# Run the container with full hardware access
docker run -d \
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
    shackmate-kiosk \
    /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf

echo "✅ ShackMate container started!"
echo "📊 Container status:"
docker ps | grep shackmate-kiosk

echo ""
echo "📝 To view logs:"
echo "docker logs -f shackmate-kiosk"
echo ""
echo "🔍 To access container shell:"
echo "docker exec -it shackmate-kiosk bash"
echo ""
echo "🌐 Access ShackMate at: http://localhost or http://shackmate.router"
