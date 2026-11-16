# 🦅 raven-dots

> **raven-dots** is a tailored, ultra-fast, and minimalist Wayland desktop setup for **Hyprland**, featuring Material You dynamic theming, custom window aesthetics, and a 3D Coverflow wallpaper picker.
> 
> *Architected for speed, clean aesthetics, and effortless portability across Linux distributions.*

---

## ✨ Features & Visual Highlights

- **Window Aesthetics**:
  - **Sharp 90° Geometry**: Pure squared window corners (`rounding = 0`) for a clean, professional aesthetic.
  - **Calibrated Transparency**: `95%` active opacity, `88%` inactive opacity, with full `100%` solid fullscreen windows (YouTube, Netflix, etc. remain completely opaque).
  - **Refined Blur**: Ultra-low latency dual-pass blur (`size = 3, passes = 2`) preventing GPU strain while keeping background text readable.
  - **Subtle Inactive Window Dimming**: Gentle `0.08` dim strength.
- **3D Coverflow Wallpaper Picker (`Super + W`)**:
  - Single-instance toggle (`Super + W` to open, `Super + W` or `Esc` to close).
  - High-performance Coverflow carousel with mouse scroll wheel support, single-click glide, and double-click apply.
  - Square solid-color filter bar (Dark, Light, Red, Orange, Yellow, Green, Blue, Purple, Pink, All) with instant active checkmark.
- **Global Dark / Light Mode Synchronization**:
  - One-click dark/light mode toggle from the status bar.
  - Seamlessly syncs GNOME GSettings, DConf, GTK-3.0 (`settings.ini`), GTK-4.0 Libadwaita, Flatpak sandbox environments, and FreeDesktop Portals.
- **Modular Arch / Extensible Structure**:
  - Built cleanly on top of the robust `illogical-impulse` Quickshell engine.
  - All user custom overrides are isolated cleanly in `dots/.config/hypr/custom/` to guarantee smooth, conflict-free updates.

---

## 🚀 Installation

### 1. Fresh Installation on New Linux Distro

Clone your repository and execute the built-in installer:

```bash
# Clone raven-dots
git clone https://github.com/xzhrael/raven-dots.git ~/raven-dots
cd ~/raven-dots

# Run setup
./setup install
```

The `./setup install` script will automatically:
1. Install all necessary dependencies for your distribution (Arch, Fedora, Gentoo, etc.).
2. Set up systemd user services, permissions, and environments.
3. Deploy all configuration files cleanly to `~/.config/` and `~/.local/share/`.

### 2. Updating raven-dots

To pull your latest configs and apply them:

```bash
cd ~/raven-dots
git pull
./setup install-files
```

---

## ⌨️ Essential Keybindings

| Keybind | Action |
| :--- | :--- |
| <kbd>Super</kbd> + <kbd>Return</kbd> | Open Terminal (`kitty`) |
| <kbd>Super</kbd> + <kbd>E</kbd> | Open File Manager (`nautilus`) |
| <kbd>Super</kbd> + <kbd>B</kbd> | Open Web Browser (`helium` / `brave`) |
| <kbd>Super</kbd> + <kbd>W</kbd> | **Toggle 3D Coverflow Wallpaper Selector** |
| <kbd>Super</kbd> + <kbd>Q</kbd> | Close Active Window |
| <kbd>Super</kbd> + <kbd>Space</kbd> | Toggle Window Floating / Tiling |
| <kbd>Super</kbd> + <kbd>N</kbd> | Open Right Sidebar / Quick Settings |
| <kbd>Super</kbd> + <kbd>Tab</kbd> | Toggle Workspaces Overview |
| <kbd>Ctrl</kbd> + <kbd>Super</kbd> + <kbd>T</kbd> | Regenerate Wallpaper Colors (Matugen) |

---

## 📂 Configuration Layout

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

## ⚖️ License & Notice of Modification

This project is licensed under the **GNU General Public License v3.0 (GPL-3.0)** - see the [LICENSE](LICENSE) file for details.

### Notice of Modification (GPLv3 §5.a)
`raven-dots` is a customized fork and derivative work based on [end-4/dots-hyprland (illogical-impulse)](https://github.com/end-4/dots-hyprland), originally developed by **end-4** and community contributors under the GNU GPLv3.

**Key modifications introduced in `raven-dots` (November 2026):**
- **Window Aesthetics**: Sharp 90° window geometry (`rounding = 0`), adjusted active/inactive window opacity (`0.95` / `0.88`), calibrated low-latency dual-pass blur (`size = 3, passes = 2`), and subtle inactive window dimming.
- **3D Coverflow Wallpaper Picker**: Integrated and enhanced `hyprquickpaper` 3D carousel with single-instance toggle (`Super + W`), mouse wheel scrolling, double-click application, and square solid-color filters.
- **Global Theme Synchronization**: Built `sync-theme.sh` engine harmonizing dark/light mode across GSettings, DConf, GTK-3.0, GTK-4.0 Libadwaita, Qt, Flatpak sandboxes, and XDG Desktop Portals.
- **Rebranding & Portability**: Rebranded configuration metadata and standalone documentation for seamless installation across new Linux distributions via `./setup install`.

All original copyrights, licenses, and author notices are strictly retained and respected in accordance with GPL-3.0.

---

## 🙏 Credits & Acknowledgments

- **Base Desktop Shell & Engine**: [end-4/dots-hyprland (illogical-impulse)](https://github.com/end-4/dots-hyprland)
- **Wallpaper Coverflow Inspiration**: [43PR](https://github.com/43pr)
- **Wayland Shell Framework**: [outfoxxed/quickshell](https://github.com/outfoxxed/quickshell)
- **Dynamic Theming**: [InioX/matugen](https://github.com/InioX/matugen)
