# Android-Based High-Performance Media Streaming Server

**Transforming a Redmi Note 10S into a Dedicated RTMP to HLS/SRT Gateway**

---

## 📖 Overview

This project demonstrates the engineering capability of repurposing consumer mobile hardware into a robust, 24/7 streaming media server. Using a **Redmi Note 10S** (MediaTek Helio G95, 6GB RAM), we establish a pipeline that ingests RTMP streams (e.g., from OBS Studio) and transmuxes them into HLS or SRT formats for global delivery.

The setup utilizes **Termux** as the host environment for Nginx and SSH, while deploying **MistServer** within an isolated **PRoot Ubuntu** container for maximum stability and performance.

### Key Features

- ✅ **Zero Transcoding Load**: Efficient remuxing results in near 0% CPU usage on the host device
- ✅ **Custom CORS Handling**: Nginx is configured as a reverse proxy to solve complex cross-origin issues for web players
- ✅ **Persistence**: Optimized against Android's aggressive background process killing
- ✅ **Remote Management**: Full PC-to-Phone control via SSH
- ✅ **Whitelist Security**: Domain-based access control for proxy endpoints
- ✅ **Cloudflare Tunnel**: Optional secure external access without port forwarding
- ✅ **Web File Manager**: Built-in file browser on port 9999

---

## 🏗️ Architecture Stack

The system is layered as follows:

| Layer | Component | Role |
|-------|-----------|------|
| **Hardware** | Redmi Note 10S | The physical host device |
| **Host OS (Android)** | Termux | Provides the Linux environment and native package management |
| **Host Services** | Nginx & OpenSSH | Nginx handles HTTP reverse proxying; SSH provides remote access |
| **Container** | PRoot Distro (Ubuntu) | Creates an isolated Linux filesystem for the media engine |
| **Media Engine** | MistServer (ARMv8) | The core server handling ingest (RTMP) and egress (HLS/SRT) |
| **Optional Services** | Cloudflare Tunnel & File Browser | Secure tunneling and web-based file management |

---

## 🛠️ Installation Guide

Follow these steps sequentially to replicate the setup.

### Step 1: Initial Access & SSH Setup

Setup remote access from a PC for easier configuration. On the Android device via Termux:

```bash
# Update local packages
pkg update && pkg upgrade -y

# Install OpenSSH
pkg install openssh

# Set a password for the Termux user
passwd

# Start the SSH daemon
sshd
```

