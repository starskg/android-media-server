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
- ✅ **Automated Installation**: One-command setup with interactive configuration

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

## 🚀 Quick Installation (Recommended)

### One-Command Install

The easiest way to get started. Just run one command and follow the prompts:

```bash
curl -fsSL https://raw.githubusercontent.com/starskg/android-streaming-server/main/install.sh | bash
```

**Or download first, then run:**

```bash
# Download the installer
curl -O https://raw.githubusercontent.com/starskg/android-streaming-server/main/install.sh

# Make it executable
chmod +x install.sh

# Run the installer
./install.sh
```

### What the Installer Does

1. ✅ **Updates packages** and installs required software
2. ✅ **Asks for SSH password** (for remote access)
3. ✅ **Configures Nginx** reverse proxy with CORS support
4. ✅ **Sets up PRoot Ubuntu** container
5. ✅ **Installs MistServer** for streaming
6. ✅ **Asks for whitelist domains** (which sites to allow)
7. ✅ **Optional:** Cloudflare Tunnel for secure external access
8. ✅ **Optional:** File Browser for web-based file management
9. ✅ **Creates auto-start** configuration
10. ✅ **Backs up** existing configurations

### Installation Process

**Step 1:** Open Termux on your Android device

**Step 2:** Run the installation command:
```bash
curl -fsSL https://raw.githubusercontent.com/starskg/android-streaming-server/main/install.sh | bash
```

**Step 3:** Follow the interactive prompts:

```
Welcome to the Android Streaming Server installer!
...
Do you want to continue? [Y/n]: y

Creating backup...
Installing base packages...
✓ Base packages installed successfully

Please set a password for SSH access:
[Enter your password]

Installing PRoot and Ubuntu container...
✓ PRoot Ubuntu installed successfully

Installing MistServer...
✓ MistServer installed successfully

Configuring Nginx proxy...

Enter domains to whitelist (comma-separated, or press Enter for localhost only):
Example: kgtv.ru,kgtv.online,cdn.example.com
> kgtv.ru,localhost:8888

Allow ALL domains (not recommended for security)?
Enable unrestricted proxy [y/N]: n

✓ Nginx configured and started

Optional: Install Cloudflare Tunnel?
(Enables secure external access without port forwarding)
Install Cloudflare Tunnel [y/N]: n

Optional: Install File Browser?
(Web-based file manager on port 9999)
Install File Browser [y/N]: y

✓ File Browser installed
```

**Step 4:** Wait for completion (5-10 minutes)

**Step 5:** Configure Android battery settings:
- Go to **Settings** → **Apps** → **Termux**
- Set **Battery Saver** to **"No restrictions"**
- Enable **Autostart** (if available in your ROM)

**Step 6:** Restart Termux to activate auto-start

### Post-Installation

After installation completes, you'll see:

```
════════════════════════════════════════════════════════════
           Installation completed successfully!
════════════════════════════════════════════════════════════

📡 SSH Access:
   ssh -p 8022 u0_a235@192.168.1.100

🌐 Nginx Proxy:
   http://192.168.1.100:8080

🎬 MistServer Admin:
   http://192.168.1.100:4242

📋 Proxy URL Format:
   http://YOUR_IP:8080/live/TARGET_HOST/PATH
   Example: http://YOUR_IP:8080/live/localhost:8888/hls/stream.m3u8

📂 Backup Location:
   /data/data/com.termux/files/home/streaming_server_backup_20240203_143022

📝 Installation Log:
   /data/data/com.termux/files/home/install_20240203_143022.log
```

---

## ⚡ Alternative: Fully Automated Install

For advanced users who want zero interaction:

```bash
curl -fsSL https://raw.githubusercontent.com/starskg/android-streaming-server/main/quick-install.sh | bash
```

**Default settings:**
- Password: `streaming123` ⚠️ **Change immediately!**
- Whitelist: `localhost:8888` only
- No optional components

