#!/data/data/com.termux/files/usr/bin/bash

#==============================================================================
# Android Streaming Server - Interactive Installer
# Version: 1.0.0
# Description: Automated setup for RTMP to HLS/SRT streaming server
#==============================================================================

set +e  # Continue on errors (we handle them manually)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log file
LOGFILE="$HOME/install_$(date +%Y%m%d_%H%M%S).log"
BACKUP_DIR="$HOME/streaming_server_backup_$(date +%Y%m%d_%H%M%S)"

#==============================================================================
# Helper Functions
#==============================================================================

log() {
    echo -e "${GREEN}[$(date +%H:%M:%S)]${NC} $1" | tee -a "$LOGFILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOGFILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOGFILE"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOGFILE"
}

print_header() {
    clear
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║     Android Streaming Server - Interactive Installer      ║"
    echo "║                                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

ask_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local answer
    
    if [ "$default" = "y" ]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi
    
    read -p "$prompt" answer
    answer=${answer:-$default}
    
    [[ "$answer" =~ ^[Yy]$ ]]
}

press_any_key() {
    read -n 1 -s -r -p "Press any key to continue..."
    echo
}

create_backup() {
    log_info "Creating backup of existing configurations..."
    mkdir -p "$BACKUP_DIR"
    
    # Backup existing configs if they exist
    [ -f "$PREFIX/etc/nginx/nginx.conf" ] && cp "$PREFIX/etc/nginx/nginx.conf" "$BACKUP_DIR/"
    [ -f "$PREFIX/etc/nginx/websites" ] && cp "$PREFIX/etc/nginx/websites" "$BACKUP_DIR/"
    [ -f "$HOME/.bashrc" ] && cp "$HOME/.bashrc" "$BACKUP_DIR/"
    [ -f "$HOME/start_mist.sh" ] && cp "$HOME/start_mist.sh" "$BACKUP_DIR/"
    
    log "Backup created at: $BACKUP_DIR"
}

#==============================================================================
# Installation Modules
#==============================================================================

install_base_packages() {
    log_info "Installing base packages (openssh, nginx)..."
    
    pkg update -y >> "$LOGFILE" 2>&1
    if [ $? -ne 0 ]; then
        log_error "Failed to update package list"
        return 1
    fi
    
    pkg install -y openssh nginx >> "$LOGFILE" 2>&1
    if [ $? -ne 0 ]; then
        log_error "Failed to install base packages"
        return 1
    fi
    
    log "✓ Base packages installed successfully"
    return 0
}

setup_ssh() {
    log_info "Setting up SSH server..."
    
    # Ask for password
    echo -e "\n${YELLOW}Please set a password for SSH access:${NC}"
    passwd
    
    if [ $? -ne 0 ]; then
        log_error "Failed to set password"
        return 1
    fi
    
    # Start SSH
    sshd >> "$LOGFILE" 2>&1
    
    # Get username and IP
    local username=$(whoami)
    local ip=$(ifconfig 2>/dev/null | grep -A 1 "wlan0" | grep "inet " | awk '{print $2}')
    
    log "✓ SSH server configured"
    log_info "You can now connect via: ssh -p 8022 $username@$ip"
    
    return 0
}

install_proot_ubuntu() {
    log_info "Installing PRoot and Ubuntu container..."
    
    pkg install -y proot-distro >> "$LOGFILE" 2>&1
    if [ $? -ne 0 ]; then
        log_error "Failed to install proot-distro"
        return 1
    fi
    
    log_info "Downloading Ubuntu (this may take a few minutes)..."
    proot-distro install ubuntu >> "$LOGFILE" 2>&1
    if [ $? -ne 0 ]; then
        log_error "Failed to install Ubuntu"
        return 1
    fi
    
    log "✓ PRoot Ubuntu installed successfully"
    return 0
}

install_mistserver() {
    log_info "Installing MistServer inside Ubuntu container..."
    
    # Install MistServer
    proot-distro login ubuntu -- bash -c "apt update && apt install -y curl" >> "$LOGFILE" 2>&1
    proot-distro login ubuntu -- bash -c "curl -o - https://releases.mistserver.org/is/mistserver_aarch64V3.10.tar.gz 2>/dev/null | sh" >> "$LOGFILE" 2>&1
    
    if [ $? -ne 0 ]; then
        log_error "Failed to install MistServer"
        return 1
    fi
    
    log "✓ MistServer installed successfully"
    return 0
}