Now, connect from your PC (replace IP with your phone's local IP):

```bash
ssh -p 8022 u0_a235@192.168.x.xxx
# Note: Your username can be found using the 'whoami' command in Termux.
```

---

### Step 2: Host Environment Setup (Nginx)

Install Nginx natively in Termux to act as the front-end proxy and handle CORS.

```bash
pkg install nginx
```

#### Configuration Strategy

We use a main `nginx.conf` and an included `websites` file for cleaner management.

- **Main Config** (`$PREFIX/etc/nginx/nginx.conf`): Setup basic HTTP parameters and include the websites file
- **Websites Config** (`$PREFIX/etc/nginx/websites`): Define the proxy rules and inject CORS headers

**Edit the main Nginx configuration:**

```bash
nano $PREFIX/etc/nginx/nginx.conf
```

**Paste the following configuration:**

```nginx
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
    
    # -----------------------------------------------------------
    # 1. Extract target host (site) from URL
    # -----------------------------------------------------------
    map $request_uri $target_host_extracted {
        # Extract host from /live/http://site.com/.. or /live/site.com/.. format
        "~^/live/(?:https?://)?(?<extracted>[^/]+)"  $extracted;
        default "";
    }
    
    # -----------------------------------------------------------
    # 2. Verify extracted host against "websites" file
    # -----------------------------------------------------------
    map $target_host_extracted $is_allowed {
        default 0;       # By default, everything is BLOCKED (0)
        include websites; # Load rules from "websites" file
    }
    
    server {
        listen 8080;
        
        # Main page
        location / {
            root /data/data/com.termux/files/usr/share/nginx/html;
            index index.html;
        }
        
        # MistServer Proxy configuration
        location ~* ^/live/(?:https?://)?(?<target_addr>[0-9.:a-zA-Z-]+)/(?<target_path>.*)$ {
            
            # --- SECURITY CHECK ---
            # If not in websites file, return 403 Forbidden
            if ($is_allowed = 0) {
                return 403 "Access Denied";
            }
            
            # Dynamic proxying
            proxy_pass http://$target_addr/$target_path$is_args$args;
            
            # Video streaming optimization
            proxy_buffering off;
            proxy_request_buffering off;
            proxy_http_version 1.1;
            
            # Properly forward headers
            proxy_set_header Host $target_addr;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # --- SOLVE CORS ISSUES ---
            proxy_hide_header 'Access-Control-Allow-Origin';
            proxy_hide_header 'Access-Control-Allow-Methods';
            proxy_hide_header 'Access-Control-Allow-Headers';
            
            # For OPTIONS (preflight) requests
            if ($request_method = 'OPTIONS') {
                add_header 'Access-Control-Allow-Origin' '*' always;
                add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS, HEAD' always;
                add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range' always;
                add_header 'Access-Control-Max-Age' 1728000;
                add_header 'Content-Type' 'text/plain; charset=utf-8';
                add_header 'Content-Length' 0;
                return 204;
            }
            
            # For main GET/POST requests
            add_header 'Access-Control-Allow-Origin' '*' always;
            add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS, HEAD' always;
            add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range' always;
            add_header 'Access-Control-Expose-Headers' 'Content-Length,Content-Range' always;
        }
    } 
}
```

**Create and edit the websites whitelist file:**

```bash
nano $PREFIX/etc/nginx/websites
```

**Add allowed domains:**

```nginx
# ADD ALLOWED SITES TO THIS FILE
# Syntax: domain_name 1;
# Example:
kgtv.ru          1;
kgtv.online      1;
my-server.local  1;
localhost:8888   1;

# --- TO ALLOW ALL SITES ---
# If you want to allow all sites,
# uncomment the following line (remove the # symbol):
# ~.* 1;
```

**Start Nginx:**

```bash
nginx
```

**Restart Nginx after configuration changes:**

```bash
nginx -s reload
```

---

### Step 3: Container Environment (PRoot Ubuntu)

Set up the isolated Ubuntu environment where MistServer will run.

```bash
# Install PRoot Distro
pkg install proot-distro

# Install Ubuntu
proot-distro install ubuntu

# Login to the Ubuntu container
proot-distro login ubuntu
```

---

### Step 4: MistServer Deployment

Inside the PRoot Ubuntu shell, install the ARM64 version of MistServer.

```bash
# Install dependencies
apt update && apt install curl -y

# Download and install MistServer (ARMv8 64-bit)
curl -o - https://releases.mistserver.org/is/mistserver_aarch64V3.10.tar.gz 2>/dev/null | sh
```

> **Note on Ports:** MistServer's default HTTP port is often 8080. To avoid conflict with Nginx (running on Termux), we configure MistServer to use port **8888** for HTTP/HLS traffic.

**Exit Ubuntu container:**

```bash
exit
```

---

### Step 5: Auto-Start Configuration

Configure automatic startup of all services on Termux launch.

**Edit the bashrc file:**

```bash
nano ~/.bashrc
```

**Add the following content at the end of the file:**

```bash
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

# Cloudflare Tunnel
if ! pgrep -x "cloudflared" > /dev/null; then
    nohup cloudflared tunnel run redmi-server > /dev/null 2>&1 &
    echo "Cloudflare Tunnel started."
fi

# MistServer (via start_mist.sh)
if ! pgrep -f "MistController" > /dev/null; then
    ~/start_mist.sh > /dev/null 2>&1 &
    echo "Mist script started."
fi

# File Browser (via tmux)
if ! pgrep -f "filebrowser" > /dev/null; then
    tmux new-session -d -s fb_session 'proot-distro login ubuntu -- filebrowser -d /root/filebrowser.db -p 9999 -a 0.0.0.0'
    echo "File Browser started."
fi

# Short commands (Aliases)
alias nr='nginx -s reload'
```

**Create the MistServer startup script:**

```bash
nano ~/start_mist.sh
```

**Add the following content:**

```bash
#!/data/data/com.termux/files/usr/bin/sh

# Check if MistController is already running
if pgrep -f "MistController" > /dev/null; then
    echo "MistServer is already running."
    exit 0
fi

# Start MistServer (/usr/bin/MistController inside Ubuntu)
nohup proot-distro login ubuntu -- MistController > /dev/null 2>&1 &

echo "MistServer started inside Ubuntu (proot)!"
```

**Make it executable:**

```bash
chmod +x ~/start_mist.sh
```

**Optional: Install additional services**

```bash
# Install tmux for File Browser
pkg install tmux

# Install Cloudflare Tunnel (optional)
pkg install cloudflared
```

**Reload bashrc to apply changes:**

```bash
source ~/.bashrc
```

---

## 🌐 Networking & Port Forwarding

For external access, configure your router to forward traffic to the phone's static local IP.

| Protocol | Port | Service | Description |
|----------|------|---------|-------------|
| TCP | 1935 | RTMP Ingest | Accepts video streams from OBS Studio |
| TCP | 4242 | MistServer API | Web administration panel access |
| TCP | 8080 | Nginx Proxy | Main proxy endpoint for HLS/SRT playback |
| TCP | 8888 | HTTP/HLS Egress | Direct MistServer port (internal) |
| UDP | 8889 | SRT (Optional) | For low-latency SRT streams if configured |
| TCP | 9999 | File Browser | Web-based file management interface |
| TCP | 8022 | SSH | Remote terminal access |

---

## 🌐 Proxy Usage & URL Format

### How the Nginx Proxy Works

This setup uses Nginx as a reverse proxy with a **whitelist-based security system**. Only domains listed in the `websites` file are allowed to be proxied.

### URL Format

To access streams through the proxy, use the following URL format:

```
http://YOUR_PHONE_IP:8080/live/TARGET_HOST/PATH
```

**Examples:**

```
# Access MistServer on localhost
http://192.168.1.100:8080/live/localhost:8888/hls/stream.m3u8

# Access external RTMP server
http://192.168.1.100:8080/live/kgtv.ru:8080/live/channel1.m3u8

# With full HTTP URL (auto-extracted)
http://192.168.1.100:8080/live/http://kgtv.online/stream/playlist.m3u8
```

### Security: Whitelist Configuration

Edit the `websites` file to control access:

```bash
nano $PREFIX/etc/nginx/websites
```

**Whitelist specific domains:**

```nginx
kgtv.ru          1;
kgtv.online      1;
localhost:8888   1;
192.168.1.50     1;
```

**Allow all domains (NOT recommended for production):**

```nginx
~.* 1;
```

> ⚠️ **Security Warning**: Only whitelist trusted domains. Unrestricted access can turn your server into an open proxy.

**After editing, reload Nginx:**

```bash
nginx -s reload
```

---

## 🔐 Cloudflare Tunnel (Optional)

For secure external access without port forwarding, this setup includes Cloudflare Tunnel.

### Prerequisites

1. Cloudflare account
2. Domain configured in Cloudflare DNS

### Setup Steps

**Install cloudflared:**

```bash
pkg install cloudflared
```

**Authenticate and create tunnel:**

```bash
cloudflared tunnel login
cloudflared tunnel create redmi-server
```

**Configure the tunnel:**

Create `~/.cloudflared/config.yml`:

```yaml
tunnel: YOUR_TUNNEL_ID
credentials-file: /data/data/com.termux/files/home/.cloudflared/YOUR_TUNNEL_ID.json

ingress:
  - hostname: stream.yourdomain.com
    service: http://localhost:8080
  - hostname: admin.yourdomain.com
    service: http://localhost:4242
  - hostname: files.yourdomain.com
    service: http://localhost:9999
  - service: http_status:404
```

**Start tunnel (already automated in .bashrc):**

```bash
cloudflared tunnel run redmi-server
```

**Configure DNS in Cloudflare:**

Add CNAME records pointing to `YOUR_TUNNEL_ID.cfargotunnel.com`:

- `stream.yourdomain.com` → `YOUR_TUNNEL_ID.cfargotunnel.com`
- `admin.yourdomain.com` → `YOUR_TUNNEL_ID.cfargotunnel.com`
- `files.yourdomain.com` → `YOUR_TUNNEL_ID.cfargotunnel.com`

---

## 📁 File Browser

A web-based file manager runs on port **9999** for easy file management.

### Access

**Local network:**
```
http://YOUR_PHONE_IP:9999
```

**Via Cloudflare Tunnel:**
```
https://files.yourdomain.com
```

### Installation (if not already done)

```bash
# Install tmux
pkg install tmux

# Login to Ubuntu and install File Browser
proot-distro login ubuntu
curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash
exit
```

### Default Credentials

- **Username**: `admin`
- **Password**: `admin`

> 🔒 **Important**: Change the default password after first login!

**Change password:**

```bash
proot-distro login ubuntu
filebrowser config set --auth.method=json
filebrowser users update admin --password NEW_PASSWORD
exit
```

---

## 🔋 Persistence & Optimization (Crucial)

Android aggressively manages background processes. These steps ensure the server runs 24/7.

### 1. Termux Wake Lock

Keep the CPU awake even when the screen is off. This is already automated in `.bashrc`:

```bash
termux-wake-lock
```

*(A notification "Wake lock held" should appear)*

### 2. Android Battery Settings (UI)

Navigate to device settings and disable optimizations for Termux:

- **Settings** > **Apps** > **Manage Apps** > **Termux** > **Battery Saver** → Set to **"No restrictions"**
- Enable **"Autostart"** permissions if available in your ROM (MIUI/HyperOS)

### 3. Startup Script Summary

The `start_mist.sh` script and `.bashrc` are configured to automatically start all services whenever Termux is launched.

---

## 🔧 Useful Commands & Aliases

The `.bashrc` includes helpful shortcuts:

**Reload Nginx configuration:**
```bash
nr
```

**Check running processes:**
```bash
pgrep -f MistController
pgrep -x nginx
pgrep -x sshd
pgrep -x cloudflared
pgrep -f filebrowser
```

**Restart services manually:**
```bash
nginx -s reload          # Reload Nginx config
nginx -s stop && nginx   # Full restart
sshd                     # Start SSH
~/start_mist.sh          # Start MistServer
```

**Test Nginx configuration:**
```bash
nginx -t
```

**View service logs:**
```bash
# Nginx error log
tail -f $PREFIX/var/log/nginx/error.log

# Cloudflared log (if running manually)
cloudflared tunnel info redmi-server
```

---

## 📊 Performance Proof

MistServer running efficiently on the Redmi Note 10S while handling active streams. Note the incredibly low CPU utilization due to direct transmuxing (no transcoding).

![Server Stats Screenshot](assets/performance-screenshot.png)

*Replace the path above with your actual screenshot location*

---

## 🐛 Troubleshooting

### MistServer won't start

**Check if already running:**
```bash
pgrep -f MistController
```

**Kill and restart:**
```bash
pkill -f MistController
~/start_mist.sh
```

**Check MistServer logs:**
```bash
proot-distro login ubuntu
# Check if MistController exists
which MistController
# Try running manually to see errors
MistController
```

---

### Nginx proxy returns 403 Forbidden

**Cause**: Target domain not whitelisted.

**Solution**: Add domain to `websites` file:
```bash
nano $PREFIX/etc/nginx/websites
# Add: yourdomain.com 1;
nginx -s reload
```

**Verify configuration:**
```bash
nginx -t
```

---

### SSH connection refused

**Check if SSH is running:**
```bash
pgrep -x sshd
```

**Start SSH manually:**
```bash
sshd
```

**Check SSH port (should be 8022):**
```bash
ssh -p 8022 $(whoami)@localhost
```

**Find your username:**
```bash
whoami
```

---

### Termux services stop after screen lock

**Solutions:**

1. **Acquire wake lock (already in .bashrc):**
   ```bash
   termux-wake-lock
   ```

2. **Check battery optimization:**
   - Settings → Apps → Termux → Battery Saver → **No restrictions**

3. **Enable autostart** (MIUI/HyperOS):
   - Settings → Apps → Manage Apps → Termux → Autostart → **Enable**

4. **Disable adaptive battery:**
   - Settings → Battery → Adaptive Battery → **Disable**

---

### CORS errors in browser

**Symptom**: Console shows "Access-Control-Allow-Origin" errors.

**Check**: Ensure the Nginx configuration includes CORS headers (already configured in provided config).

**Verify configuration:**
```bash
nginx -t
cat $PREFIX/etc/nginx/nginx.conf | grep -A 5 "CORS"
```

**Reload Nginx:**
```bash
nginx -s reload
```

---

### Cloudflare Tunnel not connecting

**Check tunnel status:**
```bash
pgrep -x cloudflared
```

**View tunnel info:**
```bash
cloudflared tunnel info redmi-server
```

**Check tunnel logs:**
```bash
# If running in background via nohup, find the process
ps aux | grep cloudflared
```

**Restart tunnel:**
```bash
pkill cloudflared
cloudflared tunnel run redmi-server
```

**Verify credentials file exists:**
```bash
ls -la ~/.cloudflared/
```

---

### File Browser not accessible

**Check if running:**
```bash
pgrep -f filebrowser
```

**Check tmux session:**
```bash
tmux list-sessions
tmux attach -t fb_session
# Press Ctrl+B then D to detach
```

**Restart File Browser:**
```bash
tmux kill-session -t fb_session
tmux new-session -d -s fb_session 'proot-distro login ubuntu -- filebrowser -d /root/filebrowser.db -p 9999 -a 0.0.0.0'
```

---

## 📊 Monitoring & Health Checks

### Check Service Status

Create a simple status script `~/check_status.sh`:

```bash
nano ~/check_status.sh
```

**Add the following:**

```bash
#!/data/data/com.termux/files/usr/bin/bash

echo "=== Service Status ==="
echo -n "SSH: "; pgrep -x sshd > /dev/null && echo "✓ Running" || echo "✗ Stopped"
echo -n "Nginx: "; pgrep -x nginx > /dev/null && echo "✓ Running" || echo "✗ Stopped"
echo -n "MistServer: "; pgrep -f MistController > /dev/null && echo "✓ Running" || echo "✗ Stopped"
echo -n "Cloudflare: "; pgrep -x cloudflared > /dev/null && echo "✓ Running" || echo "✗ Stopped"
echo -n "File Browser: "; pgrep -f filebrowser > /dev/null && echo "✓ Running" || echo "✗ Stopped"
echo ""
echo "=== Port Status ==="
echo -n "Port 8022 (SSH): "; nc -z localhost 8022 && echo "✓ Open" || echo "✗ Closed"
echo -n "Port 8080 (Nginx): "; nc -z localhost 8080 && echo "✓ Open" || echo "✗ Closed"
echo -n "Port 4242 (MistServer): "; nc -z localhost 4242 && echo "✓ Open" || echo "✗ Closed"
echo -n "Port 9999 (File Browser): "; nc -z localhost 9999 && echo "✓ Open" || echo "✗ Closed"
```

**Make executable and run:**
```bash
chmod +x ~/check_status.sh
./check_status.sh
```

### CPU and Memory Monitoring

```bash
# Check CPU usage
top -n 1 | head -20

# Check memory usage
free -h

# Check specific process
top -p $(pgrep -f MistController)
```

---

## 🎯 Performance Tips

1. **Disable unnecessary apps** to free up RAM
   - Uninstall bloatware via ADB or system settings
   - Disable Google services if not needed

2. **Use a cooling fan** for extended streaming sessions
   - Prevents thermal throttling
   - Maintains consistent performance

3. **Monitor CPU temperature** using apps like:
   - CPU-Z
   - DevCheck Hardware Info
   - AIDA64

4. **Disable auto-updates** for system apps
   - Settings → Google Play Store → Auto-update apps → Don't auto-update

5. **Use airplane mode + WiFi** to reduce background processes
   - Disables cellular radio
   - Reduces battery drain
   - Fewer background sync tasks

6. **Static IP assignment**
   - Assign static IP in router DHCP settings
   - Prevents IP changes after reboot

7. **Keep phone plugged in**
   - Use original charger or quality alternative
   - Consider battery health (keep between 20-80%)

8. **Regular cleanup**
   ```bash
   pkg clean
   apt autoremove  # Inside PRoot
   ```

---

## 📖 Advanced Configuration

### Custom MistServer Settings

Access MistServer web interface:

```
http://YOUR_PHONE_IP:4242
```

**Key settings to configure:**
- Stream protocols (RTMP, HLS, SRT)
- Buffer sizes
- Authentication
- Push/Pull configurations

### Multiple Stream Sources

You can proxy multiple upstream servers by adding them to the `websites` file:

```nginx
upstream-server-1.com:1935  1;
upstream-server-2.com:8080  1;
cdn.example.com             1;
```

### Custom HTML Landing Page

Edit the default Nginx landing page:

```bash
nano $PREFIX/share/nginx/html/index.html
```

### Load Balancing (Advanced)

For multiple MistServer instances, modify `nginx.conf`:

```nginx
upstream mistservers {
    server localhost:8888;
    server localhost:8889;
    server localhost:8890;
}

location /hls/ {
    proxy_pass http://mistservers;
}
```

### Automatic Restart on Crash

Create a systemd-style service monitor:

```bash
nano ~/monitor_services.sh
```

```bash
#!/data/data/com.termux/files/usr/bin/bash

while true; do
    if ! pgrep -f MistController > /dev/null; then
        echo "$(date): MistServer crashed, restarting..."
        ~/start_mist.sh
    fi
    
    if ! pgrep -x nginx > /dev/null; then
        echo "$(date): Nginx crashed, restarting..."
        nginx
    fi
    
    sleep 60
done
```

```bash
chmod +x ~/monitor_services.sh
nohup ~/monitor_services.sh > ~/monitor.log 2>&1 &
```

---

## 📂 Project Structure

```
.
├── install.sh                  # Interactive installer (recommended)
├── quick-install.sh            # Fully automated installer
├── uninstall.sh                # Uninstaller script
├── check-status.sh             # Service status checker
├── config/
│   └── nginx/
│       ├── nginx.conf          # Main Nginx configuration
│       └── websites            # Whitelist file
├── scripts/
│   ├── .bashrc                 # Auto-start configuration
│   ├── start_mist.sh           # MistServer startup script
│   └── monitor_services.sh     # Auto-restart monitor (optional)
├── assets/
│   └── performance-screenshot.png
└── README.md
```

---

## 🚀 Installation Methods

### Method 1: Interactive Installer (Recommended)

The interactive installer guides you through each step with prompts and confirmations.

```bash
# Download and run
curl -O https://raw.githubusercontent.com/your-username/android-streaming-server/main/install.sh
bash install.sh
```

**Features:**
- ✅ Step-by-step prompts
- ✅ Custom domain whitelist configuration
- ✅ Optional components (Cloudflare, File Browser)
- ✅ Automatic backup creation
- ✅ Detailed progress logging
- ✅ Continues on errors

---

### Method 2: Quick Install (Fully Automated)

For advanced users who want a fully automated installation with default settings.

```bash
# Download and run
curl -O https://raw.githubusercontent.com/your-username/android-streaming-server/main/quick-install.sh
bash quick-install.sh
```

**Default Settings:**
- Password: `streaming123` (⚠️ Change immediately after install)
- Whitelist: `localhost:8888` only
- Optional components: Not installed

---

### Method 3: Manual Installation

Follow the step-by-step guide in the [Installation Guide](#️-installation-guide) section below.

---

## 🗑️ Uninstallation

To remove the streaming server:

```bash
# Download and run uninstaller
curl -O https://raw.githubusercontent.com/your-username/android-streaming-server/main/uninstall.sh
bash uninstall.sh
```

The uninstaller will:
- Stop all running services
- Restore configuration backups
- Optionally remove installed packages
- Clean up temporary files

---

## 📊 Service Management

### Check Service Status

```bash
# Download status checker
curl -O https://raw.githubusercontent.com/your-username/android-streaming-server/main/check-status.sh
bash check-status.sh
```

Or use the built-in alias:
```bash
check-status
```

### Manual Service Control

```bash
# Start services
sshd                    # SSH server
nginx                   # Nginx proxy
~/start_mist.sh         # MistServer

# Stop services
pkill sshd              # Stop SSH
nginx -s stop           # Stop Nginx
pkill -f MistController # Stop MistServer

# Restart services
nginx -s reload         # Reload Nginx config (or use: nr)
nginx -s stop && nginx  # Full Nginx restart
```

---

## 🚀 Quick Start Commands (Manual Setup)

If you prefer manual configuration or need to copy files:

```bash
# Clone this repository
git clone https://github.com/your-username/android-streaming-server.git
cd android-streaming-server

# Copy configuration files
cp config/nginx/nginx.conf $PREFIX/etc/nginx/
cp config/nginx/websites $PREFIX/etc/nginx/

# Copy scripts
cp scripts/.bashrc ~/
cp scripts/start_mist.sh ~/
chmod +x ~/start_mist.sh

# Optional monitoring scripts
cp scripts/check-status.sh ~/
chmod +x ~/check-status.sh

# Reload bashrc
source ~/.bashrc

# Test Nginx configuration
nginx -t

# Reload Nginx
nginx -s reload
```

---

## 📜 License

This project configuration is open-source under the MIT License. MistServer itself follows its own licensing terms.

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](../../issues).

**How to contribute:**

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📧 Contact

For questions or collaboration:

- **GitHub**: [@your-username](https://github.com/your-username)
- **Email**: your-email@example.com
- **Issues**: [Report a bug](../../issues/new)

---

## 🙏 Acknowledgments

- **MistServer** - Efficient media streaming engine
- **Termux** - Android terminal emulator
- **Nginx** - High-performance web server
- **Cloudflare** - Secure tunneling solution
- **PRoot** - User-space implementation of chroot

---

## ⚠️ Disclaimer

This setup is intended for personal/educational use. Ensure compliance with your ISP's terms of service and local regulations regarding server hosting. The authors are not responsible for any misuse or damage caused by this configuration.

---

**⭐ If you find this project useful, please consider giving it a star!**

---

## 📝 Version History

- **v1.0.0** (2024-02-03)
  - Initial release
  - Basic RTMP to HLS streaming
  - Nginx proxy with CORS support
  - Auto-start configuration
  - Cloudflare Tunnel integration
  - File Browser integration

---

## 🗺️ Roadmap

- [ ] Add Docker support for easier deployment
- [ ] Implement stream recording automation
- [ ] Add Grafana monitoring dashboard
- [ ] Create mobile app for server management
- [ ] Add multi-language support for documentation
- [ ] Implement automated backup system
- [ ] Add fail2ban integration for security
