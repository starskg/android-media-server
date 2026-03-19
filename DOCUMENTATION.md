# Detailed Documentation - Android Media Streaming Server

This document provides in-depth information about the architecture, security, and advanced configuration of the Android-based media streaming server.

---

## 🏗️ Architecture Stack

The system is layered as follows to maximize performance on mobile hardware:

| Layer | Component | Role |
|-------|-----------|------|
| **Hardware** | Redmi Note 10S | The physical host device |
| **Host OS (Android)** | Termux | Provides the Linux environment and native package management |
| **Host Services** | Nginx & OpenSSH | Nginx handles HTTP reverse proxying; SSH provides remote access |
| **Container** | PRoot Distro (Ubuntu) | Creates an isolated Linux filesystem for the media engine |
| **Media Engine** | MistServer (ARMv8) | The core server handling ingest (RTMP) and egress (HLS/SRT) |
| **Optional Services** | File Browser | Web-based file management |

---

## 💡 Real-World Use Cases

Why should you use this project? Here are some practical examples:

1.  **IPTV Proxy & Relay:** Transmux external IPTV streams on your local network and distribute them to various devices (Smart TV, Mobile) in HLS format.
2.  **OBS Gateway:** Send an RTMP stream from your computer (OBS Studio) to your phone and use your device as a "global gateway" to relay the stream to multiple CDNs or web players simultaneously.
3.  **Home Media CDN:** Create an HLS/SRT endpoint to view home videos or live broadcasts with low-latency within the local network (or externally via port forwarding).
4.  **Low-Cost RTMP Ingest:** Turn an old Android phone into a 24/7 dedicated RTMP ingest point instead of using expensive cloud servers.

---

## ⚡ Core Engine: MistServer

This streaming gateway is powered by **MistServer**, a high-performance, open-source multimedia server designed for efficiency and flexibility.

**Why MistServer?**
- 🚀 **Efficiency:** Extremely low resource footprint, ideal for mobile hardware.
- 🔄 **Transmuxing:** Direct stream re-packaging without heavy CPU transcoding.
- 📡 **Multi-Protocol:** Native support for RTMP, HLS, SRT, DASH, and more.
- 🛠️ **Management:** Powerful web-based API and administration panel.

Learn more at [mistserver.org](https://mistserver.org).

---

## 🔒 Security Best Practices

> [!IMPORTANT]
> **NEVER IGNORE SECURITY!** Exposing your server to the open internet with default settings is high risk.

1.  **Complex SSH Password:** During installation, set a strong SSH password (avoid defaults like `Tmux2026`). Use at least 12 characters with a mix of letters, numbers, and symbols.
2.  **MistServer Admin:** Immediately after installation, access the MistServer admin panel (`http://IP:4242`) to set a unique username and a complex password.
3.  **Whitelist Management:** Keep only trusted domains in your Nginx whitelist (`/etc/nginx/streaming-whitelist`). Avoid using the catch-all `~.* 1;` rule.
4.  **Minimal Port Exposure:** Only forward necessary ports (`1935`, `8080`) on your router. If external SSH access (`8022`) isn't required, disable its port forwarding rule.

---

## 🛠️ Manual Installation Guide

<details>
<summary><b>Click to expand manual steps</b></summary>

### Step 1: Base Packages
```bash
pkg update && pkg upgrade
pkg install nginx openssh tmux termux-api
```

### Step 2: Set up Ubuntu Container
```bash
pkg install proot-distro
proot-distro install ubuntu
proot-distro login ubuntu
```

### Step 3: Install MistServer (inside Ubuntu)
```bash
apt update && apt install curl -y
curl -o - https://releases.mistserver.org/is/mistserver_aarch64V3.10.tar.gz | sh
```

### Step 4: Configure Aliases
Add aliases from `scripts/bashrc` to your `~/.bashrc` to enable shortcuts like `s-start`, `s-stop`, and `s-status`.

</details>

---

## 🔍 Troubleshooting & Verification

### Logs
- Nginx: `tail -f $PREFIX/var/log/nginx/error.log`
- MistServer: Check the admin panel at port `4242`.

### Port Availability
Use `netstat -tulpn` to ensure ports `1935`, `4242`, `8080`, and `8022` are listening.

---

## 🗺️ Roadmap & Version History

See the version history and future plans below:

- **v1.1.0 (Latest):** Removed Cloudflare, moved to port forwarding, added security docs, split documentation.
- **v1.0.0:** Initial release.

[Full Roadmap Details]...
