#!/bin/bash

# Alternative Kiosk Setup - Use existing packages
echo "🔄 Creating alternative kiosk setup using available packages..."

ssh sm@10.146.1.254 << 'EOF'
    echo "🔍 Checking what's available on the system..."
    
    # Check available browsers
    BROWSER=""
    if command -v chromium >/dev/null 2>&1; then
        BROWSER="chromium"
        echo "✅ Found chromium"
    elif command -v chromium-browser >/dev/null 2>&1; then
        BROWSER="chromium-browser"
        echo "✅ Found chromium-browser"
    elif command -v firefox-esr >/dev/null 2>&1; then
        BROWSER="firefox-esr"
        echo "✅ Found firefox-esr"
    else
        echo "❌ No browser found, installing minimal chromium..."
        sudo apt-get install -y --no-install-recommends chromium
        BROWSER="chromium"
    fi
    
    # Create simplified kiosk script that works with what we have
    echo "📝 Creating simplified kiosk script..."
    cat > ~/start-kiosk-simple.sh << SIMPLE
#!/bin/bash

echo "🚀 Starting ShackMate Simple Kiosk Mode..."

# Check if kiosk already running
if pgrep -f "chromium.*kiosk" > /dev/null; then
    echo "❌ Kiosk already running. Stop it first with: ~/stop-kiosk.sh"
    exit 1
fi

# Start Docker containers
echo "🐳 Starting Docker containers..."
cd ~/docker
if ! docker-compose up -d; then
    echo "❌ Failed to start Docker containers"
    exit 1
fi

# Wait for services
echo "⏱️ Waiting for services to start..."
sleep 15

# Check if Apache is responding
if ! curl -s http://localhost >/dev/null 2>&1; then
    echo "❌ Apache not responding. Check Docker logs:"
    docker-compose logs --tail=10
    exit 1
fi

echo "✅ Services ready! Starting browser..."

# Try to set display (might not work in SSH but worth trying)
export DISPLAY=:0

# Launch browser in kiosk mode - try different approaches
echo "🌐 Launching browser in kiosk mode..."

# Method 1: Direct browser launch
if [ "$BROWSER" = "chromium" ] || [ "$BROWSER" = "chromium-browser" ]; then
    $BROWSER \
        --kiosk \
        --no-sandbox \
        --disable-dev-shm-usage \
        --disable-gpu \
        --no-default-browser-check \
        --no-first-run \
        --start-maximized \
        --window-position=0,0 \
        --window-size=1920,1080 \
        --user-data-dir=/tmp/chromium-kiosk \
        --app=http://localhost \
        http://localhost &
elif [ "$BROWSER" = "firefox-esr" ]; then
    firefox-esr --kiosk http://localhost &
fi

echo "✅ Browser launched! Check the touchscreen."
echo "💡 If no display appears, the Pi might need a desktop environment."
echo "🛑 To stop: ~/stop-kiosk.sh"

SIMPLE

    chmod +x ~/start-kiosk-simple.sh
    
    # Update stop script to handle different browser names
    cat > ~/stop-kiosk.sh << STOP
#!/bin/bash

echo "🛑 Stopping ShackMate Kiosk Mode..."

# Kill any running browsers
pkill chromium 2>/dev/null && echo "✅ Chromium stopped"
pkill firefox-esr 2>/dev/null && echo "✅ Firefox stopped"

# Stop Docker containers
cd ~/docker
docker-compose down 2>/dev/null && echo "✅ Docker containers stopped"

echo "✅ Kiosk mode stopped"
STOP

    chmod +x ~/stop-kiosk.sh
    
    echo ""
    echo "✅ Alternative kiosk setup complete!"
    echo ""
    echo "🧪 Browser found: $BROWSER"
    echo ""
    echo "📋 Test with:"
    echo "   ~/start-kiosk-simple.sh"
    echo ""
    echo "💡 Note: For full kiosk on touchscreen, you might need:"
    echo "   sudo apt-get install -y task-lxde-desktop"
    echo "   sudo systemctl set-default graphical.target"
    echo "   sudo reboot"

EOF

echo ""
echo "🎉 Alternative kiosk setup complete!"
echo ""
echo "📋 This creates a simpler approach that:"
echo "   ✅ Uses whatever browser is available"
echo "   ✅ Doesn't require extra packages"
echo "   ✅ Can run from SSH session"
echo ""
echo "🧪 Test it on the Pi with:"
echo "   ssh sm@10.146.1.254"
echo "   ~/start-kiosk-simple.sh"