configure_nginx() {
    log_info "Configuring Nginx proxy..."
    
    # Backup existing config
    [ -f "$PREFIX/etc/nginx/nginx.conf" ] && mv "$PREFIX/etc/nginx/nginx.conf" "$PREFIX/etc/nginx/nginx.conf.backup"
    
    # Create nginx.conf
    cat > "$PREFIX/etc/nginx/nginx.conf" << 'EOF'
worker_processes auto;

events {
    worker_connections 1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
     
    map_hash_bucket_size 64;
    sendfile        on;
    keepalive_timeout  65;
    
    # DNS resolver
    resolver 8.8.8.8 1.1.1.1 valid=300s;
    resolver_timeout 5s;
    
    # Extract target host from URL
    map $request_uri $target_host_extracted {
        "~^/live/(?:https?://)?(?<extracted>[^/]+)"  $extracted;
        default "";
    }
    
    # Verify against whitelist
    map $target_host_extracted $is_allowed {
        default 0;
        include websites;
    }
    
    server {
        listen 8080;
        
        # Main page
        location / {
            root /data/data/com.termux/files/usr/share/nginx/html;
            index index.html;
        }
        
        # Proxy configuration
        location ~* ^/live/(?:https?://)?(?<target_addr>[0-9.:a-zA-Z-]+)/(?<target_path>.*)$ {
            
            # Security check
            if ($is_allowed = 0) {
                return 403 "Access Denied: Domain not whitelisted";
            }
            
            # Dynamic proxying
            proxy_pass http://$target_addr/$target_path$is_args$args;
            
            # Streaming optimization
            proxy_buffering off;
            proxy_request_buffering off;
            proxy_http_version 1.1;
            
            # Headers
            proxy_set_header Host $target_addr;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # CORS headers
            proxy_hide_header 'Access-Control-Allow-Origin';
            proxy_hide_header 'Access-Control-Allow-Methods';
            proxy_hide_header 'Access-Control-Allow-Headers';
            
            if ($request_method = 'OPTIONS') {
                add_header 'Access-Control-Allow-Origin' '*' always;
                add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS, HEAD' always;
                add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range' always;
                add_header 'Access-Control-Max-Age' 1728000;
                add_header 'Content-Type' 'text/plain; charset=utf-8';
                add_header 'Content-Length' 0;
                return 204;
            }
            
            add_header 'Access-Control-Allow-Origin' '*' always;
            add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS, HEAD' always;
            add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range' always;
            add_header 'Access-Control-Expose-Headers' 'Content-Length,Content-Range' always;
        }
    } 
}
EOF
    
    log_info "Configuring whitelist domains..."
    
    # Ask for domains to whitelist
    echo -e "\n${YELLOW}Enter domains to whitelist (comma-separated, or press Enter for localhost only):${NC}"
    echo -e "${BLUE}Example: kgtv.ru,kgtv.online,cdn.example.com${NC}"
    read -p "> " domains_input
    
    # Create websites file
    cat > "$PREFIX/etc/nginx/websites" << 'EOF'
# Whitelisted domains
# Syntax: domain_name 1;

EOF
    
    # Add localhost by default
    echo "localhost:8888   1;" >> "$PREFIX/etc/nginx/websites"
    
    # Add user-provided domains
    if [ -n "$domains_input" ]; then
        IFS=',' read -ra DOMAINS <<< "$domains_input"
        for domain in "${DOMAINS[@]}"; do
            domain=$(echo "$domain" | xargs)  # Trim whitespace
            echo "$domain   1;" >> "$PREFIX/etc/nginx/websites"
            log_info "Added $domain to whitelist"
        done
    fi
    
    # Add option to allow all
    echo -e "\n${YELLOW}Allow ALL domains (not recommended for security)?${NC}"
    if ask_yes_no "Enable unrestricted proxy" "n"; then
        echo "~.*   1;" >> "$PREFIX/etc/nginx/websites"
        log_warning "Unrestricted proxy enabled (all domains allowed)"
    fi
    
    # Test nginx config
    nginx -t >> "$LOGFILE" 2>&1
    if [ $? -ne 0 ]; then
        log_error "Nginx configuration test failed"
        return 1
    fi
    
    # Start nginx
    nginx >> "$LOGFILE" 2>&1
    
    log "✓ Nginx configured and started"
    return 0
}

