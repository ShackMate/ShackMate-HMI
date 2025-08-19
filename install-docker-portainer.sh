#!/bin/bash

# ShackMate Docker and Portainer Installation Script
# 
# Quick install from GitHub:
# curl -sSL https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/install-docker-portainer.sh | sudo bash
#
# This script:
# 1. Installs Docker and Docker Compose
# 2. Sets up Portainer for container management
# 3. Pulls the ShackMate Docker image
# 4. Downloads the ShackMate Docker configuration

set -e  # Exit on any error

echo "🐳 ShackMate Docker and Portainer Installation"
echo "=============================================="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)"
   exit 1
fi

# Get the real user (not root)
REAL_USER=${SUDO_USER:-$(whoami)}
if [ "$REAL_USER" = "root" ]; then
    echo "⚠️  Warning: Cannot determine non-root user. Please run with sudo."
    read -p "Enter the username to configure Docker for: " REAL_USER
fi

USER_HOME=$(eval echo "~$REAL_USER")
echo "📋 Configuring Docker for user: $REAL_USER"
echo "📁 User home directory: $USER_HOME"
echo ""

echo "🐳 Step 1: Docker Installation"
echo "=============================="

# Check if Docker is already installed
if command -v docker >/dev/null 2>&1; then
    DOCKER_VERSION=$(docker --version 2>/dev/null | cut -d' ' -f3 | cut -d',' -f1)
    echo "ℹ️  Docker already installed: $DOCKER_VERSION"
    
    # Check if docker-compose is available
    if docker compose version >/dev/null 2>&1; then
        COMPOSE_VERSION=$(docker compose version --short 2>/dev/null)
        echo "ℹ️  Docker Compose already available: $COMPOSE_VERSION"
    else
        echo "⚠️  Docker Compose not available, will install..."
        NEED_COMPOSE=true
    fi
    
    # Check if user is in docker group
    if groups "$REAL_USER" | grep -q "docker"; then
        echo "ℹ️  User $REAL_USER already in docker group"
        DOCKER_ALREADY_CONFIGURED=true
    else
        echo "ℹ️  Adding user $REAL_USER to docker group..."
        usermod -aG docker "$REAL_USER"
        echo "✅ User added to docker group"
        DOCKER_ALREADY_CONFIGURED=false
    fi
else
    echo "📥 Installing Docker..."
    DOCKER_ALREADY_CONFIGURED=false
    NEED_COMPOSE=true
fi

# Install Docker if needed
if [ "$DOCKER_ALREADY_CONFIGURED" != "true" ] || ! command -v docker >/dev/null 2>&1; then
    echo "📦 Installing Docker using official installation script..."
    
    # Download and execute Docker's official installation script
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh
    rm -f /tmp/get-docker.sh
    
    # Add user to docker group
    usermod -aG docker "$REAL_USER"
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    echo "✅ Docker installation completed"
else
    echo "✅ Docker already configured"
fi

# Verify Docker installation
echo "🧪 Testing Docker installation..."
if docker --version >/dev/null 2>&1; then
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
    echo "✅ Docker $DOCKER_VERSION is working"
else
    echo "❌ Docker installation failed"
    exit 1
fi

# Verify Docker Compose
if docker compose version >/dev/null 2>&1; then
    COMPOSE_VERSION=$(docker compose version --short 2>/dev/null)
    echo "✅ Docker Compose $COMPOSE_VERSION is working"
else
    echo "❌ Docker Compose not available"
    exit 1
fi

echo ""
echo "📊 Step 2: Portainer Installation"
echo "================================="

# Check if Portainer is already running
if docker ps --format "{{.Names}}" | grep -q "^portainer$"; then
    echo "ℹ️  Portainer container already running"
    PORTAINER_STATUS=$(docker ps --filter "name=portainer" --format "{{.Status}}")
    echo "   Status: $PORTAINER_STATUS"
    echo "   Skipping Portainer installation..."
else
    echo "📦 Installing Portainer..."
    
    # Create Portainer data volume
    echo "💾 Creating Portainer data volume..."
    docker volume create portainer_data
    echo "✅ Portainer volume created"
    
    # Stop and remove any existing Portainer container
    docker stop portainer 2>/dev/null || true
    docker rm portainer 2>/dev/null || true
    
    # Run Portainer container
    echo "🚀 Starting Portainer container..."
    docker run -d \
        -p 9443:9443 \
        --name portainer \
        --restart=always \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        portainer/portainer-ce:latest
    
    echo "✅ Portainer installed and started"
fi

# Wait for Portainer to be ready
echo "⏳ Waiting for Portainer to be ready..."
sleep 5

# Check Portainer status
if docker ps --filter "name=portainer" --format "{{.Status}}" | grep -q "Up"; then
    echo "✅ Portainer is running successfully"
    echo "🌐 Portainer web interface: https://$(hostname -I | cut -d' ' -f1):9443"
    echo "🔑 First-time setup: Create admin account when you visit the web interface"
