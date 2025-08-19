#!/bin/bash

# Fix Apache Issues and Restart ShackMate Containers
# This script will copy the fixed Docker configuration and restart the containers

echo "🔧 ShackMate Apache Fix and Restart Script"
echo "=========================================="

# Variables
REMOTE_HOST="10.146.1.254"
REMOTE_USER="sm"
DOCKER_DIR="~/docker"

echo "📥 Copying fixed Docker configuration to Raspberry Pi..."

# Copy the fixed files using scp
echo "Copying Dockerfile..."
scp docker/Dockerfile ${REMOTE_USER}@${REMOTE_HOST}:${DOCKER_DIR}/

echo "Copying supervisord.conf..."
scp docker/supervisord.conf ${REMOTE_USER}@${REMOTE_HOST}:${DOCKER_DIR}/

echo "Copying entrypoint.sh..."
scp docker/entrypoint.sh ${REMOTE_USER}@${REMOTE_HOST}:${DOCKER_DIR}/

echo "🔄 Connecting to Raspberry Pi to restart containers..."

# SSH to Pi and restart containers
ssh ${REMOTE_USER}@${REMOTE_HOST} << 'EOF'
    echo "🛑 Stopping existing containers..."
    cd ~/docker
    docker-compose down
    
    echo "🗑️ Removing old images..."
    docker image prune -f
    
    echo "🔨 Building new containers with Apache fixes..."
    docker-compose up -d --build
    
    echo "⏱️ Waiting for services to start..."
    sleep 10
    
    echo "📊 Container status:"
    docker ps
    
    echo "📋 Checking Apache logs..."
    docker-compose logs shackmate-hmi | tail -20
    
    echo "🌐 Testing Apache connection..."
    if curl -s http://localhost >/dev/null 2>&1; then
        echo "✅ Apache is running successfully!"
    else
        echo "❌ Apache still not responding"
        echo "📋 Apache error logs:"
        docker-compose exec shackmate-hmi cat /var/log/apache2.err.log 2>/dev/null || echo "No error logs found"
    fi
    
    echo "🖥️ Chromium kiosk status:"
    docker-compose exec shackmate-hmi pgrep chromium >/dev/null && echo "✅ Chromium is running" || echo "❌ Chromium not running"
EOF

echo "🎉 Apache fix deployment complete!"
echo "The touchscreen should now show the ShackMate interface instead of the login screen."
