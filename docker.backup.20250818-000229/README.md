# ShackMate Docker Configuration

This folder contains Docker configurations that will be automatically restored to `~/docker` on the Raspberry Pi during installation.

## How It Works

1. **Add your Docker files to this folder** in the GitHub repo
2. **Run the installer** - files are automatically downloaded and restored
3. **Docker is installed** and configured automatically
4. **Your containers are ready to start**

## Folder Structure

```text
docker/
├── README.md                 # This file
├── docker-compose.yml        # Main compose file (example)
├── .env                      # Environment variables (if needed)
└── services/                 # Individual service configurations
    ├── app1/
    │   ├── Dockerfile
    │   └── config/
    └── app2/
        ├── docker-compose.yml
        └── data/
```

## Installation

The Docker configuration is installed automatically when you run:

```bash
curl -sSL https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/install-shackmate-complete.sh | sudo bash
```

Or install just Docker and restore configuration:

```bash
curl -sSL https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/install-docker.sh | sudo bash
```

## What Gets Installed

- ✅ Docker CE (latest stable)
- ✅ Docker Compose (latest)
- ✅ User added to docker group
- ✅ Docker service enabled and started
- ✅ All files from this folder copied to `~/docker`
- ✅ Proper file permissions set

## Usage After Installation

```bash
# Navigate to docker directory
cd ~/docker

# Start your services
docker-compose up -d

# View running containers
docker ps

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

## Adding Your Configuration

1. **Copy your docker files** to this GitHub folder
2. **Commit and push** to the repository
3. **Future installations** will automatically restore them

### Example Files to Add

- `docker-compose.yml` - Your main compose configuration
- `.env` - Environment variables
- `Dockerfile` - Custom container builds
- `config/` - Application configuration files
- `data/` - Persistent data (consider using .gitignore for large files)
- `scripts/` - Helper scripts for container management

## Environment Variables

If you use environment variables, create a `.env` file:

```bash
# .env file example
APP_PORT=8080
DB_PASSWORD=your-secure-password
API_KEY=your-api-key
```

## Best Practices

- ✅ Use `.gitignore` for sensitive data and large files
- ✅ Use volume mounts for persistent data
- ✅ Set restart policies: `restart: unless-stopped`
- ✅ Use specific image tags instead of `latest`
- ✅ Document your services in comments

## Troubleshooting

### Docker Permission Denied

```bash
# Logout and login again, or reboot
sudo reboot

# Or manually refresh groups
newgrp docker
```

### Container Won't Start

```bash
# Check logs
docker-compose logs service-name

# Check Docker daemon
sudo systemctl status docker

# Check available space
df -h
```

### Port Conflicts

```bash
# Check what's using a port
sudo ss -tlnp | grep :8080

# Find Docker containers using ports
docker ps --format "table {{.Names}}\t{{.Ports}}"
```
