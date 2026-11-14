# Remote Spotlight ⚡️
### Search Remote Windows Desktops, Linux Servers & NAS Disks from a Native Apple Siri / Spotlight Bar in <5ms.

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13.0%2B%20(Ventura%20%7C%20Sonoma%20%7C%20Sequoia)-000000?style=for-the-badge&logo=apple&logoColor=white" alt="macOS" />
  <img src="https://img.shields.io/badge/Swift-5.9%2B-FA7343?style=for-the-badge&logo=swift&logoColor=white" alt="Swift" />
  <img src="https://img.shields.io/badge/Search%20Speed-%3C5ms%20(SQLite%20FTS5)-34D399?style=for-the-badge&logo=speedtest&logoColor=white" alt="Search Speed" />
  <img src="https://img.shields.io/badge/Material-Apple%20Liquid%20Glass-60A5FA?style=for-the-badge" alt="Apple Liquid Glass" />
  <img src="https://img.shields.io/badge/Mesh-Tailscale%20%7C%20SSH-4969ED?style=for-the-badge&logo=tailscale&logoColor=white" alt="Tailscale" />
  <img src="https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge" alt="License: MIT" />
</p>

---

## 💡 Why Remote Spotlight?

If you work across multiple machines — such as a **MacBook on the go**, a **heavy Windows workstation at home (e.g. `B:\` drive)**, a **headless Linux server**, or a **home NAS** — you know the pain of network shares:

* ❌ **SMB and NFS mounts freeze macOS Finder** whenever network latency spikes.
* ❌ Native macOS Spotlight **cannot index remote drives** without severe performance degradation.
* ❌ Searching for an invoice, 3D model, or PDF on another machine requires opening an SSH terminal, typing `grep` or `find`, and waiting.

**Remote Spotlight solves this completely.** It gives you a gorgeous, floating **Apple Siri-style search bar** with instant keystroke response (<5ms) that searches across all your remote machines and pulls files on demand.

```
                     ┌──────────────────────────────────────────────┐
                     │  🔍  Search remote disks, servers, or ask AI │
                     └──────────────────────┬───────────────────────┘
                                            │
                                ┌───────────┴───────────┐
                                ▼                       ▼
                     [ Instant Local Search ]   [ On-Demand Fetch ]
                        SQLite FTS5 (BM25)        Streaming via SSH
                         Keystroke: <5ms           Enter: Opens locally
                                │                       │
                   ┌────────────┴───────────────────────┴────────────┐
                   ▼                                                 ▼
        [ Remote Windows PC ]                             [ Headless Linux / NAS ]
       • Fast local disk cache                           • Tailscale / WireGuard mesh
       • B:\, D:\, Project files                         • Remote documents & media
```

---

## ✨ Features at a Glance

* **💎 Genuine Apple Liquid Glass Material:** Implements genuine macOS private materials (`NSVisualEffectView` + `NSGlassEffectView`) with tuned specular rim lighting (`alphaValue: 0.35`) and frosted-glass blur that looks identical to Apple's native Siri bar on macOS Sequoia.
* **⚡️ Sub-5ms Keystroke Latency:** Driven by a local, ultra-compressed SQLite FTS5 (BM25) search index (~10-25 MB). Every keystroke queries locally without making blocking network requests.
* **🎯 True Global Keyboard Focus:** Press `⌥ + Space` (Option + Space) from any app. The floating bar appears and captures keyboard focus immediately — no mouse click needed.
* **📂 On-Demand Remote Fetching:** Hitting `Enter` on any search result securely pulls the file from your remote host via SSH/SCP and launches it immediately in your native Mac app (Preview, Xcode, VS Code, etc.).
* **👁 QuickLook & Finder Integration:**
  * `Enter`: Stream file from remote machine and open locally.
  * `Space`: Instant QuickLook preview.
  * `⌘ + Shift + F`: Reveal file in macOS Finder.
  * `⌘ + C`: Copy match snippet to clipboard.
  * `Esc`: Dismiss immediately.
* **🔒 100% Privacy-First & Offline-Ready:** Zero telemetry, zero analytics, zero external cloud dependencies. Operates strictly over your existing SSH keys and local configuration.

---

## 📐 Visual Geometry (Apple Siri 1:1 Specification)

Remote Spotlight adheres strictly to macOS Human Interface Guidelines:

| Element | Specification |
| :--- | :--- |
| **Initial Pill Dimensions** | `550 px` width × `52 px` height (Corner Radius: `26 px` Capsule) |
| **Expanded Results Card** | `550 px` width × `420 px` height (Corner Radius: `22 px`) |
| **Screen Anchor** | Perfectly centered horizontally (`midX`), floating optical center (`midY + 50`) |
| **Glass Materials** | Dual-layer: `HUD Frosted Window Blur` + `NSGlassEffectView` Refraction |
| **Specular Control** | Calibrated dark backing (`NSColor(white: 0.08, alpha: 0.70)`) to prevent glare |
| **Hairline Stroke** | `0.5 px` border with `white.opacity(0.12)` (Pill) and `0.08` (Card) |

---

## 🚀 Quickstart (30 Seconds)

### 1. Build and Install
Remote Spotlight is lightweight Swift with zero heavy third-party package dependencies:

```bash
# Clone the repository
git clone https://github.com/benfirad/remote-spotlight.git
cd remote-spotlight

# Build the native app bundle
./build.sh

# Move to Applications
cp -R "build/RMOS Spotlight.app" /Applications/
```

### 2. Configure Your Remote Machines
Create your configuration file at `~/.config/remote-spotlight/config.json`:

```json
{
  "remoteTargets": [
    {
      "name": "Workstation (Windows B:\\)",
      "host": "my-windows-desktop",
      "rootPath": "B:/Projects"
    },
    {
      "name": "Home Server (Linux)",
      "host": "100.106.212.28",
      "rootPath": "/var/storage/docs"
    }
  ],
  "localCacheDbPath": "~/.cache/remote-spotlight/index.db",
  "cliToolPath": "/usr/local/bin/remote-spotlight",
  "searchPrefix": "search",
  "hotKeyModifiers": "option",
  "hotKeyCode": 49
}
```

*Note: If you use standard SSH configs (`~/.ssh/config`), you can use any configured host alias directly.*

---

## ⌨️ Keyboard Shortcuts Reference

| Shortcut | Description |
| :--- | :--- |
| **`⌥ + Space`** | **Toggle Remote Spotlight globally from anywhere** |
| **`↑` / `↓`** | Navigate through search results with auto-scroll |
| **`Enter`** | Fetch target file from remote PC and launch in macOS |
| **`Space`** | Preview selected result with native QuickLook |
| **`⌘ + Shift + F`** | Reveal file location in macOS Finder |
| **`⌘ + C`** | Copy result path or snippet to clipboard |
| **`Esc`** | Clear query or close Spotlight window |

---

## 🛠 Technical Architecture

Remote Spotlight decouples the **search engine** from the **file transmission channel**:

1. **Remote Indexing Agent:** A lightweight indexer extracts file paths, titles, and text chunks into a compact SQLite FTS5 table with Porter stemmer and BM25 ranking.
2. **Local Cache Synchronization:** The database is mirrored to `~/.cache/remote-spotlight/index.db` in the background (via cron, Tailscale sync, or `rsync`).
3. **AppKit Non-Activating Floating Panel:** Uses a custom `NSPanel` with `.nonactivatingPanel` and `becomesKeyOnlyIfNeeded = false`. This guarantees **zero frame drop** and zero lag when opening, even during full-screen gaming or intensive video rendering.
4. **On-Demand Secure File Streaming:** When you select a result, `FileLocator` resolves the target machine from your config and streams the binary over SSH directly into temporary macOS application storage.

---

## 📄 License & Attribution

Distributed under the **MIT License**. See [LICENSE](LICENSE) for details.  
Copyright (c) 2026 daak ([@benfirad](https://github.com/benfirad)).  
Architectural design and distributed cross-device search protocols registered in RM-OS R&D Invention Register.
