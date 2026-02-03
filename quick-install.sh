#!/data/data/com.termux/files/usr/bin/bash

#==============================================================================
# Android Streaming Server - Quick Install (Unattended)
# Version: 1.0.0
# Description: Fully automated installation with default settings
#==============================================================================

set +e

# Default settings
DEFAULT_PASSWORD="streaming123"
DEFAULT_DOMAINS="localhost:8888"
INSTALL_CLOUDFLARE=false
INSTALL_FILEBROWSER=false

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Log file
LOGFILE="$HOME/quick_install_$(date +%Y%m%d_%H%M%S).log"

log() {
    echo -e "${GREEN}[$(date +%H:%M:%S)]${NC} $1" | tee -a "$LOGFILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOGFILE"
}

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║        Quick Install - Fully Automated Setup              ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

log "Starting quick installation with default settings..."
log "Log: $LOGFILE"

# Update and install packages
log "Installing packages..."
pkg update -y >> "$LOGFILE" 2>&1
pkg install -y openssh nginx proot-distro >> "$LOGFILE" 2>&1

# Set password
log "Setting default password (streaming123)..."
echo -e "$DEFAULT_PASSWORD\n$DEFAULT_PASSWORD" | passwd >> "$LOGFILE" 2>&1

# Start SSH
sshd >> "$LOGFILE" 2>&1

# Install Ubuntu
log "Installing Ubuntu container..."
proot-distro install ubuntu >> "$LOGFILE" 2>&1

# Install MistServer
log "Installing MistServer..."
proot-distro login ubuntu -- bash -c "apt update && apt install -y curl" >> "$LOGFILE" 2>&1
proot-distro login ubuntu -- bash -c "curl -o - https://releases.mistserver.org/is/mistserver_aarch64V3.10.tar.gz 2>/dev/null | sh" >> "$LOGFILE" 2>&1

# Configure Nginx (using the same config as interactive installer)
log "Configuring Nginx..."
cat > "$PREFIX/etc/nginx/nginx.conf" << 'EOF'
worker_processes auto;
events {
    worker_connections 1024;
}
http {
    include mime.types;
    default_type application/octet-stream;
    map_hash_bucket_size 64;
    sendfile on;
    keepalive_timeout 65;
    resolver 8.8.8.8 1.1.1.1 valid=300s;
    resolver_timeout 5s;
    map $request_uri $target_host_extracted {
        "~^/live/(?:https?://)?(?<extracted>[^/]+)" $extracted;
        default "";
    }
    map $target_host_extracted $is_allowed {
        default 0;
        include websites;
    }
    server {
        listen 8080;
        location / {
            root /data/data/com.termux/files/usr/share/nginx/html;
            index index.html;
        }
        location ~* ^/live/(?:https?://)?(?<target_addr>[0-9.:a-zA-Z-]+)/(?<target_path>.*)$ {
            if ($is_allowed = 0) {
                return 403 "Access Denied";
            }
            proxy_pass http://$target_addr/$target_path$is_args$args;
            proxy_buffering off;
            proxy_request_buffering off;
            proxy_http_version 1.1;
            proxy_set_header Host $target_addr;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_hide_header 'Access-Control-Allow-Origin';
            if ($request_method = 'OPTIONS') {
                add_header 'Access-Control-Allow-Origin' '*' always;
                add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS' always;
                return 204;
            }
            add_header 'Access-Control-Allow-Origin' '*' always;
        }
    }
}
EOF

echo "localhost:8888 1;" > "$PREFIX/etc/nginx/websites"

nginx >> "$LOGFILE" 2>&1

# Create startup scripts
log "Creating startup scripts..."
cat > "$HOME/start_mist.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/sh
if pgrep -f "MistController" > /dev/null; then
    exit 0
fi
nohup proot-distro login ubuntu -- MistController > /dev/null 2>&1 &
EOF
chmod +x "$HOME/start_mist.sh"

cat > "$HOME/.bashrc" << 'EOF'
termux-wake-lock
if ! pgrep -x "sshd" > /dev/null; then sshd; fi
if ! pgrep -x "nginx" > /dev/null; then nginx; fi
if ! pgrep -f "MistController" > /dev/null; then ~/start_mist.sh > /dev/null 2>&1 &; fi
alias nr='nginx -s reload'
EOF

echo -e "${GREEN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                 Installation Complete!                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo
echo -e "SSH: ssh -p 8022 $(whoami)@$(ifconfig 2>/dev/null | grep -A 1 "wlan0" | grep "inet " | awk '{print $2}')"
echo -e "Password: ${BLUE}streaming123${NC}"
echo -e "Nginx: http://$(ifconfig 2>/dev/null | grep -A 1 "wlan0" | grep "inet " | awk '{print $2}'):8080"
echo -e "MistServer: http://$(ifconfig 2>/dev/null | grep -A 1 "wlan0" | grep "inet " | awk '{print $2}'):4242"
echo
echo -e "${BLUE}Log saved to: $LOGFILE${NC}"
echo -e "${RED}⚠️  Change the default password: passwd${NC}"
