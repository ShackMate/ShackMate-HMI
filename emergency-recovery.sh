#!/bin/bash

# Emergency Recovery Script for ShackMate Pi Boot Loop
# This script will help diagnose and fix the kiosk boot loop issue

echo "🚨 ShackMate Emergency Recovery"
echo "=============================="

# Variables
REMOTE_HOST="10.146.1.254"
REMOTE_USER="sm"

echo "🔍 This script will:"
echo "   1. Connect to the Pi and disable auto-start kiosk"
echo "   2. Check what's causing the boot loop"
echo "   3. Restore stable console-only boot"
echo "   4. Provide manual kiosk setup options"
echo ""

ssh ${REMOTE_USER}@${REMOTE_HOST} << 'EOF'
    echo "🛑 Emergency recovery mode activated..."
    
    # First, disable any auto-starting services
    echo "Disabling auto-start services..."
    sudo systemctl disable shackmate-kiosk.service 2>/dev/null || true
    sudo systemctl stop shackmate-kiosk.service 2>/dev/null || true
    
    # Remove the startx auto-launch from bashrc
    echo "Removing auto-startx from bashrc..."
    if [ -f ~/.bashrc ]; then
        # Create backup
        cp ~/.bashrc ~/.bashrc.backup
        # Remove the startx lines
        sed -i '/Auto-start kiosk mode/d' ~/.bashrc
        sed -i '/if.*DISPLAY.*XDG_VTNR.*startx/d' ~/.bashrc
        sed -i '/exec startx/d' ~/.bashrc
    fi
    
    # Stop any running Docker containers that might be causing issues
    echo "Stopping Docker containers..."
    cd ~/docker 2>/dev/null && docker-compose down 2>/dev/null || true
    
    # Check system status
    echo ""
    echo "📊 System Status Check:"
    echo "======================="
    
    echo "🔋 System load:"
    uptime
    
    echo ""
    echo "💾 Memory usage:"
    free -h
    
    echo ""
    echo "🐳 Docker status:"
    docker ps 2>/dev/null || echo "Docker not running or accessible"
    
    echo ""
    echo "📋 Recent system logs (last 20 lines):"
    sudo journalctl -n 20 --no-pager
    
    echo ""
    echo "🖥️ Display/X11 related processes:"
    ps aux | grep -E "(X|chromium|startx)" | grep -v grep || echo "No display processes found"
    
    echo ""
    echo "📁 Checking for problematic files:"
    ls -la ~/.xinitrc 2>/dev/null && echo "xinitrc found" || echo "No xinitrc"
    ls -la /etc/systemd/system/shackmate-kiosk.service 2>/dev/null && echo "Kiosk service found" || echo "No kiosk service"
    
    echo ""
    echo "🔧 Recovery Actions Taken:"
    echo "========================="
    echo "✅ Disabled shackmate-kiosk service"
    echo "✅ Removed auto-startx from bashrc"
    echo "✅ Stopped Docker containers"
    echo "✅ System should boot to console normally now"
    
    echo ""
    echo "🔄 Rebooting to console mode..."
    echo "The Pi will restart in console-only mode."
    echo "After reboot, you can SSH back in safely."
    
    sudo reboot

EOF

echo ""
echo "🎯 Recovery Process Complete!"
echo ""
echo "📋 What happened:"
echo "   - Disabled all auto-starting kiosk services"
echo "   - Removed auto-startx from login"
echo "   - Stopped problematic Docker containers"
echo "   - Pi is rebooting to safe console mode"
echo ""
echo "⏱️ Wait 1-2 minutes, then SSH back in:"
echo "   ssh sm@10.146.1.254"
echo ""
echo "🔧 After recovery, you can:"
echo "   1. Check Docker containers manually"
echo "   2. Test kiosk mode step-by-step"
echo "   3. Use safer kiosk configuration"
