#!/bin/bash

# NVMe Drive Formatter for Raspberry Pi
# This script helps safely format and mount NVMe drives

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

echo "NVMe Drive Formatter for Raspberry Pi"
echo "====================================="
echo ""

# Step 1: Detect NVMe drives
print_status "Scanning for NVMe drives..."
echo ""

# List all NVMe drives
NVME_DRIVES=$(lsblk -d -o NAME,SIZE,MODEL | grep nvme || true)

if [ -z "$NVME_DRIVES" ]; then
    print_error "No NVMe drives detected!"
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Check if NVMe drive is properly connected"
    echo "2. Check if NVMe HAT/adapter is properly seated"
    echo "3. Check Raspberry Pi configuration:"
    echo "   - Run: grep dtparam=pciex1 /boot/firmware/config.txt"
    echo "   - Should show: dtparam=pciex1=on"
    echo "4. Check dmesg for PCIe errors: dmesg | grep -i nvme"
    exit 1
fi

echo "Detected NVMe drives:"
echo "===================="
echo "NAME     SIZE   MODEL"
echo "$NVME_DRIVES"
echo ""

# Step 2: Show current disk usage
print_status "Current disk layout:"
echo ""
lsblk -f
echo ""

# Step 3: Let user select drive
echo "Available NVMe drives:"
DRIVE_LIST=$(lsblk -d -o NAME | grep nvme | sed 's/^/\/dev\//')
DRIVE_ARRAY=($DRIVE_LIST)

if [ ${#DRIVE_ARRAY[@]} -eq 0 ]; then
    print_error "No NVMe drives found in /dev/"
    exit 1
fi

echo ""
for i in "${!DRIVE_ARRAY[@]}"; do
    DRIVE="${DRIVE_ARRAY[$i]}"
    SIZE=$(lsblk -d -o SIZE "$DRIVE" | tail -n1)
    MODEL=$(lsblk -d -o MODEL "$DRIVE" | tail -n1 | xargs)
    echo "$((i+1)). $DRIVE ($SIZE) - $MODEL"
done

echo ""
read -p "Select drive to format (1-${#DRIVE_ARRAY[@]}): " CHOICE

if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt ${#DRIVE_ARRAY[@]} ]; then
    print_error "Invalid selection"
    exit 1
fi

SELECTED_DRIVE="${DRIVE_ARRAY[$((CHOICE-1))]}"
print_status "Selected drive: $SELECTED_DRIVE"

# Step 4: Show drive information
echo ""
print_status "Drive information:"
echo "=================="
lsblk -f "$SELECTED_DRIVE" 2>/dev/null || lsblk "$SELECTED_DRIVE"
echo ""

# Check if drive is mounted
MOUNTED=$(mount | grep "$SELECTED_DRIVE" || true)
if [ -n "$MOUNTED" ]; then
    print_warning "Drive is currently mounted:"
    echo "$MOUNTED"
    echo ""
    read -p "Unmount before formatting? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Unmounting partitions..."
        umount "${SELECTED_DRIVE}"* 2>/dev/null || true
        print_success "Drive unmounted"
    else
        print_error "Cannot format mounted drive"
        exit 1
    fi
fi

# Step 5: Final confirmation
echo ""
print_warning "WARNING: This will COMPLETELY ERASE all data on $SELECTED_DRIVE"
echo ""
echo "Drive details:"
echo "=============="
DRIVE_SIZE=$(lsblk -d -o SIZE "$SELECTED_DRIVE" | tail -n1)
DRIVE_MODEL=$(lsblk -d -o MODEL "$SELECTED_DRIVE" | tail -n1 | xargs)
echo "Device: $SELECTED_DRIVE"
echo "Size: $DRIVE_SIZE"
echo "Model: $DRIVE_MODEL"
echo ""

read -p "Are you absolutely sure you want to format this drive? Type 'FORMAT' to confirm: " CONFIRM

if [ "$CONFIRM" != "FORMAT" ]; then
    print_status "Operation cancelled by user"
    exit 0
fi

# Step 6: Choose filesystem type
echo ""
print_status "Select filesystem type:"
echo "======================="
echo "1. ext4 (recommended for Linux)"
echo "2. exfat (cross-platform compatibility)"
echo "3. ntfs (Windows compatibility)"
echo "4. btrfs (advanced features, snapshots)"
echo ""
read -p "Select filesystem (1-4): " FS_CHOICE

case $FS_CHOICE in
    1)
        FILESYSTEM="ext4"
        MKFS_CMD="mkfs.ext4 -F"
        ;;
    2)
        FILESYSTEM="exfat"
        MKFS_CMD="mkfs.exfat"
        # Install exfat tools if needed
        if ! command -v mkfs.exfat >/dev/null 2>&1; then
            print_status "Installing exfat-utils..."
            apt update && apt install -y exfat-utils
        fi
        ;;
    3)
        FILESYSTEM="ntfs"
        MKFS_CMD="mkfs.ntfs -f"
        # Install ntfs tools if needed
        if ! command -v mkfs.ntfs >/dev/null 2>&1; then
            print_status "Installing ntfs-3g..."
            apt update && apt install -y ntfs-3g
        fi
        ;;
    4)
        FILESYSTEM="btrfs"
        MKFS_CMD="mkfs.btrfs -f"
        # Install btrfs tools if needed
        if ! command -v mkfs.btrfs >/dev/null 2>&1; then
            print_status "Installing btrfs-progs..."
            apt update && apt install -y btrfs-progs
        fi
        ;;
    *)
        print_error "Invalid filesystem selection"
        exit 1
        ;;