create_startup_scripts() {
    log_info "Creating startup scripts..."
    
    # Create start_mist.sh
    cat > "$HOME/start_mist.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/sh

# Check if MistController is already running
if pgrep -f "MistController" > /dev/null; then
    echo "MistServer is already running."
    exit 0
fi

# Start MistServer
nohup proot-distro login ubuntu -- MistController > /dev/null 2>&1 &

echo "MistServer started inside Ubuntu (proot)!"
EOF
    
    chmod +x "$HOME/start_mist.sh"
    
    # Backup existing .bashrc
    [ -f "$HOME/.bashrc" ] && cp "$HOME/.bashrc" "$HOME/.bashrc.backup"
    
    # Create .bashrc with auto-start
    cat > "$HOME/.bashrc" << 'BASHRC_EOF'
# Auto-start services for Android Streaming Server

# Wake Lock (prevents CPU from sleeping)
termux-wake-lock

# SSH Server
if ! pgrep -x "sshd" > /dev/null; then
    sshd
    echo "SSH Server started."
fi

# Nginx
if ! pgrep -x "nginx" > /dev/null; then
    nginx
    echo "Nginx Proxy started."
fi

# MistServer (via start_mist.sh)
if ! pgrep -f "MistController" > /dev/null; then
    ~/start_mist.sh > /dev/null 2>&1 &
    echo "MistServer startup script executed."
fi
BASHRC_EOF
    
    log "✓ Startup scripts created"
    return 0
}

install_cloudflare_tunnel() {
    log_info "Installing Cloudflare Tunnel..."
    
    pkg install -y cloudflared >> "$LOGFILE" 2>&1
    if [ $? -ne 0 ]; then
        log_error "Failed to install cloudflared"
        return 1
    fi
    
    log "✓ Cloudflared installed"
    log_info "To configure Cloudflare Tunnel, run:"
    log_info "  cloudflared tunnel login"
    log_info "  cloudflared tunnel create redmi-server"
    
    # Add to .bashrc
    cat >> "$HOME/.bashrc" << 'EOF'

# Cloudflare Tunnel
if ! pgrep -x "cloudflared" > /dev/null; then
    nohup cloudflared tunnel run redmi-server > /dev/null 2>&1 &
    echo "Cloudflare Tunnel started."
fi
EOF
    
    return 0
}

install_filebrowser() {
    log_info "Installing File Browser..."
    
    # Install tmux first
    pkg install -y tmux >> "$LOGFILE" 2>&1
    if [ $? -ne 0 ]; then
        log_error "Failed to install tmux"
        return 1
    fi
    
    # Install filebrowser in Ubuntu
    proot-distro login ubuntu -- bash -c "curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash" >> "$LOGFILE" 2>&1
    if [ $? -ne 0 ]; then
        log_error "Failed to install File Browser"
        return 1
    fi
    
    log "✓ File Browser installed"
    
    # Add to .bashrc
    cat >> "$HOME/.bashrc" << 'EOF'

# File Browser (via tmux)
if ! pgrep -f "filebrowser" > /dev/null; then
    tmux new-session -d -s fb_session 'proot-distro login ubuntu -- filebrowser -d /root/filebrowser.db -p 9999 -a 0.0.0.0'
    echo "File Browser started on port 9999."
fi
EOF
    
    log_info "File Browser will be available at: http://YOUR_IP:9999"
    log_info "Default credentials - Username: admin, Password: admin"
    
    return 0
}

add_useful_aliases() {
    log_info "Adding useful command aliases..."
    
    cat >> "$HOME/.bashrc" << 'EOF'

# Useful aliases
alias nr='nginx -s reload'
alias check-status='echo "=== Services ===" && pgrep -x sshd > /dev/null && echo "SSH: Running" || echo "SSH: Stopped" && pgrep -x nginx > /dev/null && echo "Nginx: Running" || echo "Nginx: Stopped" && pgrep -f MistController > /dev/null && echo "MistServer: Running" || echo "MistServer: Stopped"'
EOF
    
    log "✓ Aliases added"
    return 0
}

#==============================================================================
# Main Installation Flow
#==============================================================================

