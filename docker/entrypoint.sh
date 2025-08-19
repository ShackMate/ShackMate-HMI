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
mkdir -p /var/run/apache2
mkdir -p /var/lock/apache2

# Set up display environment
export DISPLAY=:99

# Clean up any stale Apache PID files
rm -f /var/run/apache2/apache2.pid

# Start dbus for better X11 support
if [ -f /var/run/dbus/pid ]; then
    echo "Removing stale PID file /var/run/dbus/pid.."
    rm -f /var/run/dbus/pid
fi
/etc/init.d/dbus start 2>/dev/null || true

echo "🚀 Starting services with Supervisor..."

exec "$@"