**After install, change the password:**
```bash
passwd
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

## 🌐 Using the Proxy

### URL Format

To access streams through the proxy, use:

```
http://YOUR_PHONE_IP:8080/live/TARGET_HOST/PATH
```

### Examples

```bash
# Access MistServer on localhost
http://192.168.1.100:8080/live/localhost:8888/hls/stream.m3u8

# Access external RTMP server
http://192.168.1.100:8080/live/kgtv.ru:8080/live/channel1.m3u8

# With full HTTP URL (auto-extracted)
http://192.168.1.100:8080/live/http://kgtv.online/stream/playlist.m3u8
```

### Managing Whitelist

Edit allowed domains:

```bash
nano $PREFIX/etc/nginx/websites
```

Add domains:
```nginx
kgtv.ru          1;
kgtv.online      1;
localhost:8888   1;
```

Reload Nginx:
```bash
nginx -s reload
```

> ⚠️ **Security:** Only whitelist trusted domains to prevent your server from becoming an open proxy.

---

## 🔧 Service Management

### Check Status

```bash
# Download and run status checker
curl -fsSL https://raw.githubusercontent.com/starskg/android-streaming-server/main/check-status.sh | bash
```

Or use the built-in alias:
```bash
check-status
```

### Manual Control

```bash
# Restart Nginx
nr                      # (alias for 'nginx -s reload')

# Start services manually
sshd                    # SSH
nginx                   # Nginx
~/start_mist.sh         # MistServer

# Stop services
pkill sshd              # Stop SSH
nginx -s stop           # Stop Nginx
pkill -f MistController # Stop MistServer
```

---

## 🔐 Optional: Cloudflare Tunnel

If you installed Cloudflare Tunnel, configure it:

```bash
# Authenticate
cloudflared tunnel login

# Create tunnel
cloudflared tunnel create redmi-server

# Configure (edit ~/.cloudflared/config.yml)
nano ~/.cloudflared/config.yml
```

Example config:
```yaml
tunnel: YOUR_TUNNEL_ID
credentials-file: /data/data/com.termux/files/home/.cloudflared/YOUR_TUNNEL_ID.json

ingress:
  - hostname: stream.yourdomain.com
    service: http://localhost:8080
  - hostname: admin.yourdomain.com
    service: http://localhost:4242
  - service: http_status:404
```

Start tunnel (already in .bashrc):
```bash
cloudflared tunnel run redmi-server
```

---

## 📁 Optional: File Browser

If you installed File Browser, access it at:

```
http://YOUR_PHONE_IP:9999
```

**Default credentials:**
- Username: `admin`
- Password: `admin`

**Change password:**
```bash
proot-distro login ubuntu
filebrowser users update admin --password NEW_PASSWORD
```

---

## 🐛 Troubleshooting

### Services not running

Check status:
```bash
check-status
```

Restart manually:
```bash
sshd
nginx
~/start_mist.sh
```

### 403 Forbidden errors

Domain not whitelisted. Add to `/data/data/com.termux/files/usr/etc/nginx/websites`:
```bash
nano $PREFIX/etc/nginx/websites
# Add: yourdomain.com 1;
nginx -s reload
```

### Services stop after screen lock

1. Enable wake lock (already in .bashrc):
   ```bash
   termux-wake-lock
   ```

2. Android settings:
   - **Settings** → **Apps** → **Termux** → **Battery Saver** → **No restrictions**
   - Enable **Autostart** if available

### SSH connection refused

Start SSH:
```bash
sshd
```

Check port:
```bash
ssh -p 8022 $(whoami)@localhost
```

---

## 🗑️ Uninstallation

```bash
curl -fsSL https://raw.githubusercontent.com/starskg/android-streaming-server/main/uninstall.sh | bash
```

The uninstaller will:
- Stop all services
- Restore backups
- Optionally remove packages
- Clean up files

---

## 📊 Performance Proof

MistServer running efficiently on the Redmi Note 10S while handling active streams. Note the incredibly low CPU utilization due to direct transmuxing (no transcoding).

![Server Stats Screenshot](assets/performance-screenshot.png)

---

## 📖 Manual Installation Guide

<details>
<summary><b>Click here for detailed manual installation steps</b></summary>

If you prefer to install everything manually or need to troubleshoot, follow these detailed steps.

---

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

**Edit the main Nginx configuration:**

```bash
nano $PREFIX/etc/nginx/nginx.conf
```

**Paste the full configuration** (see [config/nginx/nginx.conf](config/nginx/nginx.conf) in this repository)

**Create the websites whitelist:**

```bash
nano $PREFIX/etc/nginx/websites
```

```nginx
# ADD ALLOWED SITES TO THIS FILE
# Syntax: domain_name 1;
localhost:8888   1;
```

**Start Nginx:**

```bash
nginx
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

