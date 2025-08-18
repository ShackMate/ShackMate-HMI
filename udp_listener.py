#!/usr/bin/env python3
import socket
import re

UDP_PORT = 4210
HOSTS_PATH = "/etc/hosts"

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
sock.bind(('', UDP_PORT))

print(f"Listening for UDP packets on port {UDP_PORT}...")

try:
    while True:
        data, addr = sock.recvfrom(4096)
        message = data.decode(errors='replace')
        print(f"Received from {addr}: {message}")

        match = re.search(r'ShackMate,(\d+\.\d+\.\d+\.\d+),\d+', message)
        if match:
            ip = match.group(1)
            host_entry = f"{ip} shackmate.router\n"

            # Read existing host file
            try:
                with open(HOSTS_PATH, "r") as f:
                    lines = f.readlines()
            except Exception as e:
                print(f"Failed to read {HOSTS_PATH}: {e}")
                continue

            # Remove old entries
            lines = [line for line in lines if "shackmate.router" not in line]

            # Append new entry
            lines.append(host_entry)

            # Write back
            try:
                with open(HOSTS_PATH, "w") as f:
                    f.writelines(lines)
                print(f"✅ Updated {HOSTS_PATH} with: {host_entry.strip()}")
            except Exception as e:
                print(f"Failed to write to {HOSTS_PATH}: {e}")
except KeyboardInterrupt:
    print("\nStopped listening.")
finally:
    sock.close()
