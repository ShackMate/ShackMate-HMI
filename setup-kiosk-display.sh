#!/bin/bash

# Configure Raspberry Pi to Boot Directly into Docker Kiosk Mode
# This script sets up the Pi to automatically start Docker containers and display Chromium on the touchscreen

echo "🖥️ ShackMate Kiosk Boot Configuration"
echo "===================================="

# Variables
REMOTE_HOST="10.146.1.254"
REMOTE_USER="sm"

echo "📋 This script will configure your Pi to:"
echo "   1. Auto-start Docker containers on boot"
echo "   2. Launch Chromium directly on the touchscreen"
echo "   3. Hide the terminal/console from the display"
echo ""

ssh ${REMOTE_USER}@${REMOTE_HOST} << 'EOF'
    echo "🔧 Setting up kiosk boot configuration..."
    
    # First, let's fix the Docker containers with the latest config
    echo "📥 Downloading latest Docker configuration..."
    cd ~/docker
    
    # Stop current containers
    docker-compose down 2>/dev/null || true
    
    # Download fixed files
    curl -s -o Dockerfile https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/docker/Dockerfile
    curl -s -o supervisord.conf https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/docker/supervisord.conf
    curl -s -o entrypoint.sh https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/docker/entrypoint.sh
    chmod +x entrypoint.sh
    
    echo "🔨 Rebuilding containers with fixes..."
    docker-compose up -d --build
    
    echo "⏱️ Waiting for services to start..."
    sleep 15
    
    # Test if Apache is working
    if curl -s http://localhost >/dev/null 2>&1; then
        echo "✅ Apache is working!"
    else
        echo "❌ Apache still not working, checking logs..."
        docker-compose logs shackmate-hmi | tail -10
    fi
    
    echo "🖥️ Now configuring display for kiosk mode..."
    
    # Install X11 packages needed for display
    sudo apt-get update
    sudo apt-get install -y xinit xorg chromium-browser unclutter
    
    # Create xinitrc for kiosk mode
    cat > ~/.xinitrc << 'XINITRC'
#!/bin/bash

# Disable screen blanking
xset s off
xset -dpms
xset s noblank

# Hide cursor
unclutter -idle 0.5 -root &

# Wait for Docker containers to be ready
sleep 10

# Check if containers are running, start if needed
cd /home/sm/docker
if ! docker-compose ps | grep -q "Up"; then
    docker-compose up -d
    sleep 10
fi

# Wait for Apache to be ready
while ! curl -s http://localhost >/dev/null 2>&1; do
    echo "Waiting for Apache..."
    sleep 2
done

# Launch Chromium in kiosk mode
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
    http://localhost
XINITRC
    
    chmod +x ~/.xinitrc
    
    echo "🎯 Creating auto-start service for kiosk mode..."
    
    # Create systemd service for auto-start
    sudo tee /etc/systemd/system/shackmate-kiosk.service > /dev/null << 'SERVICE'
[Unit]
Description=ShackMate Kiosk Mode
After=network.target docker.service
Wants=docker.service

[Service]
Type=simple
User=sm
Environment=HOME=/home/sm
Environment=XDG_RUNTIME_DIR=/run/user/1000
WorkingDirectory=/home/sm
ExecStartPre=/bin/sleep 10
ExecStart=/usr/bin/startx /home/sm/.xinitrc
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE
    
    # Enable the service
    sudo systemctl daemon-reload
    sudo systemctl enable shackmate-kiosk.service
    
    echo "🔄 Configuring boot to start kiosk automatically..."
    
    # Modify the auto-login to start X instead of just console
    sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
    sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf > /dev/null << 'OVERRIDE'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin sm --noclear %I $TERM
OVERRIDE
    
    # Add startx to the user's profile to auto-launch kiosk
    if ! grep -q "startx" ~/.bashrc; then
        echo "" >> ~/.bashrc
        echo "# Auto-start kiosk mode on login" >> ~/.bashrc
        echo "if [[ -z \$DISPLAY && \$XDG_VTNR -eq 1 ]]; then" >> ~/.bashrc
        echo "    exec startx" >> ~/.bashrc
        echo "fi" >> ~/.bashrc
    fi
    
    echo "✅ Kiosk configuration complete!"
    echo ""
    echo "📊 Current container status:"
    docker ps
    
    echo ""
    echo "🎯 Configuration Summary:"
    echo "   ✅ Docker containers configured with Apache fixes"
    echo "   ✅ X11 and Chromium installed for display"
    echo "   ✅ Kiosk mode startup script created"
    echo "   ✅ Auto-login configured to start kiosk"
    echo "   ✅ Systemd service created for reliability"
    echo ""
    echo "🔄 Reboot your Pi to see the kiosk mode on the touchscreen:"
    echo "   sudo reboot"

EOF

echo ""
echo "🎉 Kiosk configuration deployment complete!"
echo ""
echo "📋 What happens next:"
echo "   1. The Pi will auto-login as user 'sm'"
echo "   2. X11 will automatically start"
echo "   3. Docker containers will launch"
echo "   4. Chromium will open in full-screen kiosk mode"
echo "   5. The touchscreen will show the ShackMate interface"
echo ""
echo "💡 To activate the kiosk mode, reboot your Pi:"
echo "   ssh sm@10.146.1.254 'sudo reboot'"
