# 🦅 raven-dots

> **A refined, distraction-free Wayland desktop environment for Hyprland.**  
> Crafted with sharp 90° geometry, dynamic Material You color schemes, an interactive 3D Coverflow wallpaper picker, and a fully integrated terminal suite.

---

### ⚡ Highlights at a Glance

* **Sharp Geometric Styling**: Zero border rounding (`rounding = 0`) across all windows for a clean architectural look.
* **Tuned Opacity Profile**: `95%` active window opacity, `88%` inactive opacity for natural visual depth, and automatic `100%` solid fullscreen windows (YouTube, Netflix, games).
* **3D Coverflow Wallpaper Selector (`Super + W`)**: Single-instance toggle (press <kbd>Super</kbd> + <kbd>W</kbd> to open; press <kbd>Super</kbd> + <kbd>W</kbd> or <kbd>Esc</kbd> to close). Features high-FPS card glide, mouse wheel scrolling, and solid-color category chips with active indicators.
* **Unified Terminal & Fastfetch**: Built-in `kitty` terminal paired with `fish` shell, custom `starship` prompt (` `), and customized `fastfetch` displaying personalized ASCII art and system telemetry on launch.
* **Universal Theme Synchronization**: Single-click dark/light toggle seamlessly propagating across GNOME GSettings, DConf, GTK-3, GTK-4 Libadwaita, Flatpak sandboxes, and XDG Desktop Portals.

---

## 🖥️ Terminal & Shell Environment

| Component | Configuration | Key Features |
| :--- | :--- | :--- |
| **Terminal** | `kitty` | JetBrains Mono Nerd Font, dynamic palette reload, borderless comfort padding (`21.75`) |
| **Shell** | `fish` | Interactive autosuggestions, syntax highlighting, integrated PATH management |
| **Prompt** | `starship` | Minimalist execution status and git status indicator (` `) |
| **Sysinfo** | `fastfetch` | Fast modular system fetch with custom monochrome logo and hardware metrics |

---

## 🚀 Installation & Deployment

### Fresh Machine Installation

To install `raven-dots` on a fresh Linux installation (Arch, Fedora, openSUSE, etc.):

```bash
# 1. Clone the private repository
git clone git@github.com:xzhrael/raven-dots.git ~/raven-dots
cd ~/raven-dots

# 2. Run the automated installer
./setup install
```

The installer will:
1. Detect your package manager and install core Wayland, Hyprland, audio, and shell dependencies (including `fastfetch` and `kitty`).
2. Deploy all dotfiles cleanly to `~/.config/` and `~/.local/share/`.
3. Configure user environment variables and services.

### Syncing Updates

To apply updates on an existing installation:

```bash
cd ~/raven-dots
git pull
./setup install-files
```

---

## ⌨️ Essential Keybindings

| Shortcut | Action |
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

## 📂 Configuration Structure

```text
raven-dots/
├── dots/
│   ├── .config/
│   │   ├── fastfetch/       # System information fetch & custom ASCII logo
│   │   ├── fish/            # Shell interactive startup & aliases
│   │   ├── kitty/           # Terminal configuration & search helper
│   │   ├── starship.toml    # Shell prompt configuration
│   │   ├── hypr/
│   │   │   ├── custom/      # User customizations (rounding, blur, keybinds, sync-theme.sh)
│   │   │   └── hyprland/    # Core Hyprland rules, animations, and monitor bindings
│   │   ├── quickshell/
│   │   │   ├── hyprquickpaper/ # 3D Coverflow wallpaper picker
│   │   │   └── ii/             # Status bar, sidebars, dock, and control center
│   │   ├── gtk-3.0/         # GTK3 dark/light settings
│   │   ├── gtk-4.0/         # GTK4 Libadwaita settings
│   │   └── matugen/         # Material You dynamic palette templates
├── sdata/                   # Distro package scripts & dependency definitions
└── setup                    # Main installer & updater script
```

---

## ⚖️ License & Upstream Foundation

This project is licensed under the **GNU General Public License v3.0 (GPL-3.0)**. See the [LICENSE](LICENSE) file for complete terms.

```text
raven-dots is developed and maintained by xzhrael.
Based on the foundation of end-4/dots-hyprland under the GNU General Public License v3.0.
```
