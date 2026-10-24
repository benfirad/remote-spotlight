# Remote Spotlight ⚡️
### Search Remote Windows Desktops, Linux Servers & Cloud Disks from a Native macOS Spotlight Bar in <5ms.

[![macOS](https://img.shields.io/badge/macOS-13.0%2B%20(Ventura%20%7C%20Sonoma%20%7C%20Sequoia)-black?style=for-the-badge&logo=apple)](https://apple.com)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-FA7343?style=for-the-badge&logo=swift)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE)
[![Search Latency](https://img.shields.io/badge/Latency-%3C5ms%20FTS5-success?style=for-the-badge&logo=speedtest)](https://github.com/benfirad/remote-spotlight)
[![Tailscale Ready](https://img.shields.io/badge/Mesh-Tailscale%20%7C%20SSH-4969ED?style=for-the-badge&logo=tailscale)](https://tailscale.com)

---

**Remote Spotlight** is a lightweight, blazing-fast native macOS menu bar & global hotkey application that brings native Spotlight search capabilities to your **remote computers** — including Windows workstations, headless Mac mini servers, Linux storage boxes, and NAS drives across local networks or Tailscale / WireGuard meshes.

Instead of mounting slow, laggy SMB/NFS network shares that freeze Finder, Remote Spotlight uses an **asynchronous lightweight local SQLite FTS5 index** combined with **on-demand cross-device file streaming**.

```
[ Local Mac ] ──(⌥ + Space)──> [ Remote Spotlight UI (<5ms) ]
                                       │
                      ┌────────────────┴────────────────┐
                      ▼                                 ▼
             [ Local FTS5 Cache ]             [ On-Demand SCP/SSH ]
             (~25 MB SQLite DB)                         │
                      ▲                                 ▼
             (Sync in background)           [ Remote Disks & Servers ]
                                            • Windows Workstation (B:\)
                                            • Headless Linux/Mac Server
                                            • Tailscale Mesh Network
```

---

## ✨ Features

- **⚡️ Sub-5ms Search Speed:** Powered by a compact SQLite FTS5 BM25 search index. Queries complete in 1 to 4 milliseconds, even across tens of thousands of remote files and document contents.
- **💎 Apple Liquid Glass Material:** Built with native SwiftUI and AppKit glass effects, subtle floating shadows, and borderless curved geometry that feels like a built-in macOS system feature.
- **🎯 Immediate Keyboard Capture:** Press `⌥ + Space` (Option + Space) anywhere. The window opens and immediately acquires keyboard focus so you can start typing instantly without touching your mouse.
- **📂 On-Demand Remote Fetching:** Press `Enter` on any search result. Remote Spotlight automatically pulls the target PDF, document, image, or project file from the remote machine via SSH/SCP and launches it in your default Mac application.
- **🔍 QuickLook & Finder Integration:**
  - `Enter`: Fetch and open file locally.
  - `Space`: QuickLook preview.
  - `⌘ + Shift + F`: Reveal in macOS Finder.
  - `⌘ + C`: Copy match snippet to clipboard.
  - `⌘ + Shift + C`: Copy remote CLI command.
- **🛡 100% Privacy-First:** Works purely over standard SSH keys (`~/.ssh/config`). No third-party servers, no telemetry, no cloud dependencies.

---

## 🚀 Quickstart

### 1. Clone & Build
```bash
git clone https://github.com/benfirad/remote-spotlight.git
cd remote-spotlight

# Build and install directly to /Applications
./install.sh
```

### 2. Configure Your Remote Machines
Create a configuration file at `~/.config/remote-spotlight/config.json`:
```json
{
  "remoteTargets": [
    {
      "name": "Windows Desktop",
      "host": "my-windows-pc",
      "rootPath": "D:/MyProjects"
    },
    {
      "name": "Home Server",
      "host": "server-tailscale",
      "rootPath": "/mnt/storage/Documents"
    }
  ],
  "localCacheDbPath": "~/.cache/remote-spotlight/index.db",
  "cliToolPath": "/usr/local/bin/remote-spotlight",
  "searchPrefix": "search",
  "hotKeyModifiers": "option",
  "hotKeyCode": 49
}
```

---

## ⌨️ Global Keyboard Shortcut

| Shortcut | Action |
| :--- | :--- |
| **`⌥ + Space`** | **Toggle Remote Spotlight from any application** |
| **`↑ / ↓`** | Navigate through search results |
| **`Enter`** | Fetch file from remote PC and open in macOS |
| **`Space`** | Preview file with QuickLook |
| **`⌘ + Shift + F`** | Reveal file in Finder |
| **`⌘ + C`** | Copy text excerpt to clipboard |
| **`Esc`** | Close Spotlight |

---

## 🛠 Architecture & Performance

Remote Spotlight achieves zero UI latency by decoupling the **search loop** from the **remote network filesystem**:

1. **Indexer Daemon (Remote):** An indexing script runs periodically on the remote machine (or during background sync), extracting text, metadata, and chunk summaries into a compact SQLite FTS5 database.
2. **Local Cache Engine:** The compressed SQLite FTS5 database (~10-25 MB) is synchronized locally. All keystrokes query the local SQLite engine using BM25 ranking in under 5 ms.
3. **On-Demand Fetcher (`FileLocator`):** When a user triggers an action (e.g. hitting Enter to open a PDF or CAD file), Remote Spotlight resolves candidate paths across configured remote nodes and streams the file over secure SSH into a local cache directory (`~/.cache/remote-spotlight/downloads`).

---

## 📄 License & Intellectual Property

This project is open-source under the [MIT License](LICENSE).
Architectural design and distributed cross-device search protocols registered in RM-OS R&D Invention Register.
Copyright (c) 2026 Fırat Daşdöğen / DAAK.
