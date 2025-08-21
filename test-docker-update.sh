#!/bin/bash

# Test updated Docker setup from GitHub
echo "🧪 Testing Updated ShackMate Docker Setup"
echo "========================================"
echo ""

# Create a test directory
TEST_DIR="/tmp/shackmate-docker-test"
echo "📁 Creating test directory: $TEST_DIR"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Pull latest Docker configuration from GitHub
echo "📥 Pulling latest Docker configuration from GitHub..."
curl -sSL https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/docker/Dockerfile -o Dockerfile
curl -sSL https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/docker/docker-compose.yml -o docker-compose.yml
curl -sSL https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/docker/entrypoint.sh -o entrypoint.sh
curl -sSL https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/docker/supervisord.conf -o supervisord.conf
curl -sSL https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/docker/start-chromium.sh -o start-chromium.sh
curl -sSL https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/docker/udp_listener.py -o udp_listener.py

# Create basic web directory
mkdir -p web
echo "<h1>ShackMate Test</h1><p>Docker setup working!</p>" > web/index.html

echo "✅ Files downloaded successfully"
echo ""

# Show the streamlined Dockerfile
echo "📋 Updated Dockerfile packages:"
grep -A 10 "apt-get install" Dockerfile | grep -E "(chromium|xinit|xterm|xvfb|supervisor|curl|fonts|libnss)"
echo ""

# Test Docker build
echo "🔨 Testing Docker build..."
if docker build -t shackmate-test .; then
    echo "✅ Docker build successful!"
    echo ""
    
    # Show image size
    echo "📊 Docker image info:"
    docker images shackmate-test --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
    echo ""
    
    # Test container startup
    echo "🚀 Testing container startup..."
    docker run -d --name shackmate-test-container -p 8080:80 shackmate-test
    
    # Wait a moment for startup
    sleep 5
    
    # Test web interface
    echo "🌐 Testing web interface..."
    if curl -s http://localhost:8080 | grep -q "ShackMate Test"; then
        echo "✅ Web interface is working!"
        echo "🎯 Test successful - you can access it at http://localhost:8080"
    else
        echo "⚠️  Web interface may not be ready yet"
    fi
    
    # Show container status
    echo ""
    echo "📊 Container status:"
    docker ps --filter "name=shackmate-test-container" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    echo ""
    echo "🧹 Cleanup commands:"
    echo "   docker stop shackmate-test-container"
    echo "   docker rm shackmate-test-container"
    echo "   docker rmi shackmate-test"
    echo "   rm -rf $TEST_DIR"
    
else
    echo "❌ Docker build failed"
    echo "Check the error messages above for details"
fi

echo ""
echo "📁 Test files are in: $TEST_DIR"