else
    echo "⚠️  Portainer may not be running properly"
    docker logs portainer 2>/dev/null | tail -5
fi

echo ""
echo "🎯 Step 3: ShackMate Docker Image"
echo "================================="

# Pull ShackMate Docker image
echo "📥 Pulling ShackMate Docker image..."
if docker pull n4ldr/shackmate-v1; then
    echo "✅ ShackMate Docker image pulled successfully"
    
    # Show image info
    IMAGE_SIZE=$(docker images n4ldr/shackmate-v1 --format "{{.Size}}")
    echo "📦 Image size: $IMAGE_SIZE"
else
    echo "⚠️  Failed to pull ShackMate image, but continuing..."
fi

echo ""
echo "📋 Step 4: ShackMate Docker Configuration"
echo "========================================="

# Create docker directory in user home
DOCKER_DIR="$USER_HOME/docker"
echo "📁 Setting up Docker configuration in: $DOCKER_DIR"

if [ -d "$DOCKER_DIR" ]; then
    echo "ℹ️  Docker directory already exists"
    echo "   Creating backup..."
    BACKUP_DIR="$DOCKER_DIR.backup.$(date +%Y%m%d-%H%M%S)"
    cp -r "$DOCKER_DIR" "$BACKUP_DIR"
    echo "✅ Backup created: $BACKUP_DIR"
else
    echo "📁 Creating Docker directory..."
    mkdir -p "$DOCKER_DIR"
fi

# Download ShackMate Docker configuration
echo "📥 Downloading ShackMate Docker configuration..."

# GitHub repository details
GITHUB_REPO="ShackMate/ShackMate-HMI"
DOCKER_CONFIG_PATH="docker"

# List of files to download
DOCKER_FILES=(
    "docker-compose.yml"
    "Dockerfile"
    "entrypoint.sh"
    "supervisord.conf"
    "start-chromium.sh"
    "udp_listener.py"
    ".env.example"
    "README.md"
)

# Download each file
for file in "${DOCKER_FILES[@]}"; do
    echo "   Downloading $file..."
    FILE_URL="https://raw.githubusercontent.com/$GITHUB_REPO/main/$DOCKER_CONFIG_PATH/$file"
    
    if command -v curl >/dev/null 2>&1; then
        curl -sSL "$FILE_URL" -o "$DOCKER_DIR/$file"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$FILE_URL" -O "$DOCKER_DIR/$file"
    else
        echo "❌ Error: Neither curl nor wget found"
        exit 1
    fi
    
    if [ -f "$DOCKER_DIR/$file" ]; then
        echo "   ✅ $file downloaded"
    else
        echo "   ❌ Failed to download $file"
    fi
done

# Download web directory
echo "📁 Setting up web directory..."
WEB_DIR="$DOCKER_DIR/web"
mkdir -p "$WEB_DIR"

# Set proper ownership
chown -R "$REAL_USER:$REAL_USER" "$DOCKER_DIR"
echo "✅ Docker configuration downloaded and ownership set"

# Make scripts executable
chmod +x "$DOCKER_DIR/entrypoint.sh" 2>/dev/null || true
chmod +x "$DOCKER_DIR/start-chromium.sh" 2>/dev/null || true
chmod +x "$DOCKER_DIR/udp_listener.py" 2>/dev/null || true

echo ""
echo "✨ Docker and Portainer installation completed!"
echo ""
echo "📋 Summary:"
echo "   • Docker Engine installed and configured"
echo "   • Docker Compose plugin available"
echo "   • User '$REAL_USER' added to docker group"
echo "   • Portainer installed and running on port 9443"
echo "   • ShackMate Docker image pulled: n4ldr/shackmate-v1"
echo "   • Docker configuration downloaded to: $DOCKER_DIR"
echo ""
echo "🌐 Portainer Web Interface:"
echo "   URL: https://$(hostname -I | cut -d' ' -f1):9443"
echo "   Note: You'll need to create an admin account on first visit"
echo ""
echo "🔄 Next steps:"
echo "   1. Log out and back in (or reboot) to apply docker group membership"
echo "   2. Test Docker: docker run hello-world"
echo "   3. Start ShackMate services: cd ~/docker && docker-compose up -d"
echo "   4. Access Portainer web interface to manage containers"
echo "   5. Check services: docker ps"
echo ""
echo "🛠️  Useful commands:"
echo "   • Start services: cd ~/docker && docker-compose up -d"
echo "   • Stop services: cd ~/docker && docker-compose down"
echo "   • View logs: cd ~/docker && docker-compose logs -f"
echo "   • Restart Portainer: docker restart portainer"
echo "   • Check images: docker images"
echo ""
