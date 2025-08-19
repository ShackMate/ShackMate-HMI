#!/bin/bash

# Download ShackMate Docker Configuration
# This script downloads the complete Docker setup from GitHub

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "ShackMate Docker Configuration Download"
echo "======================================"
echo ""

# Get the user (works with or without sudo)
REAL_USER=${SUDO_USER:-$(whoami)}
if [ "$REAL_USER" = "root" ]; then
    REAL_USER="pi"
fi

USER_HOME=$(eval echo ~$REAL_USER)
DOCKER_DIR="$USER_HOME/docker"

print_status "User: $REAL_USER"
print_status "Docker directory: $DOCKER_DIR"

# Create docker directory
print_status "Creating Docker directory..."
mkdir -p "$DOCKER_DIR"

# Change to user ownership if running as root
if [ "$EUID" -eq 0 ]; then
    chown "$REAL_USER:$REAL_USER" "$DOCKER_DIR"
fi

# Download Docker configuration files
GITHUB_RAW="https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/docker"

print_status "Downloading Docker configuration files..."

# Core Docker files
echo "  📄 Dockerfile..."
curl -sSL "$GITHUB_RAW/Dockerfile" -o "$DOCKER_DIR/Dockerfile"

echo "  📄 docker-compose.yml..."
curl -sSL "$GITHUB_RAW/docker-compose.yml" -o "$DOCKER_DIR/docker-compose.yml"

echo "  📄 supervisord.conf..."
curl -sSL "$GITHUB_RAW/supervisord.conf" -o "$DOCKER_DIR/supervisord.conf"

echo "  📄 entrypoint.sh..."
curl -sSL "$GITHUB_RAW/entrypoint.sh" -o "$DOCKER_DIR/entrypoint.sh"
chmod +x "$DOCKER_DIR/entrypoint.sh"

echo "  📄 start-chromium.sh..."
curl -sSL "$GITHUB_RAW/start-chromium.sh" -o "$DOCKER_DIR/start-chromium.sh"
chmod +x "$DOCKER_DIR/start-chromium.sh"

echo "  📄 udp_listener.py..."
curl -sSL "$GITHUB_RAW/udp_listener.py" -o "$DOCKER_DIR/udp_listener.py"
chmod +x "$DOCKER_DIR/udp_listener.py"

# Download web folder
print_status "Downloading web application files..."

TEMP_REPO="/tmp/shackmate-repo-$$"
mkdir -p "$DOCKER_DIR/web"

if command -v git >/dev/null 2>&1; then
    # Use git for efficient download
    print_status "Using git to download web files..."
    rm -rf "$TEMP_REPO"
    
    git clone --depth 1 --filter=blob:none --sparse https://github.com/ShackMate/ShackMate-HMI.git "$TEMP_REPO" 2>/dev/null
    cd "$TEMP_REPO"
    git sparse-checkout set docker/web 2>/dev/null
    
    if [ -d "$TEMP_REPO/docker/web" ]; then
        cp -r "$TEMP_REPO/docker/web"/* "$DOCKER_DIR/web/" 2>/dev/null || true
        print_success "Downloaded web application files via git"
    else
        print_warning "Web folder not found, trying direct download..."
    fi
    
    rm -rf "$TEMP_REPO"
else
    print_status "Git not available, using direct download..."
fi

# Fallback: download main web files directly
if [ ! -f "$DOCKER_DIR/web/index.php" ]; then
    print_status "Downloading individual web files..."
    
    # Main application file
    echo "  📄 index.php..."
    curl -sSL "https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/docker/web/index.php" -o "$DOCKER_DIR/web/index.php"
    
    # JavaScript files
    echo "  📄 JavaScript files..."
    curl -sSL "https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/docker/web/rig.js" -o "$DOCKER_DIR/web/rig.js" 2>/dev/null || true
    curl -sSL "https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/docker/web/rotor.js" -o "$DOCKER_DIR/web/rotor.js" 2>/dev/null || true
    curl -sSL "https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/docker/web/antenna.js" -o "$DOCKER_DIR/web/antenna.js" 2>/dev/null || true
    
    # CSS files
    echo "  📄 CSS files..."
    curl -sSL "https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/docker/web/w3.css" -o "$DOCKER_DIR/web/w3.css" 2>/dev/null || true
    curl -sSL "https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/docker/web/display.css" -o "$DOCKER_DIR/web/display.css" 2>/dev/null || true
    curl -sSL "https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/docker/web/rig.css" -o "$DOCKER_DIR/web/rig.css" 2>/dev/null || true
    curl -sSL "https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/docker/web/antenna.css" -o "$DOCKER_DIR/web/antenna.css" 2>/dev/null || true
    curl -sSL "https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/docker/web/rotor.css" -o "$DOCKER_DIR/web/rotor.css" 2>/dev/null || true
fi

# Set proper ownership
if [ "$EUID" -eq 0 ]; then
    chown -R "$REAL_USER:$REAL_USER" "$DOCKER_DIR"
fi

print_success "Download completed!"

# Show what was downloaded
echo ""
echo "📋 Downloaded files:"
echo "==================="
if command -v tree >/dev/null 2>&1; then
    tree "$DOCKER_DIR"
else
    find "$DOCKER_DIR" -type f | sed 's|'"$DOCKER_DIR"'/|  |' | sort
fi

echo ""
total_files=$(find "$DOCKER_DIR" -type f | wc -l)
echo "📊 Total files downloaded: $total_files"

# Test docker-compose configuration
echo ""
print_status "Testing Docker Compose configuration..."
cd "$DOCKER_DIR"

if docker-compose config >/dev/null 2>&1; then
    print_success "Docker Compose configuration is valid ✓"
else
    print_warning "Docker Compose configuration may have issues"
    print_status "This is normal if Docker isn't installed yet"
fi

echo ""
print_success "ShackMate Docker configuration ready!"
echo ""
echo "📋 Next steps:"
echo "=============="
echo "1. Navigate to Docker directory:"
echo "   cd $DOCKER_DIR"
echo ""
echo "2. Build and start containers:"
echo "   docker-compose up -d --build"
echo ""
echo "3. Check container status:"
echo "   docker-compose ps"
echo ""
echo "4. View logs:"
echo "   docker-compose logs -f"
echo ""
echo "5. Set up auto-start (optional):"
echo "   curl -sSL https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/docker-kiosk-setup.sh | sudo bash"
