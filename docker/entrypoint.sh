#!/bin/bash

echo "🏁 ShackMate Docker Container Starting..."

# Update hosts file
if echo "10.146.1.241 shackmate.router" >> /etc/hosts; then
    echo "✅ /etc/hosts updated"
else
    echo "❌ Failed to update /etc/hosts"
fi

# Create necessary directories
mkdir -p /tmp/chromium-data
mkdir -p /var/log

# Set up display environment
export DISPLAY=:99

# Start dbus for better X11 support
/etc/init.d/dbus start 2>/dev/null || true

echo "🚀 Starting services with Supervisor..."

exec "$@"
