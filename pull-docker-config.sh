#!/bin/bash

# Pull Docker Configuration from Raspberry Pi
# This script downloads Docker files from your Raspberry Pi to the local docker folder

set -e

echo "📥 ShackMate Docker Configuration Pull"
echo "======================================"
echo ""

# Configuration
PI_USER="sm"
PI_HOST="10.146.1.254"
PI_DOCKER_DIR="/home/sm/docker"
LOCAL_DOCKER_DIR="./docker"

echo "🔧 Configuration:"
echo "   Pi Address: $PI_USER@$PI_HOST"
echo "   Pi Docker Dir: $PI_DOCKER_DIR"
echo "   Local Docker Dir: $LOCAL_DOCKER_DIR"
echo ""

# Check if we're in the right directory
if [ ! -f "README.md" ] || [ ! -d ".git" ]; then
    echo "❌ Error: This script must be run from the ShackMate-HMI repository root"
    echo "   Current directory: $(pwd)"
    echo "   Expected files: README.md, .git/"
    exit 1
fi

# Check if scp is available
if ! command -v scp >/dev/null 2>&1; then
    echo "❌ Error: scp command not found"
    echo "   Please install openssh-client or equivalent"
    exit 1
fi

# Test connection to Pi
echo "🔍 Testing connection to Raspberry Pi..."
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$PI_USER@$PI_HOST" "echo 'Connection test successful'" 2>/dev/null; then
    echo "❌ Error: Cannot connect to $PI_USER@$PI_HOST"
    echo ""
    echo "💡 Troubleshooting:"
    echo "   1. Check if Pi is powered on and connected"
    echo "   2. Verify the IP address: $PI_HOST"
    echo "   3. Ensure SSH is enabled on the Pi"
    echo "   4. Try manual connection: ssh $PI_USER@$PI_HOST"
    echo ""
    echo "🔑 If password authentication is required:"
    echo "   The script will prompt for password during file transfer"
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "✅ Connection to Raspberry Pi successful"
fi

# Check if docker directory exists on Pi
echo "📁 Checking for Docker directory on Pi..."
if ssh -o ConnectTimeout=10 "$PI_USER@$PI_HOST" "test -d $PI_DOCKER_DIR" 2>/dev/null; then
    echo "✅ Found Docker directory on Pi: $PI_DOCKER_DIR"
else
    echo "❌ Docker directory not found on Pi: $PI_DOCKER_DIR"
    echo ""
    echo "💡 Creating directory on Pi..."
    if ssh "$PI_USER@$PI_HOST" "mkdir -p $PI_DOCKER_DIR" 2>/dev/null; then
        echo "✅ Created Docker directory on Pi"
    else
        echo "❌ Failed to create directory on Pi"
        exit 1
    fi
fi

# List files on Pi
echo "📋 Docker files on Raspberry Pi:"
if ssh "$PI_USER@$PI_HOST" "find $PI_DOCKER_DIR -type f 2>/dev/null" | head -20; then
    file_count=$(ssh "$PI_USER@$PI_HOST" "find $PI_DOCKER_DIR -type f 2>/dev/null | wc -l")
    echo "   Total files found: $file_count"
    
    if [ "$file_count" -eq 0 ]; then
        echo "ℹ️  No files found in Pi's Docker directory"
        echo "   You may want to add some Docker configurations first"
        read -p "Continue with empty directory? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
else
    echo "⚠️  Could not list files (directory may be empty or inaccessible)"
fi

echo ""

# Create backup of existing local docker folder
if [ -d "$LOCAL_DOCKER_DIR" ]; then
    BACKUP_DIR="${LOCAL_DOCKER_DIR}.backup.$(date +%Y%m%d-%H%M%S)"
    echo "📦 Backing up existing local docker folder..."
    cp -r "$LOCAL_DOCKER_DIR" "$BACKUP_DIR"
    echo "✅ Backup created: $BACKUP_DIR"
fi

# Create local docker directory if it doesn't exist
mkdir -p "$LOCAL_DOCKER_DIR"

# Pull files from Pi
echo "📥 Pulling Docker files from Raspberry Pi..."
echo "   This may prompt for your Pi password..."
echo ""

# Use rsync if available (better than scp for directories), otherwise use scp
if command -v rsync >/dev/null 2>&1; then
    echo "🔄 Using rsync for efficient transfer..."
    if rsync -avz --progress "$PI_USER@$PI_HOST:$PI_DOCKER_DIR/" "$LOCAL_DOCKER_DIR/"; then
        echo "✅ Files transferred successfully using rsync"
    else
        echo "❌ rsync failed, trying scp..."
        # Fallback to scp
        if scp -r "$PI_USER@$PI_HOST:$PI_DOCKER_DIR/*" "$LOCAL_DOCKER_DIR/" 2>/dev/null; then
            echo "✅ Files transferred successfully using scp"
        else
            echo "⚠️  scp completed (may have transferred some files)"
        fi
    fi
else
    echo "🔄 Using scp for transfer..."
    if scp -r "$PI_USER@$PI_HOST:$PI_DOCKER_DIR/*" "$LOCAL_DOCKER_DIR/" 2>/dev/null; then
        echo "✅ Files transferred successfully using scp"
    else
        echo "⚠️  scp completed (may have transferred some files or directory was empty)"
    fi
fi

echo ""

# Show what was transferred
echo "📋 Files pulled to local docker folder:"
if [ "$(find "$LOCAL_DOCKER_DIR" -type f | wc -l)" -gt 0 ]; then
    find "$LOCAL_DOCKER_DIR" -type f | sed 's|^./docker/|  • |' | head -20
    total_files=$(find "$LOCAL_DOCKER_DIR" -type f | wc -l)
    echo "   Total files: $total_files"
else
    echo "   No files found (directory may be empty)"
fi

echo ""
echo "✨ Docker configuration pull completed!"
echo ""
echo "🔄 Next steps:"
echo "   1. Review the pulled files: ls -la $LOCAL_DOCKER_DIR"
echo "   2. Make any necessary changes"
echo "   3. Commit to GitHub: git add . && git commit -m 'Add Docker configuration from Pi'"
echo "   4. Push to GitHub: git push"
echo ""
echo "🚀 Future installations will automatically restore these files to ~/docker"
echo ""

# Offer to show pulled files
read -p "📁 Show pulled Docker files? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "📁 Docker files structure:"
    if command -v tree >/dev/null 2>&1; then
        tree "$LOCAL_DOCKER_DIR"
    else
        find "$LOCAL_DOCKER_DIR" -type f -exec ls -la {} \;
    fi
fi
