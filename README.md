# Android-Based High-Performance Media Streaming Server

**Transforming a Redmi Note 10S into a Dedicated RTMP to HLS/SRT Gateway**

> [!CAUTION]
> **THIS IS NOT PRODUCTION SAFE.** Primarily for **educational and home-lab purposes**. Lacks advanced security hardening and enterprise-grade redundancy.

---

## 📖 Quick Start Guide

This project repurposes consumer Android hardware into a robust, 24/7 streaming media server using **Termux**, **Nginx**, and **MistServer**.

### 🚀 One-Command Install

Run this in your Termux terminal and follow the prompts:

```bash
curl -fsSL https://raw.githubusercontent.com/starskg/android-media-server/main/install.sh | bash
```

### 📋 Main Commands

- **`s-start`**: Start all services (Nginx, SSH, MistServer)
- **`s-stop`**: Stop all services
- **`check-status`**: Check service health and port availability
- **`uninstall`**: Remove all project components

---

## 📚 Documentation

For in-depth guides, security practices, and architecture details, please refer to:

👉 **[Detailed Documentation (DOCUMENTATION.md)](DOCUMENTATION.md)**

---

## 📡 Port Forwarding (Router Settings)

For external access, forward these ports to your device's local IP:

| Protocol | Port | Service |
|----------|------|---------|
| TCP | 1935 | RTMP Ingest (OBS) |
| TCP | 8080 | Nginx Proxy (HLS/SRT) |
| TCP | 4242 | MistServer Admin |
| TCP | 8022 | SSH Remote Access |

---

## 🔗 Related Projects

| Project | Platform | Description |
|---------|----------|-------------|
| **[android-media-server](https://github.com/starskg/android-media-server)** | 🤖 Android | This project (Termux setup) |
| **[ubuntu-media-server](https://github.com/starskg/ubuntu-media-server)** | 🖥️ Linux | Native setup for Ubuntu/Debian |

---

## 📧 Contact & Contributions

- **GitHub**: [@starskg](https://github.com/starskg)
- **Issues**: [Report a bug](../../issues)

**⭐ If you find this project useful, please consider giving it a star!**
