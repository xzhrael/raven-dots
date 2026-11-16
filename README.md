# 🦅 raven-dots

<p align="center">
  <b>A sleek, high-performance, and minimalist Hyprland desktop environment.</b><br>
  <i>Tailored for speed, sharp geometric aesthetics, dynamic Material You theming, and seamless workflow.</i>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Hyprland-Wayland-00c853?style=for-the-badge&logo=hyprland&logoColor=white" alt="Hyprland" />
  <img src="https://img.shields.io/badge/Shell-Quickshell-7c4dff?style=for-the-badge" alt="Quickshell" />
  <img src="https://img.shields.io/badge/License-GPL--3.0-blue?style=for-the-badge" alt="License: GPL-3.0" />
</p>

---

## 🌟 Overview

**raven-dots** is a complete, standalone Wayland desktop suite engineered for users who value razor-sharp window geometry, low-latency rendering, distraction-free productivity, and dynamic color harmony.

Every component has been refined to eliminate visual clutter, reduce resource overhead, and deliver an intuitive, out-of-the-box experience on any Linux distribution.

---

## ✨ Key Features & Aesthetic Pillars

### 🔲 Sharp Geometric Window Styling
- **Pure 90° Squared Windows**: Zero rounded borders (`rounding = 0`) creating a sharp, modern workstation feel.
- **Tuned Opacity Profile**: `95%` active window opacity for crystal focus, `88%` inactive opacity for depth perception.
- **True Opaque Fullscreen**: Video players, YouTube, Netflix, and fullscreen apps automatically stay `100%` solid without dimming or transparency leakage.
- **Efficient Dual-Pass Blur**: Calibrated low-radius blur (`size = 3, passes = 2`) designed to conserve GPU cycles while keeping underlying desktop context legible.
- **Subtle Inactive Window Dimming**: Soft `0.08` dimming to keep your eyes focused on the primary task.

### 🖼️ 3D Coverflow Wallpaper Selector (`Super + W`)
- **Single-Instance Toggle**: Tap <kbd>Super</kbd> + <kbd>W</kbd> to open; tap <kbd>Super</kbd> + <kbd>W</kbd> or <kbd>Esc</kbd> to close. Never spawns duplicate windows.
- **Smooth Navigation**: High-FPS carousel navigation with native mouse wheel scroll accumulator, single-click card glide, and double-click immediate wallpaper activation.
- **Square Color Filter Bar**: Solid-color square swatches with high-contrast outlines for Dark, Light, Red, Orange, Yellow, Green, Blue, Purple, and Pink collections.
- **Active Selection**: Instant checkmark (`✓`) feedback on the active color swatch, with toggle-to-reset back to all wallpapers.

### 🌓 Universal Dark / Light Mode Engine (`sync-theme.sh`)
- Instant one-click toggle from the desktop status bar.
- **100% Synchronized Across All Toolkits**:
  - **GNOME GSettings & DConf**: Dynamically sets `prefer-dark` vs `prefer-light` and `adw-gtk3-dark` vs `adw-gtk3`.
  - **GTK3 & GTK4 Configuration**: Updates `~/.config/gtk-3.0/settings.ini` and `~/.config/gtk-4.0/settings.ini` in real time.
  - **Flatpak Sandbox Integration**: Automatically broadcasts theme environments to isolated Flatpak apps.
  - **XDG Desktop Portal**: Live portal notification ensuring browsers (Firefox, Chrome, Brave) and Electron apps (VS Code, Discord, Obsidian) follow the desktop mode instantly.

---

## 🚀 Quickstart & Installation

### Fresh System Installation

Clone **raven-dots** and run the automated installer:

```bash
# 1. Clone the repository
git clone https://github.com/xzhrael/raven-dots.git ~/raven-dots
cd ~/raven-dots

# 2. Run the automated setup installer
./setup install
```

The installer handles:
1. Detecting your distribution package manager (Arch, Fedora, openSUSE, Gentoo, etc.).
2. Installing essential Wayland, Hyprland, audio, and Quickshell dependencies.
3. Deploying configurations cleanly to your system.
4. Setting up required environment variables and services.

### Updating raven-dots

To sync and update your configuration files in-place:

```bash
cd ~/raven-dots
git pull
./setup install-files
```

---

## ⌨️ Essential Shortcuts

| Shortcut | Description |
| :--- | :--- |
| <kbd>Super</kbd> + <kbd>Return</kbd> | Launch Terminal (`kitty`) |
| <kbd>Super</kbd> + <kbd>E</kbd> | Launch File Manager (`nautilus`) |
| <kbd>Super</kbd> + <kbd>B</kbd> | Launch Web Browser |
| <kbd>Super</kbd> + <kbd>W</kbd> | **Toggle 3D Coverflow Wallpaper Selector** |
| <kbd>Super</kbd> + <kbd>Q</kbd> | Close Focused Window |
| <kbd>Super</kbd> + <kbd>Space</kbd> | Toggle Window Tiling / Floating |
| <kbd>Super</kbd> + <kbd>N</kbd> | Open Right Sidebar & System Controls |
| <kbd>Super</kbd> + <kbd>Tab</kbd> | Workspaces Overview |
| <kbd>Ctrl</kbd> + <kbd>Super</kbd> + <kbd>T</kbd> | Refresh Wallpaper Dynamic Palette (Matugen) |
| <kbd>Super</kbd> + <kbd>/</kbd> | Open Complete Keybinds Cheatsheet |

---

## 📂 Project Architecture

```text
raven-dots/
├── dots/
│   ├── .config/
│   │   ├── hypr/
│   │   │   ├── custom/          # Custom user overrides (general, keybinds, rules, scripts)
│   │   │   │   ├── general.lua  # Blur, opacity, gaps, and window rounding
│   │   │   │   ├── keybinds.lua # Super+W and custom shortcut bindings
│   │   │   │   └── scripts/     # sync-theme.sh (global theme synchronizer)
│   │   │   └── hyprland/        # Core Hyprland configuration
│   │   ├── quickshell/
│   │   │   ├── hyprquickpaper/  # 3D Coverflow wallpaper picker component
│   │   │   └── ii/              # Main desktop bar, dock, and sidebar
│   │   ├── gtk-3.0/             # GTK3 dark/light settings.ini
│   │   ├── gtk-4.0/             # GTK4 Libadwaita settings.ini
│   │   ├── matugen/             # Material You color templates
│   │   └── xdg-desktop-portal/  # Portal routing (portals.conf)
├── sdata/                       # Automated multi-distro installer scripts
└── setup                        # Unified setup script (./setup install)
```

---

## ⚖️ License & Attribution

This project is licensed under the **GNU General Public License v3.0 (GPL-3.0)** - see the [LICENSE](LICENSE) file for details.

> **Upstream Attribution & Foundation:**  
> `raven-dots` is a customized distribution based on the foundation of [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) under the GNU GPLv3 license.  
> Wallpaper Coverflow carousel inspired by [43PR](https://github.com/43pr). Powered by [Quickshell](https://github.com/outfoxxed/quickshell) and [Matugen](https://github.com/InioX/matugen).
