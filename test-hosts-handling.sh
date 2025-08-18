#!/bin/bash

# Test script to verify UDP listener hosts file handling
# This script tests that existing hosts entries are preserved

echo "🧪 Testing UDP Listener Hosts File Handling"
echo "============================================"
echo ""

# Create test hosts file
TEST_HOSTS="/tmp/test_hosts"
echo "Creating test hosts file with existing entries..."

cat > "$TEST_HOSTS" << 'EOF'
127.0.0.1	localhost
::1		localhost ip6-localhost ip6-loopback
ff02::1		ip6-allnodes
ff02::2		ip6-allrouters

# Custom entries
192.168.1.1    router.local
10.0.0.100     server.local
EOF

echo "📋 Original hosts file:"
cat "$TEST_HOSTS"
echo ""

# Create a modified version of UDP listener for testing
TEST_SCRIPT="/tmp/test_udp_listener.py"
cat > "$TEST_SCRIPT" << 'EOF'
#!/usr/bin/env python3
import os
import shutil
from datetime import datetime

HOSTS_PATH = "/tmp/test_hosts"
BACKUP_DIR = "/tmp/backups"

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
        
        print(f"📖 Read {len(existing_lines)} lines from hosts file")
        
        # Remove any existing shackmate.router entries
        filtered_lines = []
        removed_count = 0
        for line in existing_lines:
            if "shackmate.router" not in line.strip():
                filtered_lines.append(line)
            else:
                removed_count += 1
        
        if removed_count > 0:
            print(f"🗑️  Removed {removed_count} old shackmate.router entries")
        
        # Ensure the file ends with a newline before adding our entry
        if filtered_lines and not filtered_lines[-1].endswith('\n'):
            filtered_lines[-1] += '\n'
        
        # Add our entry
        filtered_lines.append(f"{host_entry}\n")
        
        # Write the updated file
        with open(HOSTS_PATH, "w") as f:
            f.writelines(filtered_lines)
        
        print(f"✅ Updated {HOSTS_PATH} with: {host_entry}")
        print(f"📝 Final file has {len(filtered_lines)} lines")
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

# Test the function
print("🧪 Testing with IP: 192.168.1.200")
update_hosts_file("192.168.1.200")

print("\n📋 Updated hosts file:")
with open(HOSTS_PATH, "r") as f:
    print(f.read())

print("🧪 Testing update with different IP: 10.146.1.254")
update_hosts_file("10.146.1.254")

print("\n📋 Final hosts file:")
with open(HOSTS_PATH, "r") as f:
    content = f.read()
    print(content)

# Verify original entries are preserved
print("🔍 Verification:")
if "127.0.0.1	localhost" in content:
    print("✅ localhost entry preserved")
else:
    print("❌ localhost entry missing!")

if "192.168.1.1    router.local" in content:
    print("✅ router.local entry preserved")
else:
    print("❌ router.local entry missing!")

if "10.146.1.254 shackmate.router" in content:
    print("✅ shackmate.router entry updated correctly")
else:
    print("❌ shackmate.router entry missing or incorrect!")

# Count shackmate.router entries
shackmate_count = content.count("shackmate.router")
if shackmate_count == 1:
    print("✅ Only one shackmate.router entry (no duplicates)")
else:
    print(f"❌ Found {shackmate_count} shackmate.router entries (should be 1)!")
EOF

# Run the test
echo "🚀 Running hosts file preservation test..."
python3 "$TEST_SCRIPT"

echo ""
echo "🧹 Cleanup..."
rm -f "$TEST_SCRIPT" "$TEST_HOSTS"
rm -rf /tmp/backups

echo "✅ Test completed!"