# Exit Ubuntu
exit
```

---

### Step 5: Auto-Start Configuration

**Create the MistServer startup script:**

```bash
nano ~/start_mist.sh
```

```bash
#!/data/data/com.termux/files/usr/bin/sh

# Check if MistController is already running
if pgrep -f "MistController" > /dev/null; then
    echo "MistServer is already running."
    exit 0
fi

# Start MistServer
nohup proot-distro login ubuntu -- MistController > /dev/null 2>&1 &

echo "MistServer started inside Ubuntu (proot)!"
```

**Make it executable:**

```bash
chmod +x ~/start_mist.sh
```

**Edit bashrc for auto-start:**

```bash
nano ~/.bashrc
```

**Add to the end:**

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

# MistServer (via start_mist.sh)
if ! pgrep -f "MistController" > /dev/null; then
    ~/start_mist.sh > /dev/null 2>&1 &
    echo "MistServer startup script executed."
fi

# Short commands (Aliases)
alias nr='nginx -s reload'
alias check-status='echo "=== Services ===" && pgrep -x sshd > /dev/null && echo "SSH: Running" || echo "SSH: Stopped" && pgrep -x nginx > /dev/null && echo "Nginx: Running" || echo "Nginx: Stopped" && pgrep -f MistController > /dev/null && echo "MistServer: Running" || echo "MistServer: Stopped"'
```

**Reload bashrc:**

```bash
source ~/.bashrc
```

---

### Optional: Install Cloudflare Tunnel

```bash
pkg install cloudflared

# Authenticate
cloudflared tunnel login

# Create tunnel
cloudflared tunnel create redmi-server
```

Add to `.bashrc`:
```bash
# Cloudflare Tunnel
if ! pgrep -x "cloudflared" > /dev/null; then
    nohup cloudflared tunnel run redmi-server > /dev/null 2>&1 &
    echo "Cloudflare Tunnel started."
fi
```

---

### Optional: Install File Browser

```bash
pkg install tmux

# Install in Ubuntu
proot-distro login ubuntu
curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash
exit
```

Add to `.bashrc`:
```bash
# File Browser (via tmux)
if ! pgrep -f "filebrowser" > /dev/null; then
    tmux new-session -d -s fb_session 'proot-distro login ubuntu -- filebrowser -d /root/filebrowser.db -p 9999 -a 0.0.0.0'
    echo "File Browser started on port 9999."
fi
```

---

</details>

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
│   └── start_mist.sh           # MistServer startup script
├── assets/
│   └── performance-screenshot.png
└── README.md
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

- **GitHub**: [@starskg](https://github.com/starskg)
- **Email**: shuhratstars@gmail.com
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

- **v1.0.0** (2026-02-03)
  - Initial release
  - One-command automated installation
  - Interactive configuration prompts
  - Auto-start and persistence features
  - Optional Cloudflare Tunnel and File Browser
  - Comprehensive troubleshooting guide

---

## 🗺️ Roadmap

- [ ] Web-based installation UI
- [ ] Docker support for easier deployment
- [ ] Stream recording automation
- [ ] Grafana monitoring dashboard
- [ ] Mobile app for server management
- [ ] Multi-language documentation
- [ ] Automated backup system
