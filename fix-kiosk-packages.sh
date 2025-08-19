#!/bin/bash

# Quick fix for missing packages on Raspberry Pi
echo "🔧 Installing missing kiosk packages..."

ssh sm@10.146.1.254 << 'EOF'
    echo "📦 Installing required packages..."
    
    # Update package list
    sudo apt-get update -qq
    
    # Install missing packages with correct names for Raspberry Pi OS
    sudo apt-get install -y \
        xinit \
        xorg \
        chromium-browser \
        unclutter \
        x11-xserver-utils \
        xserver-xorg-video-fbdev
    
    echo "✅ Package installation complete!"
    
    # Test if packages are available now
    echo "🧪 Testing package availability..."
    
    if command -v chromium-browser >/dev/null 2>&1; then
        echo "✅ chromium-browser found"
    else
        echo "⚠️ chromium-browser not found, trying alternatives..."
        if command -v chromium >/dev/null 2>&1; then
            echo "✅ chromium found instead"
            # Update the script to use 'chromium' instead of 'chromium-browser'
            sed -i 's/chromium-browser/chromium/g' ~/start-kiosk.sh
        fi
    fi
    
    if command -v unclutter >/dev/null 2>&1; then
        echo "✅ unclutter found"
    else
        echo "❌ unclutter still missing"
    fi
    
    # Fix the pgrep command in the start script
    echo "🔧 Fixing process detection in start script..."
    sed -i 's/pgrep -x "chromium-browser"/pgrep -f chromium/g' ~/start-kiosk.sh
    
    echo ""
    echo "🎯 Ready to test kiosk mode again!"
    echo "Run: ~/start-kiosk.sh"

EOF

echo "🎉 Package fix complete! Now try starting kiosk mode again on the Pi."
