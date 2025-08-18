#!/bin/bash

# Chromium Launch Diagnostic Script
# Checks for issues that might prevent Chromium from launching

echo "🔍 Chromium Launch Diagnostics"
echo "============================="
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "⚠️  Running as root - this script should be run as regular user"
   echo "   Try: su - yourusername -c './chromium-diagnostics.sh'"
   echo ""
fi

# Check display environment
echo "🖥️  Display Environment:"
echo "   DISPLAY: ${DISPLAY:-Not Set}"
echo "   WAYLAND_DISPLAY: ${WAYLAND_DISPLAY:-Not Set}"
echo "   XDG_SESSION_TYPE: ${XDG_SESSION_TYPE:-Not Set}"
echo ""

# Check if Chromium is installed
echo "📦 Chromium Installation:"
if command -v chromium-browser >/dev/null 2>&1; then
    echo "   ✅ chromium-browser found: $(which chromium-browser)"
elif command -v chromium >/dev/null 2>&1; then
    echo "   ✅ chromium found: $(which chromium)"
else
    echo "   ❌ Chromium not found in PATH"
fi
echo ""

# Check essential services
echo "🔧 Essential Services Status:"
services=("getty@tty1.service" "console-setup.service" "plymouth-start.service" "lightdm.service" "gdm.service")

for service in "${services[@]}"; do
    if systemctl list-unit-files | grep -q "^$service"; then
        status=$(systemctl is-enabled "$service" 2>/dev/null || echo "not-found")
        active=$(systemctl is-active "$service" 2>/dev/null || echo "inactive")
        echo "   $service: $status ($active)"
    fi
done
echo ""

# Check current boot parameters
echo "🥾 Current Boot Parameters:"
if [ -f /proc/cmdline ]; then
    echo "   $(cat /proc/cmdline)"
else
    echo "   ❌ Cannot read /proc/cmdline"
fi
echo ""

# Check graphics/display
echo "🎮 Graphics Information:"
if command -v lspci >/dev/null 2>&1; then
    gpu_info=$(lspci | grep -i "vga\|3d\|display" | head -1)
    echo "   GPU: ${gpu_info:-Not detected}"
else
    echo "   ⚠️  lspci not available"
fi

if [ -d /dev/dri ]; then
    echo "   ✅ DRI devices: $(ls /dev/dri/ 2>/dev/null | tr '\n' ' ')"
else
    echo "   ❌ No DRI devices found"
fi
echo ""

# Check X11/Wayland
echo "🪟 Display Server:"
if pgrep -x "Xorg" >/dev/null; then
    echo "   ✅ X11 (Xorg) is running"
elif pgrep -x "X" >/dev/null; then
    echo "   ✅ X11 is running"
elif pgrep -x "weston" >/dev/null; then
    echo "   ✅ Wayland (Weston) is running"
elif pgrep -x "gnome-shell" >/dev/null; then
    echo "   ✅ Wayland (GNOME) is running"
else
    echo "   ❌ No display server detected"
fi
echo ""

# Try launching Chromium with verbose output
echo "🚀 Chromium Launch Test:"
echo "   Attempting to launch Chromium with debug output..."
echo ""

if command -v chromium-browser >/dev/null 2>&1; then
    timeout 10s chromium-browser --no-sandbox --disable-gpu --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-test --disable-extensions --disable-plugins 2>&1 | head -20
elif command -v chromium >/dev/null 2>&1; then
    timeout 10s chromium --no-sandbox --disable-gpu --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-test --disable-extensions --disable-plugins 2>&1 | head -20
else
    echo "   ❌ Chromium not found"
fi

echo ""
echo "🔧 Recommendations:"
echo ""
echo "If Chromium won't launch, try:"
echo "1. Run the boot recovery script:"
echo "   curl -sSL https://raw.githubusercontent.com/ShackMate/ShackMate-HMI/main/fix-boot-issues.sh | sudo bash"
echo ""
echo "2. Re-enable essential services:"
echo "   sudo systemctl enable getty@tty1.service"
echo "   sudo systemctl unmask console-setup.service"
echo ""
echo "3. Check if desktop environment is running:"
echo "   ps aux | grep -E 'lxde|xfce|gnome|kde'"
echo ""
echo "4. Try launching Chromium manually:"
echo "   chromium-browser --no-sandbox --disable-gpu"
echo ""

# Clean up test directory
rm -rf /tmp/chrome-test 2>/dev/null
