#!/bin/bash

# ShackMate Docker Kiosk Startup Script
# This script configures the Raspberry Pi to start Docker and launch Chromium in kiosk mode on boot

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

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

echo "ShackMate Docker Kiosk Configuration"
echo "===================================="
echo ""

# Get the real user
REAL_USER=${SUDO_USER:-$(whoami)}
if [ "$REAL_USER" = "root" ]; then
    REAL_USER="pi"
fi

print_status "Configuring for user: $REAL_USER"
USER_HOME=$(eval echo ~$REAL_USER)
DOCKER_DIR="$USER_HOME/docker"

print_status "Docker directory: $DOCKER_DIR"

# Ensure Docker directory exists
if [ ! -d "$DOCKER_DIR" ]; then
    print_error "Docker directory not found: $DOCKER_DIR"
    print_status "Please ensure your Docker configuration is in $DOCKER_DIR"
    exit 1
fi

# Create systemd service to start Docker containers on boot
print_status "Creating systemd service for Docker kiosk..."

cat > /etc/systemd/system/shackmate-docker-kiosk.service << EOF
[Unit]
Description=ShackMate Docker Kiosk Mode
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
User=$REAL_USER
Group=$REAL_USER
WorkingDirectory=$DOCKER_DIR
ExecStart=/usr/bin/docker-compose up -d --build
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

print_success "Created systemd service: /etc/systemd/system/shackmate-docker-kiosk.service"

# Enable the service
systemctl daemon-reload
systemctl enable shackmate-docker-kiosk.service
print_success "Enabled Docker kiosk service for auto-start"

# Create a script to connect to the container's display (for troubleshooting)
cat > "$USER_HOME/connect-display.sh" << 'EOF'
#!/bin/bash
# Script to connect to the Docker container's virtual display

echo "Connecting to ShackMate container display..."
echo "This allows you to see what Chromium is displaying"
echo ""

# Check if container is running
if ! docker ps | grep -q shackmate-hmi; then
    echo "❌ ShackMate container is not running"
    echo "Start it with: cd ~/docker && docker-compose up -d"
    exit 1
fi

# Install VNC viewer if not present
if ! command -v vncviewer >/dev/null 2>&1; then
    echo "Installing VNC viewer..."
    sudo apt update && sudo apt install -y tigervnc-viewer
fi

# Start VNC server in container if not running
docker exec -d shackmate-hmi bash -c '
    if ! pgrep x11vnc; then
        apt update && apt install -y x11vnc
        x11vnc -display :99 -nopw -listen localhost -xkb -ncache 10 -ncache_cr -forever &
    fi
'

# Forward VNC port
docker exec -d shackmate-hmi socat TCP-LISTEN:5900,fork TCP:localhost:5900

# Connect with VNC viewer
echo "Starting VNC connection..."
vncviewer localhost:5900

EOF

chmod +x "$USER_HOME/connect-display.sh"
chown "$REAL_USER:$REAL_USER" "$USER_HOME/connect-display.sh"
print_success "Created display connection script: $USER_HOME/connect-display.sh"

# Create Docker management scripts
cat > "$USER_HOME/docker-commands.sh" << EOF
#!/bin/bash
# ShackMate Docker Management Commands

DOCKER_DIR="$DOCKER_DIR"

case \$1 in
    start)
        echo "🚀 Starting ShackMate Docker containers..."
        cd "\$DOCKER_DIR" && docker-compose up -d --build
        ;;
    stop)
        echo "🛑 Stopping ShackMate Docker containers..."
        cd "\$DOCKER_DIR" && docker-compose down
        ;;
    restart)
        echo "🔄 Restarting ShackMate Docker containers..."
        cd "\$DOCKER_DIR" && docker-compose down && docker-compose up -d --build
        ;;
    logs)
        echo "📋 Showing ShackMate container logs..."
        cd "\$DOCKER_DIR" && docker-compose logs -f
        ;;
    status)
        echo "📊 ShackMate container status:"
        docker ps --filter name=shackmate
        ;;
    shell)
        echo "🐚 Opening shell in ShackMate container..."
        docker exec -it shackmate-hmi bash
        ;;
    chromium-logs)
        echo "🌐 Showing Chromium logs..."
        docker exec shackmate-hmi tail -f /var/log/chromium.out.log
        ;;
    *)
        echo "ShackMate Docker Management"
        echo "=========================="
        echo "Usage: \$0 {start|stop|restart|logs|status|shell|chromium-logs}"
        echo ""
        echo "Commands:"
        echo "  start         - Start containers"
        echo "  stop          - Stop containers"
        echo "  restart       - Restart containers"
        echo "  logs          - Show all container logs"
        echo "  status        - Show container status"
        echo "  shell         - Open shell in container"
        echo "  chromium-logs - Show Chromium browser logs"
        ;;
esac
EOF

chmod +x "$USER_HOME/docker-commands.sh"
chown "$REAL_USER:$REAL_USER" "$USER_HOME/docker-commands.sh"
print_success "Created Docker management script: $USER_HOME/docker-commands.sh"

# Test the setup
print_status "Testing Docker setup..."
cd "$DOCKER_DIR"

if docker-compose config >/dev/null 2>&1; then
    print_success "Docker Compose configuration is valid"
else
    print_error "Docker Compose configuration has errors"
    exit 1
fi

echo ""
print_success "ShackMate Docker Kiosk configuration completed!"
echo ""
echo "📋 Summary:"
echo "==========="
echo "• Docker containers will auto-start on boot"
echo "• Chromium will launch in kiosk mode pointing to localhost"
echo "• Virtual display runs at 1920x1080"
echo "• Services: Apache, SMB, UDP Listener, Chromium"
echo ""
echo "🔧 Management Commands:"
echo "======================"
echo "• Start containers:    $USER_HOME/docker-commands.sh start"
echo "• Stop containers:     $USER_HOME/docker-commands.sh stop"
echo "• View logs:           $USER_HOME/docker-commands.sh logs"
echo "• Container status:    $USER_HOME/docker-commands.sh status"
echo "• Access container:    $USER_HOME/docker-commands.sh shell"
echo "• View display:        $USER_HOME/connect-display.sh"
echo ""
echo "🚀 Next Steps:"
echo "============="
echo "1. Start containers:   sudo -u $REAL_USER $USER_HOME/docker-commands.sh start"
echo "2. Check status:       sudo -u $REAL_USER $USER_HOME/docker-commands.sh status"
echo "3. View Chromium logs: sudo -u $REAL_USER $USER_HOME/docker-commands.sh chromium-logs"
echo "4. Reboot to test auto-start: sudo reboot"
echo ""
print_warning "Note: The container runs a virtual display. Use connect-display.sh to view it remotely."
