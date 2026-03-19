# Android-Based High-Performance Media Streaming Server

**Transforming a Redmi Note 10S into a Dedicated RTMP to HLS/SRT Gateway**

> [!CAUTION]
> **THIS IS NOT PRODUCTION SAFE.** Primarily for **educational and home-lab purposes**.

> 🖥️ **Looking for the Ubuntu/Debian version?** → [ubuntu-media-server](https://github.com/starskg/ubuntu-media-server)

---

## 📖 Overview

This project repurposes consumer Android hardware into a robust, 24/7 streaming media server using **Termux**, **Nginx**, and **MistServer**.

### Key Features

- ✅ **Zero Transcoding Load**: Efficient remuxing results in near 0% CPU usage
- ✅ **Custom CORS Handling**: Fixed cross-origin issues for web players
- ✅ **Persistence**: Optimized against Android process killing
- ✅ **Remote Management**: SSH access on port 8022
- ✅ **Whitelist Security**: Domain-based access control
- ✅ **Direct Port Forwarding**: Full UDP/TCP support via router
- ✅ **Web File Manager**: Optional File Browser on port 9999

---

## 🏗️ Architecture Stack

| Layer | Component | Role |
|-------|-----------|------|
| **OS (Android)** | Termux | Host environment |
| **Proxy** | Nginx | HTTP Reverse Proxy & CORS |
| **Container** | Ubuntu (PRoot) | Isolated Linux environment |
| **Media Engine** | MistServer | RTMP Ingest → HLS/SRT Egress |

---

## 🚀 Quick Start Guide

### One-Command Install

Run this in Termux and follow the prompts:

```bash
curl -fsSL https://raw.githubusercontent.com/starskg/android-media-server/main/install.sh | bash
```

### 📋 Main Commands

- **`s-start`**: Start all services
- **`s-stop`**: Stop all services
- **`check-status`**: Check health & ports
- **`uninstall`**: Remove components

---

## 📚 Detailed Documentation

For advanced features, security practices, and troubleshooting:

👉 **[Read DOCUMENTATION.md](DOCUMENTATION.md)**

---

## 📡 Port Forwarding

Forward these ports to your device's local IP:
- **TCP 1935**: RTMP Ingest (OBS)
- **TCP 8080**: Nginx Proxy (HLS)
- **TCP 4242**: MistServer Admin
- **TCP 8022**: SSH Access

---

## 📧 Contact

**GitHub**: [@starskg](https://github.com/starskg)

**⭐ If you find this project useful, please consider giving it a star!**