esac

# Step 7: Get label
echo ""
read -p "Enter volume label (optional, press Enter to skip): " VOLUME_LABEL

# Step 8: Partition and format
echo ""
print_status "Starting format process..."
echo ""

# Create partition table
print_status "Creating GPT partition table..."
parted -s "$SELECTED_DRIVE" mklabel gpt

# Create single partition using entire drive
print_status "Creating partition..."
parted -s "$SELECTED_DRIVE" mkpart primary 0% 100%

# Wait for kernel to recognize partition
sleep 2

# Get the partition device
PARTITION="${SELECTED_DRIVE}p1"
if [ ! -b "$PARTITION" ]; then
    PARTITION="${SELECTED_DRIVE}1"
fi

print_status "Formatting $PARTITION with $FILESYSTEM..."

# Format with or without label
if [ -n "$VOLUME_LABEL" ]; then
    case $FILESYSTEM in
        ext4)
            $MKFS_CMD -L "$VOLUME_LABEL" "$PARTITION"
            ;;
        exfat)
            $MKFS_CMD -n "$VOLUME_LABEL" "$PARTITION"
            ;;
        ntfs)
            $MKFS_CMD -L "$VOLUME_LABEL" "$PARTITION"
            ;;
        btrfs)
            $MKFS_CMD -L "$VOLUME_LABEL" "$PARTITION"
            ;;
    esac
else
    $MKFS_CMD "$PARTITION"
fi

print_success "Formatting completed!"

# Step 9: Mount and test
echo ""
print_status "Testing mount..."
MOUNT_POINT="/mnt/nvme_test"
mkdir -p "$MOUNT_POINT"

mount "$PARTITION" "$MOUNT_POINT"
print_success "Successfully mounted at $MOUNT_POINT"

# Test write
echo "test" > "$MOUNT_POINT/test_file.txt"
if [ -f "$MOUNT_POINT/test_file.txt" ]; then
    print_success "Write test successful"
    rm "$MOUNT_POINT/test_file.txt"
else
    print_error "Write test failed"
fi

umount "$MOUNT_POINT"
rmdir "$MOUNT_POINT"

# Step 10: Show final status
echo ""
print_success "NVMe drive formatting completed successfully!"
echo ""
echo "Drive information:"
echo "=================="
lsblk -f "$SELECTED_DRIVE"
echo ""

# Step 11: Auto-mount setup (optional)
echo ""
read -p "Would you like to set up automatic mounting at boot? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    read -p "Enter mount point (e.g., /mnt/nvme, /home/data): " MOUNT_POINT
    
    if [ -z "$MOUNT_POINT" ]; then
        MOUNT_POINT="/mnt/nvme"
    fi
    
    # Create mount point
    mkdir -p "$MOUNT_POINT"
    
    # Get UUID
    UUID=$(blkid -s UUID -o value "$PARTITION")
    
    if [ -n "$UUID" ]; then
        # Add to fstab
        echo "# NVMe drive auto-mount" >> /etc/fstab
        echo "UUID=$UUID $MOUNT_POINT $FILESYSTEM defaults,nofail 0 2" >> /etc/fstab
        
        # Test mount
        mount "$MOUNT_POINT"
        
        print_success "Auto-mount configured at $MOUNT_POINT"
        print_status "Added entry to /etc/fstab with UUID: $UUID"
        
        # Set ownership to user
        REAL_USER=${SUDO_USER:-pi}
        chown "$REAL_USER:$REAL_USER" "$MOUNT_POINT"
        print_success "Set ownership to $REAL_USER"
    else
        print_error "Could not get UUID for auto-mount setup"
    fi
fi

echo ""
print_success "NVMe setup completed!"
echo ""
echo "Summary:"
echo "========"
echo "Device: $SELECTED_DRIVE"
echo "Partition: $PARTITION"
echo "Filesystem: $FILESYSTEM"
if [ -n "$VOLUME_LABEL" ]; then
    echo "Label: $VOLUME_LABEL"
fi
if [ -n "$MOUNT_POINT" ]; then
    echo "Mount point: $MOUNT_POINT"
fi
echo ""
echo "You can now use your NVMe drive!"
