#!/data/data/com.termux/files/usr/bin/bash

#==============================================================================
# Service Status Checker
# Description: Displays status of all streaming server services
#==============================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

check_service() {
    local name="$1"
    local process="$2"
    local port="$3"
    
    echo -n "  $name: "
    
    if pgrep -f "$process" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Running${NC}"
        if [ -n "$port" ]; then
            if nc -z localhost "$port" 2>/dev/null; then
                echo -e "    ${BLUE}Port $port: Open${NC}"
            else
                echo -e "    ${RED}Port $port: Closed${NC}"
            fi
        fi
    else
        echo -e "${RED}✗ Stopped${NC}"
    fi
}

clear
echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              Streaming Server Status                       ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${YELLOW}Services:${NC}"
check_service "SSH Server" "sshd" "8022"
check_service "Nginx Proxy" "nginx" "8080"
check_service "MistServer" "MistController" "4242"
check_service "Cloudflare Tunnel" "cloudflared" ""
check_service "File Browser" "filebrowser" "9999"

echo
echo -e "${YELLOW}System Information:${NC}"
echo -e "  Username: ${BLUE}$(whoami)${NC}"
echo -e "  IP Address: ${BLUE}$(ifconfig 2>/dev/null | grep -A 1 "wlan0" | grep "inet " | awk '{print $2}')${NC}"
echo -e "  Uptime: ${BLUE}$(uptime -p)${NC}"

echo
echo -e "${YELLOW}Resource Usage:${NC}"
echo -e "  CPU: ${BLUE}$(top -bn1 | grep "CPU:" | awk '{print $2}')${NC}"
echo -e "  Memory: ${BLUE}$(free -h | awk '/Mem:/ {printf "%s / %s (%.1f%%)", $3, $2, $3/$2*100}')${NC}"

echo
echo -e "${YELLOW}Quick Actions:${NC}"
echo "  restart-all      - Restart all services"
echo "  restart-nginx    - Restart Nginx only"
echo "  restart-mist     - Restart MistServer only"
echo "  logs            - View recent logs"
echo

# Check for issues
echo -e "${YELLOW}Health Check:${NC}"

issues=0

if ! pgrep -x "sshd" > /dev/null; then
    echo -e "  ${RED}⚠${NC} SSH is not running"
    issues=$((issues + 1))
fi

if ! pgrep -x "nginx" > /dev/null; then
    echo -e "  ${RED}⚠${NC} Nginx is not running"
    issues=$((issues + 1))
fi

if ! pgrep -f "MistController" > /dev/null; then
    echo -e "  ${RED}⚠${NC} MistServer is not running"
    issues=$((issues + 1))
fi

# Check if wake lock is active
if ! dumpsys battery | grep -q "wake_lock.*termux" 2>/dev/null; then
    echo -e "  ${YELLOW}⚠${NC} Wake lock might not be active (run: termux-wake-lock)"
    issues=$((issues + 1))
fi

if [ $issues -eq 0 ]; then
    echo -e "  ${GREEN}✓ All systems operational${NC}"
fi

echo
