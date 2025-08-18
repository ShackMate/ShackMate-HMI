# ShackMate-HMI

## Complete ShackMate Installation

This repository provides scripts to set up a complete ShackMate environment on Raspberry Pi, including boot splash disable and UDP listener service.

### 🚀 One-Command Complete Installation

Run this single command to install everything:

```bash
curl -sSL https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/install-shackmate-complete.sh | sudo bash
```

This will:

- ✅ Disable boot splash screens and verbose text
- ✅ Install custom ShackMate logo as boot splash
- ✅ Install ShackMate UDP Listener service
- ✅ Install Docker and Docker Compose
- ✅ Restore Docker configuration from GitHub
- ✅ Create and start systemd service
- ✅ Enable auto-start on boot
- ✅ Set up proper file permissions and directories

---

## ShackMate UDP Listener Service

The UDP listener service automatically updates the hosts file when it receives router information via UDP packets on port 4210.

### Service Details

- **Service Name**: `shackmate-udp-listener`
- **Install Location**: `/opt/shackmate/udp_listener.py`
- **UDP Port**: 4210
- **Hosts File**: `/etc/hosts`

### Service Management

```bash
# Check service status
sudo systemctl status shackmate-udp-listener

# View live logs
sudo journalctl -u shackmate-udp-listener -f

# Restart service
sudo systemctl restart shackmate-udp-listener

# Stop service
sudo systemctl stop shackmate-udp-listener

# Start service
sudo systemctl start shackmate-udp-listener

# Disable auto-start
sudo systemctl disable shackmate-udp-listener

# Enable auto-start
sudo systemctl enable shackmate-udp-listener
```

### How It Works

1. **Listens** for UDP packets on port 4210
2. **Parses** messages in format: `ShackMate,IP_ADDRESS,PORT`
3. **Safely updates** `/etc/hosts` with: `IP_ADDRESS shackmate.router`
4. **Preserves** all existing hosts file entries
5. **Creates backups** before modifying hosts file
6. **Removes** only old shackmate.router entries (prevents duplicates)
7. **Logs** all activity to systemd journal

**Hosts File Safety**: The UDP listener preserves all existing entries in `/etc/hosts` and only updates the `shackmate.router` entry. Automatic backups are created before each modification.

---

## Docker Configuration

The complete installation automatically installs Docker and restores your Docker configuration from the GitHub repository.

### Standalone Docker Installation

If you only want to install Docker and restore configuration:

```bash
curl -sSL https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/install-docker.sh | sudo bash
```

### What Gets Installed

- ✅ Docker CE (latest stable version)
- ✅ Docker Compose (latest version)  
- ✅ User added to docker group
- ✅ Docker service enabled and auto-started
- ✅ Docker configuration restored to `~/docker`

### Adding Your Docker Configuration

1. **Add your Docker files** to the `docker/` folder in this GitHub repository
2. **Commit and push** to GitHub
3. **Future installations** will automatically restore your configuration

### Example Docker Files

- `docker-compose.yml` - Your services configuration
- `.env` - Environment variables
- `Dockerfile` - Custom container builds
- Config folders for your applications

### Using Docker After Installation

```bash
# Navigate to docker directory
cd ~/docker

# Start services
docker-compose up -d

# View running containers
docker ps

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

---

## Raspberry Pi Boot Splash Disable (Standalone)

If you only want to disable boot splash screens without the UDP listener:

### Quick Installation

```bash
curl -sSL https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/install-disable-boot-splash.sh | sudo bash
```

### Manual Installation

1. Download the script:

   ```bash
   wget https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/disable-boot-splash.sh
   ```

2. Make it executable:

   ```bash
   chmod +x disable-boot-splash.sh
   ```

3. Run with sudo:

   ```bash
   sudo ./disable-boot-splash.sh
   ```

### What the Boot Splash Script Does

The script automatically:

- ✅ Adds quiet boot parameters to `/boot/firmware/cmdline.txt`
- ✅ Disables rainbow splash screen in `/boot/firmware/config.txt`
- ✅ Reduces boot delay to 0
- ✅ Disables Plymouth splash services
- ✅ Creates automatic backups of original files
- ✅ Updates initramfs if needed

---

## Custom ShackMate Boot Logo

If you want to install just the custom boot logo without other components:

### Standalone Logo Installation

```bash
curl -sSL https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/install-custom-logo.sh | sudo bash
```

This will:

- ✅ Download and install ShackMate logo
- ✅ Create custom boot splash service
- ✅ Replace Raspberry Pi logo with ShackMate logo
- ✅ Keep quiet boot but show branded splash
- ✅ Configure for touchscreen compatibility

---

## After Installation

1. **Reboot your Raspberry Pi** to apply all changes:

   ```bash
   sudo reboot
   ```

2. **Verify the UDP service** is running:

   ```bash
   sudo systemctl status shackmate-udp-listener
   ```

3. **Test UDP listener** by sending a test packet:

   ```bash
   echo "ShackMate,192.168.1.100,80" | nc -u localhost 4210
   ```

---

## File Structure

```text
/opt/shackmate/
└── udp_listener.py          # Main UDP listener script

/etc/systemd/system/
├── shackmate-udp-listener.service  # UDP listener systemd service
└── shackmate-splash.service        # Custom boot splash service

