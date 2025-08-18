#!/bin/bash

# Docker Installation and Configuration Script
# Installs Docker and restores Docker configuration from GitHub

set -e

echo "🐳 ShackMate Docker Installation & Configuration"
echo "==============================================="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)"
   exit 1
fi

# Get the user who should own the docker files (not root)
REAL_USER=${SUDO_USER:-$(logname 2>/dev/null || echo "pi")}
REAL_HOME=$(eval echo "~$REAL_USER")

echo "👤 Installing Docker for user: $REAL_USER"
echo "🏠 User home directory: $REAL_HOME"
echo ""

# Install Docker if not already installed
echo "📦 Installing Docker..."
if ! command -v docker >/dev/null 2>&1; then
    echo "📥 Docker not found, installing..."
    
    # Update package list
    apt-get update -qq
    
    # Install required packages
    apt-get install -y ca-certificates curl gnupg lsb-release
    
    # Add Docker's official GPG key
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package list with Docker repo
    apt-get update -qq
    
    # Install Docker
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    echo "✅ Docker installed successfully"
else
    echo "✅ Docker already installed"
fi

# Install docker-compose if not already available
echo "📦 Installing Docker Compose..."
if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
    echo "📥 Installing docker-compose..."
    
    # Get latest docker-compose version
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    
    # Download and install docker-compose
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    echo "✅ Docker Compose installed successfully"
else
    echo "✅ Docker Compose already available"
fi

# Add user to docker group
echo "👥 Adding user to docker group..."
usermod -aG docker "$REAL_USER"
echo "✅ Added $REAL_USER to docker group"

# Enable and start Docker service
echo "🔄 Enabling Docker service..."
systemctl enable docker
systemctl start docker
echo "✅ Docker service enabled and started"

# Create docker directory in user's home
DOCKER_DIR="$REAL_HOME/docker"
echo "📁 Setting up Docker configuration directory..."

if [ ! -d "$DOCKER_DIR" ]; then
    mkdir -p "$DOCKER_DIR"
    chown "$REAL_USER:$REAL_USER" "$DOCKER_DIR"
    echo "✅ Created $DOCKER_DIR"
else
    echo "✅ Docker directory already exists at $DOCKER_DIR"
fi

# Download Docker configuration from GitHub
echo "📥 Downloading Docker configuration from GitHub..."
GITHUB_REPO_URL="https://github.com/ShackMate/ShackMate-HMI.git"
TEMP_DIR="/tmp/shackmate-docker-$$"

mkdir -p "$TEMP_DIR"

# Method 1: Try using git (most reliable)
if command -v git >/dev/null 2>&1; then
    echo "🔄 Using git to download Docker configuration..."
    if git clone --depth 1 --filter=blob:none --sparse "$GITHUB_REPO_URL" "$TEMP_DIR" 2>/dev/null; then
        cd "$TEMP_DIR"
        git sparse-checkout set docker
        cd - >/dev/null
        
        if [ -d "$TEMP_DIR/docker" ]; then
            echo "✅ Successfully downloaded Docker configuration using git"
            DOWNLOAD_SUCCESS=true
        else
            echo "⚠️  Git clone succeeded but docker folder not found"
            DOWNLOAD_SUCCESS=false
        fi
    else
        echo "⚠️  Git clone failed, trying alternative method..."
        DOWNLOAD_SUCCESS=false
    fi
else
    echo "ℹ️  Git not available, using alternative download method..."
    DOWNLOAD_SUCCESS=false
fi

# Method 2: Download tarball and extract (fallback)
if [ "$DOWNLOAD_SUCCESS" != "true" ]; then
    echo "🔄 Using tarball download method..."
    TARBALL_URL="https://github.com/ShackMate/ShackMate-HMI/archive/refs/heads/main.tar.gz"
    
    if curl -sSL "$TARBALL_URL" | tar -xz -C "$TEMP_DIR" --strip-components=1; then
        if [ -d "$TEMP_DIR/docker" ]; then
            echo "✅ Successfully downloaded Docker configuration using tarball"
            DOWNLOAD_SUCCESS=true
        else
            echo "❌ Tarball download succeeded but docker folder not found"
            DOWNLOAD_SUCCESS=false
        fi
    else
        echo "❌ Tarball download failed"
        DOWNLOAD_SUCCESS=false
    fi
fi

# Check if we have the docker configuration
if [ "$DOWNLOAD_SUCCESS" = "true" ] && [ -d "$TEMP_DIR/docker" ]; then
    echo "✅ Found Docker configuration in download"
    
    # Copy files to user's docker directory
    echo "📁 Copying Docker configuration files..."
    cp -r "$TEMP_DIR/docker"/* "$DOCKER_DIR/"
    chown -R "$REAL_USER:$REAL_USER" "$DOCKER_DIR"
    echo "✅ Docker configuration restored to $DOCKER_DIR"
    
    # List what was restored
    echo ""
    echo "📋 Restored Docker files:"
    find "$DOCKER_DIR" -type f | sed 's|'"$DOCKER_DIR"'/|  • |' | head -20
    total_files=$(find "$DOCKER_DIR" -type f | wc -l)
    if [ "$total_files" -gt 20 ]; then
        echo "  ... and $((total_files - 20)) more files"
    fi
    echo "   Total files: $total_files"
else
    echo "❌ Failed to download Docker configuration from GitHub"
    echo "   The installation will continue, but Docker configuration won't be restored"
    echo "   You can manually copy your docker files or use the pull-docker-config.sh script"
fi

# Clean up temporary directory
if [ -d "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
    echo "🧹 Cleaned up temporary files"
fi

# Create a sample docker-compose.yml if none exists
COMPOSE_FILE="$DOCKER_DIR/docker-compose.yml"
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "📝 Creating sample docker-compose.yml..."
    cat > "$COMPOSE_FILE" << 'EOF'
version: '3.8'

services:
  # Example service - replace with your actual services
  hello-world:
    image: hello-world
    container_name: shackmate-hello
    
  # Add your services here
  # web:
  #   image: nginx:latest
  #   ports:
  #     - "80:80"
  #   volumes:
  #     - ./html:/usr/share/nginx/html
  #   restart: unless-stopped

# Add your networks, volumes, etc. here
EOF
    chown "$REAL_USER:$REAL_USER" "$COMPOSE_FILE"
    echo "✅ Created sample docker-compose.yml"
fi

echo ""
echo "✨ Docker installation and configuration completed!"
echo ""
echo "📁 Docker directory: $DOCKER_DIR"
echo "🐳 Docker version: $(docker --version)"
echo "🔧 Docker Compose: $(docker-compose --version 2>/dev/null || echo 'Available via docker compose')"
echo ""
echo "🚀 Next steps:"
echo "   1. Logout and login again (or reboot) to apply docker group membership"
echo "   2. Test Docker: docker run hello-world"
echo "   3. Navigate to your docker directory: cd $DOCKER_DIR"
echo "   4. Start your services: docker-compose up -d"
echo ""
echo "💡 To add your Docker config to GitHub:"
echo "   1. Put your docker files in $DOCKER_DIR"
echo "   2. Add them to the repo's docker/ folder"
echo "   3. Future installations will automatically restore them"
echo ""
