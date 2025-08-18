#!/usr/bin/env python3
import socket
import re
import shutil
import os
from datetime import datetime

UDP_PORT = 4210
HOSTS_PATH = "/etc/hosts"  # Fixed: was /mnt/host_etc_hosts
BACKUP_DIR = "/var/log/shackmate"  # Different path for container

# Ensure backup directory exists
os.makedirs(BACKUP_DIR, exist_ok=True)

def backup_hosts_file():
    """Create a backup of the hosts file before modifying it"""
    try:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_path = f"{BACKUP_DIR}/hosts.backup.{timestamp}"
        shutil.copy2(HOSTS_PATH, backup_path)
        return backup_path
    except Exception as e:
        print(f"Warning: Failed to create backup: {e}")
        return None

def update_hosts_file(new_ip):
    """Safely update hosts file, preserving existing entries"""
    host_entry = f"{new_ip} shackmate.router"
    
    # Create backup before modifying
    backup_path = backup_hosts_file()
    if backup_path:
        print(f"📦 Created backup: {backup_path}")
    
    try:
        # Read existing hosts file
        existing_lines = []
        if os.path.exists(HOSTS_PATH):
            with open(HOSTS_PATH, "r") as f:
                existing_lines = f.readlines()
        
        # Remove any existing shackmate.router entries
        filtered_lines = []
        for line in existing_lines:
            if "shackmate.router" not in line.strip():
                filtered_lines.append(line)
        
        # Ensure the file ends with a newline before adding our entry
        if filtered_lines and not filtered_lines[-1].endswith('\n'):
            filtered_lines[-1] += '\n'
        
        # Add our entry
        filtered_lines.append(f"{host_entry}\n")
        
        # Write the updated file
        with open(HOSTS_PATH, "w") as f:
            f.writelines(filtered_lines)
        
        print(f"✅ Updated {HOSTS_PATH} with: {host_entry}")
        return True
        
    except Exception as e:
        print(f"❌ Failed to update {HOSTS_PATH}: {e}")
        
        # Attempt to restore from backup if we have one
        if backup_path and os.path.exists(backup_path):
            try:
                shutil.copy2(backup_path, HOSTS_PATH)
                print(f"🔄 Restored {HOSTS_PATH} from backup")
            except Exception as restore_error:
                print(f"❌ Failed to restore from backup: {restore_error}")
        
        return False

def cleanup_old_backups(max_backups=10):
    """Remove old backup files, keeping only the most recent ones"""
    try:
        backup_files = [f for f in os.listdir(BACKUP_DIR) if f.startswith("hosts.backup.")]
        backup_files.sort(reverse=True)  # Most recent first
        
        for old_backup in backup_files[max_backups:]:
            os.remove(os.path.join(BACKUP_DIR, old_backup))
            print(f"🗑️  Removed old backup: {old_backup}")
    except Exception as e:
        print(f"Warning: Failed to cleanup old backups: {e}")

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
sock.bind(('', UDP_PORT))

print(f"🎧 ShackMate UDP Listener (Docker) started on port {UDP_PORT}")
print(f"📁 Hosts file: {HOSTS_PATH}")
print(f"💾 Backups: {BACKUP_DIR}")
print("Waiting for router discovery packets...")

try:
    while True:
        data, addr = sock.recvfrom(4096)
        message = data.decode(errors='replace')
        print(f"📨 Received from {addr}: {message}")

        match = re.search(r'ShackMate,(\d+\.\d+\.\d+\.\d+),\d+', message)
        if match:
            ip = match.group(1)
            print(f"🎯 Extracted IP: {ip}")
            
            if update_hosts_file(ip):
                # Clean up old backups periodically
                cleanup_old_backups()
        else:
            print(f"⚠️  Message format not recognized: {message}")

except KeyboardInterrupt:
    print("\n🛑 ShackMate UDP Listener stopped by user")
except Exception as e:
    print(f"❌ Unexpected error: {e}")
finally:
    sock.close()
    print("🔌 Socket closed")
