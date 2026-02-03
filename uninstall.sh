#!/data/data/com.termux/files/usr/bin/bash

#==============================================================================
# Android Streaming Server - Uninstaller
# Version: 1.0.0
# Description: Removes all installed components and restores backups
#==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║              Streaming Server Uninstaller                 ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${YELLOW}This will remove:${NC}"
echo "  • Stop all running services"
echo "  • Remove configuration files"
echo "  • Optionally remove packages"
echo "  • Restore backups (if available)"
echo

read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Uninstallation cancelled."
    exit 0
fi

echo

# Stop services
echo -e "${BLUE}Stopping services...${NC}"
pkill -f MistController 2>/dev/null && echo "✓ MistServer stopped"
nginx -s stop 2>/dev/null && echo "✓ Nginx stopped"
pkill sshd 2>/dev/null && echo "✓ SSH stopped"
pkill cloudflared 2>/dev/null && echo "✓ Cloudflare Tunnel stopped"
tmux kill-session -t fb_session 2>/dev/null && echo "✓ File Browser stopped"

# Release wake lock
termux-wake-unlock 2>/dev/null && echo "✓ Wake lock released"

echo

# Find and list backups
echo -e "${BLUE}Looking for backups...${NC}"
backups=$(find ~/ -maxdepth 1 -type d -name "streaming_server_backup_*" 2>/dev/null)

if [ -n "$backups" ]; then
    echo "Found backups:"
    echo "$backups" | nl
    echo
    read -p "Restore from backup? (y/n): " restore
    
    if [ "$restore" = "y" ]; then
        latest_backup=$(echo "$backups" | tail -1)
        echo -e "${YELLOW}Restoring from: $latest_backup${NC}"
        
        [ -f "$latest_backup/nginx.conf" ] && cp "$latest_backup/nginx.conf" "$PREFIX/etc/nginx/nginx.conf" && echo "✓ Nginx config restored"
        [ -f "$latest_backup/websites" ] && cp "$latest_backup/websites" "$PREFIX/etc/nginx/websites" && echo "✓ Websites file restored"
        [ -f "$latest_backup/.bashrc" ] && cp "$latest_backup/.bashrc" "$HOME/.bashrc" && echo "✓ .bashrc restored"
        [ -f "$latest_backup/start_mist.sh" ] && cp "$latest_backup/start_mist.sh" "$HOME/start_mist.sh" && echo "✓ start_mist.sh restored"
    fi
else
    echo "No backups found."
fi

echo

# Remove configuration files
echo -e "${BLUE}Removing configuration files...${NC}"
rm -f "$HOME/start_mist.sh" && echo "✓ Removed start_mist.sh"
rm -f "$PREFIX/etc/nginx/websites" && echo "✓ Removed websites whitelist"

# Ask about .bashrc
read -p "Remove custom .bashrc? (y/n): " remove_bashrc
if [ "$remove_bashrc" = "y" ]; then
    rm -f "$HOME/.bashrc"
    echo "✓ Removed .bashrc"
    echo "  Run 'cp /etc/bash.bashrc ~/.bashrc' to restore default"
fi

echo

# Ask about packages
echo -e "${YELLOW}Remove installed packages?${NC}"
echo "This will remove: nginx, openssh, proot-distro, tmux, cloudflared"
read -p "Continue? (y/n): " remove_pkgs

if [ "$remove_pkgs" = "y" ]; then
    echo -e "${BLUE}Removing packages...${NC}"
    pkg uninstall -y nginx openssh proot-distro tmux cloudflared 2>/dev/null
    echo "✓ Packages removed"
fi

echo

# Ask about Ubuntu
read -p "Remove Ubuntu container (will delete MistServer)? (y/n): " remove_ubuntu
if [ "$remove_ubuntu" = "y" ]; then
    proot-distro remove ubuntu 2>/dev/null
    echo "✓ Ubuntu container removed"
fi

echo

# Clean up logs
read -p "Remove installation logs? (y/n): " remove_logs
if [ "$remove_logs" = "y" ]; then
    rm -f ~/install_*.log ~/quick_install_*.log 2>/dev/null
    echo "✓ Logs removed"
fi

echo
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Uninstallation Complete!                     ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "${BLUE}What was preserved:${NC}"
echo "  • Backup directories (if any)"
echo "  • User data in Termux home"
echo "  • Network settings"
echo
echo -e "${YELLOW}To completely reset, you may also want to:${NC}"
echo "  • Clear Termux data in Android settings"
echo "  • Remove port forwarding rules from router"
echo