/etc/
└── hosts                    # System hosts file (managed by UDP listener)

/usr/share/pixmaps/
└── ShackMateLogo.png        # ShackMate logo file

/boot/firmware/
├── splash.png               # Custom boot splash image
├── cmdline.txt              # Modified for quiet boot
└── config.txt               # Modified to disable default splash

~/docker/                    # Docker configuration (restored from GitHub)
├── docker-compose.yml       # Main compose file
├── .env                     # Environment variables
└── services/                # Individual service configurations
```

---

## Troubleshooting

### Service Not Starting

```bash
# Check service status
sudo systemctl status shackmate-udp-listener

# Check logs for errors
sudo journalctl -u shackmate-udp-listener --no-pager

# Manually test the script
sudo python3 /opt/shackmate/udp_listener.py
```

### UDP Port Issues

```bash
# Check if port 4210 is in use
sudo ss -ulnp | grep 4210

# Check firewall (if enabled)
sudo ufw status
```

### Hosts File Issues

```bash
# Check hosts file permissions
ls -la /etc/hosts

# Manually verify hosts file content
cat /etc/hosts

# Check for shackmate.router entry
grep "shackmate.router" /etc/hosts

# View hosts file backups (if any issues occur)
ls -la /opt/shackmate/backups/hosts.backup.*

# Restore hosts file from backup if needed
sudo cp /opt/shackmate/backups/hosts.backup.YYYYMMDD_HHMMSS /etc/hosts
```

**Note**: The UDP listener automatically creates backups before modifying `/etc/hosts` and preserves all existing entries. Only the `shackmate.router` entry is updated.

### Touchscreen Issues

If touchscreen stops working after installation:

```bash
# Fix touchscreen issues (removes problematic framebuffer settings)
curl -sSL https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/fix-touchscreen.sh | sudo bash

# Or manually remove framebuffer settings
sudo sed -i '/^framebuffer_width=/d' /boot/firmware/config.txt
sudo sed -i '/^framebuffer_height=/d' /boot/firmware/config.txt
sudo reboot

# Check if touchscreen devices are detected
ls /dev/input/
cat /proc/bus/input/devices | grep -i touch
```

### Console Text Still Visible

If you still see some console text during boot, use the enhanced silent boot script:

```bash
# Complete console silence (no text at all during boot)
curl -sSL https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/make-boot-silent.sh | sudo bash

# Then reboot to apply
sudo reboot
```

**⚠️ CAUTION**: The enhanced silent boot script is very aggressive and may cause boot issues on some systems.

### Boot Issues Recovery

If you're stuck on the logo or having boot problems after using the enhanced silent boot:

```bash
# Emergency boot recovery (fixes boot issues)
curl -sSL https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/fix-boot-issues.sh | sudo bash

# Then reboot
sudo reboot
```

This recovery script:

- ✅ Restores loglevel=3 (safer than loglevel=0)
- ✅ Removes console redirection
- ✅ Re-enables essential services
- ✅ Fixes boot hanging issues

The enhanced silent boot script:

- ✅ Sets kernel log level to 0 (completely silent)
- ✅ Redirects console to tty3 (not visible on main display)
- ✅ Disables systemd status messages
- ✅ Masks verbose services
- ✅ Disables getty on tty1

**Note**: This makes boot completely silent but you can still access console via SSH or by switching to tty2/tty3 with Ctrl+Alt+F2/F3.

### Chromium Browser Issues

If Chromium browser won't launch after installation, it may be due to console redirection or disabled services:

```bash
# Fix Chromium launch issues
curl -sSL https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/fix-chromium-launch.sh | sudo bash

# Then reboot
sudo reboot

# Diagnose Chromium issues
curl -sSL https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/chromium-diagnostics.sh | bash
```

This fix script:

- ✅ Removes console redirection that interferes with desktop
- ✅ Re-enables essential services (getty@tty1, console-setup)
- ✅ Ensures adequate GPU memory allocation
- ✅ Enables KMS graphics driver for better compatibility
- ✅ Fixes display manager service dependencies

---

## Restoring Original Settings

### Boot Splash Restore

```bash
# Restore from backup (replace DATE-TIME with your backup folder)
sudo cp /boot/firmware/backup-YYYYMMDD-HHMMSS/cmdline.txt /boot/firmware/
sudo cp /boot/firmware/backup-YYYYMMDD-HHMMSS/config.txt /boot/firmware/
sudo reboot
```

### Uninstall UDP Service

```bash
# Stop and disable service
sudo systemctl stop shackmate-udp-listener
sudo systemctl disable shackmate-udp-listener

# Remove service file
sudo rm /etc/systemd/system/shackmate-udp-listener.service

# Remove installation directory
sudo rm -rf /opt/shackmate

# Reload systemd
sudo systemctl daemon-reload
```

---

## Compatibility

- ✅ Raspberry Pi 5
- ✅ Raspberry Pi 4
- ✅ Raspberry Pi 3
- ✅ Raspberry Pi OS Bookworm
- ✅ Raspberry Pi OS Bullseye

## Requirements

- Root access (sudo)
- Internet connection (for installation)
- Python 3 (usually pre-installed)
- systemd (standard on Raspberry Pi OS)
