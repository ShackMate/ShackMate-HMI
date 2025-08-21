# ShackMate Docker Kiosk Setup

This directory contains a complete self-contained Docker solution for running ShackMate as a kiosk system on Raspberry Pi.

## 🎯 What This Does

- **Web Interface**: Serves the ShackMate PHP application via Apache
- **Kiosk Browser**: Automatically opens Chromium in fullscreen kiosk mode
- **UDP Listener**: Receives router IP updates on port 8080 and updates hostname resolution
- **Auto-Start**: Automatically starts on boot and restarts if containers fail
- **Hardware Access**: Full access to Raspberry Pi touchscreen and display hardware

## 📁 Files

- `Dockerfile` - Container definition with minimal packages
- `supervisord.conf` - Service orchestration for Apache, UDP listener, and browser
- `entrypoint.sh` - Container initialization script
- `run-shackmate-container.sh` - Docker run command with all required permissions
- `install-docker-kiosk.sh` - Complete installation script
- `shackmate-docker.service` - Systemd service for auto-start
- `README.md` - This documentation

## 🚀 Quick Install

1. **Install Docker** (if not already installed):
   ```bash
   curl -fsSL https://get.docker.com | sh
   sudo usermod -aG docker $USER
   sudo systemctl enable docker
   sudo systemctl start docker
   ```

2. **Install ShackMate Docker Kiosk**:
   ```bash
   cd /opt/shackmate/ShackMate/ShackMate-HMI/docker
   sudo ./install-docker-kiosk.sh
   ```

3. **Start the service**:
   ```bash
   sudo systemctl start shackmate-docker
   ```

## 🔧 Manual Usage

### Build the Image
```bash
cd /opt/shackmate/ShackMate/ShackMate-HMI/docker
docker build -t shackmate-kiosk .
```

### Run Container Manually
```bash
./run-shackmate-container.sh
```

### Check Status
```bash
# Service status
sudo systemctl status shackmate-docker

# Container status
docker ps | grep shackmate-kiosk

# Container logs
docker logs -f shackmate-kiosk
```

## 🛠️ Troubleshooting

### Display Issues
If the browser doesn't appear on the screen:
```bash
# Check X11 permissions
xhost +local:

# Verify DISPLAY environment
echo $DISPLAY

# Check container display access
docker exec -it shackmate-kiosk env | grep DISPLAY
```

### Network Issues
If hostname resolution fails:
```bash
# Check UDP listener logs
docker logs shackmate-kiosk | grep UDP

# Test UDP manually
echo "10.146.1.241" | nc -u localhost 8080

# Check hosts file in container
docker exec -it shackmate-kiosk cat /etc/hosts
```

### Permission Issues
If services fail to start:
```bash
# Container should run as root
docker exec -it shackmate-kiosk whoami

# Check supervisor status
docker exec -it shackmate-kiosk supervisorctl status
```

## 🔄 Service Management

```bash
# Start service
sudo systemctl start shackmate-docker

# Stop service
sudo systemctl stop shackmate-docker

# Restart service
sudo systemctl restart shackmate-docker

# Disable auto-start
sudo systemctl disable shackmate-docker

# Re-enable auto-start
sudo systemctl enable shackmate-docker
```

## 📝 Key Features

### Self-Contained Operation
- All services run within the Docker container
- No host system modifications required (except Docker)
- Complete isolation from host environment

### Hardware Integration
- Full access to Raspberry Pi touchscreen via privileged mode
- X11 framebuffer access for display output
- USB and GPIO device access if needed

### Automatic Recovery
- Container automatically restarts on failure
- Service starts automatically on system boot
- Supervisor manages all internal processes

### Network Communication
- UDP listener receives router IP updates
- Automatic hostname resolution updates
- Web interface accessible via hostname or IP

## 🔍 Architecture

```
┌─────────────────────────────────────┐
│ ShackMate Docker Container          │
│                                     │
│ ┌─────────────┐ ┌─────────────────┐ │
│ │   Apache    │ │ UDP Listener    │ │
│ │   (PHP)     │ │ (Python)        │ │
│ │   :80       │ │ :8080           │ │
│ └─────────────┘ └─────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ Chromium Kiosk Browser          │ │
│ │ (Fullscreen Display)            │ │
│ └─────────────────────────────────┘ │
│                                     │
│ Managed by Supervisord              │
└─────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────┐
│ Raspberry Pi Host System            │
│ • Docker Engine                     │
│ • X11 Display Server                │
│ • Systemd Auto-Start                │
└─────────────────────────────────────┘
```
