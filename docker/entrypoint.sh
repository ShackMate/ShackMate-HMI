#!/bin/bash

echo "🏁 ShackMate Docker Container Starting..."

# Remove default Apache index.html that conflicts with our index.php
if [ -f /var/www/html/index.html ]; then
    # Check if it's the default Debian page
    if grep -q "Apache2 Debian Default Page" /var/www/html/index.html 2>/dev/null; then
        echo "🗑️ Removing default Apache page..."
        rm -f /var/www/html/index.html
    fi
fi

# Create necessary directories with proper permissions
mkdir -p /tmp/chromium-data
mkdir -p /var/log
mkdir -p /var/run/apache2
mkdir -p /var/lock/apache2
mkdir -p /var/log/shackmate
chmod 755 /var/log/shackmate

# Set up display environment for hardware access
export DISPLAY=:0

# Clean up any stale Apache PID files
rm -f /var/run/apache2/apache2.pid

# Start dbus for better X11 support
if [ -f /var/run/dbus/pid ]; then
    echo "Removing stale PID file /var/run/dbus/pid.."
    rm -f /var/run/dbus/pid
fi
/etc/init.d/dbus start 2>/dev/null || true

# Initialize UDP listener with proper setup
echo "🌐 Setting up UDP listener for hostname updates..."

# Create the UDP listener script
cat > /usr/local/bin/shackmate-udp-listener.py << 'EOF'
import socket
import time
import logging
import sys
import os

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/shackmate/udp-listener.log'),
        logging.StreamHandler(sys.stdout)
    ]
)

def update_hosts_file(ip_address):
    """Update /etc/hosts with the new IP for shackmate.router"""
    try:
        # Read current hosts file
        with open('/etc/hosts', 'r') as f:
            lines = f.readlines()
        
        # Remove any existing shackmate.router entries
        lines = [line for line in lines if 'shackmate.router' not in line]
        
        # Add the new entry
        lines.append(f"{ip_address} shackmate.router\n")
        
        # Write back to file
        with open('/etc/hosts', 'w') as f:
            f.writelines(lines)
        
        logging.info(f"✅ Updated /etc/hosts: {ip_address} shackmate.router")
        return True
        
    except Exception as e:
        logging.error(f"❌ Failed to update /etc/hosts: {str(e)}")
        return False

def parse_shackmate_message(message):
    """Parse ShackMate,IP,PORT message format"""
    try:
        parts = message.split(',')
        if len(parts) == 3 and parts[0] == 'ShackMate':
            ip_address = parts[1].strip()
            port = parts[2].strip()
            return ip_address, port
        else:
            return None, None
    except Exception:
        return None, None

def main():
    """Main UDP listener function"""
    # Create socket
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(('0.0.0.0', 4210))
    
    logging.info("🎧 UDP listener started on port 4210 for ShackMate discovery")
    
    while True:
        try:
            data, addr = sock.recvfrom(1024)
            message = data.decode('utf-8').strip()
            
            logging.info(f"📨 Received from {addr}: {message}")
            
            # Parse the ShackMate message
            ip_address, port = parse_shackmate_message(message)
            
            if ip_address and port:
                logging.info(f"🔍 Parsed ShackMate discovery: IP={ip_address}, Port={port}")
                
                # Update hosts file with discovered IP
                if update_hosts_file(ip_address):
                    # Send acknowledgment
                    sock.sendto(b"OK", addr)
                    logging.info(f"✅ Sent acknowledgment to {addr}")
                else:
                    sock.sendto(b"ERROR", addr)
                    logging.info(f"❌ Sent error response to {addr}")
            else:
                logging.warning(f"⚠️ Invalid message format. Expected: ShackMate,IP,PORT - Got: {message}")
                sock.sendto(b"INVALID_FORMAT", addr)
                
        except Exception as e:
            logging.error(f"❌ Error in UDP listener: {str(e)}")
            time.sleep(1)

if __name__ == "__main__":
    main()
EOF
                sock.sendto(b"ERROR", addr)
                logging.info(f"❌ Sent error response to {addr}")
                
        except Exception as e:
            logging.error(f"❌ Error in UDP listener: {str(e)}")
            time.sleep(1)

if __name__ == "__main__":
    main()
EOF

# Make the UDP listener executable
chmod +x /usr/local/bin/shackmate-udp-listener.py

echo "🚀 Starting services with Supervisor..."

exec "$@"
