#!/bin/bash

# Safe Kiosk Setup - Step by Step (No Auto-Boot)
# This script sets up kiosk mode that you can start manually, avoiding boot loops

echo "🛡️ ShackMate Safe Kiosk Setup"
echo "============================="

# Variables
REMOTE_HOST="10.146.1.254"
REMOTE_USER="sm"

echo "📋 This script will create a SAFE kiosk setup that:"
echo "   ✅ Does NOT auto-start on boot (prevents loops)"
echo "   ✅ Can be started manually when ready"
echo "   ✅ Can be easily stopped if issues occur"
echo "   ✅ Includes proper error handling"
echo ""

ssh ${REMOTE_USER}@${REMOTE_HOST} << 'EOF'
    echo "🔧 Setting up safe kiosk configuration..."
    
    # Install required packages
    echo "📦 Installing display packages..."
    sudo apt-get update -qq
    sudo apt-get install -y xinit xorg chromium-browser unclutter
    
    # Create a safe kiosk script that can be run manually
    echo "📝 Creating manual kiosk startup script..."
    cat > ~/start-kiosk.sh << 'KIOSK'
#!/bin/bash

echo "🚀 Starting ShackMate Kiosk Mode..."

# Check if already running
if pgrep -x "chromium-browser" > /dev/null; then
    echo "❌ Kiosk already running. Stop it first with: ~/stop-kiosk.sh"
    exit 1
fi

# Start Docker containers first
echo "🐳 Starting Docker containers..."
cd ~/docker
if ! docker-compose up -d; then
    echo "❌ Failed to start Docker containers"
    exit 1
fi

# Wait for services to be ready
echo "⏱️ Waiting for services to start..."
sleep 15

# Check if Apache is responding
if ! curl -s http://localhost >/dev/null 2>&1; then
    echo "❌ Apache not responding. Check Docker logs:"
    docker-compose logs --tail=10
    exit 1
fi

echo "✅ Services ready! Starting display..."

# Set up display environment
export DISPLAY=:0

# Start X if not running
if ! pgrep -x "Xorg" > /dev/null; then
    echo "🖥️ Starting X server..."
    sudo systemctl start graphical.target
    sleep 5
fi

# Configure display settings
xset s off 2>/dev/null || true
xset -dpms 2>/dev/null || true  
xset s noblank 2>/dev/null || true

# Hide cursor
unclutter -idle 0.5 -root &

# Launch Chromium in kiosk mode
echo "🌐 Launching Chromium kiosk..."
chromium-browser \
    --kiosk \
    --no-sandbox \
    --disable-dev-shm-usage \
    --disable-gpu \
    --disable-software-rasterizer \
    --disable-background-timer-throttling \
    --disable-backgrounding-occluded-windows \
    --disable-renderer-backgrounding \
    --disable-field-trial-config \
    --disable-features=TranslateUI,VizDisplayCompositor \
    --disable-web-security \
    --disable-extensions \
    --disable-plugins \
    --disable-sync \
    --disable-translate \
    --disable-background-networking \
    --disable-back-forward-cache \
    --disable-ipc-flooding-protection \
    --no-default-browser-check \
    --no-first-run \
    --start-maximized \
    --window-position=0,0 \
    --window-size=1920,1080 \
    --user-data-dir=/tmp/chromium-kiosk \
    --homepage=http://localhost \
    --app=http://localhost \
    http://localhost &

echo "✅ Kiosk mode started! Use 'stop-kiosk.sh' to stop."
KIOSK

    chmod +x ~/start-kiosk.sh
    
    # Create stop script
    echo "📝 Creating kiosk stop script..."
    cat > ~/stop-kiosk.sh << 'STOP'
#!/bin/bash

echo "🛑 Stopping ShackMate Kiosk Mode..."

# Kill Chromium
pkill chromium-browser 2>/dev/null && echo "✅ Chromium stopped"

# Kill unclutter
pkill unclutter 2>/dev/null

# Stop Docker containers
cd ~/docker
docker-compose down 2>/dev/null && echo "✅ Docker containers stopped"

echo "✅ Kiosk mode stopped"
STOP

    chmod +x ~/stop-kiosk.sh
    
    # Create status check script
    echo "📝 Creating status check script..."
    cat > ~/kiosk-status.sh << 'STATUS'
#!/bin/bash

echo "📊 ShackMate Kiosk Status"
echo "========================"

echo "🐳 Docker Containers:"
cd ~/docker && docker-compose ps 2>/dev/null || echo "Docker not running"

echo ""
echo "🌐 Apache Status:"
if curl -s http://localhost >/dev/null 2>&1; then
    echo "✅ Apache responding"
else
    echo "❌ Apache not responding"
fi

echo ""
echo "🖥️ Display Processes:"
pgrep -x "Xorg" >/dev/null && echo "✅ X server running" || echo "❌ X server not running"
pgrep chromium-browser >/dev/null && echo "✅ Chromium running" || echo "❌ Chromium not running"

echo ""
echo "💡 Commands:"
echo "   Start kiosk:  ~/start-kiosk.sh"
echo "   Stop kiosk:   ~/stop-kiosk.sh"
echo "   Check status: ~/kiosk-status.sh"
STATUS

    chmod +x ~/kiosk-status.sh
    
    echo ""
    echo "✅ Safe kiosk setup complete!"
    echo ""
    echo "📋 Available commands:"
    echo "   ~/start-kiosk.sh  - Start kiosk mode manually"
    echo "   ~/stop-kiosk.sh   - Stop kiosk mode"
    echo "   ~/kiosk-status.sh - Check status"
    echo ""
    echo "🎯 To test kiosk mode:"
    echo "   1. Run: ~/start-kiosk.sh"
    echo "   2. Check touchscreen for ShackMate interface"
    echo "   3. If issues occur, run: ~/stop-kiosk.sh"

EOF

echo ""
echo "🎉 Safe kiosk setup deployed!"
echo ""
echo "📋 Next steps:"
echo "   1. SSH to the Pi: ssh sm@10.146.1.254"
echo "   2. Test kiosk: ~/start-kiosk.sh"
echo "   3. Check touchscreen"
echo "   4. If working, optionally enable auto-start later"
echo ""
echo "💡 This approach prevents boot loops by requiring manual start"
