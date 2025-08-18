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
GITHUB_DOCKER_URL="https://api.github.com/repos/ShackMate/ShackMate-HMI/contents/docker"
TEMP_DIR="/tmp/shackmate-docker-$$"

mkdir -p "$TEMP_DIR"

# Function to download directory contents recursively
download_directory() {
    local url="$1"
    local local_path="$2"
    
    # Get directory contents from GitHub API
    curl -s "$url" | grep -E '"download_url":' | cut -d'"' -f4 | while read -r file_url; do
        if [ -n "$file_url" ]; then
            # Extract filename from URL
            filename=$(basename "$file_url")
            echo "  📄 Downloading $filename..."
            curl -s "$file_url" -o "$local_path/$filename"
        fi
    done
    
    # Handle subdirectories
    curl -s "$url" | grep -E '"type": "dir"' -B 3 | grep '"name":' | cut -d'"' -f4 | while read -r dirname; do
        if [ -n "$dirname" ]; then
            echo "  📁 Processing subdirectory: $dirname"
            mkdir -p "$local_path/$dirname"
            download_directory "$url/$dirname" "$local_path/$dirname"
        fi
    done
}

# Check if docker folder exists in GitHub repo
if curl -s "$GITHUB_DOCKER_URL" | grep -q '"name":'; then
    echo "✅ Found Docker configuration in GitHub repo"
    download_directory "$GITHUB_DOCKER_URL" "$TEMP_DIR"
    
    # Copy files to user's docker directory
    if [ "$(ls -A $TEMP_DIR 2>/dev/null)" ]; then
        cp -r "$TEMP_DIR"/* "$DOCKER_DIR/"
        chown -R "$REAL_USER:$REAL_USER" "$DOCKER_DIR"
        echo "✅ Docker configuration restored to $DOCKER_DIR"
        
        # List what was restored
        echo ""
        echo "📋 Restored Docker files:"
        find "$DOCKER_DIR" -type f | sed 's|'"$DOCKER_DIR"'/|  • |'
    else
        echo "ℹ️  No files found in GitHub docker folder"
    fi
else
    echo "ℹ️  No Docker configuration found in GitHub repo"
    echo "   Add your docker files to the repo's docker/ folder to enable automatic restore"
fi

# Clean up
rm -rf "$TEMP_DIR"

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