main() {
    print_header
    
    log "Starting installation..."
    log "Log file: $LOGFILE"
    echo
    
    # Welcome message
    echo -e "${GREEN}Welcome to the Android Streaming Server installer!${NC}"
    echo -e "This script will set up:"
    echo -e "  • SSH server for remote access"
    echo -e "  • Nginx reverse proxy with CORS support"
    echo -e "  • MistServer for RTMP/HLS/SRT streaming"
    echo -e "  • Auto-start configuration"
    echo
    
    if ! ask_yes_no "Do you want to continue" "y"; then
        log "Installation cancelled by user"
        exit 0
    fi
    
    echo
    
    # Create backup
    create_backup
    echo
    
    # Install base packages
    if ! install_base_packages; then
        log_error "Base package installation failed, but continuing..."
    fi
    echo
    
    # Setup SSH
    if ! setup_ssh; then
        log_error "SSH setup failed, but continuing..."
    fi
    echo
    
    # Install PRoot Ubuntu
    if ! install_proot_ubuntu; then
        log_error "PRoot installation failed, but continuing..."
    fi
    echo
    
    # Install MistServer
    if ! install_mistserver; then
        log_error "MistServer installation failed, but continuing..."
    fi
    echo
    
    # Configure Nginx
    if ! configure_nginx; then
        log_error "Nginx configuration failed, but continuing..."
    fi
    echo
    
    # Create startup scripts
    if ! create_startup_scripts; then
        log_error "Startup script creation failed, but continuing..."
    fi
    echo
    
    # Optional: Cloudflare Tunnel
    echo -e "${YELLOW}Optional: Install Cloudflare Tunnel?${NC}"
    echo -e "${BLUE}(Enables secure external access without port forwarding)${NC}"
    if ask_yes_no "Install Cloudflare Tunnel" "n"; then
        install_cloudflare_tunnel
        echo
    fi
    
    # Optional: File Browser
    echo -e "${YELLOW}Optional: Install File Browser?${NC}"
    echo -e "${BLUE}(Web-based file manager on port 9999)${NC}"
    if ask_yes_no "Install File Browser" "n"; then
        install_filebrowser
        echo
    fi
    
    # Add aliases
    add_useful_aliases
    
    # Final summary
    print_header
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}           Installation completed successfully!              ${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo
    echo -e "${YELLOW}Important Information:${NC}"
    echo
    echo -e "📡 ${BLUE}SSH Access:${NC}"
    echo -e "   ssh -p 8022 $(whoami)@$(ifconfig 2>/dev/null | grep -A 1 "wlan0" | grep "inet " | awk '{print $2}')"
    echo
    echo -e "🌐 ${BLUE}Nginx Proxy:${NC}"
    echo -e "   http://$(ifconfig 2>/dev/null | grep -A 1 "wlan0" | grep "inet " | awk '{print $2}'):8080"
    echo
    echo -e "🎬 ${BLUE}MistServer Admin:${NC}"
    echo -e "   http://$(ifconfig 2>/dev/null | grep -A 1 "wlan0" | grep "inet " | awk '{print $2}'):4242"
    echo
    echo -e "📋 ${BLUE}Proxy URL Format:${NC}"
    echo -e "   http://YOUR_IP:8080/live/TARGET_HOST/PATH"
    echo -e "   Example: http://YOUR_IP:8080/live/localhost:8888/hls/stream.m3u8"
    echo
    echo -e "📂 ${BLUE}Backup Location:${NC}"
    echo -e "   $BACKUP_DIR"
    echo
    echo -e "📝 ${BLUE}Installation Log:${NC}"
    echo -e "   $LOGFILE"
    echo
    echo -e "${YELLOW}Next Steps:${NC}"
    echo -e "1. Configure Android battery settings (disable optimization for Termux)"
    echo -e "2. Set up port forwarding on your router (if needed)"
    echo -e "3. Access MistServer at port 4242 to configure streams"
    echo -e "4. Restart Termux to activate auto-start"
    echo
    echo -e "${GREEN}Useful Commands:${NC}"
    echo -e "  nr                - Reload Nginx configuration"
    echo -e "  check-status      - Check service status"
    echo -e "  ~/start_mist.sh   - Manually start MistServer"
    echo
    echo -e "${YELLOW}⚠️  Remember to configure battery optimization in Android settings!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo
    
    log "Installation process completed"
    
    press_any_key
}

# Run main installation
main
