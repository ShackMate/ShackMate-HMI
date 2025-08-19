#!/bin/bash

# Chromium Kiosk Mode Startup Script
# This script launches Chromium in kiosk mode pointing to localhost

# Wait for Xvfb to start
sleep 5

# Wait for Apache to be ready
echo "Waiting for Apache to start..."
until curl -s http://localhost >/dev/null 2>&1; do
    echo "Apache not ready yet, waiting..."
    sleep 2
done
echo "Apache is ready!"

# Set display
export DISPLAY=:99

# Create chromium user data directory
mkdir -p /tmp/chromium-data

# Chromium flags for kiosk mode and Raspberry Pi optimization
CHROMIUM_FLAGS="
    --kiosk
    --no-sandbox
    --disable-dev-shm-usage
    --disable-gpu
    --disable-software-rasterizer
    --disable-background-timer-throttling
    --disable-backgrounding-occluded-windows
    --disable-renderer-backgrounding
    --disable-field-trial-config
    --disable-features=TranslateUI,VizDisplayCompositor
    --disable-web-security
    --disable-extensions
    --disable-plugins
    --disable-sync
    --disable-translate
    --disable-background-networking
    --disable-back-forward-cache
    --disable-ipc-flooding-protection
    --no-default-browser-check
    --no-first-run
    --start-maximized
    --window-position=0,0
    --window-size=1920,1080
    --user-data-dir=/tmp/chromium-data
    --homepage=http://localhost
    --app=http://localhost
"

echo "Starting Chromium in kiosk mode..."
echo "Target URL: http://localhost"

# Start Chromium
exec /usr/bin/chromium $CHROMIUM_FLAGS
